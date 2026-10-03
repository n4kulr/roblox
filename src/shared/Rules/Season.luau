--!strict

local Config = script.Parent.Parent.Config
local GameConfig = require(Config.GameConfig)
local SeasonLevels = require(Config.Season)

export type Progress = { Xp: number?, ClaimedFree: number?, ClaimedPremium: number? }
export type Claim = { Level: number, Premium: boolean }

local Season = {}

local function number(value: any): number
	return if type(value) == "number" and value == value then value else 0
end

function Season.MaxLevel(): number
	return #SeasonLevels.Levels
end

function Season.Level(xp: number): number
	return math.clamp(math.floor(number(xp) / GameConfig.Season.XpPerLevel), 0, #SeasonLevels.Levels)
end

function Season.Claimed(season: Progress, premium: boolean): number
	return if premium then number(season.ClaimedPremium) else number(season.ClaimedFree)
end

function Season.CanClaim(season: Progress, level: number, premium: boolean, ownsPremium: boolean): boolean
	if type(level) ~= "number" or level % 1 ~= 0 then
		return false
	end
	if premium and not ownsPremium then
		return false
	end
	return level == Season.Claimed(season, premium) + 1 and level <= Season.Level(number(season.Xp))
end

function Season.Reward(level: number, premium: boolean): SeasonLevels.Reward?
	local entry = SeasonLevels.Levels[level]
	if not entry then
		return nil
	end
	return if premium then entry.Premium else entry.Free
end

function Season.Claimable(season: Progress, ownsPremium: boolean): { Claim }
	local out: { Claim } = {}
	local reached = Season.Level(number(season.Xp))
	for level = Season.Claimed(season, false) + 1, reached do
		table.insert(out, { Level = level, Premium = false })
	end
	if ownsPremium then
		for level = Season.Claimed(season, true) + 1, reached do
			table.insert(out, { Level = level, Premium = true })
		end
	end
	return out
end

return Season
