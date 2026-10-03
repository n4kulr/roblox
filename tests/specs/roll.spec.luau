local H = require("../harness/Harness")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

describe("Roll", function()
	local world, Roll, Keys
	beforeEach(function()
		world = H.newWorld()
		Roll = world:require("ServerScriptService.Services.RollService.Roll")
		Keys = world:require("ReplicatedStorage.Config.Keys")
	end)

	local function expectedOdds(luck: number): { [string]: number }
		local rarities = Keys.Rarities
		local odds = {}
		local remaining = 1
		for index = #rarities, 2, -1 do
			local p = math.min(1, luck / rarities[index].Chance)
			odds[rarities[index].Name] = remaining * p
			remaining *= 1 - p
		end
		odds[rarities[1].Name] = remaining
		return odds
	end

	local function sample(luck: number, count: number, seed: number): { [string]: number }
		local rng = world.Random.new(seed)
		local counts = {}
		for _ = 1, count do
			local name = Roll.PickRarity(rng, luck).Name
			counts[name] = (counts[name] or 0) + 1
		end
		return counts
	end

	local function expectMatches(luck: number, seed: number)
		local n = 200000
		local counts = sample(luck, n, seed)
		for name, p in expectedOdds(luck) do
			local sigma = math.sqrt(n * p * (1 - p))
			local observed = counts[name] or 0
			local diff = math.abs(observed - n * p)
			if diff > 5 * sigma + 2 then
				error(`{name} at luck {luck}: observed {observed}, expected {n * p} (sigma {sigma})`)
			end
		end
	end

	describe("PickRarity", function()
		it("matches the configured odds at luck 1 over 200k samples", function()
			expectMatches(1, 11)
		end)

		it("matches the expected odds at higher luck", function()
			expectMatches(3.7, 22)
			expectMatches(25, 33)
		end)

		it("returns Common as the fallback when luck is 0 or negative", function()
			local rng = world.Random.new(5)
			for _ = 1, 5000 do
				expect(Roll.PickRarity(rng, 0).Name):toBe("Common")
				expect(Roll.PickRarity(rng, -4).Name):toBe("Common")
			end
		end)

		it("makes common the most frequent result at luck 1", function()
			local counts = sample(1, 20000, 8)
			expect(counts.Common):toBeGreaterThan(counts.Uncommon)
			expect(counts.Uncommon):toBeGreaterThan(counts.Rare)
			expect(counts.Rare):toBeGreaterThan(counts.Epic)
		end)

		it("shifts toward rarer results as luck increases", function()
			local function rareOrBetter(luck: number): number
				local counts = sample(luck, 20000, 99)
				local total = 0
				for _, name in { "Rare", "Epic", "Legendary", "Mythic", "Secret" } do
					total += counts[name] or 0
				end
				return total
			end
			local low, mid, high = rareOrBetter(1), rareOrBetter(2), rareOrBetter(10)
			expect(mid):toBeGreaterThan(low * 1.5)
			expect(high):toBeGreaterThan(mid * 2)
		end)

		it("always returns a rarity at huge luck without erroring", function()
			local rng = world.Random.new(1)
			for _ = 1, 100 do
				expect(Roll.PickRarity(rng, 1e12).Name):toBe("Secret")
			end
		end)

		it("is deterministic for a given seed", function()
			expect(sample(2, 1000, 77)):toEqual(sample(2, 1000, 77))
		end)
	end)

	describe("PickInRarity", function()
		it("only returns keys of the requested rarity and reaches all of them", function()
			local rng = world.Random.new(3)
			for _, rarity in Keys.Rarities do
				local seen = {}
				for _ = 1, 400 do
					local key = Roll.PickInRarity(rng, rarity.Name)
					expect(key.Rarity):toBe(rarity.Name)
					seen[key.Id] = true
				end
				for _, key in Keys.ByRarity[rarity.Name] do
					expect(seen[key.Id]):toBe(true)
				end
			end
		end)
	end)

	describe("Pick", function()
		it("returns a catalog key whose rarity follows PickRarity", function()
			local rng = world.Random.new(4)
			for _ = 1, 500 do
				local key = Roll.Pick(rng, 2)
				expect(Keys.ById[key.Id]):toBe(key)
			end
		end)
	end)
end)

describe("Random mock", function()
	it("stays within bounds and is roughly uniform", function()
		local rng = H.newWorld().Random.new(1)
		local sum = 0
		for _ = 1, 20000 do
			local value = rng:NextNumber()
			expect(value >= 0 and value < 1):toBe(true)
			sum += value
			local integer = rng:NextInteger(3, 6)
			expect(integer >= 3 and integer <= 6 and integer % 1 == 0):toBe(true)
		end
		expect(sum / 20000):toBeCloseTo(0.5, 0.01)
	end)
end)
