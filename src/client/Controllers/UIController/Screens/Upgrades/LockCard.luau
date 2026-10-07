--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Packets)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Upgrades = require(ReplicatedStorage.Config.Upgrades)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Economy = require(script.Parent.Parent.Parent.Economy)
local Kit = require(script.Parent.Parent.Parent.Kit)
local PlayerState = require(script.Parent.Parent.Parent.PlayerState)
local Types = require(script.Parent.Parent.Parent.Types)

export type Env = {
	Trove: typeof(Trove.new()),
	Context: Types.Context,
	Parent: Instance,
	Tracker: Economy.Tracker,
	PlayUi: (name: string) -> (),
}

export type Card = {
	Refresh: () -> (),
}

local theme = Kit.Theme
local lockCardHeight = 92
local lockButtonWidth = 200
local lockReadyText = "LOCK BASE"
local lockToast = "Lasers on! Your base is locked."

local LockCard = {}

function LockCard.Build(env: Env, order: number): Card
	local trove = env.Trove
	local context = env.Context
	local playUi = env.PlayUi
	local tracker = env.Tracker
	local scroll = env.Parent
	local lockButton: Kit.Button
	local lockCard: Frame
	local lockDescription: TextLabel
	local isLockBusy = false

	local function clock(seconds: number): string
		local whole = math.max(0, math.ceil(seconds))
		return string.format("%d:%02d", whole // 60, whole % 60)
	end

	local function refreshLock()
		local upgrade = Upgrades.ById.LockTime
		local seconds = GameConfig.Defense.LockBaseSeconds + tracker.GetLevel("LockTime") * upgrade.PerLevel
		lockDescription.Text = `Lasers zap thieves for {seconds}s`
		local plot = PlayerState.OwnPlot()
		local now = workspace:GetServerTimeNow()
		local lockedUntil = if plot then plot:GetAttribute("LockedUntil") else nil
		local cooldownUntil = if plot then plot:GetAttribute("LockCooldownUntil") else nil
		if type(lockedUntil) == "number" and now < lockedUntil then
			lockButton.SetText(`LOCKED {clock(lockedUntil - now)}`)
			lockButton.SetColor(theme.Green)
			lockButton.SetDisabled(true)
		elseif type(cooldownUntil) == "number" and now < cooldownUntil then
			lockButton.SetText(`READY IN {clock(cooldownUntil - now)}`)
			lockButton.SetColor(theme.GreyDeep)
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
		Kit.Spawn(trove, function()
			return Packets.LockBase:Fire()
		end, function(isOk: boolean, success: any)
			isLockBusy = false
			if isOk and success == true then
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
		TextSize = Kit.Text.Subhead,
		Callback = pressLock,
	})

	refreshLock()
	return { Refresh = refreshLock }
end

return LockCard
