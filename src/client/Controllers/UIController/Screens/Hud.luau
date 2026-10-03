--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Upgrades = require(ReplicatedStorage.Config.Upgrades)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Rebirth = require(ReplicatedStorage.Rules.Rebirth)
local Season = require(ReplicatedStorage.Rules.Season)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Economy = require(script.Parent.Parent.Economy)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)

type StatLabels = {
	Luck: TextLabel,
	Speed: TextLabel,
	Income: TextLabel,
}

type Tile = {
	Instance: TextButton,
	SetGlow: (isOn: boolean) -> (),
}

local theme = Kit.Theme
local hintStep = 2
local margin = Kit.Margin
local columnWidth = 176
local tileWidth = 84
local tileHeight = 92
local gridGap = 8
local gridTop = margin + 52 + 16
local barWidth = 632
local barHeight = 64
local goldenWidth = 216
local rollWidth = 240
local autoWidth = 144
local barGap = 16
local sideReserve = 330
local goldenText = "GOLDEN ROLL"
local goldenNextText = "NEXT IS GOLDEN!"

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

	local menu = Instance.new("Frame")
	menu.Name = "Menu"
	menu.BackgroundTransparency = 1
	menu.Position = UDim2.fromOffset(margin, gridTop)
	menu.Size = UDim2.fromOffset(columnWidth, tileHeight * 3 + gridGap * 2)
	menu.Parent = root

	local function menuTile(
		name: string,
		iconName: string,
		label: string,
		position: Vector2,
		target: string
	): Tile
		local plate, inner = Kit.Plate({
			Parent = menu,
			Name = name,
			Class = "TextButton",
			Size = UDim2.fromOffset(tileWidth, tileHeight),
			Position = UDim2.fromOffset(position.X, position.Y),
			Thickness = 2,
			Lip = true,
		})
		local button: TextButton = plate :: any
		local stroke = Kit.StrokeOf(plate)
		Kit.Icon(inner, iconName, 56).Position = UDim2.new(0.5, -28, 0, 6)
		Kit.Label({
			Parent = inner,
			Name = "Caption",
			Text = string.upper(label),
			Position = UDim2.fromOffset(0, 66),
			Size = UDim2.new(1, 0, 0, 16),
			TextSize = 13,
			Align = Enum.TextXAlignment.Center,
			Body = true,
		})
		local glow: Tween? = nil
		trove:Connect(button.MouseButton1Down, function()
			Kit.Tween(inner, TweenInfo.new(0.05), { Position = UDim2.fromOffset(0, 2) })
		end)
		local function release()
			Kit.Tween(inner, TweenInfo.new(0.05), { Position = UDim2.new() })
		end
		trove:Connect(button.MouseButton1Up, release)
		trove:Connect(button.MouseLeave, release)
		trove:Connect(button.Activated, function()
			playUi("Click")
			toggleScreen(target)
		end)
		trove:Add(function()
			if glow then
				glow:Cancel()
				glow = nil
			end
		end)
		return {
			Instance = button,
			SetGlow = function(isOn: boolean)
				if glow then
					glow:Cancel()
					glow = nil
				end
				stroke.Thickness = 2
				stroke.Color = theme.Line
				if isOn then
					stroke.Color = Color3.fromRGB(255, 240, 150)
					glow = Kit.Tween(
						stroke,
						TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
						{ Thickness = 5 }
					)
				end
			end,
		}
	end
	local step = tileWidth + gridGap
	local rowStep = tileHeight + gridGap
	local upgradesTile = menuTile("Upgrades", "upgrades", "Upgrades", Vector2.new(0, 0), "Upgrades")
	menuTile("Keys", "keys", "Keys", Vector2.new(step, 0), "Keys")
	menuTile("Index", "index", "Index", Vector2.new(0, rowStep), "Index")
	local rebirthTile = menuTile("Rebirth", "rebirth", "Rebirth", Vector2.new(step, rowStep), "Rebirth")
	local passTile = menuTile("Pass", "pass", "Pass", Vector2.new(step / 2, rowStep * 2), "Season")
	local upgradesBadge = Kit.Badge(upgradesTile.Instance, "!")
	upgradesBadge.Visible = false
	local rebirthBadge = Kit.Badge(rebirthTile.Instance, "!")
	rebirthBadge.Visible = false
	local passBadge = Kit.Badge(passTile.Instance, "!")
	passBadge.Visible = false

	Kit.Button(trove, {
		Parent = root,
		Name = "Settings",
		GlyphName = "settings",
		Size = UDim2.fromOffset(52, 52),
		Position = UDim2.new(0, margin, 1, -margin),
		AnchorPoint = Vector2.new(0, 1),
		Color = theme.Grey,
		Callback = function()
			toggleScreen("Settings")
		end,
		Sound = playUi,
	})

	local hintX = margin + columnWidth + 16
	local hintY = gridTop + (tileHeight - 48) / 2
	local tooltip = Kit.Tooltip({
		Parent = root,
		Name = "Tooltip",
		Text = "Buy your first upgrade!",
		GlyphName = "upgrades",
		Position = UDim2.fromOffset(hintX, hintY),
		Large = true,
		Side = "Left",
	})
	tooltip.Visible = false
	local bounce = Kit.Tween(
		tooltip,
		TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = UDim2.fromOffset(hintX + 8, hintY) }
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
	top.Position = UDim2.new(0.5, 0, 0, Kit.TabBarTop)
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
	Kit.Button(trove, {
		Parent = top,
		Name = "ShopTab",
		Text = "SHOP",
		GlyphName = "shop",
		Size = UDim2.fromOffset(188, 52),
		Color = theme.Red,
		Shards = true,
		LayoutOrder = 1,
		Callback = function()
			toggleScreen("Shop")
		end,
		Sound = playUi,
	})
	Kit.Button(trove, {
		Parent = top,
		Name = "MyBase",
		Text = "MY BASE",
		GlyphName = "base",
		Size = UDim2.fromOffset(224, Kit.TabBarHeight),
		Color = theme.Blue,
		Shards = true,
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
		Name = "LeaderboardTab",
		Text = "LEADERBOARD",
		GlyphName = "leaders",
		Size = UDim2.fromOffset(188, 52),
		Color = theme.Gold,
		Shards = true,
		LayoutOrder = 3,
		Callback = function()
			toggleScreen("Leaderboards")
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
	moneyList.Padding = UDim.new(0, 16)
	moneyList.Parent = money
	money.Parent = root
	Kit.Icon(money, "clicks", Kit.ClicksHeight).LayoutOrder = 1
	local cashLabel = Kit.Label({
		Parent = money,
		Name = "Cash",
		Text = "...",
		Size = UDim2.fromOffset(0, Kit.ClicksHeight),
		TextSize = 32,
		LayoutOrder = 2,
		Outline = true,
	})
	cashLabel.AutomaticSize = Enum.AutomaticSize.X
	cashLabel.TextTruncate = Enum.TextTruncate.None
	local incomeLabel = Kit.Label({
		Parent = money,
		Name = "Income",
		Text = "",
		Size = UDim2.fromOffset(0, Kit.ClicksHeight),
		TextSize = 16,
		Color = Kit.TextSafe(theme.Green, theme.Surface),
		LayoutOrder = 3,
		Outline = true,
	})
	incomeLabel.AutomaticSize = Enum.AutomaticSize.X
	incomeLabel.TextTruncate = Enum.TextTruncate.None

	local stats = Instance.new("Frame")
	stats.Name = "Stats"
	stats.BackgroundTransparency = 1
	stats.AnchorPoint = Vector2.new(1, 1)
	stats.Position = UDim2.new(1, -margin, 1, -margin)
	stats.AutomaticSize = Enum.AutomaticSize.X
	stats.Size = UDim2.fromOffset(0, 48)
	local statList = Instance.new("UIListLayout")
	statList.SortOrder = Enum.SortOrder.LayoutOrder
	statList.FillDirection = Enum.FillDirection.Horizontal
	statList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	statList.VerticalAlignment = Enum.VerticalAlignment.Center
	statList.Padding = UDim.new(0, 8)
	statList.Parent = stats
	stats.Parent = root
	local function statChip(name: string, iconName: string, order: number): TextLabel
		local chip = Kit.Panel({
			Parent = stats,
			Name = name,
			Size = UDim2.fromOffset(0, 48),
			Color = theme.Surface,
			StrokeThickness = 3,
			LayoutOrder = order,
		})
		chip.AutomaticSize = Enum.AutomaticSize.X
		local chipList = Instance.new("UIListLayout")
		chipList.SortOrder = Enum.SortOrder.LayoutOrder
		chipList.FillDirection = Enum.FillDirection.Horizontal
		chipList.VerticalAlignment = Enum.VerticalAlignment.Center
		chipList.Padding = UDim.new(0, 8)
		chipList.Parent = chip
		local chipPadding = Instance.new("UIPadding")
		chipPadding.PaddingLeft = UDim.new(0, 8)
		chipPadding.PaddingRight = UDim.new(0, 12)
		chipPadding.Parent = chip
		Kit.Icon(chip, iconName, 32).LayoutOrder = 1
		local value = Kit.Label({
			Parent = chip,
			Name = "Value",
			Text = "",
			Size = UDim2.fromOffset(0, 32),
			TextSize = 16,
			LayoutOrder = 2,
		})
		value.AutomaticSize = Enum.AutomaticSize.X
		value.TextTruncate = Enum.TextTruncate.None
		return value
	end
	local statText: StatLabels = {
		Luck = statChip("Luck", "luck", 1),
		Speed = statChip("Speed", "speed", 2),
		Income = statChip("Income", "income", 3),
	}

	local bottom = Instance.new("Frame")
	bottom.Name = "Bottom"
	bottom.BackgroundTransparency = 1
	bottom.AnchorPoint = Vector2.new(0.5, 1)
	bottom.Position = UDim2.new(0.5, 0, 1, -margin)
	bottom.Size = UDim2.fromOffset(barWidth, barHeight)
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
		fitScale.Scale = math.clamp(available / barWidth, 0.5, 1)
	end
	fit()
	trove:Connect(root:GetPropertyChangedSignal("AbsoluteSize"), fit)

	local golden, goldenInner = Kit.Plate({
		Parent = bottom,
		Name = "Golden",
		Size = UDim2.fromOffset(goldenWidth, barHeight),
	})
	local goldenStroke = Kit.StrokeOf(golden)
	local goldenIcon = Kit.Icon(goldenInner, "star", 40)
	goldenIcon.AnchorPoint = Vector2.new(0, 0.5)
	goldenIcon.Position = UDim2.new(0, 12, 0.5, 0)
	local goldenTitle = Kit.Caption({
		Parent = goldenInner,
		Name = "Title",
		Text = goldenText,
		Position = UDim2.fromOffset(60, 14),
		Size = UDim2.new(1, -60 - 12 - 44, 0, 16),
		Color = theme.Text,
	})
	local goldenCount = Kit.Label({
		Parent = goldenInner,
		Name = "Count",
		Text = `0/{GameConfig.GoldenRollEvery}`,
		Position = UDim2.new(1, -12, 0, 14),
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(44, 16),
		TextSize = 13,
		Align = Enum.TextXAlignment.Right,
		Body = true,
	})
	local goldenBar = Kit.Bar({
		Parent = goldenInner,
		Name = "Progress",
		Position = UDim2.fromOffset(60, 36),
		Size = UDim2.new(1, -60 - 12, 0, 12),
		Color = theme.Gold,
	})
	Kit.Button(trove, {
		Parent = bottom,
		Name = "Roll",
		Text = "ROLL!",
		GlyphName = "roll",
		Hero = true,
		Size = UDim2.fromOffset(rollWidth, barHeight),
		Position = UDim2.fromOffset(goldenWidth + barGap, 0),
		Color = theme.Green,
		Immediate = true,
		Callback = function()
			rollController:RequestRoll()
		end,
	})
	local autoButton = Kit.Button(trove, {
		Parent = bottom,
		Name = "Auto",
		Text = "AUTO: OFF",
		GlyphName = "auto",
		Size = UDim2.fromOffset(autoWidth, barHeight),
		Position = UDim2.fromOffset(goldenWidth + barGap + rollWidth + barGap, 0),
		Color = theme.Grey,
		TextSize = 16,
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
		goldenStroke.Color = theme.Line
		goldenTitle.Text = if value then goldenNextText else goldenText
		goldenTitle.TextColor3 = if value then theme.Gold else theme.Text
		if value then
			goldenStroke.Color = theme.Gold
			goldenPulse = Kit.Tween(
				goldenStroke,
				TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Thickness = 6 }
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
		goldenBar.SetValue(count / GameConfig.GoldenRollEvery)
		setGoldenNext(count == GameConfig.GoldenRollEvery - 1)
	end))

	local function setHinting(value: boolean)
		if value == isHinting then
			return
		end
		isHinting = value
		tooltip.Visible = value
		upgradesTile.SetGlow(value)
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
			statText.Luck.Text = luckText
			statText.Speed.Text = speedText
			statText.Income.Text = incomeMultiplierText
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
