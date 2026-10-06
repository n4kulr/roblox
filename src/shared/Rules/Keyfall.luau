--!strict

local Config = script.Parent.Parent.Config
local GameConfig = require(Config.GameConfig)

export type PickupState = {
	CarryCount: number,
	CarryingStolen: boolean,
	IsLanded: boolean,
	IsReady: boolean,
	Distance: number,
}

export type KnockContext = {
	CallerUserId: number,
	TargetUserId: number,
	Distance: number,
	TargetCarryCount: number,
	Now: number,
	LastKnockAt: number?,
}

local keyfall = GameConfig.Keyfall
local steal = GameConfig.Steal

local Keyfall = {
	Reasons = table.freeze({
		Self = "You can't knock yourself!",
		Cooldown = "Wait a moment!",
		Empty = "They aren't carrying anything!",
		TooFar = "Get closer to knock them!",
	}),
	Events = table.freeze({
		Announce = 1,
		Grabbed = 2,
		Claimed = 3,
		Delivered = 4,
		Vanished = 5,
	}),
}

function Keyfall.RandomPointInDisc(rng: Random, center: Vector3, radius: number): Vector3
	local angle = rng:NextNumber() * math.pi * 2
	local distance = radius * math.sqrt(rng:NextNumber())
	return Vector3.new(center.X + math.cos(angle) * distance, center.Y, center.Z + math.sin(angle) * distance)
end

function Keyfall.CanPickup(state: PickupState): boolean
	return state.IsLanded
		and state.IsReady
		and not state.CarryingStolen
		and state.CarryCount < keyfall.CarryLimit
		and state.Distance <= keyfall.PickupRange
end

function Keyfall.CarrySpeed(count: number): number
	return math.max(1, steal.NormalWalkSpeed - keyfall.CarrySlowPerCap * math.max(count, 0))
end

function Keyfall.CanKnock(context: KnockContext): (boolean, string)
	local reasons = Keyfall.Reasons
	if context.CallerUserId == context.TargetUserId then
		return false, reasons.Self
	end
	local last = context.LastKnockAt
	if last and context.Now - last < keyfall.KnockCooldown then
		return false, reasons.Cooldown
	end
	if context.TargetCarryCount < 1 then
		return false, reasons.Empty
	end
	if context.Distance > keyfall.KnockRange then
		return false, reasons.TooFar
	end
	return true, ""
end

function Keyfall.NextSpacebarDelay(rng: Random): number
	local low = keyfall.GoldenSpacebarMinSeconds
	local high = keyfall.GoldenSpacebarMaxSeconds
	return low + rng:NextNumber() * (high - low)
end

return Keyfall
