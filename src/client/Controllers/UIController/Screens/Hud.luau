--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Upgrades = require(ReplicatedStorage.Config.Upgrades)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Rebirth = require(ReplicatedStorage.Rules.Rebirth)
local Season = require(ReplicatedStorage.Rules.Season)
local Stats = require(ReplicatedStorage.Rules.Stats)
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
local screenMargin = 24
local sideWidth = 184
local sideRowHeight = 56
local settingsSize = 44
local gridCell = 88
local gridGap = 8
local rollWidth = 200
local rollHeight = 98
local squareSize = 84
local barGap = 12
local barHalfWidth = rollWidth / 2 + barGap + squareSize
local sideReserve = 226
local goldenColor = Color3.fromRGB(255, 176, 32)
local ringColor = Color3.fromRGB(255, 240, 150)
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
	left.Position = UDim2.new(0, screenMargin, 0.5, 0)
	left.Size = UDim2.fromOffset(sideWidth, gridCell * 2 + gridGap)
	left.Parent = root

	local function menuButton(
		name: string,
		glyph: string,
		label: string,
		color: Color3,
		position: Vector2,
		target: string
	): Kit.Button
		return Kit.Button(trove, {
			Parent = left,
			Name = name,
			Glyph = glyph,
			Text = label,
			Color = color,
			Size = UDim2.fromOffset(gridCell, gridCell),
			Position = UDim2.fromOffset(position.X, position.Y),
			TextSize = 18,
			Callback = function()
				toggleScreen(target)
			end,
			Sound = playUi,
		})
	end
	local step = gridCell + gridGap
	local upgradesButton =
		menuButton("Upgrades", "Upgrades", "UPGRADES", theme.Green, Vector2.new(0, 0), "Upgrades")
	menuButton("Keys", "Keys", "KEYS", theme.Purple, Vector2.new(step, 0), "Keys")
	menuButton("Index", "Index", "INDEX", theme.Blue, Vector2.new(0, step), "Index")
	local rebirthButton =
		menuButton("Rebirth", "Rebirth", "REBIRTH", theme.Purple, Vector2.new(step, step), "Rebirth")
	local upgradesBadge = Kit.Badge(upgradesButton.Instance, "!")
	upgradesBadge.Visible = false
	local rebirthBadge = Kit.Badge(rebirthButton.Instance, "!")
	rebirthBadge.Visible = false

	local side = Instance.new("Frame")
	side.Name = "Side"
	side.BackgroundTransparency = 1
	side.AnchorPoint = Vector2.new(1, 0.5)
	side.Position = UDim2.new(1, -screenMargin, 0.5, 0)
	side.Size = UDim2.fromOffset(sideWidth, gridCell * 2 + gridGap)
	local sideList = Instance.new("UIListLayout")
	sideList.SortOrder = Enum.SortOrder.LayoutOrder
	sideList.Padding = UDim.new(0, gridGap)
	sideList.Parent = side
	side.Parent = root
	local function sideButton(
		name: string,
		glyph: string,
		label: string,
		color: Color3,
		order: number,
		target: string
	): Kit.Button
		return Kit.Button(trove, {
			Parent = side,
			Name = name,
			Glyph = glyph,
			IconLeft = true,
			Text = label,
			Color = color,
			Size = UDim2.fromOffset(sideWidth, sideRowHeight),
			TextSize = 22,
			LayoutOrder = order,
			Callback = function()
				toggleScreen(target)
			end,
			Sound = playUi,
		})
	end
	sideButton("Store", "Shop", "STORE", theme.Red, 1, "Shop")
	sideButton("Leaderboard", "Leaderboard", "LEADERBOARD", theme.Gold, 2, "Leaderboards")
	local passButton = sideButton("Pass", "Pass", "PASS", theme.Orange, 3, "Season")
	local passBadge = Kit.Badge(passButton.Instance, "!")
	passBadge.Visible = false

	Kit.Button(trove, {
		Parent = root,
		Name = "Settings",
		Glyph = "Settings",
		Size = UDim2.fromOffset(settingsSize, settingsSize),
		Position = UDim2.new(0, screenMargin, 1, -screenMargin),
		AnchorPoint = Vector2.new(0, 1),
		Color = theme.Grey,
		Callback = function()
			toggleScreen("Settings")
		end,
		Sound = playUi,
	})

	local tooltip = Kit.Panel({
		Parent = left,
		Name = "Tooltip",
		Size = UDim2.fromOffset(250, 46),
		Position = UDim2.new(0, sideWidth + 16, 0, gridCell / 2),
		AnchorPoint = Vector2.new(0, 0.5),
		Color = theme.Yellow,
	})
	tooltip.Visible = false
	Kit.Label({
		Parent = tooltip,
		Name = "Text",
		Text = "Buy your first upgrade!",
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 1, 0),
		TextSize = 22,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local bounce = Kit.Tween(
		tooltip,
		TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = UDim2.new(0, sideWidth + 6, 0, gridCell / 2) }
	)
	bounce:Pause()
	trove:Add(function()
		bounce:Cancel()
		bounce:Destroy()
	end)

	local tabWidth = 168
	local tabGap = 10
	local tabs = Instance.new("Frame")
	tabs.Name = "Travel"
	tabs.BackgroundTransparency = 1
	tabs.AnchorPoint = Vector2.new(0.5, 0)
	tabs.Position = UDim2.new(0.5, 0, 0, Kit.TabBarTop)
	tabs.Size = UDim2.fromOffset(tabWidth * 2 + tabGap, Kit.TabBarHeight)
	tabs.Parent = root
	local tabList = Instance.new("UIListLayout")
	tabList.FillDirection = Enum.FillDirection.Horizontal
	tabList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tabList.VerticalAlignment = Enum.VerticalAlignment.Center
	tabList.Padding = UDim.new(0, tabGap)
	tabList.SortOrder = Enum.SortOrder.LayoutOrder
	tabList.Parent = tabs
	Kit.Button(trove, {
		Parent = tabs,
		Name = "MyBase",
		Glyph = "Base",
		IconLeft = true,
		Text = "MY BASE",
		Size = UDim2.fromOffset(tabWidth, Kit.TabBarHeight),
		Color = theme.Blue,
		TextSize = 28,
		LayoutOrder = 1,
		Callback = function()
			if not rollController:TeleportToBase() then
				context.Toast("Your base isn't ready yet!", "Bad")
			end
		end,
		Sound = playUi,
	})
	Kit.Button(trove, {
		Parent = tabs,
		Name = "TravelShop",
		Glyph = "Shop",
		IconLeft = true,
		Text = "SHOP",
		Size = UDim2.fromOffset(tabWidth, Kit.TabBarHeight),
		Color = theme.Orange,
		TextSize = 28,
		LayoutOrder = 2,
		Callback = function()
			if not rollController:TeleportToShop() then
				context.Toast("Shop isn't ready yet!", "Bad")
			end
		end,
		Sound = playUi,
	})

	local money = Instance.new("Frame")
	money.Name = "Currency"
	money.BackgroundTransparency = 1
	money.AnchorPoint = Vector2.new(0.5, 0)
	money.Position = UDim2.new(0.5, 0, 0, Kit.TabBarTop + Kit.TabBarHeight + Kit.ClicksGap)
	money.AutomaticSize = Enum.AutomaticSize.X
	money.Size = UDim2.fromOffset(0, Kit.ClicksHeight)
	local moneyList = Instance.new("UIListLayout")
	moneyList.SortOrder = Enum.SortOrder.LayoutOrder
	moneyList.FillDirection = Enum.FillDirection.Horizontal
	moneyList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	moneyList.VerticalAlignment = Enum.VerticalAlignment.Center
	moneyList.Padding = UDim.new(0, gridGap)
	moneyList.Parent = money
	money.Parent = root
	Kit.Icon({
		Parent = money,
		Name = "Icon",
		Glyph = "Clicks",
		Size = UDim2.fromOffset(Kit.ClicksHeight, Kit.ClicksHeight),
		LayoutOrder = 1,
	})
	local cashLabel = Kit.Label({
		Parent = money,
		Name = "Cash",
		Text = "...",
		Size = UDim2.fromOffset(0, Kit.ClicksHeight),
		TextSize = 40,
		Color = cashColor,
		LayoutOrder = 2,
	})
	cashLabel.AutomaticSize = Enum.AutomaticSize.X
	cashLabel.TextTruncate = Enum.TextTruncate.None
	local incomeLabel = Kit.Label({
		Parent = money,
		Name = "Income",
		Text = "",
		Size = UDim2.fromOffset(0, Kit.ClicksHeight),
		TextSize = 24,
		Color = theme.Good,
		LayoutOrder = 3,
	})
	incomeLabel.AutomaticSize = Enum.AutomaticSize.X
	incomeLabel.TextTruncate = Enum.TextTruncate.None

	local multipliers = Instance.new("Frame")
	multipliers.Name = "Multipliers"
	multipliers.BackgroundTransparency = 1
	multipliers.AnchorPoint = Vector2.new(1, 1)
	multipliers.Position = UDim2.new(1, -screenMargin, 1, -screenMargin)
	multipliers.Size = UDim2.fromOffset(3 * 58 + 12, 64)
	local multiplierList = Instance.new("UIListLayout")
	multiplierList.SortOrder = Enum.SortOrder.LayoutOrder
	multiplierList.FillDirection = Enum.FillDirection.Horizontal
	multiplierList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	multiplierList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	multiplierList.Padding = UDim.new(0, 6)
	multiplierList.Parent = multipliers
	multipliers.Parent = root
	local function multiplier(name: string, glyph: string, order: number): TextLabel
		local holder = Instance.new("Frame")
		holder.Name = name
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(58, 64)
		holder.LayoutOrder = order
		Kit.Icon({
			Parent = holder,
			Name = "Icon",
			Glyph = glyph,
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
		Luck = multiplier("Luck", "Luck", 1),
		Speed = multiplier("Speed", "Speed", 2),
		Income = multiplier("Income", "Coin", 3),
	}

	local bottom = Instance.new("Frame")
	bottom.Name = "Bottom"
	bottom.BackgroundTransparency = 1
	bottom.AnchorPoint = Vector2.new(0.5, 1)
	bottom.Position = UDim2.new(0.5, 0, 1, -screenMargin)
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
		Text = "ROLL!",
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
		Glyph = "Auto",
		Text = "AUTO: OFF",
		Size = UDim2.fromOffset(squareSize, squareSize),
		Position = UDim2.new(0, rollWidth / 2 + barGap, 1, 0),
		AnchorPoint = Vector2.new(0, 1),
		Color = theme.Grey,
		TextSize = 18,
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
		Size = UDim2.fromOffset(squareSize, squareSize),
		Position = UDim2.new(0, -(rollWidth / 2 + barGap), 1, 0),
		AnchorPoint = Vector2.new(1, 1),
		Color = theme.Track,
		StrokeThickness = 2.5,
		Bevel = false,
	})
	golden.ClipsDescendants = true
	local goldenFill = Instance.new("Frame")
	goldenFill.Name = "Fill"
	goldenFill.BorderSizePixel = 0
	goldenFill.AnchorPoint = Vector2.new(0, 1)
	goldenFill.Position = UDim2.fromScale(0, 1)
	goldenFill.Size = UDim2.fromScale(1, 0)
	Kit.Paint(goldenFill, goldenColor)
	goldenFill.Parent = golden
	Kit.Icon({
		Parent = golden,
		Name = "Icon",
		Glyph = "Golden",
		Color = theme.Text,
		Size = UDim2.fromScale(1, 0.56),
		Position = UDim2.fromScale(0, 0.06),
	})
	local goldenLabel = Kit.Label({
		Parent = golden,
		Name = "Progress",
		Text = `0/{GameConfig.GoldenRollEvery}`,
		Position = UDim2.fromScale(0, 0.6),
		Size = UDim2.fromScale(1, 0.34),
		TextSize = 22,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local goldenStroke = Kit.StrokeOf(golden)
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
		goldenStroke.Thickness = 2.5
		goldenStroke.Color = theme.Ink
		if value then
			goldenStroke.Color = ringColor
			goldenPulse = Kit.Tween(
				goldenStroke,
				TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Thickness = 4.5 }
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
	local function refreshGolden()
		local progress = dataController:Get({ "GoldenProgress" })
		local count = if type(progress) == "number" then progress else 0
		local every = Stats.GoldenEvery(dataController:Get({ "Upgrades" }))
		count = math.min(count, every - 1)
		local isNext = count >= every - 1
		goldenLabel.Text = if isNext then "NEXT!" else `{count}/{every}`
		goldenFill.Size = UDim2.fromScale(1, if isNext then 1 else count / every)
		setGoldenNext(isNext)
	end
	trove:Add(dataController:Observe({ "GoldenProgress" }, refreshGolden))
	trove:Add(dataController:Observe({ "Upgrades", "Golden" }, refreshGolden))

	local function setHinting(value: boolean)
		if value == isHinting then
			return
		end
		isHinting = value
		tooltip.Visible = value
		upgradesButton.SetGlow(value)
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

	local function currentSeason(): Season.Progress
		local value = dataController:Get({ "Season" })
		return if type(value) == "table" then value else {}
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
		rebirthBadge.Visible = balance ~= nil and balance >= Rebirth.Cost(tracker.GetRebirths())
		passBadge.Visible = #Season.Claimable(
			currentSeason(),
			tracker.Boosts.Owns(GameConfig.Season.PremiumPassId)
		) > 0
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
