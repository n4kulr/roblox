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

local KeysScreen = {}

function KeysScreen.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local dataController = context.Controllers.DataController
	local playUi = Kit.UiSound(context.Controllers)
	local cells: { [string]: Cells.Cell } = {}
	local inventory: { [string]: number } = {}
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
		Icon = "🔑",
		IconAsset = UiAssets.Icons.Keys,
		MaxSize = Vector2.new(700, 520),
		HeaderColor = theme.Purple,
		OnClose = function()
			context.Close("Keys")
		end,
		Sound = playUi,
	})
	local body = modal.Body

	Kit.Button(trove, {
		Parent = modal.HeaderRight,
		Name = "EquipBest",
		Text = "⭐ EQUIP BEST",
		Size = UDim2.fromOffset(190, 46),
		Color = theme.Green,
		TextSize = 24,
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
		Parent = body,
		Name = "BoardCount",
		Text = "Keys on your keyboard: 0/10",
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 26),
		TextSize = 20,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local grid = Kit.GridScroll({
		Parent = body,
		Name = "Grid",
		Position = UDim2.fromOffset(6, 36),
		Size = UDim2.new(1, -12, 1, -42),
		CellSize = Cells.Size,
	})
	local emptyLabel = Kit.Label({
		Parent = body,
		Name = "Empty",
		Text = "No keys yet! Hit 🎲 ROLL to find some!",
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
	Kit.Corner(overlay, 5)
	local detail = Kit.Panel({
		Parent = overlay,
		Name = "Detail",
		Size = UDim2.fromOffset(320, 338),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = theme.Slate,
		StrokeThickness = 4,
	})
	detail.Active = true
	local detailPop = Instance.new("UIScale")
	detailPop.Parent = detail
	Kit.Burst({
		Parent = detail,
		Diameter = 150,
		Position = UDim2.fromOffset(160, 72),
	})
	local detailCap = Kit.Keycap({
		Parent = detail,
		Color = theme.Grey,
		Size = UDim2.fromOffset(80, 80),
		Position = UDim2.new(0.5, 0, 0, 28),
		AnchorPoint = Vector2.new(0.5, 0),
	})
	local detailName = Kit.Label({
		Parent = detail,
		Name = "Name",
		Text = "",
		Position = UDim2.fromOffset(14, 112),
		Size = UDim2.new(1, -28, 0, 34),
		TextSize = 30,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local detailInfo = Kit.Label({
		Parent = detail,
		Name = "Info",
		Text = "",
		Position = UDim2.fromOffset(14, 146),
		Size = UDim2.new(1, -28, 0, 22),
		TextSize = 19,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local detailPerk = Kit.Label({
		Parent = detail,
		Name = "Perk",
		Text = "",
		Position = UDim2.fromOffset(14, 168),
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
		Position = UDim2.fromOffset(14, 190),
		Size = UDim2.new(1, -28, 0, 22),
		TextSize = 17,
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
		detailCap.SetColor(rarity.Color)
		detailCap.SetGlyph(Cells.Glyph(key))
		detailName.Text = key.Name
		detailName.TextColor3 = Kit.Shade(rarity.Color, 0.2)
		detailInfo.Text = `{rarity.Name}  •  +{NumberFormat.Compact(rarity.Income)}/s`
		detailPerk.Text = Cells.PerkText(key) or ""
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
			sellAll.SetText(`💰 SELL SPARE  +{NumberFormat.Compact(value * spare)}`)
			sellAll.SetColor(theme.Orange)
		end
	end

	sellOne = Kit.Button(trove, {
		Parent = detail,
		Name = "SellOne",
		Text = "SELL 1",
		Position = UDim2.fromOffset(16, 220),
		Size = UDim2.new(1, -32, 0, 50),
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
		Position = UDim2.fromOffset(16, 278),
		Size = UDim2.new(1, -32, 0, 50),
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

	local function refreshAll()
		isDirty = false
		local onBoard = boardCounts()
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
				local tag = cell.TagChip
				if tag then
					tag.Visible = (onBoard[keyId] or 0) > 0
				end
			end
		end
		emptyLabel.Visible = ownedKinds == 0
		local filled = 0
		for _, count in onBoard do
			filled += count
		end
		boardLabel.Text = `Keys on your keyboard: {filled}/{tracker.GetStats().Slots}`
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
