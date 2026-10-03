local H = require("../harness/Harness")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

local function signature(offers: any): string
	local parts = {}
	for _, offer in offers do
		table.insert(parts, `{offer.Index}:{offer.KeyId}:{offer.Price}:{offer.Stock}:{offer.Multiplier}`)
	end
	return table.concat(parts, "|")
end

describe("Market rules", function()
	local Market, GameConfig, Keys, config
	local firstSlot = 5666667

	beforeEach(function()
		local world = H.newWorld()
		Market = world:require("ReplicatedStorage.Rules.Market")
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		Keys = world:require("ReplicatedStorage.Config.Keys")
		config = GameConfig.Market
	end)

	it("maps time to slots and counts down to the next one", function()
		expect(Market.Slot(0)):toBe(0)
		expect(Market.Slot(299.9)):toBe(0)
		expect(Market.Slot(300)):toBe(1)
		expect(Market.Slot(1700000250)):toBe(firstSlot)
		expect(Market.SecondsLeft(0)):toBe(300)
		expect(Market.SecondsLeft(299)):toBe(1)
		expect(Market.SecondsLeft(300)):toBe(300)
		expect(Market.SecondsLeft(1700000250)):toBe(150)
	end)

	it("rounds to two significant figures", function()
		expect(Market.RoundNice(1234)):toBe(1200)
		expect(Market.RoundNice(1250)):toBe(1300)
		expect(Market.RoundNice(420)):toBe(420)
		expect(Market.RoundNice(436.8)):toBe(440)
		expect(Market.RoundNice(99999)):toBe(100000)
		expect(Market.RoundNice(0)):toBe(0)
	end)

	it("is deterministic for a slot and differs between slots", function()
		for slot = firstSlot, firstSlot + 50 do
			expect(signature(Market.Offers(slot))):toBe(signature(Market.Offers(slot)))
		end
		local seen: { [string]: boolean } = {}
		local distinct = 0
		for slot = firstSlot, firstSlot + 199 do
			local text = signature(Market.Offers(slot))
			if not seen[text] then
				seen[text] = true
				distinct += 1
			end
		end
		expect(distinct):toBe(200)
		expect(signature(Market.Offers(firstSlot)) ~= signature(Market.Offers(firstSlot + 1))):toBe(true)
	end)

	it("returns OfferCount indexed offers and never Exclusive keys", function()
		for slot = firstSlot, firstSlot + 1999 do
			local offers = Market.Offers(slot)
			expect(#offers):toBe(config.OfferCount)
			for index, offer in offers do
				expect(offer.Index):toBe(index)
				local key = Keys.ById[offer.KeyId]
				expect(key ~= nil):toBe(true)
				expect(key.Exclusive):toBe(false)
			end
		end
	end)

	it("avoids duplicate keys within a slot", function()
		for slot = firstSlot, firstSlot + 1999 do
			local seen: { [string]: boolean } = {}
			for _, offer in Market.Offers(slot) do
				expect(seen[offer.KeyId]):toBeNil()
				seen[offer.KeyId] = true
			end
		end
	end)

	it("sorts offers by rarity then price", function()
		local rank: { [string]: number } = {}
		for index, rarity in Keys.Rarities do
			rank[rarity.Name] = index
		end
		for slot = firstSlot, firstSlot + 499 do
			local offers = Market.Offers(slot)
			for index = 2, #offers do
				local before, after = offers[index - 1], offers[index]
				local rankBefore = rank[Keys.ById[before.KeyId].Rarity]
				local rankAfter = rank[Keys.ById[after.KeyId].Rarity]
				expect(rankBefore <= rankAfter):toBe(true)
				if rankBefore == rankAfter then
					expect(before.Price <= after.Price):toBe(true)
				end
			end
		end
	end)

	it("prices by income within the multiplier range, the floor and two significant figures", function()
		for slot = firstSlot, firstSlot + 1999 do
			for _, offer in Market.Offers(slot) do
				expect(offer.Multiplier >= config.MinPriceMultiplier):toBe(true)
				expect(offer.Multiplier <= config.MaxPriceMultiplier):toBe(true)
				local income = Keys.GetIncome(offer.KeyId)
				local base = income * 60 * config.PriceMinutesOfIncome
				expect(offer.Price >= config.MinPrice):toBe(true)
				expect(offer.Price):toBe(math.max(config.MinPrice, Market.RoundNice(base * offer.Multiplier)))
				local low = math.max(config.MinPrice, Market.RoundNice(base * config.MinPriceMultiplier))
				local high = math.max(config.MinPrice, Market.RoundNice(base * config.MaxPriceMultiplier))
				expect(offer.Price >= low and offer.Price <= high):toBe(true)
				if offer.Price >= 100 then
					local step = 10 ^ (math.floor(math.log10(offer.Price)) - 1)
					expect((offer.Price / step) % 1):toBe(0)
				end
			end
		end
	end)

	it("keeps stock within bounds and flags deals below DealBelow", function()
		local stocks: { [number]: boolean } = {}
		local deals, plain = 0, 0
		for slot = firstSlot, firstSlot + 1999 do
			for _, offer in Market.Offers(slot) do
				expect(offer.Stock % 1):toBe(0)
				expect(offer.Stock >= config.MinStock and offer.Stock <= config.MaxStock):toBe(true)
				stocks[offer.Stock] = true
				expect(offer.IsDeal):toBe(offer.Multiplier < config.DealBelow)
				if offer.IsDeal then
					deals += 1
				else
					plain += 1
				end
			end
		end
		for stock = config.MinStock, config.MaxStock do
			expect(stocks[stock]):toBe(true)
		end
		expect(deals > 0 and plain > deals):toBe(true)
	end)

	it("follows the rarity weights across many slots", function()
		local counts: { [string]: number } = {}
		local total = 0
		local weightTotal = 0
		for _, weight in config.RarityWeights do
			weightTotal += weight
		end
		for slot = firstSlot, firstSlot + 4999 do
			for _, offer in Market.Offers(slot) do
				local rarity = Keys.ById[offer.KeyId].Rarity
				counts[rarity] = (counts[rarity] or 0) + 1
				total += 1
			end
		end
		expect(counts.Secret):toBeNil()
		for name, weight in config.RarityWeights do
			local expected = weight / weightTotal
			local actual = (counts[name] or 0) / total
			expect(math.abs(actual - expected) <= math.max(0.02, expected * 0.5)):toBe(true)
		end
		expect((counts.Common or 0) > (counts.Rare or 0)):toBe(true)
		expect((counts.Rare or 0) > (counts.Legendary or 0)):toBe(true)
	end)
end)
