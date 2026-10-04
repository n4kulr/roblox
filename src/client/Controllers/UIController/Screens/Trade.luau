--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Keys = require(ReplicatedStorage.Config.Keys)
local Trade = require(ReplicatedStorage.Rules.Trade)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Cells = require(script.Parent.Parent.Cells)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)

type TroveInstance = typeof(Trove.new())
type Entry = { KeyId: string, Count: number }
type Picker = { Wrapper: Frame, Cell: Cells.Cell }

local theme = Kit.Theme
local teal = Color3.fromRGB(0, 168, 168)
local warnRarity = "Epic"
local pickerCellSize = UDim2.fromOffset(120, 176)
local panelHeight = 0.4
local offerTexts = {
	Open = "Both players press READY to trade!",
	Warning = "Make sure this is a fair trade!",
}

local TradeScreen = {}

local function countdownText(seconds: number): string
	local parts: { string } = {}
	for value = seconds, 1, -1 do
		table.insert(parts, tostring(value))
	end
	return `Trading in {table.concat(parts, "...")}`
end

function TradeScreen.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local controller = context.Controllers.TradeController
	local dataController = context.Controllers.DataController
	local playUi = Kit.UiSound(context.Controllers)
	local inventory: { [string]: number } = {}
	local mine: { [string]: number } = {}
	local pickers: { [string]: Picker } = {}
	local offerTrove = Trove.new()
	trove:Add(offerTrove)
	local isOpen = false

	local modal = Kit.Modal(trove, {
		Parent = context.PlayerGui,
		Name = "Trade",
		Title = "TRADE",
		Glyph = "Trade",
		MaxSize = Vector2.new(780, 600),
		HeaderColor = teal,
		OnClose = function()
			context.Close("Trade")
		end,
		Sound = playUi,
	})
	local body = modal.Body

	local banner = Kit.Label({
		Parent = body,
		Name = "Banner",
		Text = offerTexts.Open,
		Position = UDim2.fromOffset(8, 4),
		Size = UDim2.new(1, -16, 0, 30),
		TextSize = 24,
		Color = theme.Gold,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})

	local function sidePanel(name: string, position: UDim2): (Frame, TextLabel, ScrollingFrame)
		local panel = Kit.Panel({
			Parent = body,
			Name = name,
			Position = position,
			Size = UDim2.new(0.5, -9, panelHeight, 0),
			Color = theme.Slate,
		})
		local title = Kit.Label({
			Parent = panel,
			Name = "Title",
			Text = name,
			Position = UDim2.fromOffset(8, 4),
			Size = UDim2.new(1, -16, 0, 26),
			TextSize = 22,
			Align = Enum.TextXAlignment.Center,
			Scaled = true,
		})
		local grid = Kit.GridScroll({
			Parent = panel,
			Name = "Offer",
			Position = UDim2.fromOffset(4, 32),
			Size = UDim2.new(1, -8, 1, -36),
			CellSize = Cells.Size,
		})
		return panel, title, grid
	end

	local _youPanel, _youTitle, youGrid = sidePanel("YOU", UDim2.fromOffset(6, 38))
	local _themPanel, themTitle, themGrid = sidePanel("THEM", UDim2.new(0.5, 3, 0, 38))

	local readyRow = Instance.new("Frame")
	readyRow.Name = "ReadyRow"
	readyRow.BackgroundTransparency = 1
	readyRow.BorderSizePixel = 0
	readyRow.Position = UDim2.new(0, 6, panelHeight, 44)
	readyRow.Size = UDim2.new(1, -12, 0, 52)
	readyRow.Parent = body

	local readyButton = Kit.Button(trove, {
		Parent = readyRow,
		Name = "Ready",
		Text = "READY?",
		Size = UDim2.new(0.5, -9, 1, 0),
		Color = theme.Grey,
		TextSize = 28,
		Callback = function()
			local state = controller:GetState()
			if state then
				controller:SetReady(not state.MyReady)
			end
		end,
		Sound = playUi,
	})
	local theirReady = Kit.Panel({
		Parent = readyRow,
		Name = "TheirReady",
		Position = UDim2.new(0.5, 3, 0, 0),
		Size = UDim2.new(0.5, -3, 1, 0),
		Color = theme.Grey,
	})
	local theirReadyLabel = Kit.Label({
		Parent = theirReady,
		Name = "Text",
		Text = "Waiting...",
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 1, 0),
		TextSize = 24,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})

	local warning = Kit.Label({
		Parent = body,
		Name = "Warning",
		Text = offerTexts.Warning,
		Position = UDim2.new(0, 8, panelHeight, 100),
		Size = UDim2.new(1, -16, 0, 24),
		TextSize = 20,
		Color = theme.Orange,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	warning.Visible = false

	Kit.Label({
		Parent = body,
		Name = "PickerTitle",
		Text = "YOUR SPARE KEYS",
		Position = UDim2.new(0, 8, panelHeight, 126),
		Size = UDim2.new(1, -16, 0, 22),
		TextSize = 18,
		Color = theme.TextDim,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local pickerGrid = Kit.GridScroll({
		Parent = body,
		Name = "Picker",
		Position = UDim2.new(0, 6, panelHeight, 150),
		Size = UDim2.new(1, -12, 1 - panelHeight, -154),
		CellSize = pickerCellSize,
	})

	local function adjust(keyId: string, delta: number)
		local owned = inventory[keyId] or 0
		local nextCount = math.clamp((mine[keyId] or 0) + delta, 0, owned)
		if nextCount ~= (mine[keyId] or 0) then
			controller:SetOffer(keyId, nextCount)
		end
	end

	local function ensurePicker(key: Keys.Key): Picker
		local existing = pickers[key.Id]
		if existing then
			return existing
		end
		local wrapper = Instance.new("Frame")
		wrapper.Name = key.Id
		wrapper.BackgroundTransparency = 1
		wrapper.BorderSizePixel = 0
		wrapper.LayoutOrder = -key.Index
		wrapper.Parent = pickerGrid
		local cell = Cells.New(trove, {
			Parent = wrapper,
			Key = key,
			HasChips = true,
			Sound = playUi,
		})
		Kit.Button(trove, {
			Parent = wrapper,
			Name = "Minus",
			Text = "-",
			Size = UDim2.fromOffset(56, 30),
			Position = UDim2.fromOffset(0, 144),
			Color = theme.Red,
			TextSize = 24,
			Callback = function()
				adjust(key.Id, -1)
			end,
			Sound = playUi,
		})
		Kit.Button(trove, {
			Parent = wrapper,
			Name = "Plus",
			Text = "+",
			Size = UDim2.fromOffset(56, 30),
			Position = UDim2.fromOffset(64, 144),
			Color = theme.Green,
			TextSize = 24,
			Callback = function()
				adjust(key.Id, 1)
			end,
			Sound = playUi,
		})
		local picker: Picker = { Wrapper = wrapper, Cell = cell }
		pickers[key.Id] = picker
		return picker
	end

	local function refreshPicker()
		for _, key in Keys.Catalog do
			local owned = inventory[key.Id] or 0
			local picker = pickers[key.Id]
			if owned > 0 then
				picker = ensurePicker(key)
			end
			if picker then
				picker.Wrapper.Visible = owned > 0
				local offered = mine[key.Id] or 0
				picker.Cell.SetFound(true, if offered > 0 then `Offering {offered}` else "", theme.Gold)
				local count = picker.Cell.Count
				if count then
					count.Text = `x{owned}`
				end
			end
		end
	end

	local function fillOffers(grid: ScrollingFrame, entries: { Entry })
		for _, child in grid:GetChildren() do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for index, entry in entries do
			local key = Keys.ById[entry.KeyId]
			if key then
				local cell = Cells.New(offerTrove, {
					Parent = grid,
					Key = key,
					LayoutOrder = index,
					HasChips = true,
				})
				cell.SetFound(true, "", theme.Gold)
				if cell.Count then
					cell.Count.Text = `x{entry.Count}`
				end
			end
		end
	end

	local function refresh(state: any)
		if state == nil then
			return
		end
		offerTrove:Clean()
		table.clear(mine)
		local hasRareOffer = false
		for _, entry in state.Mine do
			mine[entry.KeyId] = entry.Count
			if Trade.IsAtLeast(entry.KeyId, warnRarity) then
				hasRareOffer = true
			end
		end
		themTitle.Text = string.upper(state.Partner)
		fillOffers(youGrid, state.Mine)
		fillOffers(themGrid, state.Theirs)
		warning.Visible = hasRareOffer
		if state.Phase == 2 and state.Seconds > 0 then
			banner.Text = countdownText(state.Seconds)
			banner.TextColor3 = theme.Good
		else
			banner.Text = offerTexts.Open
			banner.TextColor3 = theme.Gold
		end
		readyButton.SetText(if state.MyReady then "READY!" else "READY?")
		readyButton.SetColor(if state.MyReady then theme.Green else theme.Grey)
		Kit.Paint(theirReady, if state.TheirReady then theme.Green else theme.Grey)
		theirReadyLabel.Text = if state.TheirReady then `{state.Partner} is ready!` else "Waiting..."
		refreshPicker()
	end

	trove:Add(
		controller.StateChanged:Connect(function(state: any)
			if state == nil then
				context.Close("Trade")
				return
			end
			if not isOpen then
				context.Open("Trade")
			end
			refresh(state)
		end),
		"Disconnect"
	)

	trove:Add(dataController:Observe({ "Inventory" }, function(value: any)
		local copy: { [string]: number } = {}
		if type(value) == "table" then
			for keyId, count in value do
				if type(keyId) == "string" and type(count) == "number" and count > 0 then
					copy[keyId] = count
				end
			end
		end
		inventory = copy
		if isOpen then
			refreshPicker()
		end
	end))

	return {
		Modal = true,
		StartsOpen = false,
		Open = function(_self: Types.Screen)
			isOpen = true
			refresh(controller:GetState())
			modal.Show()
		end,
		Close = function(_self: Types.Screen)
			isOpen = false
			controller:Cancel()
			modal.Hide()
		end,
		Destroy = function(_self: Types.Screen)
			trove:Destroy()
		end,
	}
end

return TradeScreen
