--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local IncomeRules = require(ReplicatedStorage.Rules.Income)
local PlayerData = require(script.Parent.Parent.Parent.Data.PlayerData)

local Income = {}

function Income.TotalEarnedAfter(data: PlayerData.Data, cash: number): number
	return data.TotalEarned + math.max(0, cash - data.Cash)
end

function Income.Settled(data: PlayerData.Data, now: number, rate: number): (number, number)
	if data.IncomeAt <= 0 or now <= data.IncomeAt then
		return data.Cash, if data.IncomeAt <= 0 then now else data.IncomeAt
	end
	local earned = IncomeRules.Earned(
		rate,
		data.IncomeAt,
		now,
		data.Boosts.ClicksUntil,
		GameConfig.Boosts.PotionMultiplier
	)
	return math.min(GameConfig.MaxCash, data.Cash + earned), now
end

function Income.Offline(data: PlayerData.Data, now: number, rate: number): number
	if data.IncomeAt <= 0 then
		return data.Cash
	end
	local elapsed = math.clamp(now - data.IncomeAt, 0, GameConfig.OfflineCapSeconds)
	local earned = math.floor(
		IncomeRules.Earned(
			rate,
			data.IncomeAt,
			data.IncomeAt + elapsed,
			data.Boosts.ClicksUntil,
			GameConfig.Boosts.PotionMultiplier
		) * GameConfig.OfflineRate
	)
	return math.min(GameConfig.MaxCash, data.Cash + earned)
end

return Income
