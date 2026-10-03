--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Economy = require(script.Parent.Parent.Economy)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)

type TroveInstance = typeof(Trove.new())
type InventoryRow = {
	Key: Keys.Key,
	Trove: TroveInstance,
	Button: Kit.Button,
	Count: TextLabel,
	SellOne: Kit.Button,
	SellAll: Kit.Button,
	ConfirmStamp: number,
}

local theme = Kit.Theme
local rowHeight = 80
local boardHeight = 150
local confirmSeconds = 3
local sellCooldown = 0.25
local placeCooldown = 0.12
local lockedColor = Color3.fromRGB(30, 31, 36)

local rarityIndex: { [string]: number } = {}
for index, rarity in Keys.Rarities do
	rarityIndex[rarity.Name] = index
end

local sortRank: { [string]: number } = {}
do
	local sorted = table.clone(Keys.Catalog)
	table.sort(sorted, function(a: Keys.Key, b: Keys.Key)
		local rankA = rarityIndex[a.Rarity]
		local rankB = rarityIndex[b.Rarity]
		if rankA ~= rankB then
			return rankA > rankB
		end
		return a.Name < b.Name
	end)
	for rank, key in sorted do
		sortRank[key.Id] = rank
	end
end

local function shortName(key: Keys.Key): string
	local letters = ""
	for word in string.gmatch(key.Name, "[^%s%-]+") do
		letters ..= string.sub(word, 1, 1)
	end
	return letters
end

local function perkText(key: Keys.Key): string?
	local perk = key.Perk
	if not perk then
		return nil
	end
	local percent = math.floor(perk.Amount * 100 + 0.5)
	local label = if perk.Kind == "Speed" then "Roll Speed" else perk.Kind
	return `+{percent}% {label}`
end

local function detailText(key: Keys.Key): string
	local rarity = Keys.GetRarity(key)
	local text = `{rarity.Name}  |  +{NumberFormat.Compact(rarity.Income)}/s`
	local perk = perkText(key)
	if perk then
		text ..= `  |  {perk}`
	end
	return text
end

local KeysScreen = {}

function KeysScreen.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local playUi = Kit.UiSound(context.Controllers)
	local caps: { TextButton } = {}
	local capButtons: { Kit.Button } = {}
	local rows: { [string]: InventoryRow } = {}
	local inventory: { [string]: number } = {}
	local selected: string? = nil
	local isPlacing = false
	local isSelling = false
	local lastSell = 0
	local lastPlace = 0
	local tracker: Economy.Tracker
	local isReady = false

	local modal = Kit.Modal(trove, {
		Parent = context.PlayerGui,
		Name = "Keys",
		Title = "Keys",
		MaxSize = Vector2.new(780, 620),
		OnClose = function()
			context.Close("Keys")
		end,
		Sound = playUi,
	})
	local panel = modal.Panel

	Kit.Label({
		Parent = panel,
		Name = "Hint",
		Text = "Tap a key below, then tap a slot. Tap a placed key to take it back.",
		Position = UDim2.fromOffset(18, 50),
		Size = UDim2.new(1, -36, 0, 22),
		TextSize = 15,
		Color = theme.TextDim,
		Bold = false,
	})
	local grid = Kit.Grid(
		panel,
		"Board",
		UDim2.new(0.09, 0, 0.3, 0),
		UDim2.new(0.0111, 0, 0.05, 0),
		GameConfig.BoardColumns
	)
	grid.Position = UDim2.fromOffset(12, 78)
	grid.Size = UDim2.new(1, -24, 0, boardHeight)
	Kit.Label({
		Parent = panel,
		Name = "InventoryTitle",
		Text = "Spare keys",
		Position = UDim2.fromOffset(18, 78 + boardHeight + 6),
		Size = UDim2.new(1, -36, 0, 24),
		TextSize = 20,
	})
	local scroll = Kit.Scroll({
		Parent = panel,
		Name = "Inventory",
		Position = UDim2.fromOffset(12, 78 + boardHeight + 34),
		Size = UDim2.new(1, -24, 1, -(78 + boardHeight + 46)),
		Padding = 8,
	})
	local emptyLabel = Kit.Label({
		Parent = scroll,
		Name = "Empty",
		Text = "No spare keys. Roll to find more!",
		Size = UDim2.new(1, 0, 0, 40),
		TextSize = 18,
		Color = theme.TextDim,
		Align = Enum.TextXAlignment.Center,
		LayoutOrder = -1,
	})

	local function refreshCap(slot: number)
		local button = capButtons[slot]
		local cap = caps[slot]
		local board = tracker.GetBoard()
		local keyId = board[slot]
		local key = if type(keyId) == "string" then Keys.ById[keyId] else nil
		if slot > tracker.GetStats().Slots then
			button.SetColor(lockedColor)
			cap.Text = "🔒"
			cap.TextColor3 = theme.TextDim
		elseif key then
			button.SetColor(Keys.GetRarity(key).Color)
			cap.Text = shortName(key)
			cap.TextColor3 = theme.TextDark
		else
			button.SetColor(theme.Raised)
			cap.Text = if selected then "+" else ""
			cap.TextColor3 = theme.TextDim
		end
	end

	local function refreshBoard()
		if not isReady then
			return
		end
		for slot = 1, GameConfig.BoardSlots do
			refreshCap(slot)
		end
	end

	local function refreshSelection()
		for keyId, row in rows do
			local stroke = row.Button.Instance:FindFirstChildOfClass("UIStroke")
			if stroke then
				local isSelected = keyId == selected
				stroke.Color = if isSelected then theme.Gold else Keys.GetRarity(row.Key).Color
				stroke.Thickness = if isSelected then 3 else 1.5
			end
		end
		refreshBoard()
	end

	local function selectKey(keyId: string)
		selected = if selected == keyId then nil else keyId
		refreshSelection()
	end

	local function sell(keyId: string, count: number, row: InventoryRow)
		local now = os.clock()
		if isSelling or now - lastSell < sellCooldown then
			return
		end
		isSelling = true
		lastSell = now
		task.spawn(function()
			local success = Packets.SellKey:Fire(keyId, count)
			isSelling = false
			if success == true then
				playUi("Confirm")
			else
				playUi("Error")
				if row.Button.Instance.Parent then
					Kit.Shake(row.Button.Instance)
				end
			end
		end)
	end

	local function sellAll(keyId: string, row: InventoryRow)
		local count = inventory[keyId] or 0
		if count <= 0 then
			return
		end
		if
			rarityIndex[row.Key.Rarity] >= rarityIndex.Epic
			and os.clock() - row.ConfirmStamp > confirmSeconds
		then
			local stamp = os.clock()
			row.ConfirmStamp = stamp
			row.SellAll.SetText(`Confirm?\n${NumberFormat.Compact(Keys.GetSellValue(keyId) * count)}`)
			task.delay(confirmSeconds, function()
				if row.ConfirmStamp == stamp and row.SellAll.Instance.Parent then
					row.ConfirmStamp = 0
					row.SellAll.SetText(
						`Sell All\n${NumberFormat.Compact(Keys.GetSellValue(keyId) * (inventory[keyId] or 0))}`
					)
				end
			end)
			return
		end
		row.ConfirmStamp = 0
		sell(keyId, count, row)
	end

	local function updateRow(keyId: string, row: InventoryRow, count: number)
		local value = Keys.GetSellValue(keyId)
		row.Count.Text = `x{count}`
		row.SellOne.SetText(`Sell 1\n${NumberFormat.Compact(value)}`)
		if os.clock() - row.ConfirmStamp > confirmSeconds then
			row.ConfirmStamp = 0
			row.SellAll.SetText(`Sell All\n${NumberFormat.Compact(value * count)}`)
		else
			row.SellAll.SetText(`Confirm?\n${NumberFormat.Compact(value * count)}`)
		end
	end

	local function createRow(key: Keys.Key): InventoryRow
		local keyId = key.Id
		local rarity = Keys.GetRarity(key)
		local rowTrove = Trove.new()
		trove:Add(rowTrove :: any)
		local row: InventoryRow = {
			Key = key,
			Trove = rowTrove,
			Button = nil :: any,
			Count = nil :: any,
			SellOne = nil :: any,
			SellAll = nil :: any,
			ConfirmStamp = 0,
		}
		row.Button = Kit.Button(rowTrove, {
			Parent = scroll,
			Name = keyId,
			Size = UDim2.new(1, 0, 0, rowHeight),
			LayoutOrder = sortRank[keyId],
			Color = theme.Raised,
			Callback = function()
				selectKey(keyId)
			end,
			Sound = playUi,
		})
		local frame = row.Button.Instance
		local stroke = frame:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = rarity.Color
		end
		Kit.Label({
			Parent = frame,
			Name = "KeyName",
			Text = key.Name,
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(1, -290, 0, 28),
			TextSize = 22,
			Color = rarity.Color,
		})
		Kit.Label({
			Parent = frame,
			Name = "Detail",
			Text = detailText(key),
			Position = UDim2.fromOffset(14, 40),
			Size = UDim2.new(1, -290, 0, 24),
			TextSize = 15,
			Color = theme.TextDim,
			Bold = false,
		})
		row.Count = Kit.Label({
			Parent = frame,
			Name = "Count",
			Position = UDim2.new(1, -216, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Size = UDim2.fromOffset(60, 30),
			TextSize = 24,
			Align = Enum.TextXAlignment.Right,
		})
		row.SellOne = Kit.Button(rowTrove, {
			Parent = frame,
			Name = "SellOne",
			Position = UDim2.new(1, -112, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Size = UDim2.fromOffset(96, 58),
			TextSize = 15,
			Color = theme.Panel,
			Callback = function()
				sell(keyId, 1, row)
			end,
			Sound = playUi,
		})
		row.SellAll = Kit.Button(rowTrove, {
			Parent = frame,
			Name = "SellAll",
			Position = UDim2.new(1, -8, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Size = UDim2.fromOffset(96, 58),
			TextSize = 15,
			Color = theme.Panel,
			Callback = function()
				sellAll(keyId, row)
			end,
			Sound = playUi,
		})
		return row
	end

	local function refreshInventory()
		local anyKey = false
		for keyId, count in inventory do
			local key = Keys.ById[keyId]
			if key and count > 0 then
				anyKey = true
				local row = rows[keyId]
				if not row then
					row = createRow(key)
					rows[keyId] = row
				end
				updateRow(keyId, row, count)
			end
		end
		for keyId, row in rows do
			if (inventory[keyId] or 0) <= 0 then
				rows[keyId] = nil
				row.Button.Instance:Destroy()
				trove:Remove(row.Trove :: any)
			end
		end
		local current = selected
		if current and (inventory[current] or 0) <= 0 then
			selected = nil
		end
		emptyLabel.Visible = not anyKey
		refreshSelection()
	end

	local function onSlot(slot: number)
		local now = os.clock()
		if isPlacing or now - lastPlace < placeCooldown then
			return
		end
		if slot > tracker.GetStats().Slots then
			playUi("Error")
			Kit.Shake(caps[slot])
			return
		end
		local keyId = selected
		local occupied = tracker.GetBoard()[slot]
		if not keyId and (occupied == nil or occupied == "") then
			return
		end
		isPlacing = true
		lastPlace = now
		task.spawn(function()
			local success: any
			if keyId then
				success = Packets.PlaceKey:Fire(slot, keyId)
			else
				success = Packets.ClearSlot:Fire(slot)
			end
			isPlacing = false
			if success ~= true then
				playUi("Error")
				Kit.Shake(caps[slot])
			end
		end)
	end

	for slot = 1, GameConfig.BoardSlots do
		local button = Kit.Button(trove, {
			Parent = grid,
			Name = `Slot{slot}`,
			LayoutOrder = slot,
			Color = theme.Raised,
			TextSize = 18,
			Callback = function()
				onSlot(slot)
			end,
		})
		local instance = button.Instance
		instance.TextScaled = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 22
		limit.MinTextSize = 8
		limit.Parent = instance
		caps[slot] = instance
		capButtons[slot] = button
	end

	tracker = Economy.Track(context.Controllers.DataController, trove, refreshBoard)
	trove:Add(context.Controllers.DataController:Observe({ "Inventory" }, function(value: any)
		local copy: { [string]: number } = {}
		if type(value) == "table" then
			for keyId, count in value do
				if type(keyId) == "string" and type(count) == "number" then
					copy[keyId] = count
				end
			end
		end
		inventory = copy
		refreshInventory()
	end))
	isReady = true
	refreshBoard()

	return {
		Modal = true,
		StartsOpen = false,
		Open = function(_self: Types.Screen)
			refreshBoard()
			modal.Show()
		end,
		Close = function(_self: Types.Screen)
			selected = nil
			refreshSelection()
			modal.Hide()
		end,
		Destroy = function(_self: Types.Screen)
			trove:Destroy()
		end,
	}
end

return KeysScreen
