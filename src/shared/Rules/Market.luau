--!strict

local Config = script.Parent.Parent.Config
local GameConfig = require(Config.GameConfig)
local Eggs = require(Config.Eggs)
local Stats = require(script.Parent.Stats)

export type Offer = {
	Index: number,
	EggId: string,
	Stock: number,
	Multiplier: number,
	IsDeal: boolean,
}

local config = GameConfig.Market
local modulus = 4294967296
local warmupRounds = 8

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

function Market.BaseRate(board: { string }, upgrades: any): number
	return Stats.Compute(board, upgrades).Rate
end

function Market.Price(offer: Offer, _rate: number): number
	local egg = Eggs.ById[offer.EggId]
	if not egg then
		return 0
	end
	return egg.MinPrice
end

function Market.Offers(slot: number): { Offer }
	local draw = newGenerator(slot)
	local offers: { Offer } = {}
	for _, egg in Eggs.Catalog do
		local appears = draw() < egg.AppearChance
		draw()
		local stock = 0
		if appears then
			stock = egg.StockMin + math.floor(draw() * (egg.StockMax - egg.StockMin + 1))
			stock = math.min(stock, egg.StockMax)
		end
		table.insert(offers, {
			Index = egg.Index,
			EggId = egg.Id,
			Stock = stock,
			Multiplier = 1,
			IsDeal = false,
		})
	end
	return offers
end

return table.freeze(Market)
