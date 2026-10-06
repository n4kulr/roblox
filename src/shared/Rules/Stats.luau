--!strict

local Config = script.Parent.Parent.Config
local GameConfig = require(Config.GameConfig)
local Keys = require(Config.Keys)
local Upgrades = require(Config.Upgrades)

export type Levels = {
	Luck: number,
	Speed: number,
	Slots: number,
	Income: number?,
	Walls: number?,
	LockTime: number?,
	Golden: number?,
}

export type Stats = {
	Luck: number,
	RollsPerSecond: number,
	Slots: number,
	IncomeMultiplier: number,
	Rate: number,
}

local Stats = {}

local function level(levels: any, id: string): number
	local value = if type(levels) == "table" then levels[id] else nil
	return if type(value) == "number" then value else 0
end

function Stats.Slots(levels: any): number
	local slots = GameConfig.BaseSlots + level(levels, "Slots") * Upgrades.ById.Slots.PerLevel
	return math.clamp(slots, GameConfig.BaseSlots, GameConfig.BoardSlots)
end

function Stats.GoldenEvery(levels: any, reduction: number?): number
	local every = GameConfig.GoldenRollEvery
		- level(levels, "Golden") * Upgrades.ById.Golden.PerLevel
		- (reduction or 0)
	return math.max(1, every)
end

export type Modifiers = { Luck: number?, Income: number?, Speed: number? }

function Stats.Compute(board: { string }, levels: any, modifiers: Modifiers?): Stats
	local slots = Stats.Slots(levels)
	local luckBonus, speedBonus, incomeBonus, baseRate = 0, 0, 0, 0
	for index = 1, slots do
		local keyId = board[index]
		local key = if type(keyId) == "string" then Keys.Resolve(keyId) else nil
		if key then
			baseRate += Keys.GetIncome(keyId :: string)
			local perk = key.Perk
			if perk then
				if perk.Kind == "Luck" then
					luckBonus += perk.Amount
				elseif perk.Kind == "Speed" then
					speedBonus += perk.Amount
				else
					incomeBonus += perk.Amount
				end
			end
		end
	end
	local luck = (GameConfig.Luck + level(levels, "Luck") * Upgrades.ById.Luck.PerLevel) * (1 + luckBonus)
	local rollsPerSecond = (GameConfig.RollsPerSecond + level(levels, "Speed") * Upgrades.ById.Speed.PerLevel)
		* (1 + speedBonus)
	if modifiers then
		rollsPerSecond *= modifiers.Speed or 1
	end
	rollsPerSecond = math.min(rollsPerSecond, GameConfig.MaxRollsPerSecond)
	local multiplier = (1 + incomeBonus) * (1 + level(levels, "Income") * Upgrades.ById.Income.PerLevel)
	if modifiers then
		luck *= modifiers.Luck or 1
		multiplier *= modifiers.Income or 1
	end
	return {
		Luck = luck,
		RollsPerSecond = rollsPerSecond,
		Slots = slots,
		IncomeMultiplier = multiplier,
		Rate = math.floor(baseRate * multiplier),
	}
end

return Stats
