--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Boosts = require(ReplicatedStorage.Rules.Boosts)
local Income = require(ReplicatedStorage.Rules.Income)
local Stats = require(ReplicatedStorage.Rules.Stats)
local Trove = require(ReplicatedStorage.Packages.Trove)
local BoostState = require(script.Parent.BoostState)

type TroveInstance = typeof(Trove.new())

export type Tracker = {
	IsLoaded: () -> boolean,
	Balance: () -> number?,
	GetStats: () -> Stats.Stats,
	Boosts: BoostState.State,
	GetBoard: () -> { string },
	GetLevel: (id: string) -> number,
}

local Economy = {}

function Economy.Predict(cash: number, incomeAt: number, rate: number, clicksUntil: number): number
	if incomeAt <= 0 then
		return cash
	end
	local earned = Income.Earned(
		rate,
		incomeAt,
		workspace:GetServerTimeNow(),
		clicksUntil,
		GameConfig.Boosts.PotionMultiplier
	)
	return cash + earned
end

function Economy.Track(dataController: any, trove: TroveInstance, onChanged: (() -> ())?): Tracker
	local cash: number? = nil
	local incomeAt = 0
	local board: { string } = {}
	local levels: any = {}
	local boostState = BoostState.Track(dataController, trove)

	local function changed()
		if onChanged then
			onChanged()
		end
	end

	trove:Add(dataController:Observe({ "Cash" }, function(value: any)
		cash = if type(value) == "number" then value else nil
		changed()
	end))
	trove:Add(dataController:Observe({ "IncomeAt" }, function(value: any)
		incomeAt = if type(value) == "number" then value else 0
		changed()
	end))
	trove:Add(dataController:Observe({ "Board" }, function(value: any)
		local copy: { string } = {}
		if type(value) == "table" then
			for index, keyId in value do
				if type(index) == "number" and type(keyId) == "string" then
					copy[index] = keyId
				end
			end
		end
		board = copy
		changed()
	end))
	trove:Add(dataController:Observe({ "Upgrades" }, function(value: any)
		levels = if type(value) == "table" then value else {}
		changed()
	end))

	return {
		IsLoaded = function()
			return cash ~= nil
		end,
		Boosts = boostState,
		Balance = function()
			local current = cash
			if not current then
				return nil
			end
			local passIncome = Boosts.PassIncome(boostState.Passes())
			local rate = Stats.Compute(board, levels, { Income = passIncome }).Rate
			return Economy.Predict(current, incomeAt, rate, boostState.Stored().ClicksUntil or 0)
		end,
		GetStats = function()
			return Stats.Compute(board, levels, boostState.Modifiers(workspace:GetServerTimeNow()))
		end,
		GetBoard = function()
			return board
		end,
		GetLevel = function(id: string)
			local level = levels[id]
			return if type(level) == "number" then level else 0
		end,
	}
end

return Economy
