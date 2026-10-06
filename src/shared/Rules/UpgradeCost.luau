--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Upgrades = require(ReplicatedStorage.Config.Upgrades)

local UpgradeCost = {}

function UpgradeCost.Remaining(upgrade: Upgrades.Upgrade, level: number): number
	return math.max(0, upgrade.MaxLevel - level)
end

function UpgradeCost.Total(upgrade: Upgrades.Upgrade, level: number, count: number): number
	local last = math.min(upgrade.MaxLevel, level + count)
	local total = 0
	for current = level, last - 1 do
		total += Upgrades.Cost(upgrade, current) or 0
	end
	return total
end

function UpgradeCost.Affordable(upgrade: Upgrades.Upgrade, level: number, cash: number, want: number): number
	local limit = UpgradeCost.Remaining(upgrade, level)
	if want > 0 then
		limit = math.min(limit, want)
	end
	local bought = 0
	local spent = 0
	while bought < limit do
		local cost = Upgrades.Cost(upgrade, level + bought)
		if not cost or spent + cost > cash then
			break
		end
		spent += cost
		bought += 1
	end
	return bought
end

return table.freeze(UpgradeCost)
