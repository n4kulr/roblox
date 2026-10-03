--!strict

local Config = script.Parent.Parent.Config
local GameConfig = require(Config.GameConfig)
local Keys = require(Config.Keys)

export type Offer = {
	Index: number,
	KeyId: string,
	Price: number,
	Stock: number,
	Multiplier: number,
	IsDeal: boolean,
}

local config = GameConfig.Market
local modulus = 4294967296
local drawAttempts = 24
local warmupRounds = 8

local rarityRank: { [string]: number } = {}
for index, rarity in Keys.Rarities do
	rarityRank[rarity.Name] = index
end

local Market = {}

local function newGenerator(slot: number): () -> number
	local state = (math.floor(slot) * 747796405 + 2891336453) % modulus
	if state == 0 then
		state = 2463534242
	end
	local function step(): number
		state = bit32.bxor(state, bit32.lshift(state, 13))
		state = bit32.bxor(state, bit32.rshift(state, 17))
		state = bit32.bxor(state, bit32.lshift(state, 5))
		return state
	end
	for _ = 1, warmupRounds do
		step()
	end
	return function(): number
		return step() / modulus
	end
end

local function pickRarity(draw: () -> number, total: number): string
	local roll = draw() * total
	local chosen = ""
	for _, rarity in Keys.Rarities do
		local weight = config.RarityWeights[rarity.Name]
		local group = Keys.ByRarity[rarity.Name]
		if weight and weight > 0 and #group > 0 then
			chosen = rarity.Name
			roll -= weight
			if roll < 0 then
				return rarity.Name
			end
		end
	end
	return chosen
end

local function totalWeight(): number
	local total = 0
	for _, rarity in Keys.Rarities do
		local weight = config.RarityWeights[rarity.Name]
		if weight and weight > 0 and #Keys.ByRarity[rarity.Name] > 0 then
			total += weight
		end
	end
	return total
end

function Market.RoundNice(value: number): number
	if value <= 0 then
		return 0
	end
	local magnitude = math.floor(math.log10(value))
	local step = 10 ^ math.max(0, magnitude - 1)
	return math.floor(value / step + 0.5) * step
end

function Market.Slot(now: number): number
	return math.floor(now / config.RefreshSeconds)
end

function Market.SecondsLeft(now: number): number
	local slot = Market.Slot(now)
	return math.max(0, (slot + 1) * config.RefreshSeconds - now)
end

function Market.Offers(slot: number): { Offer }
	local draw = newGenerator(slot)
	local total = totalWeight()
	local picked: { string } = {}
	local used: { [string]: boolean } = {}
	for _ = 1, config.OfferCount do
		local keyId = ""
		for attempt = 1, drawAttempts do
			local rarity = pickRarity(draw, total)
			local group = Keys.ByRarity[rarity]
			keyId = group[math.min(#group, math.floor(draw() * #group) + 1)].Id
			if not used[keyId] or attempt == drawAttempts then
				break
			end
		end
		used[keyId] = true
		table.insert(picked, keyId)
	end
	local offers: { Offer } = {}
	for _, keyId in picked do
		local multiplier = config.MinPriceMultiplier
			+ (config.MaxPriceMultiplier - config.MinPriceMultiplier) * draw()
		local stock = math.min(
			config.MaxStock,
			config.MinStock + math.floor(draw() * (config.MaxStock - config.MinStock + 1))
		)
		local price = math.max(
			config.MinPrice,
			Market.RoundNice(Keys.GetIncome(keyId) * 60 * config.PriceMinutesOfIncome * multiplier)
		)
		table.insert(offers, {
			Index = 0,
			KeyId = keyId,
			Price = price,
			Stock = stock,
			Multiplier = multiplier,
			IsDeal = multiplier < config.DealBelow,
		})
	end
	table.sort(offers, function(a: Offer, b: Offer)
		local rankA = rarityRank[Keys.ById[a.KeyId].Rarity]
		local rankB = rarityRank[Keys.ById[b.KeyId].Rarity]
		if rankA ~= rankB then
			return rankA < rankB
		end
		if a.Price ~= b.Price then
			return a.Price < b.Price
		end
		return a.KeyId < b.KeyId
	end)
	for index, offer in offers do
		offer.Index = index
	end
	return offers
end

return table.freeze(Market)
