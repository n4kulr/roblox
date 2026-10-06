local H = require("../harness/Harness")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

local function signature(offers: any): string
	local parts = {}
	for _, offer in offers do
		table.insert(parts, `{offer.Index}:{offer.EggId}:{offer.Stock}:{offer.Multiplier}`)
	end
	return table.concat(parts, "|")
end

describe("Market rules", function()
	local Market, Eggs, Keys
	local firstSlot = 5666667

	beforeEach(function()
		local world = H.newWorld()
		Market = world:require("ReplicatedStorage.Rules.Market")
		Eggs = world:require("ReplicatedStorage.Config.Eggs")
		Keys = world:require("ReplicatedStorage.Config.Keys")
	end)

	it("maps time to slots and counts down to the next one", function()
		expect(Market.Slot(0)):toBe(0)
		expect(Market.Slot(299.9)):toBe(0)
		expect(Market.Slot(300)):toBe(1)
		expect(Market.Slot(1700000250)):toBe(firstSlot)
		expect(Market.SecondsLeft(0)):toBe(300)
		expect(Market.SecondsLeft(299)):toBe(1)
		expect(Market.SecondsLeft(1700000250)):toBe(150)
	end)

	it("rounds to two significant figures", function()
		expect(Market.RoundNice(1234)):toBe(1200)
		expect(Market.RoundNice(1250)):toBe(1300)
		expect(Market.RoundNice(420)):toBe(420)
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
		expect(distinct > 20):toBe(true)
	end)

	it("always lists every egg, cheap ones in stock, rarer ones sometimes at 0", function()
		for slot = firstSlot, firstSlot + 1999 do
			local offers = Market.Offers(slot)
			expect(#offers):toBe(#Eggs.Catalog)
			expect(offers[1].EggId):toBe("Linear")
			expect(offers[2].EggId):toBe("Tactile")
			expect(offers[1].Stock > 0):toBe(true)
			expect(offers[2].Stock > 0):toBe(true)
			local lastTier = 0
			for index, offer in offers do
				expect(offer.Index):toBe(index)
				local egg = Eggs.ById[offer.EggId]
				expect(egg ~= nil):toBe(true)
				expect(egg.Index > lastTier):toBe(true)
				lastTier = egg.Index
				if offer.Stock > 0 then
					expect(offer.Stock >= egg.StockMin and offer.Stock <= egg.StockMax):toBe(true)
				else
					expect(offer.Stock):toBe(0)
				end
				expect(offer.Multiplier):toBe(1)
				expect(offer.IsDeal):toBe(false)
			end
		end
	end)

	it("makes rare eggs appear in stock less often than cheap ones", function()
		local counts = { Linear = 0, Clicky = 0, Rainbow = 0 }
		for slot = firstSlot, firstSlot + 1999 do
			for _, offer in Market.Offers(slot) do
				if counts[offer.EggId] and offer.Stock > 0 then
					counts[offer.EggId] += 1
				end
			end
		end
		expect(counts.Linear):toBe(2000)
		expect(counts.Clicky < counts.Linear):toBe(true)
		expect(counts.Rainbow < counts.Clicky):toBe(true)
		expect(counts.Rainbow > 300 and counts.Rainbow < 1100):toBe(true)
	end)

	it("prices each egg at a fixed MinPrice", function()
		for _, egg in Eggs.Catalog do
			local offer = { Index = 1, EggId = egg.Id, Stock = 1, Multiplier = 1, IsDeal = false }
			expect(Market.Price(offer, 0)):toBe(egg.MinPrice)
			expect(Market.Price(offer, 1000000)):toBe(egg.MinPrice)
		end
		local linear = { Index = 1, EggId = "Linear", Stock = 1, Multiplier = 1.5, IsDeal = false }
		expect(Market.Price(linear, 1000)):toBe(Eggs.ById.Linear.MinPrice)
		expect(Market.Price({ Index = 1, EggId = "Nope", Stock = 1, Multiplier = 1, IsDeal = false }, 5)):toBe(0)
	end)

	it("makes pricier tiers cost more", function()
		local last = 0
		for _, egg in Eggs.Catalog do
			local price =
				Market.Price({ Index = 1, EggId = egg.Id, Stock = 1, Multiplier = 1, IsDeal = false }, 500)
			expect(price > last):toBe(true)
			last = price
		end
	end)

	it("derives the price rate from the board and upgrades without boosts", function()
		local rate = Market.BaseRate({ "PlainClack", "PlainClack" }, { Slots = 0, Luck = 0, Speed = 0 })
		expect(rate):toBe(2 * Keys.GetIncome("PlainClack"))
		expect(Market.BaseRate({}, {})):toBe(0)
	end)
end)
