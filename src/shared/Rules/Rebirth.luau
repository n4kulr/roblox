--!strict

local GameConfig = require(script.Parent.Parent.Config.GameConfig)

local Rebirth = {}

local function count(rebirths: any): number
	return if type(rebirths) == "number" and rebirths == rebirths and rebirths > 0 then rebirths else 0
end

function Rebirth.Cost(rebirths: number): number
	local total = count(rebirths)
	local steps = GameConfig.Rebirth.CostSteps
	local cost = GameConfig.Rebirth.BaseCost
	for index = 1, total do
		cost *= steps[index] or GameConfig.Rebirth.CostGrowth
	end
	return math.floor(cost)
end

function Rebirth.IncomeMultiplier(rebirths: number): number
	return 1 + GameConfig.Rebirth.IncomePerRebirth * count(rebirths)
end

return Rebirth
