--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Keys = require(ReplicatedStorage.Config.Keys)
local Packets = require(ReplicatedStorage.Packets)
local UiAssets = require(ReplicatedStorage.Config.UiAssets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Cells = require(script.Parent.Parent.Cells)
local Economy = require(script.Parent.Parent.Economy)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)

local theme = Kit.Theme
local sureRank = 4
local confirmSeconds = 3
local sellCooldown = 0.2
local refreshSeconds = 0.2

local sortModes = { "BEST", "RARITY", "AMOUNT", "NAME" }
local sortMode = 1

local KeysScreen = {}

function KeysScreen.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local dataController = context.Controllers.DataController
	local playUi = Kit.UiSound(context.Controllers)
	local cells: { [string]: Cells.Cell } = {}
	local inventory: { [string]: number } = {}
	local boardTags: { [number]: string } = {}
	local isOpen = false
	local isDirty = true
	local isEquipping = false
	local isSelling = false
	local lastSell = 0
	local detailKey: string? = nil
	local confirmStamp = 0
	local isConfirming = false
	local tracker: Economy.Tracker

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
		Sound = playUi,
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
		TextSize = 20,
		LayoutOrder = -1,
		Callback = function()
			sortMode = sortMode % #sortModes + 1
			refreshAll()
		end,
		Sound = playUi,
	})

	Kit.Button(trove, {
		Parent = modal.HeaderRight,
		Name = "EquipBest",
		Text = "EQUIP BEST",
		Glyph = "Sparkle",
		IconLeft = true,
		Size = UDim2.fromOffset(176, 46),
		Color = theme.Green,
		TextSize = 20,
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
					context.Toast("Equipped your best keys!", "Good")
				else
					playUi("Error")
					context.Toast("Your keyboard is already the best!", "Info")
				end
			end)
		end,
		Sound = playUi,
	})
	local grid = Kit.GridScroll({
		Parent = body,
		Name = "Grid",
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12),
		CellSize = Cells.Size,
	})
	local emptyLabel = Kit.Label({
		Parent = body,
		Name = "Empty",
		Text = "No keys yet! Hit ROLL to find some!",
		Position = UDim2.new(0, 20, 0.5, -30),
		Size = UDim2.new(1, -40, 0, 60),
		TextSize = 26,
		Align = Enum.TextXAlignment.Center,
		Wrapped = true,
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
	Kit.Corner(overlay, Kit.Radius.Panel)
	local detail = Kit.Panel({
		Parent = overlay,
		Name = "Detail",
		Size = UDim2.fromOffset(340, 400),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = theme.PanelDeep,
		Radius = Kit.Radius.Panel,
		StrokeThickness = 4,
	})
	detail.Active = true
	local detailPop = Instance.new("UIScale")
	detailPop.Parent = detail
	Kit.Burst({
		Parent = detail,
		Diameter = 170,
		Position = UDim2.fromOffset(170, 84),
	})
	local detailCap = Kit.Keycap({
		Parent = detail,
		Color = theme.Grey,
		Size = UDim2.fromOffset(92, 92),
		Position = UDim2.new(0.5, 0, 0, 36),
		AnchorPoint = Vector2.new(0.5, 0),
	})
	local detailName = Kit.Label({
		Parent = detail,
		Name = "Name",
		Text = "",
		Position = UDim2.fromOffset(14, 138),
		Size = UDim2.new(1, -28, 0, 36),
		TextSize = 32,
		Title = true,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local detailInfo = Kit.Label({
		Parent = detail,
		Name = "Info",
		Text = "",
		Position = UDim2.fromOffset(14, 176),
		Size = UDim2.new(1, -28, 0, 22),
		TextSize = 19,
		Subtle = true,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local detailPerk = Kit.Label({
		Parent = detail,
		Name = "Perk",
		Text = "",
		Position = UDim2.fromOffset(14, 200),
		Size = UDim2.new(1, -28, 0, 22),
		TextSize = 19,
		Color = theme.Gold,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local detailOwn = Kit.Label({
		Parent = detail,
		Name = "Own",
		Text = "",
		Position = UDim2.fromOffset(14, 224),
		Size = UDim2.new(1, -28, 0, 22),
		TextSize = 17,
		Subtle = true,
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
		detailCap.SetColor(rarity.Color)
		detailCap.SetGlyph(Cells.Glyph(key))
		detailName.Text = key.Name
		detailName.TextColor3 = Kit.Shade(rarity.Color, 0.2)
		detailInfo.Text = `{rarity.Name}  |  +{NumberFormat.Compact(rarity.Income)}/s`
		detailPerk.Text = Cells.PerkText(key) or ""
		detailOwn.Text = `You have {spare + onBoard}: {onBoard} on keyboard, {spare} spare`
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
		if isConfirming then
			sellAll.SetText("Sure? Tap again!")
			sellAll.SetColor(theme.Red)
		else
			sellAll.SetText(`SELL SPARE  +{NumberFormat.Compact(value * spare)}`)
			sellAll.SetColor(theme.Orange)
		end
	end

	sellOne = Kit.Button(trove, {
		Parent = detail,
		Name = "SellOne",
		Text = "SELL 1",
		Glyph = "Sell",
		IconLeft = true,
		Position = UDim2.fromOffset(16, 264),
		Size = UDim2.new(1, -32, 0, 56),
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
		Text = "SELL SPARE",
		Glyph = "Income",
		IconLeft = true,
		Position = UDim2.fromOffset(16, 332),
		Size = UDim2.new(1, -32, 0, 56),
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
			if (Cells.RarityRank[key.Rarity] or 1) >= sureRank and not isConfirming then
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
	Kit.CloseButton(trove, detail, closeDetail, playUi)
	trove:Connect(overlay.Activated, closeDetail)

	local function openDetail(keyId: string)
		detailKey = keyId
		isConfirming = false
		overlay.Visible = true
		detailPop.Scale = 0.85
		Kit.Tween(detailPop, Kit.PopInfo(), { Scale = 1 })
		refreshDetail()
	end

	for rank, key in Cells.SortedCatalog(true) do
		local cell = Cells.New(trove, {
			Parent = grid,
			Key = key,
			LayoutOrder = rank,
			HasChips = true,
			Callback = function()
				openDetail(key.Id)
			end,
			Sound = playUi,
		})
		cell.Instance.Visible = false
		cell.Info.Text = `+{NumberFormat.Compact(Keys.GetIncome(key.Id))}/s`
		cells[key.Id] = cell
	end

	local rankedKeys = Cells.SortedCatalog(true)
	local function ordered(totals: { [string]: number }): { Keys.Key }
		local mode = sortModes[sortMode]
		local list = table.clone(rankedKeys)
		table.sort(list, function(a: Keys.Key, b: Keys.Key): boolean
			local incomeA = Keys.GetIncome(a.Id)
			local incomeB = Keys.GetIncome(b.Id)
			local rankA = Cells.RarityRank[a.Rarity] or 1
			local rankB = Cells.RarityRank[b.Rarity] or 1
			if mode == "NAME" then
				return a.Name < b.Name
			end
			if mode == "AMOUNT" and totals[a.Id] ~= totals[b.Id] then
				return (totals[a.Id] or 0) > (totals[b.Id] or 0)
			end
			if mode == "RARITY" and rankA ~= rankB then
				return rankA > rankB
			end
			if incomeA ~= incomeB then
				return incomeA > incomeB
			end
			if rankA ~= rankB then
				return rankA > rankB
			end
			return a.Name < b.Name
		end)
		return list
	end

	function refreshAll()
		isDirty = false
		sortButton.SetText(`SORT: {sortModes[sortMode]}`)
		local onBoard = boardCounts()
		local totals: { [string]: number } = {}
		for keyId in cells do
			totals[keyId] = (inventory[keyId] or 0) + (onBoard[keyId] or 0)
		end
		for rank, key in ordered(totals) do
			cells[key.Id].Instance.LayoutOrder = rank
		end
		local tags = stolenTags()
		local ownedKinds = 0
		for keyId, cell in cells do
			local total = (inventory[keyId] or 0) + (onBoard[keyId] or 0)
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
