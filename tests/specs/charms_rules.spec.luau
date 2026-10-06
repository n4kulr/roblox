local H = require("../harness/Harness")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

describe("Pet and egg config", function()
	local Charms, Eggs, Rules

	beforeEach(function()
		local world = H.newWorld()
		Charms = world:require("ReplicatedStorage.Config.Charms")
		Eggs = world:require("ReplicatedStorage.Config.Eggs")
		Rules = world:require("ReplicatedStorage.Rules.Charms")
	end)

	it("defines unique pets with known rarities and kinds", function()
		local seen: { [string]: boolean } = {}
		for _, charm in Charms.Catalog do
			expect(seen[charm.Id]):toBeNil()
			seen[charm.Id] = true
			expect(Charms.RarityByName[charm.Rarity] ~= nil):toBe(true)
			expect(Charms.Kinds[charm.Kind] ~= nil):toBe(true)
			expect(charm.Amount > 0):toBe(true)
		end
		expect(#Charms.Catalog >= 20):toBe(true)
	end)

	it("has the insane top-tier pets", function()
		local diamond = Charms.ById.DiamondSpacebar
		expect(diamond.Rarity):toBe("Mythic")
		expect(diamond.Kind):toBe("Income")
		expect(diamond.Amount):toBe(10)
		expect(Charms.ById.GoldSpacebar.Amount):toBe(5)
	end)

	it("orders the five egg tiers by hatch time and cost", function()
		expect(#Eggs.Catalog):toBe(5)
		local lastSeconds, lastMinutes, lastPrice = 0, 0, 0
		for index, egg in Eggs.Catalog do
			expect(egg.Index):toBe(index)
			expect(egg.HatchSeconds > lastSeconds):toBe(true)
			expect(egg.PriceMinutes > lastMinutes):toBe(true)
			expect(egg.MinPrice > lastPrice):toBe(true)
			lastSeconds, lastMinutes, lastPrice = egg.HatchSeconds, egg.PriceMinutes, egg.MinPrice
		end
		expect(Eggs.ById.Linear.HatchSeconds):toBe(120)
		expect(Eggs.ById.Tactile.HatchSeconds):toBe(480)
		expect(Eggs.ById.Clicky.HatchSeconds):toBe(1200)
		expect(Eggs.ById.Golden.HatchSeconds):toBe(2700)
		expect(Eggs.ById.Rainbow.HatchSeconds):toBe(7200)
	end)

	it("only drops rarities that have pets", function()
		for _, egg in Eggs.Catalog do
			for rarity in egg.Drops do
				expect(#Charms.ByRarity[rarity] > 0):toBe(true)
			end
		end
	end)

	it("gives drop chances that sum to one", function()
		for _, egg in Eggs.Catalog do
			local total = 0
			for _, drop in Rules.Drops(egg.Id) do
				expect(Charms.ById[drop.CharmId] ~= nil):toBe(true)
				total += drop.Chance
			end
			expect(math.abs(total - 1) < 1e-9):toBe(true)
		end
		expect(#Rules.Drops("Nope")):toBe(0)
	end)
end)

describe("Charm rules", function()
	local Charms, Eggs, Rules, world

	beforeEach(function()
		world = H.newWorld()
		Charms = world:require("ReplicatedStorage.Config.Charms")
		Eggs = world:require("ReplicatedStorage.Config.Eggs")
		Rules = world:require("ReplicatedStorage.Rules.Charms")
	end)

	it("returns neutral effects for nothing equipped or bad input", function()
		local neutral = Rules.Neutral()
		expect(Rules.Effects({})):toEqual(neutral)
		expect(Rules.Effects(nil)):toEqual(neutral)
		expect(Rules.Effects("x")):toEqual(neutral)
		expect(Rules.Effects({ "Nope", 5 })):toEqual(neutral)
	end)

	it("adds bonuses within a kind and keeps kinds separate", function()
		local effects = Rules.Effects({ "ThockPad", "GoldSpacebar", "LuckyCable" })
		expect(effects.Income):toBe(1 + 1 + 4)
		expect(math.abs(effects.Luck - 1.8) < 1e-9):toBe(true)
		expect(effects.Speed):toBe(1)
		local mixed = Rules.Effects({ "TurboSpring", "GoldTab", "LaserLens" })
		expect(math.abs(mixed.Speed - 1.3) < 1e-9):toBe(true)
		expect(mixed.GoldenReduction):toBe(10)
		expect(mixed.LaserSeconds):toBe(10)
		local thief = Rules.Effects({ "StickyFingers", "PhantomPaw" })
		expect(thief.StealSpeed):toBe(2.25)
	end)

	it("makes the Diamond Spacebar a x10 income charm", function()
		expect(Rules.Effects({ "DiamondSpacebar" }).Income):toBe(10)
	end)

	it("ignores active entries beyond the limit", function()
		local effects = Rules.Effects({ "ThockPad", "ThockPad", "ThockPad", "ThockPad", "ThockPad", "ThockPad", "ThockPad" })
		expect(effects.Income):toBe(7)
	end)

	it("describes every pet with its effect", function()
		expect(Rules.Describe("ThockPad")):toBe("x2 Income")
		expect(Rules.Describe("KeycapPin")):toBe("x1.25 Income")
		expect(Rules.Describe("LuckyLube")):toBe("x1.4 Luck")
		expect(Rules.Describe("TurboSpring")):toBe("+30% Roll Speed")
		expect(Rules.Describe("GoldTab")):toBe("Golden -10 rolls")
		expect(Rules.Describe("GhostHand")):toBe("+50% Steal Speed")
		expect(Rules.Describe("LaserLens")):toBe("+10s Laser Time")
		expect(Rules.Describe("Nope")):toBe("")
		for _, charm in Charms.Catalog do
			expect(#Rules.Describe(charm.Id) > 0):toBe(true)
		end
	end)

	it("ranks pets by a power score with income first", function()
		expect(Rules.Score("DiamondSpacebar") > Rules.Score("GoldSpacebar")):toBe(true)
		expect(Rules.Score("GoldSpacebar") > Rules.Score("CloverCrown")):toBe(true)
		expect(Rules.Score("ThockPad") > Rules.Score("LuckyCable")):toBe(true)
		expect(Rules.Score("Nope")):toBe(0)
	end)

	it("picks the best six pets", function()
		local owned = {
			KeycapPin = 1,
			ThockPad = 1,
			GoldSpacebar = 1,
			DiamondSpacebar = 1,
			TinySwitch = 1,
			BrassStab = 1,
			RainbowCoil = 1,
		}
		expect(Rules.Best(owned)):toEqual({
			"DiamondSpacebar",
			"GoldSpacebar",
			"RainbowCoil",
			"ThockPad",
			"BrassStab",
			"KeycapPin",
		})
		expect(Rules.Best({})):toEqual({})
		expect(#Rules.Best({ ThockPad = 9 })):toBe(6)
		expect(Rules.Best({ Nope = 3, KeycapPin = 0 })):toEqual({})
	end)

	it("only counts the top six pets in the stacked effects", function()
		local owned = { ThockPad = 10 }
		local effects = Rules.Effects(Rules.Best(owned))
		expect(effects.Income):toBe(1 + 6)
		local all: { [string]: number } = {}
		for _, pet in Charms.Catalog do
			all[pet.Id] = 4
		end
		expect(#Rules.Best(all)):toBe(6)
		expect(Rules.Effects(Rules.Best(all)).Income >= 1 + 9):toBe(true)
	end)

	it("tells whether a pet is among the active six", function()
		local owned = { ThockPad = 1, GoldSpacebar = 1, DiamondSpacebar = 1, RainbowCoil = 1, BrassStab = 1, MegaLaser = 1 }
		expect(Rules.IsActive(owned, "DiamondSpacebar")):toBe(true)
		expect(Rules.IsActive(owned, "KeycapPin")):toBe(false)
		owned.TinySwitch = 1
		expect(Rules.IsActive(owned, "TinySwitch")):toBe(false)
		expect(Rules.IsActive(owned, "MegaLaser")):toBe(true)
		owned.KeycapPin = 1
		expect(Rules.IsActive(owned, "KeycapPin")):toBe(true)
		expect(Rules.IsActive(owned, "MegaLaser")):toBe(false)
		expect(Rules.IsActive({}, "Nope")):toBe(false)
	end)

	it("rolls deterministically from a seed and only from the egg table", function()
		for _, egg in Eggs.Catalog do
			local allowed: { [string]: boolean } = {}
			for _, drop in Rules.Drops(egg.Id) do
				allowed[drop.CharmId] = true
			end
			local a, b = world.Random.new(77), world.Random.new(77)
			for _ = 1, 300 do
				local first = Rules.Roll(a, egg.Id)
				expect(first):toBe(Rules.Roll(b, egg.Id))
				expect(allowed[first]):toBe(true)
			end
		end
		expect(Rules.Roll(world.Random.new(1), "Nope")):toBe("")
	end)

	it("rolls Mythic from the Rainbow egg about one percent of the time and never from cheap eggs", function()
		local random = world.Random.new(2024)
		local mythic = 0
		local total = 20000
		for _ = 1, total do
			if Charms.ById[Rules.Roll(random, "Rainbow")].Rarity == "Mythic" then
				mythic += 1
			end
		end
		expect(mythic > total * 0.004 and mythic < total * 0.02):toBe(true)
		for _, id in { "Linear", "Tactile", "Clicky", "Golden" } do
			for _ = 1, 500 do
				expect(Charms.ById[Rules.Roll(random, id)].Rarity ~= "Mythic"):toBe(true)
			end
		end
	end)
end)

describe("Stats with charm modifiers", function()
	local Stats, GameConfig, Upgrades

	beforeEach(function()
		local world = H.newWorld()
		Stats = world:require("ReplicatedStorage.Rules.Stats")
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		Upgrades = world:require("ReplicatedStorage.Config.Upgrades")
	end)

	local board = { "PlainClack", "PlainClack", "PlainClack" }
	local levels = { Luck = 0, Speed = 0, Slots = 0, Income = 0, Walls = 0, LockTime = 0, Golden = 0 }

	it("applies the income modifier to the rate", function()
		local base = Stats.Compute(board, levels)
		local boosted = Stats.Compute(board, levels, { Income = 5 })
		expect(boosted.IncomeMultiplier):toBe(base.IncomeMultiplier * 5)
		expect(boosted.Rate):toBe(math.floor(base.Rate * 5))
	end)

	it("applies the luck modifier", function()
		local base = Stats.Compute(board, levels)
		expect(math.abs(Stats.Compute(board, levels, { Luck = 3 }).Luck - base.Luck * 3) < 1e-9):toBe(true)
	end)

	it("applies the speed modifier and respects the cap", function()
		local base = Stats.Compute(board, levels)
		local fast = Stats.Compute(board, levels, { Speed = 1.5 })
		expect(math.abs(fast.RollsPerSecond - base.RollsPerSecond * 1.5) < 1e-9):toBe(true)
		local capped = Stats.Compute(board, levels, { Speed = 100 })
		expect(capped.RollsPerSecond):toBe(GameConfig.MaxRollsPerSecond)
	end)

	it("leaves stats unchanged with no or empty modifiers", function()
		local base = Stats.Compute(board, levels)
		expect(Stats.Compute(board, levels, {})):toEqual(base)
		expect(Stats.Compute(board, levels, { Speed = 1, Luck = 1, Income = 1 })):toEqual(base)
	end)

	it("shortens the golden interval with a reduction and never below one", function()
		expect(Stats.GoldenEvery(levels)):toBe(GameConfig.GoldenRollEvery)
		expect(Stats.GoldenEvery(levels, 25)):toBe(GameConfig.GoldenRollEvery - 25)
		expect(Stats.GoldenEvery({ Golden = 2 }, 10)):toBe(
			GameConfig.GoldenRollEvery - 2 * Upgrades.ById.Golden.PerLevel - 10
		)
		expect(Stats.GoldenEvery(levels, 100000)):toBe(1)
	end)
end)

describe("Steal and lock charm bonuses", function()
	it("shortens the steal hold with a speed multiplier", function()
		local world = H.newWorld()
		local Steal = world:require("ReplicatedStorage.Rules.Steal")
		local base = Steal.HoldSeconds(3, false)
		expect(Steal.HoldSeconds(3, false, 2)):toBe(base / 2)
		expect(Steal.HoldSeconds(3, false, 1)):toBe(base)
		expect(Steal.HoldSeconds(3, false, 0.2)):toBe(base)
		expect(Steal.HoldSeconds(3, true, 2)):toBe(Steal.HoldSeconds(3, true) / 2)
	end)

	it("lengthens the laser lock with bonus seconds", function()
		local world = H.newWorld()
		local Lock = world:require("ServerScriptService.Services.PlotService.Lock")
		expect(Lock.Duration(0, 10)):toBe(Lock.Duration(0) + 10)
		expect(Lock.Duration(0, nil)):toBe(Lock.Duration(0))
	end)
end)
