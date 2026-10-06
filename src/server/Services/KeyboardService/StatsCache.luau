--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charms = require(ReplicatedStorage.Rules.Charms)
local Rebirth = require(ReplicatedStorage.Rules.Rebirth)
local Stats = require(ReplicatedStorage.Rules.Stats)
local PlayerData = require(script.Parent.Parent.Parent.Data.PlayerData)

export type RollStats = {
	Luck: number,
	RollsPerSecond: number,
	GoldenEvery: number,
}

type RateEntry = {
	Rate: number,
	Board: { string },
	Charms: { string },
	Rebirths: number,
	SlotsLevel: number,
	IncomeLevel: number,
	PassIncome: number,
}

type RollEntry = {
	Stats: RollStats,
	Board: { string },
	Charms: { string },
	SlotsLevel: number,
	LuckLevel: number,
	SpeedLevel: number,
	GoldenLevel: number,
	LuckMultiplier: number,
}

export type Cache = {
	_rates: { [Player]: RateEntry },
	_rolls: { [Player]: RollEntry },
	Rate: (self: Cache, player: Player, data: PlayerData.Data, passIncome: number) -> number,
	Roll: (self: Cache, player: Player, data: PlayerData.Data, luckMultiplier: number) -> RollStats,
	Invalidate: (self: Cache, player: Player) -> (),
}

local StatsCache = {}
StatsCache.__index = StatsCache

function StatsCache.new(): Cache
	return setmetatable({ _rates = {}, _rolls = {} }, StatsCache) :: any
end

local function levelOf(data: PlayerData.Data, id: string): number
	local levels: any = data.Upgrades
	local value = if type(levels) == "table" then levels[id] else nil
	return if type(value) == "number" then value else 0
end

function StatsCache.Rate(self: Cache, player: Player, data: PlayerData.Data, passIncome: number): number
	local slotsLevel, incomeLevel = levelOf(data, "Slots"), levelOf(data, "Income")
	local entry = self._rates[player]
	if
		entry
		and entry.Board == data.Board
		and entry.Charms == data.EquippedCharms
		and entry.Rebirths == data.Rebirths
		and entry.SlotsLevel == slotsLevel
		and entry.IncomeLevel == incomeLevel
		and entry.PassIncome == passIncome
	then
		return entry.Rate
	end
	local income = passIncome
		* Rebirth.IncomeMultiplier(data.Rebirths)
		* Charms.Effects(data.EquippedCharms).Income
	local rate = Stats.Compute(data.Board, data.Upgrades, { Income = income }).Rate
	self._rates[player] = {
		Rate = rate,
		Board = data.Board,
		Charms = data.EquippedCharms,
		Rebirths = data.Rebirths,
		SlotsLevel = slotsLevel,
		IncomeLevel = incomeLevel,
		PassIncome = passIncome,
	}
	return rate
end

function StatsCache.Roll(
	self: Cache,
	player: Player,
	data: PlayerData.Data,
	luckMultiplier: number
): RollStats
	local slotsLevel, luckLevel = levelOf(data, "Slots"), levelOf(data, "Luck")
	local speedLevel, goldenLevel = levelOf(data, "Speed"), levelOf(data, "Golden")
	local entry = self._rolls[player]
	if
		entry
		and entry.Board == data.Board
		and entry.Charms == data.EquippedCharms
		and entry.SlotsLevel == slotsLevel
		and entry.LuckLevel == luckLevel
		and entry.SpeedLevel == speedLevel
		and entry.GoldenLevel == goldenLevel
		and entry.LuckMultiplier == luckMultiplier
	then
		return entry.Stats
	end
	local effects = Charms.Effects(data.EquippedCharms)
	local computed = Stats.Compute(
		data.Board,
		data.Upgrades,
		{ Luck = luckMultiplier * effects.Luck, Speed = effects.Speed }
	)
	local rollStats: RollStats = {
		Luck = computed.Luck,
		RollsPerSecond = computed.RollsPerSecond,
		GoldenEvery = Stats.GoldenEvery(data.Upgrades, effects.GoldenReduction),
	}
	self._rolls[player] = {
		Stats = rollStats,
		Board = data.Board,
		Charms = data.EquippedCharms,
		SlotsLevel = slotsLevel,
		LuckLevel = luckLevel,
		SpeedLevel = speedLevel,
		GoldenLevel = goldenLevel,
		LuckMultiplier = luckMultiplier,
	}
	return rollStats
end

function StatsCache.Invalidate(self: Cache, player: Player)
	self._rates[player] = nil
	self._rolls[player] = nil
end

return StatsCache
