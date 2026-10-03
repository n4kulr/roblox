--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Keys = require(ReplicatedStorage.Config.Keys)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Economy = require(script.Parent.Parent.Economy)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)

type OwnedCard = {
	Key: Keys.Key,
	Button: Kit.Button,
	Count: TextLabel,
	Tag: Frame,
}
type IndexCard = {
	Key: Keys.Key,
	Frame: Frame,
	Name: TextLabel,
	Icon: TextLabel,
	Rarity: TextLabel,
	Chance: TextLabel,
}

local theme = Kit.Theme
local sureRank = 4
local confirmSeconds = 3
local sellCooldown = 0.2
local refreshSeconds = 0.2
local ownedCell = UDim2.fromOffset(142, 170)
local indexCell = UDim2.fromOffset(142, 132)
local silhouetteColor = Color3.fromRGB(40, 34, 74)
local perkIcons: { [string]: string } = { Luck = "🍀", Speed = "⚡", Income = "💰" }

local rarityRank: { [string]: number } = {}
for index, rarity in Keys.Rarities do
	rarityRank[rarity.Name] = index
end

local function sortedCatalog(isHighFirst: boolean): { Keys.Key }
	local sorted = table.clone(Keys.Catalog)
	table.sort(sorted, function(a: Keys.Key, b: Keys.Key)
		local rankA = rarityRank[a.Rarity]
		local rankB = rarityRank[b.Rarity]
		if rankA ~= rankB then
			if isHighFirst then
				return rankA > rankB
			end
			return rankA < rankB
		end
		return a.Index < b.Index
	end)
	return sorted
end

local function iconFor(key: Keys.Key): string
	local perk = key.Perk
	if perk then
		return perkIcons[perk.Kind] or "⌨️"
	end
	return "⌨️"
end

local function perkText(key: Keys.Key): string?
	local perk = key.Perk
	if not perk then
		return nil
	end
	local percent = math.floor(perk.Amount * 100 + 0.5)
	local label = if perk.Kind == "Speed"
		then "Roll Speed"
		elseif perk.Kind == "Income" then "Clicks"
		else "Luck"
	return `{iconFor(key)} +{percent}% {label}`
end

local KeysScreen = {}

function KeysScreen.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local dataController = context.Controllers.DataController
	local playUi = Kit.UiSound(context.Controllers)
	local ownedCards: { [string]: OwnedCard } = {}
	local indexCards: { [string]: IndexCard } = {}
	local inventory: { [string]: number } = {}
	local discovered: { [string]: number } = {}
	local isOpen = false
	local isDirty = true
	local isEquipping = false
	local isSelling = false
	local lastSell = 0
	local detailKey: string? = nil
	local confirmStamp = 0
	local isConfirming = false
	local tracker: Economy.Tracker
	local activeTab = "My"

	local modal = Kit.Modal(trove, {
		Parent = context.PlayerGui,
		Name = "Keys",
		Title = "🔑 KEYS",
		MaxSize = Vector2.new(680, 640),
		HeaderColor = theme.Purple,
		OnClose = function()
			context.Close("Keys")
		end,
		Sound = playUi,
	})
	local body = modal.Body

	local myPage = Instance.new("Frame")
	myPage.Name = "MyPage"
	myPage.BackgroundTransparency = 1
	myPage.Position = UDim2.fromOffset(0, 72)
	myPage.Size = UDim2.new(1, 0, 1, -72)
	myPage.Parent = body
	local indexPage = Instance.new("Frame")
	indexPage.Name = "IndexPage"
	indexPage.BackgroundTransparency = 1
	indexPage.Position = UDim2.fromOffset(0, 72)
	indexPage.Size = UDim2.new(1, 0, 1, -72)
	indexPage.Visible = false
	indexPage.Parent = body

	local function showTab(name: string)
		activeTab = name
		myPage.Visible = name == "My"
		indexPage.Visible = name == "Index"
	end
	local myTab: Kit.Button
	local indexTab: Kit.Button
	local function paintTabs()
		myTab.SetColor(if activeTab == "My" then theme.Blue else theme.Grey)
		indexTab.SetColor(if activeTab == "Index" then theme.Blue else theme.Grey)
	end
	myTab = Kit.Button(trove, {
		Parent = body,
		Name = "MyTab",
		Text = "MY KEYS",
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.new(0.5, -18, 0, 56),
		Color = theme.Blue,
		TextSize = 26,
		Callback = function()
			showTab("My")
			paintTabs()
		end,
		Sound = playUi,
	})
	indexTab = Kit.Button(trove, {
		Parent = body,
		Name = "IndexTab",
		Text = "INDEX",
		Position = UDim2.new(0.5, 6, 0, 10),
		Size = UDim2.new(0.5, -18, 0, 56),
		Color = theme.Grey,
		TextSize = 26,
		Callback = function()
			showTab("Index")
			paintTabs()
		end,
		Sound = playUi,
	})

	Kit.Button(trove, {
		Parent = myPage,
		Name = "EquipBest",
		Text = "⭐ EQUIP BEST",
		Position = UDim2.new(0.5, 0, 0, 2),
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(300, 64),
		Color = theme.Green,
		TextSize = 32,
		Radius = 16,
		Callback = function()
			if isEquipping then
				return
			end
			isEquipping = true
			task.spawn(function()
				local success = Packets.EquipBest:Fire()
				isEquipping = false
				if success == true then
					playUi("Confirm")
					context.Toast("Equipped your best keys! ⭐", "Good")
				else
					playUi("Error")
					context.Toast("Your keyboard is already the best!", "Info")
				end
			end)
		end,
		Sound = playUi,
	})
	local boardLabel = Kit.Label({
		Parent = myPage,
		Name = "BoardCount",
		Text = "Keys on your keyboard: 0/10",
		Position = UDim2.fromOffset(12, 74),
		Size = UDim2.new(1, -24, 0, 28),
		TextSize = 22,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local ownedGrid = Kit.GridScroll({
		Parent = myPage,
		Name = "Grid",
		Position = UDim2.fromOffset(8, 106),
		Size = UDim2.new(1, -16, 1, -106),
		CellSize = ownedCell,
	})
	local emptyLabel = Kit.Label({
		Parent = myPage,
		Name = "Empty",
		Text = "No keys yet! Hit 🎲 ROLL to find some!",
		Position = UDim2.new(0, 20, 0.5, 20),
		Size = UDim2.new(1, -40, 0, 60),
		TextSize = 26,
		Align = Enum.TextXAlignment.Center,
		Wrapped = true,
	})

	local foundLabel = Kit.Label({
		Parent = indexPage,
		Name = "Found",
		Text = "Found 0/0",
		Position = UDim2.fromOffset(12, 2),
		Size = UDim2.new(1, -24, 0, 36),
		TextSize = 28,
		Color = theme.Gold,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local indexGrid = Kit.GridScroll({
		Parent = indexPage,
		Name = "Grid",
		Position = UDim2.fromOffset(8, 42),
		Size = UDim2.new(1, -16, 1, -42),
		CellSize = indexCell,
	})

	local overlay = Instance.new("TextButton")
	overlay.Name = "DetailOverlay"
	overlay.AutoButtonColor = false
	overlay.Text = ""
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.45
	overlay.BorderSizePixel = 0
	overlay.Size = UDim2.fromScale(1, 1)
	overlay.Visible = false
	overlay.Parent = modal.Panel
	Kit.Corner(overlay, 16)
	local detail = Kit.Panel({
		Parent = overlay,
		Name = "Detail",
		Size = UDim2.fromOffset(310, 330),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = theme.Raised,
		Radius = 18,
		StrokeThickness = 4,
	})
	detail.Active = true
	local detailPop = Instance.new("UIScale")
	detailPop.Parent = detail
	local detailName = Kit.Label({
		Parent = detail,
		Name = "Name",
		Text = "",
		Position = UDim2.fromOffset(14, 12),
		Size = UDim2.new(1, -28, 0, 42),
		TextSize = 32,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local detailInfo = Kit.Label({
		Parent = detail,
		Name = "Info",
		Text = "",
		Position = UDim2.fromOffset(14, 56),
		Size = UDim2.new(1, -28, 0, 26),
		TextSize = 20,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local detailPerk = Kit.Label({
		Parent = detail,
		Name = "Perk",
		Text = "",
		Position = UDim2.fromOffset(14, 84),
		Size = UDim2.new(1, -28, 0, 24),
		TextSize = 20,
		Color = theme.Gold,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local detailOwn = Kit.Label({
		Parent = detail,
		Name = "Own",
		Text = "",
		Position = UDim2.fromOffset(14, 112),
		Size = UDim2.new(1, -28, 0, 26),
		TextSize = 19,
		Color = theme.TextDim,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})

	local function boardCounts(): { [string]: number }
		local counts: { [string]: number } = {}
		local slots = tracker.GetStats().Slots
		local board = tracker.GetBoard()
		for index = 1, slots do
			local keyId = board[index]
			if type(keyId) == "string" and Keys.ById[keyId] then
				counts[keyId] = (counts[keyId] or 0) + 1
			end
		end
		return counts
	end

	local function closeDetail()
		detailKey = nil
		isConfirming = false
		overlay.Visible = false
	end

	local function sell(keyId: string, count: number)
		local now = os.clock()
		if isSelling or now - lastSell < sellCooldown or count < 1 then
			return
		end
		isSelling = true
		lastSell = now
		local value = Keys.GetSellValue(keyId) * count
		task.spawn(function()
			local success = Packets.SellKey:Fire(keyId, count)
			isSelling = false
			if success == true then
				playUi("Confirm")
				context.Toast(`Sold for {NumberFormat.Compact(value)} Clicks! 💰`, "Good")
			else
				playUi("Error")
				context.Toast("Oops, couldn't sell that!", "Bad")
			end
		end)
	end

	local sellOne: Kit.Button
	local sellAll: Kit.Button
	local function spareOf(keyId: string): number
		return inventory[keyId] or 0
	end
	local function refreshDetail()
		local keyId = detailKey
		local key = if keyId then Keys.ById[keyId] else nil
		if not keyId or not key then
			return
		end
		local rarity = Keys.GetRarity(key)
		local spare = spareOf(keyId)
		local onBoard = boardCounts()[keyId] or 0
		if spare + onBoard < 1 then
			closeDetail()
			return
		end
		detailName.Text = key.Name
		detailName.TextColor3 = Kit.Shade(rarity.Color, 0.2)
		detailInfo.Text = `{rarity.Name}  •  +{NumberFormat.Compact(rarity.Income)} Clicks per second`
		detailPerk.Text = perkText(key) or ""
		detailOwn.Text = `You have {spare + onBoard}  •  {onBoard} on keyboard  •  {spare} spare`
		local value = Keys.GetSellValue(keyId)
		if spare < 1 then
			sellOne.SetDisabled(true)
			sellOne.SetText("All on board")
			sellAll.SetDisabled(true)
			sellAll.SetText("All on board")
			return
		end
		sellOne.SetDisabled(false)
		sellOne.SetText(`💰 SELL 1  +{NumberFormat.Compact(value)}`)
		sellAll.SetDisabled(false)
		if isConfirming then
			sellAll.SetText("Sure? Tap again!")
			sellAll.SetColor(theme.Red)
		else
			sellAll.SetText(`💰 SELL ALL SPARE  +{NumberFormat.Compact(value * spare)}`)
			sellAll.SetColor(theme.Orange)
		end
	end

	sellOne = Kit.Button(trove, {
		Parent = detail,
		Name = "SellOne",
		Text = "SELL 1",
		Position = UDim2.fromOffset(16, 150),
		Size = UDim2.new(1, -32, 0, 62),
		Color = theme.Green,
		TextSize = 24,
		Callback = function()
			local keyId = detailKey
			if keyId then
				isConfirming = false
				sell(keyId, 1)
			end
		end,
		Sound = playUi,
	})
	sellAll = Kit.Button(trove, {
		Parent = detail,
		Name = "SellAll",
		Text = "SELL ALL SPARE",
		Position = UDim2.fromOffset(16, 226),
		Size = UDim2.new(1, -32, 0, 62),
		Color = theme.Orange,
		TextSize = 24,
		Callback = function()
			local keyId = detailKey
			local key = if keyId then Keys.ById[keyId] else nil
			if not keyId or not key then
				return
			end
			local spare = spareOf(keyId)
			if spare < 1 then
				return
			end
			if (rarityRank[key.Rarity] or 1) >= sureRank and not isConfirming then
				isConfirming = true
				confirmStamp += 1
				local stamp = confirmStamp
				refreshDetail()
				task.delay(confirmSeconds, function()
					if isConfirming and confirmStamp == stamp then
						isConfirming = false
						refreshDetail()
					end
				end)
				return
			end
			isConfirming = false
			confirmStamp += 1
			sell(keyId, spare)
		end,
		Sound = playUi,
	})
	Kit.IconButton(trove, {
		Parent = detail,
		Name = "Close",
		Text = "X",
		Size = UDim2.fromOffset(44, 49),
		Position = UDim2.new(1, -2, 0, 2),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = theme.Red,
		Radius = 22,
		TextSize = 24,
		Callback = closeDetail,
		Sound = playUi,
	})
	trove:Connect(overlay.Activated, closeDetail)

	local function openDetail(keyId: string)
		detailKey = keyId
		isConfirming = false
		overlay.Visible = true
		detailPop.Scale = 0.8
		Kit.Tween(detailPop, Kit.PopInfo(), { Scale = 1 })
		refreshDetail()
	end

	for rank, key in sortedCatalog(true) do
		local rarity = Keys.GetRarity(key)
		local button = Kit.Button(trove, {
			Parent = ownedGrid,
			Name = key.Id,
			Size = ownedCell,
			Color = rarity.Color,
			Radius = 14,
			LayoutOrder = rank,
			Callback = function()
				openDetail(key.Id)
			end,
			Sound = playUi,
		})
		button.Instance.Visible = false
		local face = button.Face
		Kit.Label({
			Parent = face,
			Name = "Name",
			Text = key.Name,
			Position = UDim2.fromOffset(8, 6),
			Size = UDim2.new(1, -16, 0, 34),
			TextSize = 19,
			Align = Enum.TextXAlignment.Center,
			Wrapped = true,
			Scaled = true,
		})
		Kit.Label({
			Parent = face,
			Name = "Icon",
			Text = iconFor(key),
			Position = UDim2.fromOffset(0, 40),
			Size = UDim2.new(1, 0, 0, 42),
			TextSize = 38,
			Align = Enum.TextXAlignment.Center,
			Outline = false,
			Scaled = true,
		})
		Kit.Label({
			Parent = face,
			Name = "Rarity",
			Text = rarity.Name,
			Position = UDim2.fromOffset(0, 84),
			Size = UDim2.new(1, 0, 0, 18),
			TextSize = 16,
			Align = Enum.TextXAlignment.Center,
			Scaled = true,
		})
		Kit.Label({
			Parent = face,
			Name = "Income",
			Text = `+{NumberFormat.Compact(rarity.Income)}/s`,
			Position = UDim2.fromOffset(0, 102),
			Size = UDim2.new(1, 0, 0, 22),
			TextSize = 20,
			Align = Enum.TextXAlignment.Center,
			Scaled = true,
		})
		local perk = perkText(key)
		if perk then
			Kit.Label({
				Parent = face,
				Name = "Perk",
				Text = perk,
				Position = UDim2.fromOffset(4, 123),
				Size = UDim2.new(1, -8, 0, 18),
				TextSize = 15,
				Color = theme.Gold,
				Align = Enum.TextXAlignment.Center,
				Scaled = true,
			})
		end
		local tag = Instance.new("Frame")
		tag.Name = "OnBoard"
		tag.BorderSizePixel = 0
		tag.AnchorPoint = Vector2.new(0.5, 1)
		tag.Position = UDim2.new(0.5, 0, 1, -6)
		tag.Size = UDim2.fromOffset(104, 20)
		Kit.Paint(tag, theme.Green)
		Kit.Corner(tag, 10)
		Kit.Stroke(tag, theme.Ink, 2)
		Kit.Label({
			Parent = tag,
			Name = "Text",
			Text = "✓ ON BOARD",
			Size = UDim2.fromScale(1, 1),
			TextSize = 14,
			Align = Enum.TextXAlignment.Center,
			Scaled = true,
		})
		tag.Visible = false
		tag.Parent = face
		local badge = Instance.new("Frame")
		badge.Name = "Badge"
		badge.BorderSizePixel = 0
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.new(1, 8, 0, -8)
		badge.Size = UDim2.fromOffset(46, 30)
		Kit.Paint(badge, theme.Red)
		Kit.Corner(badge, 15)
		Kit.Stroke(badge, theme.Ink, 3)
		local count = Kit.Label({
			Parent = badge,
			Name = "Count",
			Text = "x1",
			Size = UDim2.fromScale(1, 1),
			TextSize = 20,
			Align = Enum.TextXAlignment.Center,
			Scaled = true,
		})
		badge.Parent = button.Instance
		ownedCards[key.Id] = { Key = key, Button = button, Count = count, Tag = tag }
	end

	for rank, key in sortedCatalog(false) do
		local frame = Kit.Panel({
			Parent = indexGrid,
			Name = key.Id,
			Size = indexCell,
			Color = silhouetteColor,
			Radius = 14,
			LayoutOrder = rank,
		})
		local nameLabel = Kit.Label({
			Parent = frame,
			Name = "Name",
			Text = "???",
			Position = UDim2.fromOffset(8, 6),
			Size = UDim2.new(1, -16, 0, 34),
			TextSize = 19,
			Align = Enum.TextXAlignment.Center,
			Wrapped = true,
			Scaled = true,
		})
		local icon = Kit.Label({
			Parent = frame,
			Name = "Icon",
			Text = "❔",
			Position = UDim2.fromOffset(0, 40),
			Size = UDim2.new(1, 0, 0, 40),
			TextSize = 36,
			Align = Enum.TextXAlignment.Center,
			Outline = false,
			Scaled = true,
		})
		local rarityLabel = Kit.Label({
			Parent = frame,
			Name = "Rarity",
			Text = key.Rarity,
			Position = UDim2.fromOffset(0, 84),
			Size = UDim2.new(1, 0, 0, 20),
			TextSize = 17,
			Align = Enum.TextXAlignment.Center,
			Scaled = true,
		})
		local chance = Kit.Label({
			Parent = frame,
			Name = "Chance",
			Text = "",
			Position = UDim2.fromOffset(0, 104),
			Size = UDim2.new(1, 0, 0, 20),
			TextSize = 16,
			Color = theme.TextDim,
			Align = Enum.TextXAlignment.Center,
			Scaled = true,
		})
		indexCards[key.Id] = {
			Key = key,
			Frame = frame,
			Name = nameLabel,
			Icon = icon,
			Rarity = rarityLabel,
			Chance = chance,
		}
	end

	local function refreshAll()
		isDirty = false
		local onBoard = boardCounts()
		local ownedKinds = 0
		for keyId, card in ownedCards do
			local total = (inventory[keyId] or 0) + (onBoard[keyId] or 0)
			card.Button.Instance.Visible = total > 0
			if total > 0 then
				ownedKinds += 1
				card.Count.Text = `x{total}`
				card.Tag.Visible = (onBoard[keyId] or 0) > 0
			end
		end
		emptyLabel.Visible = ownedKinds == 0
		local filled = 0
		for _, count in onBoard do
			filled += count
		end
		boardLabel.Text = `Keys on your keyboard: {filled}/{tracker.GetStats().Slots}`
		local found = 0
		for keyId, card in indexCards do
			local rarity = Keys.GetRarity(card.Key)
			if (discovered[keyId] or 0) > 0 then
				found += 1
				Kit.Paint(card.Frame, rarity.Color)
				card.Name.Text = card.Key.Name
				card.Icon.Text = iconFor(card.Key)
				card.Chance.Text = `1 in {NumberFormat.Commas(rarity.Chance)}`
			else
				Kit.Paint(card.Frame, silhouetteColor)
				card.Name.Text = "???"
				card.Icon.Text = "❔"
				card.Chance.Text = ""
			end
		end
		foundLabel.Text = `Found {found}/{#Keys.Catalog}`
		refreshDetail()
	end

	local function markDirty()
		isDirty = true
	end
	tracker = Economy.Track(dataController, trove, markDirty)
	trove:Add(dataController:Observe({ "Inventory" }, function(value: any)
		local copy: { [string]: number } = {}
		if type(value) == "table" then
			for keyId, count in value do
				if type(keyId) == "string" and type(count) == "number" then
					copy[keyId] = count
				end
			end
		end
		inventory = copy
		markDirty()
	end))
	trove:Add(dataController:Observe({ "Discovered" }, function(value: any)
		local copy: { [string]: number } = {}
		if type(value) == "table" then
			for keyId, count in value do
				if type(keyId) == "string" and type(count) == "number" then
					copy[keyId] = count
				end
			end
		end
		discovered = copy
		markDirty()
	end))

	local elapsed = 0
	trove:Connect(RunService.Heartbeat, function(dt: number)
		if not isOpen or not isDirty then
			return
		end
		elapsed += dt
		if elapsed >= refreshSeconds then
			elapsed = 0
			refreshAll()
		end
	end)
	refreshAll()

	return {
		Modal = true,
		StartsOpen = false,
		Open = function(_self: Types.Screen)
			isOpen = true
			closeDetail()
			refreshAll()
			modal.Show()
		end,
		Close = function(_self: Types.Screen)
			isOpen = false
			closeDetail()
			modal.Hide()
		end,
		Destroy = function(_self: Types.Screen)
			trove:Destroy()
		end,
	}
end

return KeysScreen
