--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)

type SliderRow = {
	Setting: string,
	Slider: Kit.Slider,
	Percent: TextLabel,
}

local theme = Kit.Theme
local toggleHeight = 84
local sliderHeight = 100
local codeHeight = 124
local lowQualityMax = 3

local volumes: { { Setting: string, Title: string, Glyph: string } } = {
	{ Setting = "RollVolume", Title = "Roll Sounds", Glyph = "Roll" },
	{ Setting = "BoardVolume", Title = "Keyboard Sounds", Glyph = "Music" },
	{ Setting = "OtherVolume", Title = "Other Players", Glyph = "People" },
	{ Setting = "MusicVolume", Title = "Music", Glyph = "Music" },
}

local effectOptions: { { Value: number, Text: string, Color: Color3 } } = {
	{ Value = 8, Text = "OFF", Color = theme.Grey },
	{ Value = 6, Text = "MYTHIC+", Color = theme.Red },
	{ Value = 5, Text = "LEGENDARY+", Color = theme.Orange },
	{ Value = 4, Text = "EPIC+", Color = theme.Purple },
	{ Value = 1, Text = "ALL", Color = theme.Blue },
}
local effectsHeight = 130
local effectsDefault = 5

local function isLowQuality(): boolean
	local ok, level = pcall(function()
		return UserSettings():GetService("UserGameSettings").SavedQualityLevel.Value
	end)
	return ok and type(level) == "number" and level >= 1 and level <= lowQualityMax
end

local Settings = {}

function Settings.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local dataController = context.Controllers.DataController
	local playUi = Kit.UiSound(context.Controllers)
	local hasCheckedQuality = false

	local function send(name: string, value: number)
		Kit.Spawn(trove, function()
			Packets.SetSetting:Fire(name, value)
		end)
	end

	local modal = Kit.Modal(trove, {
		Parent = context.PlayerGui,
		Name = "Settings",
		Title = "SETTINGS",
		Glyph = "Settings",
		MaxSize = Vector2.new(780, 620),
		HeaderColor = theme.Grey,
		OnClose = function()
			context.Close("Settings")
		end,
	})
	local scroll = Kit.Scroll({
		Parent = modal.Body,
		Name = "List",
		Position = UDim2.fromOffset(6, 4),
		Size = UDim2.new(1, -12, 1, -8),
		Padding = Kit.Space.M,
	})

	local toggles: { [string]: Kit.Toggle } = {}
	local sliderRows: { SliderRow } = {}
	local effects: Kit.TabBar? = nil
	local order = 0

	local function addRow(setting: string, height: number): Frame
		order += 1
		return Kit.Panel({
			Parent = scroll,
			Name = setting,
			Size = UDim2.new(1, 0, 0, height),
			Color = theme.Panel,
			LayoutOrder = order,
			Radius = Kit.Radius.L,
		})
	end

	local function addIcon(row: Frame, glyph: string, color: Color3)
		Kit.IconPlate({
			Parent = row,
			Name = "IconPlate",
			Position = UDim2.fromOffset(Kit.Space.M, Kit.Space.M),
			Size = UDim2.fromOffset(52, 52),
			Color = color,
			Glyph = glyph,
		})
	end

	local function addToggle(setting: string, title: string, detail: string, glyph: string)
		local row = addRow(setting, toggleHeight)
		addIcon(row, glyph, theme.Purple)
		Kit.Label({
			Parent = row,
			Name = "Title",
			Text = title,
			Position = UDim2.fromOffset(78, 8),
			Size = UDim2.new(1, -230, 0, 36),
			TextSize = Kit.Text.Heading,
			Scaled = true,
			Title = true,
		})
		Kit.Label({
			Parent = row,
			Name = "Detail",
			Text = detail,
			Position = UDim2.fromOffset(78, 46),
			Size = UDim2.new(1, -230, 0, 26),
			TextSize = Kit.Text.Note,
			Subtle = true,
			Scaled = true,
		})
		toggles[setting] = Kit.Toggle(trove, {
			Parent = row,
			Name = "Toggle",
			Position = UDim2.new(1, -14, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Value = false,
			OnChanged = function(value: boolean)
				send(setting, if value then 1 else 0)
			end,
		})
	end

	local function addSlider(setting: string, title: string, glyph: string)
		local row = addRow(setting, sliderHeight)
		addIcon(row, glyph, theme.Blue)
		Kit.Label({
			Parent = row,
			Name = "Title",
			Text = title,
			Position = UDim2.fromOffset(78, 6),
			Size = UDim2.new(1, -230, 0, 36),
			TextSize = Kit.Text.Heading,
			Scaled = true,
			Title = true,
		})
		local percent = Kit.Label({
			Parent = row,
			Name = "Percent",
			Text = "100%",
			Position = UDim2.new(1, -14, 0, 8),
			AnchorPoint = Vector2.new(1, 0),
			Size = UDim2.fromOffset(90, 34),
			TextSize = Kit.Text.Subhead,
			Align = Enum.TextXAlignment.Right,
		})
		local slider = Kit.Slider(trove, {
			Parent = row,
			Name = "Slider",
			Position = UDim2.new(0, 64, 0, 44),
			Size = UDim2.new(1, -76, 0, 48),
			Value = 1,
			Color = theme.Green,
			OnChanged = function(value: number)
				percent.Text = `{math.floor(value * 100 + 0.5)}%`
			end,
			OnReleased = function(value: number)
				send(setting, value)
			end,
		})
		table.insert(sliderRows, { Setting = setting, Slider = slider, Percent = percent })
	end

	local function addEffects()
		local row = addRow("EffectsMinRarity", effectsHeight)
		addIcon(row, "Sparkle", theme.Pink)
		Kit.Label({
			Parent = row,
			Name = "Title",
			Text = "Big Reveal Effects",
			Position = UDim2.fromOffset(78, 6),
			Size = UDim2.new(1, -92, 0, 36),
			TextSize = Kit.Text.Heading,
			Scaled = true,
			Title = true,
		})
		Kit.Label({
			Parent = row,
			Name = "Detail",
			Text = "Which pulls get the full-screen show",
			Position = UDim2.fromOffset(78, 42),
			Size = UDim2.new(1, -92, 0, 24),
			TextSize = Kit.Text.Note,
			Subtle = true,
			Scaled = true,
		})
		local tabs: { Kit.Tab } = {}
		for _, option in effectOptions do
			table.insert(tabs, { Id = tostring(option.Value), Text = option.Text, Color = option.Color })
		end
		effects = Kit.TabBar(trove, {
			Parent = row,
			Name = "EffectsSelector",
			Position = UDim2.fromOffset(12, 74),
			Size = UDim2.new(1, -24, 0, 46),
			Tabs = tabs,
			Selected = tostring(effectsDefault),
			TextSize = Kit.Text.Body,
			OnSelect = function(id: string)
				send("EffectsMinRarity", tonumber(id) or effectsDefault)
			end,
		})
	end

	addToggle("LowGraphics", "Low Graphics", "Faster on phones", "Graphics")
	addToggle("AutoPlace", "Auto-Equip New Keys", "New keys jump onto your keyboard!", "Equip")
	addEffects()
	for _, volume in volumes do
		addSlider(volume.Setting, volume.Title, volume.Glyph)
	end

	local codeRow = addRow("Codes", codeHeight)
	Kit.Label({
		Parent = codeRow,
		Name = "Title",
		Text = "CODES",
		Position = UDim2.fromOffset(78, 8),
		Size = UDim2.new(1, -92, 0, 36),
		TextSize = Kit.Text.Heading,
		Scaled = true,
		Title = true,
	})
	addIcon(codeRow, "Code", theme.Orange)
	local codeField = Kit.Panel({
		Parent = codeRow,
		Name = "Field",
		Position = UDim2.fromOffset(78, 56),
		Size = UDim2.new(1, -270, 0, 50),
		Color = theme.Track,
		Radius = Kit.Radius.M,
		Flat = true,
	})
	local codeBox = Instance.new("TextBox")
	codeBox.Name = "Input"
	codeBox.BackgroundTransparency = 1
	codeBox.BorderSizePixel = 0
	codeBox.Position = UDim2.fromOffset(10, 0)
	codeBox.Size = UDim2.new(1, -20, 1, 0)
	codeBox.Font = Kit.Font
	codeBox.TextSize = Kit.Text.Title
	codeBox.TextColor3 = theme.Text
	codeBox.PlaceholderText = "Enter code"
	codeBox.PlaceholderColor3 = theme.Disabled
	codeBox.TextXAlignment = Enum.TextXAlignment.Left
	codeBox.ClearTextOnFocus = false
	codeBox.Text = ""
	codeBox.Parent = codeField
	local isRedeeming = false
	Kit.Button(trove, {
		Parent = codeRow,
		Name = "Redeem",
		Text = "REDEEM",
		Glyph = "Check",
		IconLeft = true,
		Position = UDim2.new(1, -14, 0, 54),
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(170, 56),
		Color = theme.Green,
		TextSize = Kit.Text.Title,
		Callback = function()
			local text = codeBox.Text
			if isRedeeming or #text == 0 then
				return
			end
			isRedeeming = true
			Kit.Spawn(trove, function()
				return Packets.RedeemCode:Fire(text)
			end, function(_isOk: boolean, result: any)
				isRedeeming = false
				if result == 1 then
					codeBox.Text = ""
					playUi("Confirm")
					context.Toast("Code redeemed!", "Good")
					return
				end
				playUi("Error")
				if result == 3 then
					context.Toast("Already used!", "Bad")
				elseif result == 4 then
					context.Toast("That code expired", "Bad")
				else
					context.Toast("That code doesn't exist", "Bad")
				end
			end)
		end,
	})

	trove:Add(dataController:Observe({ "Settings" }, function(value: any)
		if type(value) ~= "table" then
			return
		end
		for setting, toggle in toggles do
			toggle.SetValue(value[setting] == true)
		end
		for _, row in sliderRows do
			local amount = value[row.Setting]
			if type(amount) == "number" then
				row.Slider.SetValue(amount)
				row.Percent.Text = `{math.floor(math.clamp(amount, 0, 1) * 100 + 0.5)}%`
			end
		end
		local selector = effects
		local chosen = value.EffectsMinRarity
		if selector and type(chosen) == "number" then
			selector.Select(tostring(math.clamp(math.floor(chosen), 1, 8)))
		end
		if not hasCheckedQuality then
			hasCheckedQuality = true
			if dataController:Get({ "Tutorial" }) == 0 and value.LowGraphics ~= true and isLowQuality() then
				send("LowGraphics", 1)
			end
		end
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

return Settings
