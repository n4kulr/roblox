--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeyTiers = require(ReplicatedStorage.Config.KeyTiers)
local Keys = require(ReplicatedStorage.Config.Keys)
local Packets = require(ReplicatedStorage.Packets)
local UiAssets = require(ReplicatedStorage.Config.UiAssets)
local Variants = require(ReplicatedStorage.Rules.Variants)
local Trove = require(ReplicatedStorage.Packages.Trove)
local KeyModels = require(ReplicatedStorage.Utils.KeyModels)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Cells = require(script.Parent.Parent.Cells)
local Economy = require(script.Parent.Parent.Economy)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)
local Viewport = require(script.Parent.Parent.Viewport)

type Entry = {
	Id: string,
	Key: Keys.Key,
	Tier: number,
	Cell: Cells.Cell,
}

local theme = Kit.Theme
local sureRank = 4
local confirmSeconds = 3
local sellCooldown = 0.2
local gridShare = 0.6
local fuseSeconds = 0.55
local landSeconds = fuseSeconds * 0.65
local flyerCount = Variants.FuseCost
local previewHeight = 140
local contentHeight = 540
local spinSpeed = 0.9

local sortModes = { "BEST", "RARITY", "AMOUNT", "NAME" }
local sortMode = 1

local KeysScreen = {}

function KeysScreen.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local dataController = context.Controllers.DataController
	local playUi = Kit.UiSound(context.Controllers)
	local entries: { [string]: Entry } = {}
	local inventory: { [string]: number } = {}
	local boardTags: { [number]: string } = {}
	local isOpen = false
	local isDirty = true
	local equipGuard = Kit.Request(trove)
	local sellGuard = Kit.Request(trove)
	local fuseGuard = Kit.Request(trove)
	local lastSell = 0
	local detailKey: string? = nil
	local previewKey: string? = nil
	local refreshDetail: () -> ()
	local confirm = Kit.Confirm(trove, confirmSeconds, function()
		refreshDetail()
	end)
	local tracker: Economy.Tracker
	local previewModel: Model? = nil
	local stopLegend: (() -> ())? = nil
	local previewTier = 0

	local modal = Kit.Modal(trove, {
		Parent = context.PlayerGui,
		Name = "Keys",
		Title = "KEYS",
		Glyph = "Keys",
		IconAsset = UiAssets.Icons.Keys,
		MaxSize = Vector2.new(900, 640),
		HeaderColor = theme.Purple,
		OnClose = function()
			context.Close("Keys")
		end,
	})
	local body = modal.Body
	local refreshAll: () -> ()
	local sortButton = Kit.Button(trove, {
		Parent = modal.HeaderRight,
		Name = "Sort",
		Text = `SORT: {sortModes[sortMode]}`,
		Glyph = "Arrow",
		IconLeft = true,
		Size = UDim2.fromOffset(172, 46),
		Color = theme.Blue,
		TextSize = Kit.Text.Label,
		LayoutOrder = -1,
		Callback = function()
			sortMode = sortMode % #sortModes + 1
			refreshAll()
		end,
	})

	Kit.Button(trove, {
		Parent = modal.HeaderRight,
		Name = "EquipBest",
		Text = "EQUIP BEST",
		Glyph = "Sparkle",
		IconLeft = true,
		Size = UDim2.fromOffset(176, 46),
		Color = theme.Green,
		TextSize = Kit.Text.Label,
		Callback = function()
			if equipGuard.IsBusy() then
				return
			end
			equipGuard.Run(function()
				return Packets.EquipBest:Fire()
			end, function(isOk: boolean, success: any)
				if isOk and success == true then
					playUi("Confirm")
					context.Toast("Equipped your best keys!", "Good")
				else
					playUi("Error")
					context.Toast("Your keyboard is already the best!", "Info")
				end
			end)
		end,
	})

	local fullGridSize = UDim2.new(1, -12, 1, -12)
	local splitGridSize = UDim2.new(gridShare, -9, 1, -12)
	local grid = Kit.GridScroll({
		Parent = body,
		Name = "Grid",
		Position = UDim2.fromOffset(6, 6),
		Size = fullGridSize,
		CellSize = Cells.Size,
	})
	local emptyLabel = Kit.Label({
		Parent = body,
		Name = "Empty",
		Text = "No keys yet! Hit ROLL to find some!",
		Position = UDim2.new(0, 20, 0.5, -30),
		Size = UDim2.new(1, -40, 0, 60),
		TextSize = Kit.Text.Subhead,
		Align = Enum.TextXAlignment.Center,
		Wrapped = true,
	})

	local detail = Kit.Panel({
		Parent = body,
		Name = "Detail",
		Size = UDim2.new(1 - gridShare, -9, 1, -12),
		Position = UDim2.new(gridShare, 3, 0, 6),
		Color = theme.PanelDeep,
		Radius = Kit.Radius.Panel,
		StrokeThickness = Kit.StrokeSize.Heavy,
	})
	detail.Visible = false
	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "Scroller"
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.Size = UDim2.fromScale(1, 1)
	scroller.CanvasSize = UDim2.fromOffset(0, contentHeight)
	scroller.ScrollBarThickness = 6
	scroller.ScrollingDirection = Enum.ScrollingDirection.Y
	scroller.Parent = detail
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, -8, 0, contentHeight)
	content.Parent = scroller

	local previewArea = Instance.new("Frame")
	previewArea.Name = "Preview"
	previewArea.BackgroundTransparency = 1
	previewArea.Size = UDim2.new(1, 0, 0, previewHeight)
	previewArea.Parent = content
	local previewPop = Instance.new("UIScale")
	previewPop.Parent = previewArea
	Kit.Burst({
		Parent = previewArea,
		Diameter = 150,
		Position = UDim2.new(0.5, -75, 0, 6),
	})
	local detailCap = Kit.Keycap({
		Parent = previewArea,
		Color = theme.Grey,
		Size = UDim2.fromOffset(96, 96),
		Position = UDim2.new(0.5, 0, 0, 24),
		AnchorPoint = Vector2.new(0.5, 0),
	})
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "Model"
	viewport.BackgroundTransparency = 1
	viewport.Size = UDim2.new(1, -20, 1, 0)
	viewport.Position = UDim2.fromOffset(10, 0)
	viewport.Visible = false
	viewport.Parent = previewArea
	local flash = Kit.Flash({ Parent = previewArea, Radius = Kit.Radius.L, ZIndex = Kit.ZIndex.Hover })

	local detailName = Kit.Label({
		Parent = content,
		Name = "Name",
		Text = "",
		Position = UDim2.fromOffset(6, 144),
		Size = UDim2.new(1, -12, 0, 34),
		TextSize = Kit.Text.Banner,
		Title = true,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local rarityChip = Kit.Chip({
		Parent = content,
		Name = "RarityChip",
		Text = "",
		Size = UDim2.fromOffset(104, 24),
		Position = UDim2.new(0.5, -4, 0, 182),
		AnchorPoint = Vector2.new(1, 0),
		Color = theme.Grey,
		TextSize = Kit.Text.Caption,
	})
	local tierChip = Kit.Chip({
		Parent = content,
		Name = "TierChip",
		Text = "",
		Size = UDim2.fromOffset(104, 24),
		Position = UDim2.new(0.5, 4, 0, 182),
		Color = theme.Grey,
		TextSize = Kit.Text.Caption,
	})
	local detailIncome = Kit.Label({
		Parent = content,
		Name = "Income",
		Text = "",
		Position = UDim2.fromOffset(6, 212),
		Size = UDim2.new(1, -12, 0, 42),
		TextSize = Kit.Text.Headline,
		Color = theme.Good,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
		Title = true,
		StrokeSize = 5,
	})
	local detailOwned = Kit.Label({
		Parent = content,
		Name = "Owned",
		Text = "",
		Position = UDim2.fromOffset(6, 256),
		Size = UDim2.new(1, -12, 0, 22),
		TextSize = Kit.Text.Body,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local detailBoard = Kit.Label({
		Parent = content,
		Name = "OnKeyboard",
		Text = "",
		Position = UDim2.fromOffset(6, 278),
		Size = UDim2.new(1, -12, 0, 22),
		TextSize = Kit.Text.Body,
		Subtle = true,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local detailPerk = Kit.Label({
		Parent = content,
		Name = "Perk",
		Text = "",
		Position = UDim2.fromOffset(6, 300),
		Size = UDim2.new(1, -12, 0, 22),
		TextSize = Kit.Text.Body,
		Color = theme.Gold,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})

	local fusePanel = Kit.Panel({
		Parent = content,
		Name = "Fuse",
		Size = UDim2.new(1, -12, 0, 150),
		Position = UDim2.fromOffset(6, 326),
		Color = theme.Inset,
		Radius = Kit.Radius.L,
		StrokeThickness = Kit.StrokeSize.Normal,
	})
	local fuseTitle = Kit.Label({
		Parent = fusePanel,
		Name = "FuseTitle",
		Text = "",
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -16, 0, 26),
		TextSize = Kit.Text.Note,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local fuseBar = Kit.Bar({
		Parent = fusePanel,
		Name = "FuseProgress",
		Size = UDim2.new(1, -24, 0, 26),
		Position = UDim2.fromOffset(12, 36),
		Color = theme.Green,
		Text = "0/5",
		TextSize = Kit.Text.Small,
	})
	local fuseBoost = Kit.Label({
		Parent = fusePanel,
		Name = "FuseBoost",
		Text = "",
		Position = UDim2.fromOffset(8, 66),
		Size = UDim2.new(1, -16, 0, 22),
		TextSize = Kit.Text.Note,
		Color = theme.Gold,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local fuseButton: Kit.Button

	local sellRow = Instance.new("Frame")
	sellRow.Name = "SellRow"
	sellRow.BackgroundTransparency = 1
	sellRow.Position = UDim2.fromOffset(6, 486)
	sellRow.Size = UDim2.new(1, -12, 0, 46)
	sellRow.Parent = content
	local sellLayout = Instance.new("UIListLayout")
	sellLayout.FillDirection = Enum.FillDirection.Horizontal
	sellLayout.Padding = UDim.new(0, Kit.Space.S)
	sellLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sellLayout.Parent = sellRow

	local function boardCounts(): { [string]: number }
		local counts: { [string]: number } = {}
		local slots = tracker.GetStats().Slots
		local board = tracker.GetBoard()
		for index = 1, slots do
			local keyId = board[index]
			if type(keyId) == "string" and Keys.Resolve(keyId) then
				counts[keyId] = (counts[keyId] or 0) + 1
			end
		end
		return counts
	end

	local function stolenTags(): { [string]: string }
		local tags: { [string]: string } = {}
		local board = tracker.GetBoard()
		for index = 1, tracker.GetStats().Slots do
			local keyId = board[index]
			local tag = boardTags[index]
			if type(keyId) == "string" and tag and tag ~= "" and not tags[keyId] then
				tags[keyId] = tag
			end
		end
		return tags
	end

	local function clearPreviewModel()
		if stopLegend then
			stopLegend()
			stopLegend = nil
		end
		if previewModel then
			previewModel:Destroy()
			previewModel = nil
		end
		viewport.Visible = false
		detailCap.Instance.Visible = true
	end

	local function buildPreview(keyId: string)
		clearPreviewModel()
		local _, tier = KeyTiers.Parse(keyId)
		local ok = pcall(function()
			local model = KeyModels.Build(keyId)
			local camera = Instance.new("Camera")
			camera.FieldOfView = 40
			local box, size = model:GetBoundingBox()
			local radius = math.max(math.sqrt(size.X * size.X + size.Z * size.Z) / 2, size.Y / 2, 0.5)
			local focus = Vector3.new(0, box.Position.Y, 0)
			local distance = radius * 1.15 / math.sin(math.rad(camera.FieldOfView) / 2)
			camera.CFrame = CFrame.lookAt(focus + Vector3.new(0, 0.45, 1).Unit * distance, focus)
			camera.Parent = viewport
			viewport.CurrentCamera = camera
			model.Parent = viewport
			stopLegend = Viewport.TrackLegend(viewport, model, camera)
			previewModel = model
			previewTier = tier
		end)
		if ok and previewModel then
			viewport.Visible = true
			detailCap.Instance.Visible = ReplicatedStorage:GetAttribute("IconAtlasPreview") ~= nil
		else
			previewModel = nil
		end
	end

	local function spin(now: number)
		local model = previewModel
		if not model then
			return
		end
		pcall(function()
			model:PivotTo(CFrame.Angles(0, now * spinSpeed, 0))
			if previewTier == 2 then
				for _, name in { "Skirt", "Top", "Cap" } do
					local part = model:FindFirstChild(name)
					if part and part:IsA("BasePart") then
						part.Color = Color3.fromHSV((now * 0.25) % 1, 0.55, 1)
					end
				end
			end
		end)
	end

	local function setLayout(showDetail: boolean)
		detail.Visible = showDetail
		Kit.Tween(grid, Kit.Motion.Base, {
			Size = if showDetail then splitGridSize else fullGridSize,
		})
	end

	local function closeDetail()
		detailKey = nil
		previewKey = nil
		confirm.Reset()
		clearPreviewModel()
		setLayout(false)
	end

	local function sell(keyId: string, count: number)
		local now = os.clock()
		if sellGuard.IsBusy() or now - lastSell < sellCooldown or count < 1 then
			return
		end
		lastSell = now
		local value = Keys.GetSellValue(keyId) * count
		sellGuard.Run(function()
			return Packets.SellKey:Fire(keyId, count)
		end, function(isOk: boolean, success: any)
			if isOk and success == true then
				playUi("Confirm")
				context.Toast(`Sold for {NumberFormat.Compact(value)} Clicks!`, "Good")
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

	function refreshDetail()
		local keyId = detailKey
		local key = Keys.Resolve(keyId)
		if not keyId or not key then
			return
		end
		local rarity = Keys.GetRarity(key)
		local _, tier = KeyTiers.Parse(keyId)
		local tierInfo = KeyTiers.Get(tier)
		local spare = spareOf(keyId)
		local onBoard = boardCounts()[keyId] or 0
		if spare + onBoard < 1 and not fuseGuard.IsBusy() then
			closeDetail()
			return
		end
		local style = Keys.VariantStyle(keyId)
		if previewKey ~= keyId then
			previewKey = keyId
			buildPreview(keyId)
		end
		detailCap.SetColor(style)
		detailCap.SetGlyph(Cells.Glyph(key))
		detailName.Text = Variants.Name(keyId)
		detailName.TextColor3 = Kit.Shade(style, 0.2)
		rarityChip.Text = string.upper(rarity.Name)
		local rarityPlate = rarityChip.Parent :: Frame
		rarityPlate.BackgroundColor3 = rarity.Color
		tierChip.Text = string.upper(tierInfo.Name)
		local tierPlate = tierChip.Parent :: Frame
		tierPlate.BackgroundColor3 = if tier == 0 then theme.Grey else tierInfo.Color
		detailIncome.Text = `+{NumberFormat.Compact(Keys.GetIncome(keyId))}/s`
		detailOwned.Text = `Owned: {spare + onBoard}`
		detailBoard.Text = `On your keyboard: {onBoard}`
		detailPerk.Text = Cells.PerkText(key) or ""

		local nextId = Variants.Next(keyId)
		if nextId then
			local cost = Variants.FuseCost
			local multiplier = Variants.Multiplier(tier + 1)
			fuseTitle.Text = `{cost} x {Variants.Name(keyId)}  >  1 {Variants.Name(nextId)}`
			fuseBar.SetValue(math.min(spare, cost) / cost)
			fuseBar.SetText(`{spare}/{cost}`)
			fuseBoost.Text = `Income x{multiplier}  (+{NumberFormat.Compact(Keys.GetIncome(nextId))}/s)`
			fuseButton.Instance.Visible = true
			fuseButton.SetText("FUSE")
			fuseButton.SetColor(if spare >= cost then theme.Green else theme.Grey)
		else
			fuseTitle.Text = "MAX TIER! Can't fuse higher."
			fuseBar.SetValue(1)
			fuseBar.SetText("MAX")
			fuseBoost.Text = `Income x{Variants.Multiplier(tier)}`
			fuseButton.Instance.Visible = false
		end

		local value = Keys.GetSellValue(keyId)
		if spare < 1 then
			sellOne.SetDisabled(true)
			sellOne.SetText("All on board")
			sellAll.SetDisabled(true)
			sellAll.SetText("All on board")
			return
		end
		sellOne.SetDisabled(false)
		sellOne.SetText(`SELL 1  +{NumberFormat.Compact(value)}`)
		sellAll.SetDisabled(false)
		if confirm.IsArmed() then
			sellAll.SetText("Sure? Tap again!")
			sellAll.SetColor(theme.Red)
		else
			sellAll.SetText(`SELL SPARE  +{NumberFormat.Compact(value * spare)}`)
			sellAll.SetColor(theme.Orange)
		end
	end

	local function playMerge(color: Color3)
		local center = UDim2.new(0.5, 0, 0, 70)
		for index = 1, flyerCount do
			local angle = (index - 1) / flyerCount * math.pi * 2 - math.pi / 2
			local start = UDim2.new(0.5, math.cos(angle) * 120, 0, 70 + math.sin(angle) * 60)
			local flyer = Kit.Keycap({
				Parent = detail,
				Name = "Flyer",
				Color = color,
				Glyph = "",
				Size = UDim2.fromOffset(34, 34),
				Position = start,
				AnchorPoint = Vector2.new(0.5, 0.5),
			})
			flyer.Instance.ZIndex = Kit.ZIndex.Hit
			Kit.Tween(flyer.Instance, Kit.Retime(Kit.Motion.Pull, landSeconds), { Position = center })
			Kit.Later(trove, landSeconds, function()
				flyer.Instance:Destroy()
			end)
		end
		Kit.Later(trove, landSeconds, function()
			flash.Fire(0.1)
			previewPop.Scale = 0.6
			Kit.Tween(previewPop, Kit.Motion.Spring, { Scale = 1 })
		end)
	end

	local function fuse()
		local keyId = detailKey
		if not keyId or fuseGuard.IsBusy() then
			return
		end
		local nextId = Variants.Next(keyId)
		if not nextId then
			return
		end
		local cost = Variants.FuseCost
		local spare = spareOf(keyId)
		if spare < cost then
			playUi("Error")
			context.Toast(`Need {cost - spare} more {Variants.Name(keyId)}!`, "Info")
			return
		end
		playMerge((Keys.VariantStyle(keyId)))
		fuseGuard.Run(function()
			local fused = Packets.FuseKey:Fire(keyId)
			task.wait(fuseSeconds)
			return fused
		end, function(isOk: boolean, result: any)
			if isOk and type(result) == "string" and result ~= "" then
				playUi("Confirm")
				context.Toast(`Fused into {Variants.Name(result)}!`, "Good")
				detailKey = result
				confirm.Reset()
				isDirty = true
				refreshAll()
			else
				playUi("Error")
				context.Toast("Couldn't fuse that!", "Bad")
				isDirty = true
			end
		end)
	end

	fuseButton = Kit.Button(trove, {
		Parent = fusePanel,
		Name = "FuseButton",
		Text = "FUSE",
		Glyph = "Sparkle",
		IconLeft = true,
		Position = UDim2.fromOffset(12, 94),
		Size = UDim2.new(1, -24, 0, 50),
		Color = theme.Grey,
		TextSize = Kit.Text.Heading,
		Title = true,
		Callback = fuse,
	})

	sellOne = Kit.Button(trove, {
		Parent = sellRow,
		Name = "SellOne",
		Text = "SELL 1",
		Glyph = "Sell",
		IconLeft = true,
		Size = UDim2.new(0.5, -4, 1, 0),
		Color = theme.Green,
		TextSize = Kit.Text.Note,
		LayoutOrder = 1,
		Callback = function()
			local keyId = detailKey
			if keyId then
				confirm.Reset()
				sell(keyId, 1)
			end
		end,
	})
	sellAll = Kit.Button(trove, {
		Parent = sellRow,
		Name = "SellAll",
		Text = "SELL SPARE",
		Glyph = "Income",
		IconLeft = true,
		Size = UDim2.new(0.5, -4, 1, 0),
		Color = theme.Orange,
		TextSize = Kit.Text.Note,
		LayoutOrder = 2,
		Callback = function()
			local keyId = detailKey
			local key = Keys.Resolve(keyId)
			if not keyId or not key then
				return
			end
			local spare = spareOf(keyId)
			if spare < 1 then
				return
			end
			local _, tier = KeyTiers.Parse(keyId)
			local isPrized = (Cells.RarityRank[key.Rarity] or 1) >= sureRank or tier > 0
			confirm.Press(isPrized, function()
				sell(keyId, spare)
			end)
		end,
	})
	Kit.CloseButton(trove, detail, closeDetail)

	local function openDetail(keyId: string)
		detailKey = keyId
		previewKey = nil
		confirm.Reset()
		setLayout(true)
		previewPop.Scale = 0.85
		Kit.Tween(previewPop, Kit.Motion.Spring, { Scale = 1 })
		refreshDetail()
	end

	local function ensureEntry(keyId: string): Entry?
		local existing = entries[keyId]
		if existing then
			return existing
		end
		local key = Keys.Resolve(keyId)
		if not key then
			return nil
		end
		local _, tier = KeyTiers.Parse(keyId)
		local cell = Cells.New(trove, {
			Parent = grid,
			Key = key,
			KeyId = keyId,
			LayoutOrder = 0,
			HasChips = true,
			Callback = function()
				openDetail(keyId)
			end,
		})
		cell.Instance.Visible = false
		cell.Info.Text = `+{NumberFormat.Compact(Keys.GetIncome(keyId))}/s`
		local entry: Entry = { Id = keyId, Key = key, Tier = tier, Cell = cell }
		entries[keyId] = entry
		return entry
	end

	local function ordered(totals: { [string]: number }): { Entry }
		local mode = sortModes[sortMode]
		local list: { Entry } = {}
		for _, entry in entries do
			table.insert(list, entry)
		end
		table.sort(list, function(a: Entry, b: Entry): boolean
			local incomeA = Keys.GetIncome(a.Id)
			local incomeB = Keys.GetIncome(b.Id)
			local rankA = Cells.RarityRank[a.Key.Rarity] or 1
			local rankB = Cells.RarityRank[b.Key.Rarity] or 1
			local nameA = Variants.Name(a.Id)
			local nameB = Variants.Name(b.Id)
			if mode == "NAME" then
				return nameA < nameB
			end
			if mode == "AMOUNT" and totals[a.Id] ~= totals[b.Id] then
				return (totals[a.Id] or 0) > (totals[b.Id] or 0)
			end
			if mode == "RARITY" and (rankA ~= rankB or a.Tier ~= b.Tier) then
				if rankA ~= rankB then
					return rankA > rankB
				end
				return a.Tier > b.Tier
			end
			if incomeA ~= incomeB then
				return incomeA > incomeB
			end
			if rankA ~= rankB then
				return rankA > rankB
			end
			return nameA < nameB
		end)
		return list
	end

	function refreshAll()
		isDirty = false
		sortButton.SetText(`SORT: {sortModes[sortMode]}`)
		local onBoard = boardCounts()
		for keyId in inventory do
			ensureEntry(keyId)
		end
		for keyId in onBoard do
			ensureEntry(keyId)
		end
		local totals: { [string]: number } = {}
		for keyId in entries do
			totals[keyId] = (inventory[keyId] or 0) + (onBoard[keyId] or 0)
		end
		for rank, entry in ordered(totals) do
			entry.Cell.Instance.LayoutOrder = rank
		end
		local tags = stolenTags()
		local ownedKinds = 0
		for keyId, entry in entries do
			local cell = entry.Cell
			local total = totals[keyId]
			cell.Instance.Visible = total > 0
			if total > 0 then
				ownedKinds += 1
				local count = cell.Count
				if count then
					count.Text = `x{total}`
				end
				local stolenChip = cell.StolenChip
				local stolenLabel = cell.StolenLabel
				if stolenChip and stolenLabel then
					local stolenFrom = tags[keyId]
					stolenChip.Visible = stolenFrom ~= nil
					if stolenFrom then
						stolenLabel.Text = `Stolen from {stolenFrom}`
					end
				end
			end
		end
		emptyLabel.Visible = ownedKinds == 0
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

	trove:Add(dataController:Observe({ "BoardTags" }, function(value: any)
		local copy: { [number]: string } = {}
		if type(value) == "table" then
			for index, tag in value do
				if type(index) == "number" and type(tag) == "string" then
					copy[index] = tag
				end
			end
		end
		boardTags = copy
		markDirty()
	end))

	Kit.Poll(trove, 0, function()
		return isOpen and detailKey ~= nil
	end, function()
		spin(os.clock())
	end)
	Kit.Poll(trove, Kit.PollSeconds.Fast, function()
		return isOpen and isDirty
	end, refreshAll)
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
			if stopLegend then
				stopLegend()
				stopLegend = nil
			end
			trove:Destroy()
		end,
	}
end

return KeysScreen
