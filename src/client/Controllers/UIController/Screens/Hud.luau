--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Upgrades = require(ReplicatedStorage.Config.Upgrades)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Rebirth = require(ReplicatedStorage.Rules.Rebirth)
local Season = require(ReplicatedStorage.Rules.Season)
local Charms = require(ReplicatedStorage.Rules.Charms)
local Stats = require(ReplicatedStorage.Rules.Stats)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local TimeFormat = require(ReplicatedStorage.Utils.TimeFormat)
local Economy = require(script.Parent.Parent.Economy)
local Kit = require(script.Parent.Parent.Kit)
local Playtime = require(script.Parent.Parent.Playtime)
local Types = require(script.Parent.Parent.Types)

type StatLabels = {
	Luck: TextLabel,
	Speed: TextLabel,
	Income: TextLabel,
}

local theme = Kit.Theme
local hintStep = 2
local margin = Kit.ScreenMargin
local cell = 86
local cellGap = 10
local menuWidth = cell * 2 + cellGap
local menuHeight = cell * 3 + cellGap * 2
local settingsSize = 58
local topButtonWidth = 176
local topGap = 10
local statWidth = 150
local statHeight = 46
local statGap = 16
local statsHeight = 3 * statHeight + 2 * statGap
local statClearance = 14
local rollWidth = 240
local rollHeight = 104
local barGap = 14
local barHalfWidth = rollWidth / 2 + barGap + cell
local sideReserve = 260
local goldenColor = Color3.fromHex("FFB820")
local ringColor = Color3.fromRGB(255, 240, 150)
local countRate = 9

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
	local shownCash: number? = nil
	local targetCash = 0

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
	menu.AnchorPoint = Vector2.new(0, 0.5)
	menu.Position = UDim2.new(0, margin, 0.5, 0)
	menu.Size = UDim2.fromOffset(menuWidth, menuHeight)
	local menuGrid = Instance.new("UIGridLayout")
	menuGrid.SortOrder = Enum.SortOrder.LayoutOrder
	menuGrid.CellSize = UDim2.fromOffset(cell, cell)
	menuGrid.CellPadding = UDim2.fromOffset(cellGap, cellGap)
	menuGrid.FillDirection = Enum.FillDirection.Horizontal
	menuGrid.Parent = menu
	menu.Parent = root

	local function squareButton(
		parent: Instance,
		name: string,
		glyph: string,
		label: string,
		color: Color3,
		order: number,
		tip: string,
		side: string,
		callback: () -> ()
	): Kit.Button
		return Kit.Button(trove, {
			Parent = parent,
			Name = name,
			Glyph = glyph,
			Text = label,
			Color = color,
			Size = UDim2.fromOffset(cell, cell),
			LayoutOrder = order,
			TextSize = 18,
			IconScale = 0.6,
			Tooltip = tip,
			TooltipSide = side,
			Callback = callback,
			Sound = playUi,
		})
	end
	local function leftButton(
		name: string,
		glyph: string,
		label: string,
		color: Color3,
		order: number,
		tip: string,
		target: string
	): Kit.Button
		return squareButton(menu, name, glyph, label, color, order, tip, "Right", function()
			toggleScreen(target)
		end)
	end

	local upgradesButton =
		leftButton("Upgrades", "Upgrades", "UPGRADES", theme.Green, 2, "Make your keys stronger!", "Upgrades")
	leftButton("Keys", "Keys", "KEYS", theme.Purple, 1, "See and equip your keys!", "Keys")
	leftButton("Index", "Index", "INDEX", theme.Blue, 3, "Every key you can find!", "Index")
	local rebirthButton =
		leftButton("Rebirth", "Rebirth", "REBIRTH", theme.Pink, 4, "Start over for a big bonus!", "Rebirth")
	local dailyButton =
		leftButton("DailyRewards", "Gift", "GIFTS", theme.Teal, 5, "Free gifts for playing!", "Daily")
	local petsButton =
		leftButton("Pets", "Heart", "PETS", theme.Yellow, 6, "See your pets and what they do!", "Pets")
	local petsBadge = Kit.Badge(petsButton.Instance, "!")
	petsBadge.Visible = false
	local ownedPets = 0
	local seenPets = 0
	local hasPetBaseline = false
	trove:Add(dataController:Observe({ "Charms" }, function(value: any)
		if type(value) ~= "table" then
			return
		end
		local total = 0
		for _, count in value do
			if type(count) == "number" then
				total += count
			end
		end
		ownedPets = total
		if not hasPetBaseline then
			hasPetBaseline = true
			seenPets = total
		end
		petsBadge.Visible = ownedPets > seenPets and not context.IsOpen("Pets")
	end))
	trove:Connect(petsButton.Instance.Activated, function()
		seenPets = ownedPets
		petsBadge.Visible = false
	end)
	local upgradesBadge = Kit.Badge(upgradesButton.Instance, "!")
	upgradesBadge.Visible = false
	local rebirthBadge = Kit.Badge(rebirthButton.Instance, "!")
	rebirthBadge.Visible = false
	local dailyBadge = Kit.Badge(dailyButton.Instance, "1")
	dailyBadge.Visible = false
	local dailyBadgeText = dailyBadge:FindFirstChild("Text") :: TextLabel
	local dailyTimer = Kit.Chip({
		Parent = dailyButton.Instance,
		Name = "GiftTimer",
		Text = "",
		Size = UDim2.fromOffset(46, 22),
		Position = UDim2.new(1, 8, 0, -8),
		AnchorPoint = Vector2.new(1, 0),
		Color = theme.Blue,
		TextSize = 16,
	}).Parent :: Frame
	dailyTimer.ZIndex = 5
	dailyTimer.Visible = false
	local dailyTimerText = dailyTimer:FindFirstChild("Text") :: TextLabel
	local dailyBadgeHome = dailyBadge.Position
	local dailyBadgeHop = Kit.Tween(
		dailyBadge,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1, true),
		{ Position = dailyBadgeHome - UDim2.fromOffset(0, 5) }
	)
	trove:Add(function()
		dailyBadgeHop:Cancel()
	end)

	local side = Instance.new("Frame")
	side.Name = "Side"
	side.BackgroundTransparency = 1
	side.AnchorPoint = Vector2.new(1, 1)
	side.Position = UDim2.new(1, -margin, 1, -(margin + statsHeight + statClearance))
	side.Size = UDim2.fromOffset(cell, cell * 4 + cellGap * 3)
	local sideList = Instance.new("UIListLayout")
	sideList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	sideList.SortOrder = Enum.SortOrder.LayoutOrder
	sideList.Padding = UDim.new(0, cellGap)
	sideList.Parent = side
	side.Parent = root
	local function sideButton(
		name: string,
		glyph: string,
		label: string,
		color: Color3,
		order: number,
		tip: string,
		target: string
	): Kit.Button
		return squareButton(side, name, glyph, label, color, order, tip, "Left", function()
			toggleScreen(target)
		end)
	end
	local giftButton = squareButton(
		side,
		"StarterPack",
		"Gift",
		"STARTER",
		theme.Orange,
		0,
		"A special one-time deal!",
		"Left",
		function()
			context.Open("StarterOffer")
		end
	)
	giftButton.SetGlow(true)
	trove:Add(dataController:Observe({ "StarterPackBought" }, function(value: any)
		giftButton.Instance.Visible = value ~= true
	end))
	sideButton("Store", "Store", "STORE", theme.Red, 1, "Get boosts and goodies!", "Shop")
	sideButton(
		"Leaderboard",
		"Leaderboard",
		"RANKS",
		theme.Purple,
		2,
		"See the best players!",
		"Leaderboards"
	)
	local passButton =
		sideButton("Pass", "Pass", "PASS", theme.Yellow, 3, "Season rewards to claim!", "Season")
	local passBadge = Kit.Badge(passButton.Instance, "!")
	passBadge.Visible = false

	Kit.Button(trove, {
		Parent = root,
		Name = "Settings",
		Glyph = "Settings",
		Size = UDim2.fromOffset(settingsSize, settingsSize),
		Position = UDim2.new(0, margin, 1, -margin),
		AnchorPoint = Vector2.new(0, 1),
		Color = theme.Grey,
		Tooltip = "Settings",
		TooltipSide = "Right",
		Callback = function()
			toggleScreen("Settings")
		end,
		Sound = playUi,
	})

	local hintX = margin + menuWidth + 18
	local hintY = -menuHeight / 2 + cell / 2
	local tooltip = Kit.Panel({
		Parent = root,
		Name = "Tooltip",
		Size = UDim2.fromOffset(270, 46),
		Position = UDim2.new(0, hintX, 0.5, hintY),
		AnchorPoint = Vector2.new(0, 0.5),
		Color = theme.Yellow,
		Pill = true,
		Gloss = true,
	})
	tooltip.Visible = false
	Kit.Label({
		Parent = tooltip,
		Name = "Text",
		Text = "Buy your first upgrade!",
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 1, 0),
		TextSize = 22,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local bounce = Kit.Tween(
		tooltip,
		TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = UDim2.new(0, hintX - 10, 0.5, hintY) }
	)
	bounce:Pause()
	trove:Add(function()
		bounce:Cancel()
		bounce:Destroy()
	end)

	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.BackgroundTransparency = 1
	topBar.AnchorPoint = Vector2.new(0.5, 0)
	topBar.Position = UDim2.new(0.5, 0, 0, Kit.TabBarTop)
	topBar.Size = UDim2.fromOffset(topButtonWidth * 2 + topGap, Kit.TabBarHeight)
	topBar.Parent = root
	local function jumpButton(
		name: string,
		glyph: string,
		label: string,
		color: Color3,
		x: number,
		go: () -> (boolean, string?)
	): Kit.Button
		return Kit.Button(trove, {
			Parent = topBar,
			Name = name,
			Glyph = glyph,
			IconLeft = true,
			Text = label,
			Size = UDim2.fromOffset(topButtonWidth, Kit.TabBarHeight),
			Position = UDim2.fromOffset(x, 0),
			Color = color,
			TextSize = 28,
			Pill = true,
			Callback = function()
				local ok, reason = go()
				if not ok then
					context.Toast(reason or "You can't go there right now!", "Bad")
				end
			end,
			Sound = playUi,
		})
	end
	jumpButton("Shop", "Shop", "SHOP", theme.Orange, 0, function()
		return rollController:TeleportToMarket()
	end)
	local myBaseButton = jumpButton("MyBase", "Home", "BASE", theme.Blue, topButtonWidth + topGap, function()
		return rollController:TeleportToBase()
	end)

	local money = Kit.Panel({
		Parent = root,
		Name = "Currency",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, Kit.TabBarTop + Kit.TabBarHeight + Kit.ClicksGap),
		Size = UDim2.fromOffset(0, Kit.ClicksHeight),
		Color = theme.Track,
		Pill = true,
		Flat = true,
	})
	money.AutomaticSize = Enum.AutomaticSize.X
	local moneyRow = Instance.new("Frame")
	moneyRow.Name = "Row"
	moneyRow.BackgroundTransparency = 1
	moneyRow.BorderSizePixel = 0
	moneyRow.AutomaticSize = Enum.AutomaticSize.X
	moneyRow.Size = UDim2.fromOffset(0, Kit.ClicksHeight)
	moneyRow.Parent = money
	local moneyList = Instance.new("UIListLayout")
	moneyList.SortOrder = Enum.SortOrder.LayoutOrder
	moneyList.FillDirection = Enum.FillDirection.Horizontal
	moneyList.HorizontalAlignment = Enum.HorizontalAlignment.Left
	moneyList.VerticalAlignment = Enum.VerticalAlignment.Center
	moneyList.Padding = UDim.new(0, Kit.Space.S)
	moneyList.Parent = moneyRow
	local moneyPadding = Instance.new("UIPadding")
	moneyPadding.PaddingLeft = UDim.new(0, 10)
	moneyPadding.PaddingRight = UDim.new(0, 20)
	moneyPadding.Parent = moneyRow
	Kit.Icon({
		Parent = moneyRow,
		Name = "Coin",
		Size = UDim2.fromOffset(Kit.ClicksHeight - 10, Kit.ClicksHeight - 10),
		Glyph = "Clicks",
		LayoutOrder = 1,
	})
	local cashLabel = Kit.Label({
		Parent = moneyRow,
		Name = "Cash",
		Text = "...",
		Size = UDim2.fromOffset(0, Kit.ClicksHeight),
		TextSize = 34,
		LayoutOrder = 2,
	})
	cashLabel.AutomaticSize = Enum.AutomaticSize.X
	cashLabel.TextTruncate = Enum.TextTruncate.None
	local incomeLabel = Kit.Label({
		Parent = moneyRow,
		Name = "Income",
		Text = "",
		Size = UDim2.fromOffset(0, Kit.ClicksHeight),
		TextSize = 20,
		Color = theme.Good,
		LayoutOrder = 3,
	})
	incomeLabel.AutomaticSize = Enum.AutomaticSize.X
	incomeLabel.TextTruncate = Enum.TextTruncate.None

	local stats = Instance.new("Frame")
	stats.Name = "Multipliers"
	stats.BackgroundTransparency = 1
	stats.AnchorPoint = Vector2.new(1, 1)
	stats.Position = UDim2.new(1, -margin, 1, -margin)
	stats.Size = UDim2.fromOffset(statWidth, statsHeight)
	local statList = Instance.new("UIListLayout")
	statList.SortOrder = Enum.SortOrder.LayoutOrder
	statList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	statList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	statList.Padding = UDim.new(0, statGap)
	statList.Parent = stats
	stats.Parent = root
	local function statChip(
		name: string,
		caption: string,
		glyph: string,
		discColor: Color3,
		order: number,
		tip: string
	): TextLabel
		local pill = Kit.Pill({
			Parent = stats,
			Name = name,
			Glyph = glyph,
			Caption = caption,
			Text = "",
			DiscColor = discColor,
			Size = UDim2.fromOffset(statWidth - 10, statHeight),
			LayoutOrder = order,
			TextSize = 24,
		})
		Kit.Tooltip(trove, pill.Instance, tip, "Left")
		return pill.Label
	end
	local statText: StatLabels = {
		Luck = statChip("Luck", "LUCK", "Luck", theme.Green, 1, "Higher Luck finds rarer keys!"),
		Speed = statChip("Speed", "SPEED", "Speed", theme.Yellow, 2, "Rolls you make every second!"),
		Income = statChip("Income", "CLICKS", "Clicks", theme.Orange, 3, "Multiplies your Clicks!"),
	}

	local bottom = Instance.new("Frame")
	bottom.Name = "Bottom"
	bottom.BackgroundTransparency = 1
	bottom.AnchorPoint = Vector2.new(0.5, 1)
	bottom.Position = UDim2.new(0.5, 0, 1, -margin)
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

	local pulseToken = 0
	local function pulseMyBase()
		pulseToken += 1
		local mine = pulseToken
		myBaseButton.SetGlow(true)
		Kit.Pulse(myBaseButton.Instance)
		task.delay(1.8, function()
			if pulseToken == mine then
				myBaseButton.SetGlow(false)
			end
		end)
	end

	local rollHolder = Instance.new("Frame")
	rollHolder.Name = "RollHolder"
	rollHolder.BackgroundTransparency = 1
	rollHolder.AnchorPoint = Vector2.new(0.5, 1)
	rollHolder.Position = UDim2.new(0, 0, 1, 0)
	rollHolder.Size = UDim2.fromOffset(rollWidth, rollHeight)
	local rollBreath = Instance.new("UIScale")
	rollBreath.Name = "IdleScale"
	rollBreath.Parent = rollHolder
	rollHolder.Parent = bottom
	Kit.Breathe(trove, rollBreath, 0.035, 0.9)
	local rollButton = Kit.Button(trove, {
		Parent = rollHolder,
		Name = "Roll",
		Text = "ROLL!",
		Size = UDim2.fromScale(1, 1),
		Color = theme.Yellow,
		TextSize = 54,
		Title = true,
		Lip = 10,
		Immediate = true,
		Callback = function()
			if not rollController:IsInBase() then
				context.Toast("Go to your base to roll!", "Bad")
				pulseMyBase()
				return
			end
			rollController:RequestRoll()
		end,
	})
	local baseTag = Kit.Panel({
		Parent = rollHolder,
		Name = "BaseTag",
		Size = UDim2.fromOffset(150, 24),
		Position = UDim2.new(0.5, 0, 0, -12),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = theme.Red,
		StrokeThickness = 2,
		Pill = true,
	})
	baseTag.ZIndex = 6
	baseTag.Visible = false
	local baseTagText = Kit.Label({
		Parent = baseTag,
		Name = "Text",
		Text = "GO TO YOUR BASE",
		Size = UDim2.fromScale(1, 1),
		TextSize = 16,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	baseTagText.ZIndex = 7
	local function showBaseState(isInBase: boolean)
		rollButton.SetColor(if isInBase then theme.Yellow else theme.Grey)
		baseTag.Visible = not isInBase
	end
	showBaseState(rollController:IsInBase())
	trove:Add(rollController.InBaseChanged:Connect(showBaseState))
	local hint = Kit.Panel({
		Parent = rollHolder,
		Name = "KeyHint",
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.fromOffset(-10, -12),
		Color = theme.Track,
		StrokeColor = theme.Text,
		StrokeThickness = 2,
		Radius = 12,
		Flat = true,
	})
	hint.ZIndex = 6
	local hintLabel = Kit.Label({
		Parent = hint,
		Name = "Key",
		Text = "E",
		Size = UDim2.fromScale(1, 1),
		TextSize = 26,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	hintLabel.ZIndex = 7

	local autoButton = Kit.Button(trove, {
		Parent = bottom,
		Name = "Auto",
		Glyph = "Auto",
		Text = "AUTO",
		Size = UDim2.fromOffset(cell, cell),
		Position = UDim2.new(0, -(rollWidth / 2 + barGap), 1, 0),
		AnchorPoint = Vector2.new(1, 1),
		Color = theme.Grey,
		TextSize = 20,
		IconScale = 0.6,
		Tooltip = "Roll over and over by itself!",
		TooltipSide = "Above",
		Callback = function()
			rollController:SetAuto(not rollController:IsAuto())
		end,
		Sound = playUi,
	})
	local autoChip = Kit.Panel({
		Parent = autoButton.Instance,
		Name = "State",
		Size = UDim2.fromOffset(44, 24),
		Position = UDim2.new(0.5, 0, 0, -10),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = theme.Grey,
		StrokeThickness = 2,
		Pill = true,
	})
	autoChip.ZIndex = 5
	local autoChipText = Kit.Label({
		Parent = autoChip,
		Name = "Text",
		Text = "OFF",
		Size = UDim2.fromScale(1, 1),
		TextSize = 16,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	autoChipText.ZIndex = 6
	local function showAuto(isOn: boolean)
		autoButton.SetColor(if isOn then theme.Green else theme.Grey)
		autoButton.SetGlow(isOn)
		autoChipText.Text = if isOn then "ON" else "OFF"
		Kit.Paint(autoChip, if isOn then theme.Green else theme.Grey)
	end
	showAuto(rollController:IsAuto())
	trove:Add(rollController.AutoChanged:Connect(showAuto))

	local goldenHolder = Instance.new("Frame")
	goldenHolder.Name = "GoldenHolder"
	goldenHolder.BackgroundTransparency = 1
	goldenHolder.AnchorPoint = Vector2.new(0, 1)
	goldenHolder.Position = UDim2.new(0, rollWidth / 2 + barGap, 1, 0)
	goldenHolder.Size = UDim2.fromOffset(cell, cell)
	local goldenBreath = Instance.new("UIScale")
	goldenBreath.Name = "IdleScale"
	goldenBreath.Parent = goldenHolder
	goldenHolder.Parent = bottom
	local golden = Kit.Panel({
		Parent = goldenHolder,
		Name = "Golden",
		Size = UDim2.fromOffset(cell, cell),
		Color = theme.Track,
		Radius = Kit.Radius.L,
		Flat = true,
	})
	golden.ClipsDescendants = true
	local goldenFill = Instance.new("Frame")
	goldenFill.Name = "Fill"
	goldenFill.BorderSizePixel = 0
	goldenFill.AnchorPoint = Vector2.new(0, 1)
	goldenFill.Position = UDim2.fromScale(0, 1)
	goldenFill.Size = UDim2.fromScale(1, 0)
	Kit.Paint(goldenFill, goldenColor)
	Kit.Gloss(goldenFill, 8)
	goldenFill.Parent = golden
	local goldenIcon = Kit.Icon({
		Parent = golden,
		Name = "Icon",
		Glyph = "Golden",
		Size = UDim2.fromScale(1, 0.56),
		Position = UDim2.fromScale(0, 0.06),
	})
	goldenIcon.ZIndex = 4
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
	goldenLabel.ZIndex = 4
	Kit.Tooltip(trove, golden, "Every few rolls is a Golden key!", "Above")
	local goldenStroke = Kit.StrokeOf(golden)
	local goldenShimmer = Kit.Shimmer(trove, golden, 12, 1.1)
	goldenShimmer.Visible = false
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
		goldenStroke.Color = theme.Ink
		goldenShimmer.Visible = value
		goldenBreath.Scale = 1
		if value then
			goldenStroke.Color = ringColor
			goldenPulse = Kit.Tween(
				goldenBreath,
				TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ Scale = 1.08 }
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
		local every = Stats.GoldenEvery(
			dataController:Get({ "Upgrades" }),
			Charms.Effects(dataController:Get({ "EquippedCharms" })).GoldenReduction
		)
		count = math.min(count, every - 1)
		local isNext = count >= every - 1
		goldenLabel.Text = if isNext then "NEXT!" else `{count}/{every}`
		goldenFill.Size = UDim2.fromScale(1, if isNext then 1 else count / every)
		setGoldenNext(isNext)
	end
	trove:Add(dataController:Observe({ "GoldenProgress" }, refreshGolden))
	trove:Add(dataController:Observe({ "Upgrades", "Golden" }, refreshGolden))
	trove:Add(dataController:Observe({ "EquippedCharms" }, refreshGolden))

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
		local current = tracker.GetStats()
		if balance then
			targetCash = balance
			if shownCash == nil then
				shownCash = balance
			end
		else
			shownCash = nil
		end
		local incomeText = if balance then `+{NumberFormat.Compact(current.Rate)}/s` else ""
		if incomeText ~= lastIncome then
			lastIncome = incomeText
			incomeLabel.Text = incomeText
		end
		local luckText = if balance then multiplierText(current.Luck) else ""
		local speedText = if balance then string.format("%.1f/s", current.RollsPerSecond) else ""
		local incomeMultiplierText = if balance then multiplierText(current.IncomeMultiplier) else ""
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
		local gifts = Playtime.Read(Players.LocalPlayer, workspace:GetServerTimeNow())
		dailyBadge.Visible = gifts.ReadyCount > 0
		if gifts.ReadyCount > 0 then
			dailyBadgeText.Text = tostring(gifts.ReadyCount)
		end
		local nextLeft = gifts.NextLeft
		dailyTimer.Visible = gifts.ReadyCount == 0 and nextLeft ~= nil
		if nextLeft then
			dailyTimerText.Text = TimeFormat.Clock(nextLeft)
		end
		setHinting(tutorialStep == hintStep and canAfford)
	end

	local function showCash(dt: number)
		local shown = shownCash
		if not shown then
			if lastCash ~= "..." then
				lastCash = "..."
				cashLabel.Text = "..."
			end
			return
		end
		local gap = targetCash - shown
		if math.abs(gap) < 1 then
			shown = targetCash
		else
			shown += gap * math.min(1, dt * countRate)
		end
		shownCash = shown
		local text = NumberFormat.Compact(shown)
		if text ~= lastCash then
			lastCash = text
			cashLabel.Text = text
		end
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
		showCash(dt)
	end)
	refresh()
	showCash(1)

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
