--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharmConfig = require(ReplicatedStorage.Config.Charms)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Charms = require(ReplicatedStorage.Rules.Charms)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)

type TroveInstance = typeof(Trove.new())
type CachedCard = { Frame: Frame, Cleanup: () -> (), Signature: string }
type Entry = {
	Charm: CharmConfig.Charm,
	Count: number,
}

local theme = Kit.Theme
local columns = 3
local cardHeight = 124
local cardGap = 10
local chipHeight = 44
local chipGap = 12
local kindOrder: { string } = { "Income", "Luck", "Speed", "Golden", "Steal", "Laser" }

local function trim(value: number): string
	return string.format("%g", math.floor(value * 100 + 0.5) / 100)
end

local function bonusText(kind: string, effects: Charms.Effects): string?
	if kind == "Income" and effects.Income ~= 1 then
		return `x{trim(effects.Income)} Income`
	elseif kind == "Luck" and effects.Luck ~= 1 then
		return `x{trim(effects.Luck)} Luck`
	elseif kind == "Speed" and effects.Speed ~= 1 then
		return `+{trim((effects.Speed - 1) * 100)}% Roll Speed`
	elseif kind == "Golden" and effects.GoldenReduction ~= 0 then
		return `Golden -{trim(effects.GoldenReduction)} rolls`
	elseif kind == "Steal" and effects.StealSpeed ~= 1 then
		return `+{trim((effects.StealSpeed - 1) * 100)}% Steal Speed`
	elseif kind == "Laser" and effects.LaserSeconds ~= 0 then
		return `+{trim(effects.LaserSeconds)}s Laser`
	end
	return nil
end

local function rowsFor(count: number): number
	return math.max(1, math.ceil(count / columns))
end

local function sortEntries(entries: { Entry })
	table.sort(entries, function(a: Entry, b: Entry)
		local scoreA, scoreB = Charms.Score(a.Charm.Id), Charms.Score(b.Charm.Id)
		if scoreA ~= scoreB then
			return scoreA > scoreB
		end
		return a.Charm.Id < b.Charm.Id
	end)
end

local PetsScreen = {}

function PetsScreen.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local renderTrove = Trove.new()
	local dataController = context.Controllers.DataController
	local rollController = context.Controllers.RollController
	local playUi = Kit.UiSound(context.Controllers)
	local owned: { [string]: number } = {}
	local cards: { [string]: CachedCard } = {}
	local lastSignature: string? = nil

	trove:Add(function()
		renderTrove:Destroy()
		for _, cached in cards do
			cached.Cleanup()
		end
		table.clear(cards)
	end)

	local modal = Kit.Modal(trove, {
		Parent = context.PlayerGui,
		Name = "Pets",
		Title = "PETS",
		Glyph = "Heart",
		MaxSize = Vector2.new(900, 640),
		HeaderColor = theme.Gold,
		OnClose = function()
			context.Close("Pets")
		end,
	})
	local ownedPill = Kit.Pill({
		Parent = modal.HeaderRight,
		Name = "Owned",
		Glyph = "Heart",
		Text = "0 pets",
		Size = UDim2.fromOffset(170, 40),
		TextSize = Kit.Text.Strong,
		Color = theme.Track,
	})
	local scroll = Kit.Scroll({
		Parent = modal.Body,
		Name = "Content",
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12),
		Padding = Kit.Space.M,
	})

	local function addSection(text: string, glyph: string, color: Color3, order: number)
		Kit.Section({
			Parent = scroll,
			Name = `{text}Section`,
			Text = text,
			Glyph = glyph,
			Color = color,
			LayoutOrder = order,
		})
	end

	local function addGrid(
		name: string,
		count: number,
		order: number,
		cell: UDim2,
		height: number,
		gap: number
	)
		local rows = rowsFor(count)
		local holder = Instance.new("Frame")
		holder.Name = name
		holder.BackgroundTransparency = 1
		holder.BorderSizePixel = 0
		holder.LayoutOrder = order
		holder.Size = UDim2.new(1, 0, 0, rows * height + (rows - 1) * gap)
		local grid = Instance.new("UIGridLayout")
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.CellSize = cell
		grid.CellPadding = UDim2.fromOffset(cardGap, gap)
		grid.Parent = holder
		holder.Parent = scroll
		return holder
	end

	local function buildCard(
		cardTrove: TroveInstance,
		parent: Instance,
		entry: Entry,
		order: number,
		isActive: boolean
	): Frame
		local charm = entry.Charm
		local rarity = CharmConfig.RarityByName[charm.Rarity]
		local info = CharmConfig.Kinds[charm.Kind]
		local color = if isActive then rarity.Color else Kit.Shade(rarity.Color, -0.4)
		local card = Kit.Panel({
			Parent = parent,
			Name = charm.Id,
			Color = color,
			LayoutOrder = order,
			Shards = true,
			Radius = Kit.Radius.L,
		})
		card.ClipsDescendants = true
		if isActive then
			Kit.RarityPaint(cardTrove, card, rarity.Name, rarity.Color, Kit.Radius.L)
		end
		Kit.IconPlate({
			Parent = card,
			Name = "KindIcon",
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.fromOffset(52, 52),
			Color = info.Color,
			Glyph = info.Glyph,
		})
		Kit.Label({
			Parent = card,
			Name = "Name",
			Text = charm.Name,
			Position = UDim2.fromOffset(70, 8),
			Size = UDim2.new(1, -80, 0, 28),
			TextSize = Kit.Text.Strong,
			Scaled = true,
			Title = true,
		})
		Kit.Chip({
			Parent = card,
			Name = "Rarity",
			Text = rarity.Name,
			Position = UDim2.fromOffset(70, 40),
			Size = UDim2.fromOffset(110, 24),
			Color = Kit.Shade(color, -0.35),
			TextSize = Kit.Text.Small,
		})
		Kit.Label({
			Parent = card,
			Name = "Effect",
			Text = Charms.Describe(charm.Id),
			Position = UDim2.fromOffset(8, 72),
			Size = UDim2.new(1, -16, 0, 44),
			TextSize = Kit.Text.Banner,
			Align = Enum.TextXAlignment.Center,
			Color = if isActive then theme.Text else theme.TextDim,
			Scaled = true,
			Title = true,
		})
		if entry.Count > 1 then
			Kit.Chip({
				Parent = card,
				Name = "Count",
				Text = `x{entry.Count}`,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -8, 0, 40),
				Size = UDim2.fromOffset(52, 24),
				Color = theme.Ink,
				TextSize = Kit.Text.Body,
			})
		end
		return card
	end

	local function placeCard(
		used: { [string]: boolean },
		parent: Instance,
		entry: Entry,
		order: number,
		isActive: boolean
	)
		local key = `{if isActive then "Active" else "Stored"}:{entry.Charm.Id}`
		local signature = `{entry.Count}`
		used[key] = true
		local cached = cards[key]
		if cached and cached.Signature == signature then
			cached.Frame.LayoutOrder = order
			cached.Frame.Parent = parent
			return
		end
		if cached then
			cached.Cleanup()
			cached.Frame:Destroy()
		end
		local cardTrove = Trove.new()
		local frame = buildCard(cardTrove, parent, entry, order, isActive)
		cards[key] = {
			Frame = frame,
			Cleanup = function()
				cardTrove:Destroy()
			end,
			Signature = signature,
		}
	end

	local function renderEmpty()
		local empty = Kit.Card({
			Parent = scroll,
			Name = "Empty",
			Size = UDim2.new(1, 0, 0, 230),
			Tint = theme.Track,
		})
		Kit.Icon({
			Parent = empty,
			Name = "Icon",
			Glyph = "Heart",
			Size = UDim2.fromOffset(72, 72),
			Position = UDim2.new(0.5, 0, 0, 18),
			AnchorPoint = Vector2.new(0.5, 0),
		})
		Kit.Label({
			Parent = empty,
			Name = "Message",
			Text = "Hatch eggs at the Egg Market to get pets!",
			Position = UDim2.fromOffset(16, 98),
			Size = UDim2.new(1, -32, 0, 40),
			TextSize = Kit.Text.Heading,
			Align = Enum.TextXAlignment.Center,
			Scaled = true,
			Title = true,
		})
		Kit.Button(renderTrove, {
			Parent = empty,
			Name = "Shop",
			Text = "SHOP",
			Glyph = "Shop",
			IconLeft = true,
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.new(0.5, 0, 1, -18),
			Size = UDim2.fromOffset(200, 58),
			Color = theme.Orange,
			TextSize = Kit.Text.Heading,
			Pill = true,
			Callback = function()
				local ok, reason = rollController:TeleportToMarket()
				if ok then
					context.Close("Pets")
				else
					context.Toast(reason or "You can't go there right now!", "Bad")
				end
			end,
		})
	end

	local function signatureOf(): string
		local ids = {}
		for id, count in owned do
			table.insert(ids, `{id}={count}`)
		end
		table.sort(ids)
		return table.concat(ids, ",")
	end

	local function render()
		local signature = signatureOf()
		if signature == lastSignature then
			return
		end
		lastSignature = signature
		renderTrove:Destroy()
		renderTrove = Trove.new()
		for _, cached in cards do
			cached.Frame.Parent = nil
		end
		for _, child in scroll:GetChildren() do
			if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
				child:Destroy()
			end
		end
		local total = 0
		for _, count in owned do
			total += count
		end
		ownedPill.SetText(`{total} {if total == 1 then "pet" else "pets"}`)
		local used: { [string]: boolean } = {}
		local function dropUnused()
			for key, cached in cards do
				if not used[key] then
					cached.Cleanup()
					cached.Frame:Destroy()
					cards[key] = nil
				end
			end
		end
		if total == 0 then
			dropUnused()
			renderEmpty()
			return
		end

		local best = Charms.Best(owned)
		local activeCounts: { [string]: number } = {}
		for _, id in best do
			activeCounts[id] = (activeCounts[id] or 0) + 1
		end
		local active: { Entry } = {}
		local stored: { Entry } = {}
		for _, charm in CharmConfig.Catalog do
			local count = owned[charm.Id] or 0
			local activeCount = activeCounts[charm.Id] or 0
			if activeCount > 0 then
				table.insert(active, { Charm = charm, Count = activeCount })
			end
			if count - activeCount > 0 then
				table.insert(stored, { Charm = charm, Count = count - activeCount })
			end
		end
		sortEntries(active)
		sortEntries(stored)

		local effects = Charms.Effects(best)
		local bonuses: { { Kind: string, Text: string } } = {}
		for _, kind in kindOrder do
			local text = bonusText(kind, effects)
			if text then
				table.insert(bonuses, { Kind = kind, Text = text })
			end
		end
		addSection("ACTIVE BONUSES", "Sparkle", theme.Gold, 1)
		local summary = addGrid(
			"Bonuses",
			#bonuses,
			2,
			UDim2.new(1 / columns, -cardGap - 10, 0, chipHeight),
			chipHeight,
			chipGap
		)
		local summaryPadding = Instance.new("UIPadding")
		summaryPadding.PaddingLeft = UDim.new(0, 14)
		summaryPadding.PaddingTop = UDim.new(0, Kit.Space.Xs)
		summaryPadding.Parent = summary
		for index, bonus in bonuses do
			local info = CharmConfig.Kinds[bonus.Kind]
			Kit.Pill({
				Parent = summary,
				Name = bonus.Kind,
				Glyph = info.Glyph,
				Text = bonus.Text,
				DiscColor = info.Color,
				LayoutOrder = index,
				TextSize = Kit.Text.Strong,
			})
		end

		addSection(`ACTIVE ({#best}/{CharmConfig.ActiveLimit})`, "Heart", theme.Green, 3)
		local cell = UDim2.new(1 / columns, -cardGap, 0, cardHeight)
		local activeGrid = addGrid("Active", #active, 4, cell, cardHeight, cardGap)
		for index, entry in active do
			placeCard(used, activeGrid, entry, index, true)
		end

		if #stored > 0 then
			addSection("STORED", "Lock", theme.Grey, 5)
			Kit.Label({
				Parent = scroll,
				Name = "StoredNote",
				Text = `Only your best {CharmConfig.ActiveLimit} pets are active`,
				Size = UDim2.new(1, 0, 0, 24),
				TextSize = Kit.Text.Label,
				Subtle = true,
				Scaled = true,
				LayoutOrder = 6,
			})
			local storedGrid = addGrid("Stored", #stored, 7, cell, cardHeight, cardGap)
			for index, entry in stored do
				placeCard(used, storedGrid, entry, index, false)
			end
		end
		dropUnused()
	end

	trove:Add(dataController:Observe({ "Charms" }, function(value: any)
		local copy: { [string]: number } = {}
		if type(value) == "table" then
			for id, count in value do
				if
					type(id) == "string"
					and CharmConfig.ById[id]
					and type(count) == "number"
					and count > 0
				then
					copy[id] = math.floor(count)
				end
			end
		end
		owned = copy
		render()
	end))

	return {
		Modal = true,
		StartsOpen = false,
		Open = function(_self: Types.Screen)
			modal.Show()
		end,
		Close = function(_self: Types.Screen)
			modal.Hide()
		end,
		Destroy = function(_self: Types.Screen)
			trove:Destroy()
		end,
	}
end

return PetsScreen
