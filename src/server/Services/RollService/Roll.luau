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

function Roll.PickInRarity(rng: Random, rarityName: string): Keys.Key
	local group = Keys.ByRarity[rarityName]
	return group[rng:NextInteger(1, #group)]
end

function Roll.Pick(rng: Random, luck: number): Keys.Key
	return Roll.PickInRarity(rng, Roll.PickRarity(rng, luck).Name)
end

return Roll
