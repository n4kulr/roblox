--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local UiAssets = require(ReplicatedStorage.Config.UiAssets)
local Upgrades = require(ReplicatedStorage.Config.Upgrades)
local Trove = require(ReplicatedStorage.Packages.Trove)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Economy = require(script.Parent.Parent.Economy)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)

type BadgeText = {
	Luck: TextLabel,
	Speed: TextLabel,
	Income: TextLabel,
}

local theme = Kit.Theme
local hintStep = 2
local gridCell = 84
local gridGap = 8
local rollWidth = 200
local rollHeight = 98
local autoWidth = 130
local autoHeight = 84
local goldenWidth = 200
local goldenHeight = 62
local barGap = 12
local barHalfWidth = rollWidth / 2 + barGap + goldenWidth
local sideReserve = 226
local goldenColor = Color3.fromRGB(255, 160, 24)
local cashColor = Color3.fromRGB(84, 236, 72)

local function multiplierText(value: number): string
	local text = string.format("%.2f", value)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	return `x{text}`
end

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

	local function toggleScreen(target: string)
		if context.IsOpen(target) then
			context.Close(target)
		else
			context.Open(target)
		end
	end

	local left = Instance.new("Frame")
	left.Name = "Menu"
	left.BackgroundTransparency = 1
	left.AnchorPoint = Vector2.new(0, 0.5)
	left.Position = UDim2.new(0, 12, 0.5, 0)
	left.Size = UDim2.fromOffset(gridCell * 2 + gridGap, gridCell * 2 + gridGap)
	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.CellSize = UDim2.fromOffset(gridCell, gridCell)
	grid.CellPadding = UDim2.fromOffset(gridGap, gridGap)
	grid.Parent = left
	left.Parent = root

	local function menuButton(
		name: string,
		emoji: string,
		asset: string,
		label: string,
		color: Color3,
		order: number,
		target: string
	): Kit.Button
		return Kit.Button(trove, {
			Parent = left,
			Name = name,
			Icon = emoji,
			IconAsset = asset,
			Text = label,
			Color = color,
			TextSize = 18,
			LayoutOrder = order,
			Callback = function()
				toggleScreen(target)
			end,
			Sound = playUi,
		})
	end
	local upgradesButton =
		menuButton("Upgrades", "🛒", UiAssets.Icons.Upgrades, "UPGRADES", theme.Green, 1, "Upgrades")
	menuButton("Keys", "🔑", UiAssets.Icons.Keys, "KEYS", theme.Purple, 2, "Keys")
	menuButton("Index", "📘", UiAssets.Icons.Index, "INDEX", theme.Blue, 3, "Index")
	menuButton("Settings", "⚙️", UiAssets.Icons.Settings, "SETTINGS", theme.Grey, 4, "Settings")
	local upgradesBadge = Kit.Badge(upgradesButton.Instance, "!")
	upgradesBadge.Visible = false

	local tooltip = Kit.Panel({
		Parent = left,
		Name = "Tooltip",
		Size = UDim2.fromOffset(250, 46),
		Position = UDim2.new(0, 0, 0, -12),
		AnchorPoint = Vector2.new(0, 1),
		Color = theme.Yellow,
		Shards = true,
	})
	tooltip.Visible = false
	Kit.Label({
		Parent = tooltip,
		Name = "Text",
		Text = "👇 Buy your first upgrade!",
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 1, 0),
		TextSize = 22,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local bounce = Kit.Tween(
		tooltip,
		TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = UDim2.new(0, 0, 0, -2) }
	)
	bounce:Pause()
	trove:Add(function()
		bounce:Cancel()
		bounce:Destroy()
	end)

	local top = Instance.new("Frame")
	top.Name = "Tabs"
	top.BackgroundTransparency = 1
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, 6)
	top.AutomaticSize = Enum.AutomaticSize.XY
	top.Size = UDim2.new()
	local tabList = Instance.new("UIListLayout")
	tabList.SortOrder = Enum.SortOrder.LayoutOrder
	tabList.FillDirection = Enum.FillDirection.Horizontal
	tabList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tabList.VerticalAlignment = Enum.VerticalAlignment.Top
	tabList.Padding = UDim.new(0, 8)
	tabList.Parent = top
	top.Parent = root
	local upgradesTab = Kit.Button(trove, {
		Parent = top,
		Name = "UpgradesTab",
		Text = "UPGRADES",
		Size = UDim2.fromOffset(150, 48),
		Color = theme.Green,
		TextSize = 24,
		LayoutOrder = 1,
		Callback = function()
			toggleScreen("Upgrades")
		end,
		Sound = playUi,
	})
	Kit.Button(trove, {
		Parent = top,
		Name = "MyBase",
		Text = "MY BASE",
		Icon = "🏠",
		IconAsset = UiAssets.Icons.MyBase,
		IconLeft = true,
		Size = UDim2.fromOffset(196, 58),
		Color = theme.Blue,
		TextSize = 30,
		LayoutOrder = 2,
		Callback = function()
			if not rollController:TeleportToBase() then
				context.Toast("Your base isn't ready yet!", "Bad")
			end
		end,
		Sound = playUi,
	})
	Kit.Button(trove, {
		Parent = top,
		Name = "KeysTab",
		Text = "KEYS",
		Size = UDim2.fromOffset(150, 48),
		Color = theme.Purple,
		TextSize = 24,
		LayoutOrder = 3,
		Callback = function()
			toggleScreen("Keys")
		end,
		Sound = playUi,
	})

	local money = Instance.new("Frame")
	money.Name = "Currency"
	money.BackgroundTransparency = 1
	money.AnchorPoint = Vector2.new(0, 1)
	money.Position = UDim2.new(0, 12, 1, -12)
	money.Size = UDim2.fromOffset(190, 92)
	money.Parent = root
	local rollsLabel = Kit.Label({
		Parent = money,
		Name = "Rolls",
		Text = "🎲 0 rolls",
		Position = UDim2.fromOffset(4, 0),
		Size = UDim2.new(1, -4, 0, 20),
		TextSize = 18,
		Color = theme.TextDim,
	})
	Kit.Icon({
		Parent = money,
		Name = "Icon",
		Emoji = "⌨️",
		Asset = UiAssets.Icons.Clicks,
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.fromOffset(44, 44),
	})
	local cashLabel = Kit.Label({
		Parent = money,
		Name = "Cash",
		Text = "...",
		Position = UDim2.fromOffset(48, 22),
		Size = UDim2.new(1, -48, 0, 44),
		TextSize = 40,
		Color = cashColor,
		Scaled = true,
	})
	local incomeLabel = Kit.Label({
		Parent = money,
		Name = "Income",
		Text = "",
		Position = UDim2.fromOffset(50, 66),
		Size = UDim2.new(1, -50, 0, 22),
		TextSize = 20,
		Color = Color3.fromRGB(200, 255, 190),
	})

	local multipliers = Instance.new("Frame")
	multipliers.Name = "Multipliers"
	multipliers.BackgroundTransparency = 1
	multipliers.AnchorPoint = Vector2.new(1, 1)
	multipliers.Position = UDim2.new(1, -12, 1, -12)
	multipliers.Size = UDim2.fromOffset(3 * 58 + 12, 64)
	local multiplierList = Instance.new("UIListLayout")
	multiplierList.SortOrder = Enum.SortOrder.LayoutOrder
	multiplierList.FillDirection = Enum.FillDirection.Horizontal
	multiplierList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	multiplierList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	multiplierList.Padding = UDim.new(0, 6)
	multiplierList.Parent = multipliers
	multipliers.Parent = root
	local function multiplier(name: string, emoji: string, order: number): TextLabel
		local holder = Instance.new("Frame")
		holder.Name = name
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(58, 64)
		holder.LayoutOrder = order
		Kit.Icon({
			Parent = holder,
			Name = "Icon",
			Emoji = emoji,
			Size = UDim2.fromOffset(40, 40),
			Position = UDim2.fromOffset(9, 0),
		})
		local label = Kit.Label({
			Parent = holder,
			Name = "Value",
			Text = "",
			Position = UDim2.fromOffset(0, 38),
			Size = UDim2.new(1, 0, 0, 24),
			TextSize = 20,
			Align = Enum.TextXAlignment.Center,
			Scaled = true,
		})
		holder.Parent = multipliers
		return label
	end
	local badgeText: BadgeText = {
		Luck = multiplier("Luck", "🍀", 1),
		Speed = multiplier("Speed", "⚡", 2),
		Income = multiplier("Income", "💰", 3),
	}

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
		local available = root.AbsoluteSize.X / factor - 2 * sideReserve
		fitScale.Scale = math.clamp(available / (2 * barHalfWidth), 0.5, 1)
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
		Color = theme.Yellow,
		TextSize = 46,
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
		Size = UDim2.fromOffset(autoWidth, autoHeight),
		Position = UDim2.new(0, rollWidth / 2 + barGap, 1, 0),
		AnchorPoint = Vector2.new(0, 1),
		Color = theme.Grey,
		TextSize = 20,
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

	local golden = Instance.new("Frame")
	golden.Name = "Golden"
	golden.BackgroundTransparency = 1
	golden.Size = UDim2.fromOffset(goldenWidth, goldenHeight)
	golden.Position = UDim2.new(0, -(rollWidth / 2 + barGap), 1, 0)
	golden.AnchorPoint = Vector2.new(1, 1)
	golden.Parent = bottom
	local goldenTitle = Kit.Label({
		Parent = golden,
		Name = "Title",
		Text = "⭐ GOLDEN ROLL",
		Size = UDim2.new(1, 0, 0, 24),
		TextSize = 20,
		Color = theme.Gold,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local goldenBar = Kit.Bar({
		Parent = golden,
		Name = "Progress",
		Position = UDim2.fromScale(0, 1),
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.new(1, 0, 0, 34),
		Color = goldenColor,
		Text = `0/{GameConfig.GoldenRollEvery}`,
		TextSize = 22,
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
		goldenBar.Stroke.Thickness = 3
		goldenBar.Stroke.Color = theme.Ink
		goldenTitle.Text = if value then "NEXT ROLL IS GOLDEN! ⭐" else "⭐ GOLDEN ROLL"
		if value then
			goldenBar.Stroke.Color = theme.Gold
			goldenPulse = Kit.Tween(
				goldenBar.Stroke,
				TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Thickness = 7 }
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
		goldenBar.SetText(`{count}/{GameConfig.GoldenRollEvery}`)
		goldenBar.SetValue(count / GameConfig.GoldenRollEvery)
		setGoldenNext(count == GameConfig.GoldenRollEvery - 1)
		rollsLabel.Text = `🎲 {NumberFormat.Commas(rolls)} rolls`
	end))

	local function setHinting(value: boolean)
		if value == isHinting then
			return
		end
		isHinting = value
		tooltip.Visible = value
		upgradesButton.SetGlow(value)
		upgradesTab.SetGlow(value)
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
		local luckText = if balance then multiplierText(stats.Luck) else ""
		local speedText = if balance then string.format("%.1f/s", stats.RollsPerSecond) else ""
		local incomeMultiplierText = if balance then multiplierText(stats.IncomeMultiplier) else ""
		local statsText = `{luckText}|{speedText}|{incomeMultiplierText}`
		if statsText ~= lastStats then
			lastStats = statsText
			badgeText.Luck.Text = luckText
			badgeText.Speed.Text = speedText
			badgeText.Income.Text = incomeMultiplierText
		end
		local cost = cheapestCost()
		local canAfford = balance ~= nil and cost ~= nil and balance >= cost
		upgradesBadge.Visible = canAfford
		setHinting(tutorialStep == hintStep and canAfford)
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
