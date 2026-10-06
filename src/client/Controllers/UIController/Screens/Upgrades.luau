--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Packets = require(ReplicatedStorage.Packets)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local UiAssets = require(ReplicatedStorage.Config.UiAssets)
local Upgrades = require(ReplicatedStorage.Config.Upgrades)
local Stats = require(ReplicatedStorage.Rules.Stats)
local UpgradeCost = require(ReplicatedStorage.Rules.UpgradeCost)
local Trove = require(ReplicatedStorage.Packages.Trove)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local RateLimit = require(ReplicatedStorage.Utils.RateLimit)
local Economy = require(script.Parent.Parent.Economy)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)

type Row = {
	Frame: Frame,
	Bar: Kit.Bar,
	Line2: TextLabel,
	Buy: Kit.Button,
	Upgrade: Upgrades.Upgrade,
	IsBusy: boolean,
	Token: number,
}

local theme = Kit.Theme
local cardHeight = 96
local refreshSeconds = 0.2
local buyWidth = 190
local safetySeconds = 2
local clientBuysPerSecond = 8
local modeBarHeight = 52
local modeBarWidth = 360
local modeBarGap = 8

local modes: { Kit.Tab } = {
	{ Id = "x1", Text = "x1", Color = theme.Green },
	{ Id = "x10", Text = "x10", Color = theme.Green },
	{ Id = "MAX", Text = "MAX", Color = theme.Gold },
}
local modeAmounts: { [string]: number } = { x1 = 1, x10 = 10, MAX = 0 }

local cardColors: { [string]: Color3 } = {
	Luck = theme.Green,
	Speed = theme.Yellow,
	Slots = theme.Blue,
	Income = theme.Gold,
	Walls = theme.Orange,
	LockTime = theme.Red,
	Golden = theme.Pink,
}

local sections: { { Category: Upgrades.Category, Caption: string, Glyph: string } } = {
	{ Category = "Keys", Caption = "KEYS", Glyph = "Keys" },
	{ Category = "Defense", Caption = "BASE DEFENSE", Glyph = "Walls" },
}
local sectionStride = 1000
local lockRefreshSeconds = 0.25
local lockCardHeight = 92
local lockButtonWidth = 200
local lockCardOrder = 900
local lockReadyText = "LOCK BASE"
local lockToast = "Lasers on! Your base is locked."
local greyColor = Color3.fromRGB(120, 124, 134)

local effectShortenings: { { string } } = {
	{ " each level", "" },
	{ "rolls per second", "rolls/s" },
	{ " to a Golden Roll", "" },
	{ "keyboard slot", "slot" },
	{ "(%d+) seconds of lasers", "%1s lasers" },
	{ "Luck", "luck" },
}

local function shortEffect(effect: string): string
	local text = effect
	for _, pair in effectShortenings do
		text = string.gsub(text, pair[1], pair[2])
	end
	return `{text} per level`
end

local function tint(color: Color3, text: string): string
	return string.format(
		'<font color="#%02X%02X%02X">%s</font>',
		math.round(color.R * 255),
		math.round(color.G * 255),
		math.round(color.B * 255),
		text
	)
end

local UpgradesScreen = {}

function UpgradesScreen.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local playUi = Kit.UiSound(context.Controllers)
	local rows: { Row } = {}
	local isOpen = false
	local tracker: Economy.Tracker
	local mode = "x1"
	local limiter = RateLimit.new(clientBuysPerSecond, 1)

	local modal = Kit.Modal(trove, {
		Parent = context.PlayerGui,
		Name = "Upgrades",
		Title = "UPGRADES",
		Glyph = "Upgrades",
		IconAsset = UiAssets.Icons.Upgrades,
		MaxSize = Vector2.new(860, 620),
		HeaderColor = theme.Green,
		OnClose = function()
			context.Close("Upgrades")
		end,
		Sound = playUi,
	})
	local scroll = Kit.Scroll({
		Parent = modal.Body,
		Name = "List",
		Position = UDim2.fromOffset(6, modeBarHeight + modeBarGap * 2),
		Size = UDim2.new(1, -12, 1, -(modeBarHeight + modeBarGap * 2 + 4)),
		Padding = 12,
	})

	local function buyPlan(upgrade: Upgrades.Upgrade, level: number): (number, number, boolean)
		local want = modeAmounts[mode]
		local cash = tracker.Balance() or 0
		local count = UpgradeCost.Affordable(upgrade, level, cash, want)
		local isAffordable = count > 0
		if not isAffordable then
			count = if want == 0 then 1 else math.min(want, UpgradeCost.Remaining(upgrade, level))
		end
		return count, UpgradeCost.Total(upgrade, level, count), isAffordable
	end

	local function valueParts(upgrade: Upgrades.Upgrade, level: number): (string, string, string)
		local board = tracker.GetBoard()
		local levels = {
			Luck = tracker.GetLevel("Luck"),
			Speed = tracker.GetLevel("Speed"),
			Slots = tracker.GetLevel("Slots"),
			Income = tracker.GetLevel("Income"),
			Golden = tracker.GetLevel("Golden"),
		}
		local nextLevels = table.clone(levels)
		nextLevels[upgrade.Id] = level + 1
		local now = Stats.Compute(board, levels)
		local after = Stats.Compute(board, nextLevels)
		local id = upgrade.Id
		if id == "Luck" then
			return string.format("x%.1f", now.Luck), string.format("x%.1f", after.Luck), ""
		elseif id == "Speed" then
			return string.format("%.1f/s", now.RollsPerSecond),
				string.format("%.1f/s", after.RollsPerSecond),
				""
		elseif id == "Slots" then
			return tostring(now.Slots), tostring(after.Slots), " slots"
		elseif id == "Income" then
			local current = math.round(level * upgrade.PerLevel * 100)
			return `+{current}%`, `+{current + math.round(upgrade.PerLevel * 100)}%`, ""
		elseif id == "Golden" then
			return tostring(Stats.GoldenEvery({ Golden = level })),
				tostring(Stats.GoldenEvery({ Golden = level + 1 })),
				" rolls"
		elseif id == "Walls" then
			local current = GameConfig.Defense.WallBaseHeight + level * upgrade.PerLevel
			return tostring(current), tostring(current + upgrade.PerLevel), " studs"
		end
		local current = GameConfig.Defense.LockBaseSeconds + level * upgrade.PerLevel
		return `{current}s`, `{current + upgrade.PerLevel}s`, ""
	end

	local function previewText(upgrade: Upgrades.Upgrade, level: number): string
		local current, following, suffix = valueParts(upgrade, level)
		if level >= upgrade.MaxLevel then
			return `{current}{suffix}  {tint(theme.Orange, "MAX")}`
		end
		return `{current} {tint(theme.GoodDeep, `> {following}{suffix}`)}`
	end

	local function headline(upgrade: Upgrades.Upgrade): string
		return `{upgrade.Name}  {tint(theme.Cream, `[{shortEffect(upgrade.Effect)}]`)}`
	end

	local function refreshRow(row: Row)
		local level = tracker.GetLevel(row.Upgrade.Id)
		row.Line2.Text = previewText(row.Upgrade, level)
		local maxLevel = row.Upgrade.MaxLevel
		row.Bar.SetValue(level / maxLevel)
		if level >= maxLevel then
			row.Buy.SetText("MAX")
			row.Buy.SetIconVisible(false)
			row.Buy.SetColor(theme.Gold)
			row.Buy.SetLocked(false)
			return
		end
		local count, total, canBuy = buyPlan(row.Upgrade, level)
		row.Buy.SetText(`x{count}  {NumberFormat.Compact(total)}`)
		row.Buy.SetIconVisible(true)
		row.Buy.SetColor(if canBuy then theme.Green else theme.Disabled)
		row.Buy.SetLocked(not canBuy)
	end

	local function refreshAll()
		for _, row in rows do
			refreshRow(row)
		end
	end

	tracker = Economy.Track(context.Controllers.DataController, trove, refreshAll)

	local function buy(row: Row)
		if row.IsBusy then
			return
		end
		local level = tracker.GetLevel(row.Upgrade.Id)
		if level >= row.Upgrade.MaxLevel then
			playUi("Confirm")
			context.Toast("Already MAXED!", "Good")
			Kit.Pulse(row.Frame, theme.Gold, 1)
			return
		end
		local count, total, canBuy = buyPlan(row.Upgrade, level)
		if not canBuy then
			playUi("Error")
			Kit.Shake(row.Frame)
			local balance = tracker.Balance() or 0
			context.Toast(`Need {NumberFormat.Compact(total - balance)} more Clicks!`, "Bad")
			return
		end
		if not limiter:Allow("Buy") then
			return
		end
		row.IsBusy = true
		row.Token += 1
		local token = row.Token
		task.delay(safetySeconds, function()
			if row.Token == token and row.IsBusy then
				row.IsBusy = false
				refreshRow(row)
			end
		end)
		task.spawn(function()
			local success = Packets.BuyUpgrade:Fire(row.Upgrade.Id, modeAmounts[mode])
			if row.Token ~= token then
				refreshRow(row)
				return
			end
			row.IsBusy = false
			if success == true then
				playUi("Confirm")
				Kit.Pulse(row.Frame, theme.Good, 1)
				local suffix = if count > 1 then ` x{count}` else ""
				context.Toast(`Bought {row.Upgrade.Name}{suffix}!`, "Good")
			else
				playUi("Error")
				Kit.Shake(row.Frame)
				context.Toast("Oops, couldn't buy that!", "Bad")
			end
			refreshRow(row)
		end)
	end

	Kit.TabBar(trove, {
		Parent = modal.Body,
		Name = "Amount",
		Tabs = modes,
		Selected = mode,
		Position = UDim2.new(0.5, -modeBarWidth // 2, 0, modeBarGap),
		Size = UDim2.fromOffset(modeBarWidth, modeBarHeight),
		TextSize = 24,
		OnSelect = function(id: string)
			mode = id
			refreshAll()
		end,
		Sound = playUi,
	})

	local function addCaption(section: { Caption: string, Glyph: string }, order: number)
		Kit.Section({
			Parent = scroll,
			Name = `Caption{section.Caption}`,
			Text = section.Caption,
			Glyph = section.Glyph,
			Color = theme.Gold,
			LayoutOrder = order,
		})
	end

	local function addCard(upgrade: Upgrades.Upgrade, order: number)
		local color = cardColors[upgrade.Id] or theme.Green
		local layout = Kit.Row({
			Parent = scroll,
			Name = upgrade.Id,
			Height = cardHeight,
			LayoutOrder = order,
			Color = color,
			Glyph = upgrade.Glyph,
			Title = headline(upgrade),
			TitleSize = 24,
			RightWidth = buyWidth,
		})
		local card = layout.Frame
		layout.Title.Name = "Line1"
		layout.Title.RichText = true
		layout.Title.Position = UDim2.fromOffset(layout.Left, 10)
		local line2 = Kit.Label({
			Parent = card,
			Name = "Line2",
			Text = "",
			Position = UDim2.fromOffset(layout.Left, 42),
			Size = UDim2.new(1, -(layout.Left + layout.Right), 0, 24),
			TextSize = 22,
			Color = theme.Subtext,
			Subtle = true,
			Scaled = true,
			RichText = true,
		})
		local bar = Kit.Bar({
			Parent = card,
			Name = "Level",
			Position = UDim2.fromOffset(layout.Left, 72),
			Size = UDim2.new(1, -(layout.Left + layout.Right), 0, 12),
			Color = theme.Green,
		})
		local row: Row = {
			Frame = card,
			Bar = bar,
			Line2 = line2,
			Buy = nil :: any,
			Upgrade = upgrade,
			IsBusy = false,
			Token = 0,
		}
		row.Buy = Kit.Button(trove, {
			Parent = card,
			Name = "Buy",
			Text = "BUY",
			Glyph = "Clicks",
			IconLeft = true,
			Position = UDim2.new(1, -Kit.Space.M, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Size = UDim2.fromOffset(buyWidth, 60),
			Color = theme.Green,
			TextSize = 26,
			Callback = function()
				buy(row)
			end,
			Sound = playUi,
		})
		table.insert(rows, row)
	end

	local lockButton: Kit.Button
	local lockCard: Frame
	local lockDescription: TextLabel
	local isLockBusy = false

	local function ownPlot(): Model?
		local plots = workspace:FindFirstChild("Plots")
		if not plots then
			return nil
		end
		local userId = Players.LocalPlayer.UserId
		for _, child in plots:GetChildren() do
			if child:IsA("Model") and child:GetAttribute("Owner") == userId then
				return child
			end
		end
		return nil
	end

	local function clock(seconds: number): string
		local whole = math.max(0, math.ceil(seconds))
		return string.format("%d:%02d", whole // 60, whole % 60)
	end

	local function refreshLock()
		local upgrade = Upgrades.ById.LockTime
		local seconds = GameConfig.Defense.LockBaseSeconds + tracker.GetLevel("LockTime") * upgrade.PerLevel
		lockDescription.Text = `Lasers zap thieves for {seconds}s`
		local plot = ownPlot()
		local now = workspace:GetServerTimeNow()
		local lockedUntil = if plot then plot:GetAttribute("LockedUntil") else nil
		local cooldownUntil = if plot then plot:GetAttribute("LockCooldownUntil") else nil
		if type(lockedUntil) == "number" and now < lockedUntil then
			lockButton.SetText(`LOCKED {clock(lockedUntil - now)}`)
			lockButton.SetColor(theme.Green)
			lockButton.SetDisabled(true)
		elseif type(cooldownUntil) == "number" and now < cooldownUntil then
			lockButton.SetText(`READY IN {clock(cooldownUntil - now)}`)
			lockButton.SetColor(greyColor)
			lockButton.SetDisabled(true)
		else
			lockButton.SetText(lockReadyText)
			lockButton.SetColor(theme.Red)
			lockButton.SetDisabled(plot == nil)
		end
	end

	local function pressLock()
		if isLockBusy then
			return
		end
		isLockBusy = true
		task.spawn(function()
			local success = Packets.LockBase:Fire()
			isLockBusy = false
			if success == true then
				playUi("Confirm")
				Kit.Pulse(lockCard, theme.Good, 1)
				context.Toast(lockToast, "Good")
			else
				playUi("Error")
				Kit.Shake(lockCard)
			end
			refreshLock()
		end)
	end

	local function addLockCard(order: number)
		local layout = Kit.Row({
			Parent = scroll,
			Name = "LockBase",
			Height = lockCardHeight,
			LayoutOrder = order,
			Color = theme.Red,
			Glyph = "Lock",
			Title = "LOCK BASE",
			Subtitle = "",
			RightWidth = lockButtonWidth,
		})
		lockCard = layout.Frame
		local sub = layout.Subtitle
		if sub then
			sub.Name = "Description"
			lockDescription = sub
		end
		lockButton = Kit.Button(trove, {
			Parent = lockCard,
			Name = "Lock",
			Text = lockReadyText,
			Position = UDim2.new(1, -Kit.Space.M, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Size = UDim2.fromOffset(lockButtonWidth, 56),
			Color = theme.Red,
			TextSize = 26,
			Callback = pressLock,
			Sound = playUi,
		})
	end

	for sectionIndex, section in sections do
		addCaption(section, sectionIndex * sectionStride)
		if section.Category == "Defense" then
			addLockCard(sectionIndex * sectionStride + lockCardOrder)
		end
		for index, upgrade in Upgrades.List do
			if upgrade.Category == section.Category then
				addCard(upgrade, sectionIndex * sectionStride + index)
			end
		end
	end

	refreshLock()

	local elapsed = 0
	local lockElapsed = 0
	trove:Connect(RunService.Heartbeat, function(dt: number)
		if not isOpen then
			return
		end
		elapsed += dt
		lockElapsed += dt
		if elapsed >= refreshSeconds then
			elapsed = 0
			refreshAll()
		end
		if lockElapsed >= lockRefreshSeconds then
			lockElapsed = 0
			refreshLock()
		end
	end)

	return {
		Modal = true,
		StartsOpen = false,
		Open = function(_self: Types.Screen)
			isOpen = true
			refreshAll()
			refreshLock()
			modal.Show()
		end,
		Close = function(_self: Types.Screen)
			isOpen = false
			modal.Hide()
		end,
		Destroy = function(_self: Types.Screen)
			trove:Destroy()
		end,
	}
end

return UpgradesScreen
