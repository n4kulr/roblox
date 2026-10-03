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
local rowHeight = 88
local lowQualityMax = 3

local volumes: { { Setting: string, Title: string } } = {
	{ Setting = "RollVolume", Title = "🔊 Roll Sounds" },
	{ Setting = "BoardVolume", Title = "🎹 Keyboard Sounds" },
	{ Setting = "OtherVolume", Title = "👥 Other Players" },
}

local function send(name: string, value: number)
	task.spawn(function()
		Packets.SetSetting:Fire(name, value)
	end)
end

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

	local modal = Kit.Modal(trove, {
		Parent = context.PlayerGui,
		Name = "Settings",
		Title = "⚙️ SETTINGS",
		MaxSize = Vector2.new(600, 560),
		HeaderColor = theme.Grey,
		OnClose = function()
			context.Close("Settings")
		end,
		Sound = playUi,
	})
	local scroll = Kit.Scroll({
		Parent = modal.Panel,
		Name = "List",
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 1, -18),
		Padding = 12,
	})

	local toggles: { [string]: Kit.Toggle } = {}
	local sliderRows: { SliderRow } = {}
	local order = 0

	local function addToggle(setting: string, title: string, detail: string)
		order += 1
		local row = Kit.Panel({
			Parent = scroll,
			Name = setting,
			Size = UDim2.new(1, 0, 0, rowHeight),
			Color = theme.Raised,
			LayoutOrder = order,
		})
		Kit.Label({
			Parent = row,
			Name = "Title",
			Text = title,
			Position = UDim2.fromOffset(14, 12),
			Size = UDim2.new(1, -140, 0, 32),
			TextSize = 24,
			Scaled = true,
		})
		Kit.Label({
			Parent = row,
			Name = "Detail",
			Text = detail,
			Position = UDim2.fromOffset(14, 46),
			Size = UDim2.new(1, -140, 0, 30),
			TextSize = 17,
			Color = theme.TextDim,
			Outline = false,
			Wrapped = true,
			VerticalAlign = Enum.TextYAlignment.Top,
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
			Sound = playUi,
		})
	end

	local function addSlider(setting: string, title: string)
		order += 1
		local row = Kit.Panel({
			Parent = scroll,
			Name = setting,
			Size = UDim2.new(1, 0, 0, rowHeight),
			Color = theme.Raised,
			LayoutOrder = order,
		})
		Kit.Label({
			Parent = row,
			Name = "Title",
			Text = title,
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(1, -110, 0, 32),
			TextSize = 24,
			Scaled = true,
		})
		local percent = Kit.Label({
			Parent = row,
			Name = "Percent",
			Text = "100%",
			Position = UDim2.new(1, -14, 0, 8),
			AnchorPoint = Vector2.new(1, 0),
			Size = UDim2.fromOffset(80, 32),
			TextSize = 22,
			Color = theme.Gold,
			Align = Enum.TextXAlignment.Right,
		})
		local slider = Kit.Slider(trove, {
			Parent = row,
			Name = "Slider",
			Position = UDim2.new(0, 0, 0, 38),
			Size = UDim2.new(1, 0, 0, 46),
			Value = 1,
			OnChanged = function(value: number)
				percent.Text = `{math.floor(value * 100 + 0.5)}%`
			end,
			OnReleased = function(value: number)
				send(setting, value)
			end,
		})
		table.insert(sliderRows, { Setting = setting, Slider = slider, Percent = percent })
	end

	addToggle("LowGraphics", "📉 Low Graphics", "(faster on phones)")
	addToggle("AutoPlace", "✨ Auto-Equip New Keys", "New keys jump onto your keyboard!")
	for _, volume in volumes do
		addSlider(volume.Setting, volume.Title)
	end

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
