--!strict

local Config = script.Parent.Parent.Config
local GameConfig = require(Config.GameConfig)
local Keys = require(Config.Keys)

export type Context = {
	ThiefUserId: number,
	VictimUserId: number,
	HasThiefData: boolean,
	HasVictimData: boolean,
	ThiefCarrying: boolean,
	ActiveThiefUserId: number,
	VictimPlaySeconds: number,
	VictimLockedUntil: number,
	Now: number,
	ThiefRate: number,
	VictimRate: number,
	ExpectedKeyId: string,
	SlotKeyId: string,
	Distance: number,
}

local steal = GameConfig.Steal
local rarityIndexByName: { [string]: number } = {}
for index, rarity in Keys.Rarities do
	rarityIndexByName[rarity.Name] = index
end

local Steal = {
	Reasons = table.freeze({
		Self = "That's your own key!",
		NoData = "Something went wrong, try again!",
		Carrying = "You're already carrying a key!",
		Shielded = "They're protected by a new-player shield!",
		Locked = "Their base is locked!",
		TooWeak = "They're too weak to rob!",
		Gone = "Too slow! That key is gone!",
		TooFar = "Get closer to steal it!",
		Busy = "Someone is already stealing from them!",
		TooFast = "Keep holding to steal it!",
	}),
	AlertPhase = table.freeze({
		Stealing = 1,
		Stolen = 2,
		Returned = 3,
		GotAway = 4,
		Rejected = 9,
		Info = 10,
		Good = 11,
	}),
}

function Steal.RarityIndex(keyId: string): number
	local key = Keys.Resolve(keyId)
	return if key then rarityIndexByName[key.Rarity] or 1 else 1
end

function Steal.HoldSeconds(rarityIndex: number, lessonPending: boolean, speed: number?): number
	local seconds = steal.BaseHoldSeconds + steal.HoldSecondsPerRarity * (math.max(rarityIndex, 1) - 1)
	seconds = if lessonPending then seconds * steal.LessonHoldMultiplier else seconds
	return seconds / math.max(speed or 1, 1)
end

function Steal.IsShielded(playSeconds: number): boolean
	return playSeconds < steal.ShieldPlaySeconds
end

function Steal.PowerGapBlocked(thiefRate: number, victimRate: number): boolean
	return thiefRate > victimRate * steal.PowerGapRatio
end

function Steal.CanSteal(context: Context): (boolean, string)
	local reasons = Steal.Reasons
	if context.ThiefUserId == context.VictimUserId then
		return false, reasons.Self
	end
	if not context.HasThiefData or not context.HasVictimData then
		return false, reasons.NoData
	end
	if context.ThiefCarrying then
		return false, reasons.Carrying
	end
	if context.ActiveThiefUserId ~= 0 and context.ActiveThiefUserId ~= context.ThiefUserId then
		return false, reasons.Busy
	end
	if Steal.IsShielded(context.VictimPlaySeconds) then
		return false, reasons.Shielded
	end
	if context.Now < context.VictimLockedUntil then
		return false, reasons.Locked
	end
	if Steal.PowerGapBlocked(context.ThiefRate, context.VictimRate) then
		return false, reasons.TooWeak
	end
	if context.SlotKeyId == "" or context.SlotKeyId ~= context.ExpectedKeyId then
		return false, reasons.Gone
	end
	if context.Distance > steal.PromptRange + 2 then
		return false, reasons.TooFar
	end
	return true, ""
end

return Steal
