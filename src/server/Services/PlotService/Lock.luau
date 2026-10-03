--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Upgrades = require(ReplicatedStorage.Config.Upgrades)
local Types = require(script.Parent.Types)
local Walls = require(script.Parent.Walls)

local defense = GameConfig.Defense

local laserColor = Color3.fromRGB(255, 30, 50)
local laserCount = 5
local laserThickness = 0.3
local laserMargin = 0.5
local anchorLift = 4
local verticalSlack = 15
local depthBelow = 6
local statusReady = "Ready"
local statusActive = "Active"
local statusCooldown = "Cooldown"

local Lock = {
	Ready = statusReady,
	Active = statusActive,
	Cooldown = statusCooldown,
}

function Lock.Duration(level: any): number
	local clamped = 0
	if type(level) == "number" and level == level then
		clamped = math.clamp(math.floor(level), 0, Upgrades.ById.LockTime.MaxLevel)
	end
	return defense.LockBaseSeconds + clamped * Upgrades.ById.LockTime.PerLevel
end

function Lock.StatusAt(state: Types.Defense, now: number): string
	if state.IsActive and now < state.LockedUntil then
		return statusActive
	end
	if now < state.CooldownUntil then
		return statusCooldown
	end
	return statusReady
end

function Lock.Format(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("🔒 LOCKED %d:%02d", whole // 60, whole % 60)
end

function Lock.EntranceCFrame(info: Types.PlotInfo): CFrame
	local size = info.Base.Size
	return info.Base.CFrame * CFrame.new(0, size.Y / 2, -(size.Z / 2 - defense.WallThickness / 2))
end

function Lock.Outward(info: Types.PlotInfo): Vector3
	return info.Base.CFrame.LookVector
end

function Lock.Build(): Types.Defense
	local state: Types.Defense = {
		IsActive = false,
		LockedUntil = 0,
		CooldownUntil = 0,
		Lasers = nil,
		Anchor = nil,
		Label = nil,
		ShownSeconds = -1,
		Status = statusReady,
	}
	return state
end

function Lock.ClearLasers(state: Types.Defense)
	local lasers = state.Lasers
	local anchor = state.Anchor
	state.Lasers = nil
	state.Anchor = nil
	state.Label = nil
	state.ShownSeconds = -1
	if lasers then
		lasers:Destroy()
	end
	if anchor then
		anchor:Destroy()
	end
end

function Lock.ShowLasers(info: Types.PlotInfo, state: Types.Defense)
	Lock.ClearLasers(state)
	local height = Walls.Height(info.WallLevel)
	local entrance = Lock.EntranceCFrame(info)
	local folder = Instance.new("Folder")
	folder.Name = "Lasers"
	local low = laserMargin
	local high = math.max(low, height - laserMargin)
	for index = 1, laserCount do
		local fraction = (index - 1) / (laserCount - 1)
		local laser = Instance.new("Part")
		laser.Name = `Laser{index}`
		laser.Anchored = true
		laser.CanCollide = false
		laser.CanQuery = false
		laser.CanTouch = false
		laser.CastShadow = false
		laser.Material = Enum.Material.Neon
		laser.Color = laserColor
		laser.Transparency = 0.15
		laser.Size = Vector3.new(defense.EntranceWidth, laserThickness, laserThickness)
		laser.CFrame = entrance * CFrame.new(0, low + (high - low) * fraction, 0)
		laser.Parent = folder
	end
	local anchor = Instance.new("Part")
	anchor.Name = "LockAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = entrance * CFrame.new(0, height + anchorLift, 0)
	local gui = Instance.new("BillboardGui")
	gui.Name = "LockTimer"
	gui.Size = UDim2.fromOffset(260, 56)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 200
	gui.Adornee = anchor
	local label = Instance.new("TextLabel")
	label.Name = "Countdown"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 80, 90)
	label.TextStrokeTransparency = 0
	label.Text = ""
	label.Parent = gui
	gui.Parent = anchor
	folder.Parent = info.Model
	anchor.Parent = info.Model
	state.Lasers = folder
	state.Anchor = anchor
	state.Label = label
end

function Lock.Start(info: Types.PlotInfo, state: Types.Defense, now: number, seconds: number)
	state.IsActive = true
	state.LockedUntil = now + seconds
	state.CooldownUntil = state.LockedUntil + defense.LockCooldownSeconds
	Lock.ShowLasers(info, state)
end

function Lock.Finish(state: Types.Defense)
	state.IsActive = false
	Lock.ClearLasers(state)
end

function Lock.Reset(state: Types.Defense)
	state.IsActive = false
	state.LockedUntil = 0
	state.CooldownUntil = 0
	state.Status = statusReady
	Lock.ClearLasers(state)
end

function Lock.Present(info: Types.PlotInfo, state: Types.Defense, now: number)
	local status = Lock.StatusAt(state, now)
	state.Status = status
	local remaining = math.ceil(state.LockedUntil - now)
	local label = state.Label
	if status == statusActive and label and remaining ~= state.ShownSeconds then
		state.ShownSeconds = remaining
		label.Text = Lock.Format(remaining)
	end
	local lockedAttribute: number? = if state.LockedUntil > 0 then state.LockedUntil else nil
	local cooldownAttribute: number? = if state.CooldownUntil > 0 then state.CooldownUntil else nil
	info.Model:SetAttribute("LockedUntil", lockedAttribute)
	info.Model:SetAttribute("LockCooldownUntil", cooldownAttribute)
end

function Lock.IsInside(info: Types.PlotInfo, position: Vector3): boolean
	local relative = info.Base.CFrame:PointToObjectSpace(position)
	local size = info.Base.Size
	local top = size.Y / 2 + Walls.Height(info.WallLevel)
	return math.abs(relative.X) <= size.X / 2
		and math.abs(relative.Z) <= size.Z / 2
		and relative.Y >= -size.Y / 2 - depthBelow
		and relative.Y <= top + verticalSlack
end

function Lock.Knock(info: Types.PlotInfo, root: BasePart)
	local outward = Lock.Outward(info)
	local size = info.Base.Size
	local position = (info.Base.CFrame * CFrame.new(
		0,
		size.Y / 2 + 3,
		-(size.Z / 2 + defense.WallThickness + 5)
	)).Position
	root.CFrame = CFrame.lookAt(position, position + outward)
	root.AssemblyLinearVelocity = outward * defense.LaserKnockback + Vector3.new(0, 15, 0)
end

return Lock
