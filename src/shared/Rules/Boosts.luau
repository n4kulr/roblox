--!strict

local GameConfig = require(script.Parent.Parent.Config.GameConfig)

export type Modifiers = { Luck: number, Income: number }
export type Stored = { LuckUntil: number?, ClicksUntil: number? }

local Boosts = {}

local function isActive(expiresAt: any, now: number): boolean
	return type(expiresAt) == "number" and expiresAt > now
end

function Boosts.PassIncome(passes: { [string]: boolean }): number
	local income = 1
	if passes.DoubleClicks then
		income *= GameConfig.Boosts.DoubleClicksPassMultiplier
	end
	if passes.Vip then
		income *= GameConfig.Boosts.VipIncomeMultiplier
	end
	return income
end

function Boosts.Modifiers(
	boosts: Stored,
	passes: { [string]: boolean },
	now: number,
	serverLuckUntil: number
): Modifiers
	local luck = 1
	if passes.DoubleLuck then
		luck *= GameConfig.Boosts.DoubleLuckPassMultiplier
	end
	if isActive(boosts.LuckUntil, now) then
		luck *= GameConfig.Boosts.PotionMultiplier
	end
	if isActive(serverLuckUntil, now) then
		luck *= GameConfig.Boosts.ServerLuckMultiplier
	end
	local income = Boosts.PassIncome(passes)
	if isActive(boosts.ClicksUntil, now) then
		income *= GameConfig.Boosts.PotionMultiplier
	end
	return { Luck = luck, Income = income }
end

function Boosts.Extend(expiresAt: number, now: number, seconds: number): number
	return math.min(math.max(expiresAt, now) + seconds, now + GameConfig.Boosts.MaxStackSeconds)
end

function Boosts.Remaining(expiresAt: number, now: number): number
	return math.max(0, expiresAt - now)
end

return Boosts
