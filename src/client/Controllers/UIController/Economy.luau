--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats = require(ReplicatedStorage.Rules.Stats)
local Trove = require(ReplicatedStorage.Packages.Trove)

type TroveInstance = typeof(Trove.new())

export type Tracker = {
	IsLoaded: () -> boolean,
	Balance: () -> number?,
	GetStats: () -> Stats.Stats,
	GetBoard: () -> { string },
	GetLevel: (id: string) -> number,
}

local Economy = {}

function Economy.Predict(cash: number, incomeAt: number, rate: number): number
	if incomeAt <= 0 then
		return cash
	end
	local elapsed = math.max(0, workspace:GetServerTimeNow() - incomeAt)
	return cash + math.floor(rate * elapsed)
end

function Economy.Track(dataController: any, trove: TroveInstance, onChanged: (() -> ())?): Tracker
	local cash: number? = nil
	local incomeAt = 0
	local board: { string } = {}
	local levels: any = {}
	local stats = Stats.Compute(board, levels)

	local function changed()
		stats = Stats.Compute(board, levels)
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
		Balance = function()
			local current = cash
			if not current then
				return nil
			end
			return Economy.Predict(current, incomeAt, stats.Rate)
		end,
		GetStats = function()
			return stats
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
