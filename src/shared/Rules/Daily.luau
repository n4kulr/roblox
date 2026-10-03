--!strict

local GameConfig = require(script.Parent.Parent.Config.GameConfig)
local DailyRewards = require(script.Parent.Parent.Config.DailyRewards)

export type Stored = { Streak: number?, LastClaim: number? }
export type Status = {
	CanClaim: boolean,
	Day: number,
	SecondsLeft: number,
	StreakBroken: boolean,
}

local Daily = {}

local function number(value: any): number
	return if type(value) == "number" then value else 0
end

function Daily.Status(daily: Stored, now: number): Status
	local lastClaim = number(daily.LastClaim)
	local streak = number(daily.Streak)
	local total = #DailyRewards.Rewards
	if lastClaim <= 0 then
		return { CanClaim = true, Day = 1, SecondsLeft = 0, StreakBroken = false }
	end
	local elapsed = now - lastClaim
	local canClaim = elapsed >= GameConfig.DailyCooldownSeconds
	local isBroken = elapsed >= GameConfig.DailyStreakResetSeconds
	local day = 1
	if not isBroken then
		day = (math.max(streak, 0) % total) + 1
	end
	return {
		CanClaim = canClaim,
		Day = day,
		SecondsLeft = if canClaim then 0 else math.ceil(GameConfig.DailyCooldownSeconds - elapsed),
		StreakBroken = isBroken,
	}
end

return Daily
