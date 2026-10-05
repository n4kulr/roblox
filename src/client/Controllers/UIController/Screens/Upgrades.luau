--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Packets = require(ReplicatedStorage.Packets)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local UiAssets = require(ReplicatedStorage.Config.UiAssets)
local Upgrades = require(ReplicatedStorage.Config.Upgrades)
local Stats = require(ReplicatedStorage.Rules.Stats)
local Trove = require(ReplicatedStorage.Packages.Trove)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Economy = require(script.Parent.Parent.Economy)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)

type Row = {
	Frame: Frame,
	Bar: Kit.Bar,
	Preview: TextLabel,
	Buy: Kit.Button,
	Upgrade: Upgrades.Upgrade,
	IsBusy: boolean,
}

local theme = Kit.Theme
local cardHeight = 112
local refreshSeconds = 0.2
local buyWidth = 158

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

local UpgradesScreen = {}

function UpgradesScreen.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local playUi = Kit.UiSound(context.Controllers)
	local rows: { Row } = {}
	local isOpen = false
	local tracker: Economy.Tracker

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
		Position = UDim2.fromOffset(6, 4),
		Size = UDim2.new(1, -12, 1, -8),
		Padding = 12,
	})

	local function previewText(upgrade: Upgrades.Upgrade, level: number): string
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
		local isMaxed = level >= upgrade.MaxLevel
		local after = if isMaxed then now else Stats.Compute(board, nextLevels)
		if upgrade.Id == "Luck" then
			if isMaxed then
				return string.format("Now: x%.1f Luck", now.Luck)
			end
			return string.format("x%.1f > x%.1f Luck", now.Luck, after.Luck)
		elseif upgrade.Id == "Speed" then
			if isMaxed then
				return string.format("Now: %.1f rolls/s", now.RollsPerSecond)
			end
			return string.format("%.1f/s > %.1f/s", now.RollsPerSecond, after.RollsPerSecond)
		end
		if upgrade.Id == "Golden" then
			local current = Stats.GoldenEvery({ Golden = level })
			if isMaxed then
				return `Now: every {current} rolls`
			end
			return `Every {current} > {Stats.GoldenEvery({ Golden = level + 1 })} rolls`
		end
		if upgrade.Id == "Income" then
			local current = math.round(level * upgrade.PerLevel * 100)
			if isMaxed then
				return string.format("Now: +%d%% Clicks", current)
			end
			return string.format(
				"+%d%% > +%d%% Clicks",
				current,
				current + math.round(upgrade.PerLevel * 100)
			)
		elseif upgrade.Id == "Walls" then
			local current = GameConfig.Defense.WallBaseHeight + level * upgrade.PerLevel
			if isMaxed then
				return string.format("Now: %d studs tall", current)
			end
			return string.format("%d > %d studs tall", current, current + upgrade.PerLevel)
		elseif upgrade.Id == "LockTime" then
			local current = GameConfig.Defense.LockBaseSeconds + level * upgrade.PerLevel
			if isMaxed then
				return string.format("Now: %ds of lasers", current)
			end
			return string.format("%ds > %ds of lasers", current, current + upgrade.PerLevel)
		end
		if isMaxed then
			return string.format("Now: %d slots", now.Slots)
		end
		return string.format("%d > %d slots", now.Slots, after.Slots)
	end

	local function refreshRow(row: Row)
		local level = tracker.GetLevel(row.Upgrade.Id)
		row.Preview.Text = previewText(row.Upgrade, level)
		local maxLevel = row.Upgrade.MaxLevel
		row.Bar.SetText(`Lv {level}/{maxLevel}`)
		row.Bar.SetValue(level / maxLevel)
		local cost = Upgrades.Cost(row.Upgrade, level)
		if not cost then
			row.Buy.SetText("MAX")
			row.Buy.SetIconVisible(false)
			row.Buy.SetColor(theme.Gold)
			row.Buy.SetLocked(false)
			return
		end
		local balance = tracker.Balance()
		local canBuy = balance ~= nil and balance >= cost
		row.Buy.SetText(NumberFormat.Compact(cost))
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
		local cost = Upgrades.Cost(row.Upgrade, level)
		if not cost then
			playUi("Confirm")
			context.Toast("Already MAXED!", "Good")
			Kit.Pulse(row.Frame, theme.Gold)
			return
		end
		local balance = tracker.Balance() or 0
		if balance < cost then
			playUi("Error")
			Kit.Shake(row.Frame)
			context.Toast(`Need {NumberFormat.Compact(cost - balance)} more Clicks!`, "Bad")
			return
		end
		row.IsBusy = true
		task.spawn(function()
			local success = Packets.BuyUpgrade:Fire(row.Upgrade.Id)
			row.IsBusy = false
			if success == true then
				playUi("Confirm")
				Kit.Pulse(row.Frame, theme.Good)
				context.Toast(`Bought {row.Upgrade.Name}!`, "Good")
			else
				playUi("Error")
				Kit.Shake(row.Frame)
				context.Toast("Oops, couldn't buy that!", "Bad")
			end
			refreshRow(row)
		end)
	end

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
			Title = upgrade.Name,
			Subtitle = upgrade.Effect,
			RightWidth = buyWidth,
		})
		local card = layout.Frame
		layout.Title.Position = UDim2.fromOffset(layout.Left, 6)
		local subtitle = layout.Subtitle
		if subtitle then
			subtitle.Position = UDim2.fromOffset(layout.Left, 36)
			subtitle.Name = "Effect"
		end
		local previewLabel = Kit.Label({
			Parent = card,
			Name = "Preview",
			Text = "",
			Position = UDim2.fromOffset(layout.Left, 56),
			Size = UDim2.new(1, -(layout.Left + layout.Right), 0, 20),
			TextSize = 18,
			Color = theme.GoodDeep,
			Subtle = true,
			Scaled = true,
		})
		local bar = Kit.Bar({
			Parent = card,
			Name = "Level",
			Position = UDim2.fromOffset(layout.Left, 80),
			Size = UDim2.new(1, -(layout.Left + layout.Right), 0, 22),
			Color = theme.Green,
			Text = "Lv 0",
			TextSize = 15,
		})
		local row: Row = {
			Frame = card,
			Bar = bar,
			Preview = previewLabel,
			Buy = nil :: any,
			Upgrade = upgrade,
			IsBusy = false,
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
			TextSize = 28,
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
				Kit.Pulse(lockCard, theme.Good)
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
