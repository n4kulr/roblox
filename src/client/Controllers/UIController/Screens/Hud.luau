--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Upgrades = require(ReplicatedStorage.Config.Upgrades)
local Trove = require(ReplicatedStorage.Packages.Trove)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Economy = require(script.Parent.Parent.Economy)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)

local theme = Kit.Theme
local hintStep = 2
local menuButtonWidth = 80
local menuButtonHeight = 86
local rollWidth = 200
local rollHeight = 98
local autoWidth = 130
local goldenWidth = 200
local goldenHeight = 84
local barGap = 12
local barDesignWidth = 2 * (rollWidth / 2 + barGap + goldenWidth) + 24

local Hud = {}

function Hud.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local dataController = context.Controllers.DataController
	local rollController = context.Controllers.RollController
	local playUi = Kit.UiSound(context.Controllers)
	local gui, root = Kit.ScreenGui("ThockHud", 1, context.PlayerGui, trove)
	local tracker = Economy.Track(dataController, trove)
	local tutorialStep = 0
	local lastCash = ""
	local lastIncome = ""
	local lastStats = ""
	local isHinting = false

	local left = Instance.new("Frame")
	left.Name = "Left"
	left.BackgroundTransparency = 1
	left.AnchorPoint = Vector2.new(0, 0.5)
	left.Position = UDim2.new(0, 12, 0.5, 0)
	left.Size = UDim2.fromOffset(190, 0)
	left.AutomaticSize = Enum.AutomaticSize.Y
	local leftList = Instance.new("UIListLayout")
	leftList.SortOrder = Enum.SortOrder.LayoutOrder
	leftList.FillDirection = Enum.FillDirection.Vertical
	leftList.HorizontalAlignment = Enum.HorizontalAlignment.Left
	leftList.Padding = UDim.new(0, 8)
	leftList.Parent = left
	left.Parent = root

	local pill = Kit.Panel({
		Parent = left,
		Name = "Clicks",
		Size = UDim2.new(1, 0, 0, 78),
		Color = theme.Deep,
		Radius = 20,
		LayoutOrder = 1,
	})
	Kit.Label({
		Parent = pill,
		Name = "Icon",
		Text = "⌨️",
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(0, 48, 1, 0),
		TextSize = 36,
		Align = Enum.TextXAlignment.Center,
		Outline = false,
		Scaled = true,
	})
	local cashLabel = Kit.Label({
		Parent = pill,
		Name = "Cash",
		Text = "...",
		Position = UDim2.fromOffset(60, 6),
		Size = UDim2.new(1, -68, 0, 40),
		TextSize = 36,
		Color = theme.Gold,
		Scaled = true,
	})
	local incomeLabel = Kit.Label({
		Parent = pill,
		Name = "Income",
		Text = "",
		Position = UDim2.fromOffset(60, 46),
		Size = UDim2.new(1, -68, 0, 24),
		TextSize = 20,
		Color = theme.Good,
		Scaled = true,
	})
	local readout = Kit.Panel({
		Parent = left,
		Name = "Readout",
		Size = UDim2.new(1, 0, 0, 34),
		Color = theme.Deep,
		Radius = 17,
		StrokeThickness = 2,
		LayoutOrder = 2,
	})
	local statsLabel = Kit.Label({
		Parent = readout,
		Name = "Stats",
		Text = "",
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.new(1, -12, 1, 0),
		TextSize = 18,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})

	local function menuButton(
		name: string,
		icon: string,
		label: string,
		color: Color3,
		order: number,
		target: string
	)
		local holder = Instance.new("Frame")
		holder.Name = `{name}Holder`
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(menuButtonWidth, menuButtonHeight)
		holder.LayoutOrder = order
		holder.Parent = left
		local button = Kit.Button(trove, {
			Parent = holder,
			Name = name,
			Icon = icon,
			Text = label,
			Size = UDim2.fromScale(1, 1),
			Color = color,
			TextSize = 18,
			IconSize = 36,
			Radius = 16,
			Callback = function()
				if context.IsOpen(target) then
					context.Close(target)
				else
					context.Open(target)
				end
			end,
			Sound = playUi,
		})
		return button, holder
	end
	local shopButton, shopHolder = menuButton("Shop", "🛒", "SHOP", theme.Green, 3, "Shop")
	menuButton("Keys", "🔑", "KEYS", theme.Purple, 4, "Keys")
	menuButton("Settings", "⚙️", "SETTINGS", theme.Grey, 5, "Settings")

	local tooltip = Kit.Panel({
		Parent = shopHolder,
		Name = "Tooltip",
		Size = UDim2.fromOffset(270, 52),
		Position = UDim2.new(1, 14, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Color = theme.Gold,
		Radius = 16,
	})
	tooltip.Visible = false
	Kit.Label({
		Parent = tooltip,
		Name = "Text",
		Text = "👈 Buy your first upgrade!",
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 1, 0),
		TextSize = 22,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local bounce = Kit.Tween(
		tooltip,
		TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = UDim2.new(1, 24, 0.5, 0) }
	)
	bounce:Pause()
	trove:Add(function()
		bounce:Cancel()
		bounce:Destroy()
	end)

	local bottom = Instance.new("Frame")
	bottom.Name = "Bottom"
	bottom.BackgroundTransparency = 1
	bottom.AnchorPoint = Vector2.new(0.5, 1)
	bottom.Position = UDim2.new(0.5, 0, 1, -14)
	bottom.Size = UDim2.fromOffset(0, rollHeight)
	local fitScale = Instance.new("UIScale")
	fitScale.Name = "FitScale"
	fitScale.Parent = bottom
	bottom.Parent = root
	local function fit()
		local viewport = root:FindFirstChild("ViewportScale")
		local factor = if viewport
				and viewport:IsA("UIScale")
				and viewport.Scale > 0
			then viewport.Scale
			else 1
		local available = root.AbsoluteSize.X / factor
		fitScale.Scale = math.clamp(available / barDesignWidth, 0.5, 1)
	end
	fit()
	trove:Connect(root:GetPropertyChangedSignal("AbsoluteSize"), fit)

	Kit.Button(trove, {
		Parent = bottom,
		Name = "Roll",
		Text = "🎲 ROLL!",
		Size = UDim2.fromOffset(rollWidth, rollHeight),
		Position = UDim2.new(0, 0, 1, 0),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = Color3.fromRGB(255, 176, 28),
		TextSize = 44,
		Radius = 20,
		Lip = 8,
		Immediate = true,
		Callback = function()
			rollController:RequestRoll()
		end,
	})
	local autoButton = Kit.Button(trove, {
		Parent = bottom,
		Name = "Auto",
		Icon = "🔁",
		Text = "AUTO: OFF",
		Size = UDim2.fromOffset(autoWidth, 84),
		Position = UDim2.new(0, rollWidth / 2 + barGap, 1, 0),
		AnchorPoint = Vector2.new(0, 1),
		Color = theme.Grey,
		TextSize = 20,
		IconSize = 32,
		Radius = 18,
		Callback = function()
			rollController:SetAuto(not rollController:IsAuto())
		end,
		Sound = playUi,
	})
	local function showAuto(isOn: boolean)
		autoButton.SetText(if isOn then "AUTO: ON" else "AUTO: OFF")
		autoButton.SetColor(if isOn then theme.Green else theme.Grey)
		autoButton.SetGlow(isOn)
	end
	showAuto(rollController:IsAuto())
	trove:Add(rollController.AutoChanged:Connect(showAuto))

	local golden = Kit.Panel({
		Parent = bottom,
		Name = "Golden",
		Size = UDim2.fromOffset(goldenWidth, goldenHeight),
		Position = UDim2.new(0, -(rollWidth / 2 + barGap), 1, 0),
		AnchorPoint = Vector2.new(1, 1),
		Color = theme.Deep,
		Radius = 18,
	})
	local goldenStroke = golden:FindFirstChild("Stroke") :: UIStroke
	goldenStroke.Color = theme.Gold
	local goldenTitle = Kit.Label({
		Parent = golden,
		Name = "Title",
		Text = "⭐ GOLDEN ROLL",
		Position = UDim2.fromOffset(8, 6),
		Size = UDim2.new(1, -16, 0, 24),
		TextSize = 22,
		Color = theme.Gold,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local goldenTrack = Instance.new("Frame")
	goldenTrack.Name = "Track"
	goldenTrack.BorderSizePixel = 0
	goldenTrack.Position = UDim2.new(0, 10, 1, -12)
	goldenTrack.AnchorPoint = Vector2.new(0, 1)
	goldenTrack.Size = UDim2.new(1, -20, 0, 30)
	Kit.Paint(goldenTrack, theme.Ink)
	Kit.Corner(goldenTrack, 15)
	Kit.Stroke(goldenTrack, theme.Ink, 2)
	goldenTrack.Parent = golden
	local goldenFill = Instance.new("Frame")
	goldenFill.Name = "Fill"
	goldenFill.BorderSizePixel = 0
	goldenFill.Size = UDim2.fromScale(0, 1)
	Kit.Paint(goldenFill, theme.Gold)
	Kit.Corner(goldenFill, 15)
	goldenFill.Parent = goldenTrack
	local goldenCount = Kit.Label({
		Parent = goldenTrack,
		Name = "Count",
		Text = "0/" .. GameConfig.GoldenRollEvery,
		Size = UDim2.fromScale(1, 1),
		TextSize = 20,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local goldenPulse: Tween? = nil
	local isGoldenNext = false
	local function setGoldenNext(value: boolean)
		if value == isGoldenNext then
			return
		end
		isGoldenNext = value
		if goldenPulse then
			goldenPulse:Cancel()
			goldenPulse:Destroy()
			goldenPulse = nil
		end
		goldenStroke.Thickness = 3
		goldenTitle.Text = if value then "NEXT ROLL IS GOLDEN! ⭐" else "⭐ GOLDEN ROLL"
		if value then
			goldenStroke.Thickness = 4
			goldenPulse = Kit.Tween(
				goldenStroke,
				TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Thickness = 9 }
			)
		end
	end
	trove:Add(function()
		if goldenPulse then
			goldenPulse:Cancel()
			goldenPulse:Destroy()
			goldenPulse = nil
		end
	end)
	trove:Add(dataController:Observe({ "Rolls" }, function(value: any)
		local rolls = if type(value) == "number" then value else 0
		local count = rolls % GameConfig.GoldenRollEvery
		goldenCount.Text = `{count}/{GameConfig.GoldenRollEvery}`
		goldenFill.Size = UDim2.fromScale(math.clamp(count / GameConfig.GoldenRollEvery, 0, 1), 1)
		setGoldenNext(count == GameConfig.GoldenRollEvery - 1)
	end))

	local function setHinting(value: boolean)
		if value == isHinting then
			return
		end
		isHinting = value
		tooltip.Visible = value
		shopButton.SetGlow(value)
		if value then
			bounce:Play()
		else
			bounce:Pause()
		end
	end
	trove:Add(function()
		setHinting(false)
	end)

	local function cheapestCost(): number?
		local cheapest: number? = nil
		for _, upgrade in Upgrades.List do
			local cost = Upgrades.Cost(upgrade, tracker.GetLevel(upgrade.Id))
			if cost and (not cheapest or cost < cheapest) then
				cheapest = cost
			end
		end
		return cheapest
	end

	local function refresh()
		local balance = tracker.Balance()
		local stats = tracker.GetStats()
		local cashText = if balance then NumberFormat.Compact(balance) else "..."
		if cashText ~= lastCash then
			lastCash = cashText
			cashLabel.Text = cashText
		end
		local incomeText = if balance then `+{NumberFormat.Compact(stats.Rate)}/s` else ""
		if incomeText ~= lastIncome then
			lastIncome = incomeText
			incomeLabel.Text = incomeText
		end
		local statsText = if balance
			then string.format("🍀 x%.1f   ⚡ %.1f/s", stats.Luck, stats.RollsPerSecond)
			else ""
		if statsText ~= lastStats then
			lastStats = statsText
			statsLabel.Text = statsText
		end
		local cost = cheapestCost()
		setHinting(tutorialStep == hintStep and balance ~= nil and cost ~= nil and balance >= cost)
	end

	trove:Add(dataController:Observe({ "Tutorial" }, function(value: any)
		tutorialStep = if type(value) == "number" then value else 0
	end))

	local elapsedSinceRefresh = 0
	trove:Connect(RunService.Heartbeat, function(dt: number)
		elapsedSinceRefresh += dt
		if elapsedSinceRefresh >= 0.1 then
			elapsedSinceRefresh = 0
			refresh()
		end
	end)
	refresh()

	return {
		Modal = false,
		StartsOpen = true,
		Open = function(_self: Types.Screen)
			gui.Enabled = true
		end,
		Close = function(_self: Types.Screen)
			gui.Enabled = false
		end,
		Destroy = function(_self: Types.Screen)
			trove:Destroy()
		end,
	}
end

return Hud
