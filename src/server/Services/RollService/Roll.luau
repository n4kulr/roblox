--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Keys = require(ReplicatedStorage.Config.Keys)

local Roll = {}

function Roll.PickRarity(rng: Random, luck: number): Keys.Rarity
	for index = #Keys.Rarities, 2, -1 do
		local rarity = Keys.Rarities[index]
		if rng:NextNumber() < luck / rarity.Chance then
			return rarity
		end
	end
	return Keys.Rarities[1]
end

function Roll.Pick(rng: Random, luck: number): Keys.Key
	local rarity = Roll.PickRarity(rng, luck)
	local group = Keys.ByRarity[rarity.Name]
	return group[rng:NextInteger(1, #group)]
end

return Roll
