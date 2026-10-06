--!strict

local Config = script.Parent.Parent.Config
local CharmConfig = require(Config.Charms)
local Eggs = require(Config.Eggs)

export type Effects = {
	Income: number,
	Luck: number,
	Speed: number,
	GoldenReduction: number,
	StealSpeed: number,
	LaserSeconds: number,
}

export type Drop = {
	CharmId: string,
	Chance: number,
}

local scoreWeights: { [string]: number } = {
	Income = 1,
	Luck = 0.8,
	Speed = 0.8,
	Golden = 0.5,
	Steal = 0.3,
	Laser = 0.2,
}
local scoreScales: { [string]: number } = {
	Income = 1,
	Luck = 1,
	Speed = 1,
	Golden = 1 / 25,
	Steal = 1,
	Laser = 1 / 30,
}

local Charms = {}

function Charms.Neutral(): Effects
	return { Income = 1, Luck = 1, Speed = 1, GoldenReduction = 0, StealSpeed = 1, LaserSeconds = 0 }
end

function Charms.Effects(equipped: any): Effects
	local effects = Charms.Neutral()
	if type(equipped) ~= "table" then
		return effects
	end
	local counted = 0
	for index = 1, #equipped do
		local charm = if type(equipped[index]) == "string" then CharmConfig.ById[equipped[index]] else nil
		if charm and counted < CharmConfig.EquipLimit then
			counted += 1
			local kind = charm.Kind
			if kind == "Income" then
				effects.Income += charm.Amount - 1
			elseif kind == "Luck" then
				effects.Luck += charm.Amount - 1
			elseif kind == "Speed" then
				effects.Speed += charm.Amount
			elseif kind == "Golden" then
				effects.GoldenReduction += charm.Amount
			elseif kind == "Steal" then
				effects.StealSpeed += charm.Amount
			else
				effects.LaserSeconds += charm.Amount
			end
		end
	end
	return effects
end

function Charms.Describe(charmId: string): string
	local charm = CharmConfig.ById[charmId]
	if not charm then
		return ""
	end
	local kind = charm.Kind
	local function trim(value: number): string
		return string.format("%g", math.floor(value * 100 + 0.5) / 100)
	end
	if kind == "Income" then
		return `x{trim(charm.Amount)} Income`
	elseif kind == "Luck" then
		return `x{trim(charm.Amount)} Luck`
	elseif kind == "Speed" then
		return `+{trim(charm.Amount * 100)}% Roll Speed`
	elseif kind == "Golden" then
		return `Golden -{trim(charm.Amount)} rolls`
	elseif kind == "Steal" then
		return `+{trim(charm.Amount * 100)}% Steal Speed`
	end
	return `+{trim(charm.Amount)}s Laser Time`
end

function Charms.Score(charmId: string): number
	local charm = CharmConfig.ById[charmId]
	if not charm then
		return 0
	end
	local amount = if charm.Kind == "Income" or charm.Kind == "Luck" then charm.Amount - 1 else charm.Amount
	return amount * scoreScales[charm.Kind] * scoreWeights[charm.Kind]
end

function Charms.CountOf(equipped: { string }, charmId: string): number
	local total = 0
	for _, id in equipped do
		if id == charmId then
			total += 1
		end
	end
	return total
end

function Charms.CanEquip(owned: { [string]: number }, equipped: { string }, charmId: string): boolean
	if CharmConfig.ById[charmId] == nil or #equipped >= CharmConfig.EquipLimit then
		return false
	end
	local count = owned[charmId]
	return type(count) == "number" and count > Charms.CountOf(equipped, charmId)
end

function Charms.Best(owned: { [string]: number }): { string }
	local pool: { string } = {}
	for _, charm in CharmConfig.Catalog do
		local count = owned[charm.Id]
		if type(count) == "number" then
			for _ = 1, math.min(count, CharmConfig.EquipLimit) do
				table.insert(pool, charm.Id)
			end
		end
	end
	table.sort(pool, function(a: string, b: string)
		local scoreA, scoreB = Charms.Score(a), Charms.Score(b)
		if scoreA ~= scoreB then
			return scoreA > scoreB
		end
		return a < b
	end)
	local best: { string } = {}
	for index = 1, math.min(CharmConfig.EquipLimit, #pool) do
		best[index] = pool[index]
	end
	return best
end

function Charms.Drops(eggId: string): { Drop }
	local egg = Eggs.ById[eggId]
	local drops: { Drop } = {}
	if not egg then
		return drops
	end
	local total = 0
	for rarity, weight in egg.Drops do
		if #CharmConfig.ByRarity[rarity] > 0 then
			total += weight
		end
	end
	for _, rarity in CharmConfig.Rarities do
		local weight = egg.Drops[rarity.Name]
		local group = CharmConfig.ByRarity[rarity.Name]
		if weight and #group > 0 then
			for _, charm in group do
				table.insert(drops, { CharmId = charm.Id, Chance = weight / total / #group })
			end
		end
	end
	return drops
end

function Charms.Roll(random: Random, eggId: string): string
	local drops = Charms.Drops(eggId)
	local roll = random:NextNumber()
	for _, drop in drops do
		roll -= drop.Chance
		if roll < 0 then
			return drop.CharmId
		end
	end
	local last = drops[#drops]
	return if last then last.CharmId else ""
end

function Charms.Sanitize(owned: any, equipped: any): { string }
	local clean: { string } = {}
	if type(equipped) ~= "table" or type(owned) ~= "table" then
		return clean
	end
	for _, id in equipped do
		if type(id) == "string" and Charms.CanEquip(owned, clean, id) then
			table.insert(clean, id)
		end
	end
	return clean
end

return table.freeze(Charms)
