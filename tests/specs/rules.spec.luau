local H = require("../harness/Harness")
local S = require("../support")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

describe("Stats", function()
	local Stats, GameConfig, Keys, Upgrades
	beforeEach(function()
		local world = H.newWorld()
		Stats = world:require("ReplicatedStorage.Rules.Stats")
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		Keys = world:require("ReplicatedStorage.Config.Keys")
		Upgrades = world:require("ReplicatedStorage.Config.Upgrades")
	end)

	local function income(keyId: string): number
		return Keys.GetIncome(keyId)
	end

	local noUpgrades = { Luck = 0, Speed = 0, Slots = 0 }
	local allSlots = { Luck = 0, Speed = 0, Slots = 999 }

	describe("Slots", function()
		it("starts at the base slot count", function()
			expect(Stats.Slots(noUpgrades)):toBe(GameConfig.BaseSlots)
		end)

		it("adds the configured slots per Slots level", function()
			expect(Stats.Slots({ Luck = 0, Speed = 0, Slots = 1 })):toBe(
				math.min(GameConfig.BoardSlots, GameConfig.BaseSlots + Upgrades.ById.Slots.PerLevel)
			)
		end)

		it("clamps to the board size", function()
			expect(Stats.Slots({ Luck = 0, Speed = 0, Slots = Upgrades.ById.Slots.MaxLevel })):toBe(
				GameConfig.BoardSlots
			)
			expect(Stats.Slots({ Luck = 0, Speed = 0, Slots = 999 })):toBe(GameConfig.BoardSlots)
		end)

		it("reaches BoardSlots exactly at the Slots max level", function()
			local perLevel = Upgrades.ById.Slots.PerLevel
			local maxLevel = Upgrades.ById.Slots.MaxLevel
			expect(GameConfig.BaseSlots + maxLevel * perLevel >= GameConfig.BoardSlots):toBe(true)
			expect(Stats.Slots({ Luck = 0, Speed = 0, Slots = maxLevel })):toBe(GameConfig.BoardSlots)
		end)

		it("never goes below the base slot count", function()
			expect(Stats.Slots({ Luck = 0, Speed = 0, Slots = -50 })):toBe(GameConfig.BaseSlots)
		end)

		it("tolerates malformed level tables", function()
			expect(Stats.Slots(nil)):toBe(GameConfig.BaseSlots)
			expect(Stats.Slots("x")):toBe(GameConfig.BaseSlots)
			expect(Stats.Slots({ Slots = "3" })):toBe(GameConfig.BaseSlots)
		end)
	end)

	describe("Compute", function()
		it("scales income by 10% per Income level", function()
			local board = S.fill("PlainClack", 4)
			local base = Stats.Compute(board, noUpgrades)
			local boosted = Stats.Compute(board, { Luck = 0, Speed = 0, Slots = 0, Income = 5 })
			expect(boosted.IncomeMultiplier):toBeCloseTo(1.5, 1e-9)
			expect(boosted.Rate):toBe(math.floor(base.Rate * 1.5))
		end)

		it("returns base stats for an empty board", function()
			local stats = Stats.Compute(S.fill("", 30), noUpgrades)
			expect(stats.Luck):toBe(GameConfig.Luck)
			expect(stats.RollsPerSecond):toBe(GameConfig.RollsPerSecond)
			expect(stats.Slots):toBe(GameConfig.BaseSlots)
			expect(stats.IncomeMultiplier):toBe(1)
			expect(stats.Rate):toBe(0)
		end)

		it("sums key income into Rate", function()
			local board = S.board("PlainClack", "PlainClack", "CreamyThock", "GlassTink")
			expect(Stats.Compute(board, allSlots).Rate):toBe(
				income("PlainClack") * 2 + income("CreamyThock") + income("GlassTink")
			)
		end)

		it("scales luck by level and by Luck perks", function()
			local levels = { Luck = 5, Speed = 0, Slots = 0 }
			expect(Stats.Compute({}, levels).Luck):toBeCloseTo(1.5, 1e-9)
			local withClover = Stats.Compute(S.board("CloverCap"), levels)
			expect(withClover.Luck):toBeCloseTo(1.5 * 1.1, 1e-9)
			local withBoth = Stats.Compute(S.board("CloverCap", "FourLeafArtisan"), levels)
			expect(withBoth.Luck):toBeCloseTo(1.5 * (1 + 0.1 + 0.5), 1e-9)
		end)

		it("scales speed by level and Speed perks", function()
			local perLevel = Upgrades.ById.Speed.PerLevel
			expect(Stats.Compute({}, { Luck = 0, Speed = 4, Slots = 0 }).RollsPerSecond):toBeCloseTo(
				GameConfig.RollsPerSecond + 4 * perLevel,
				1e-9
			)
			expect(Stats.Compute(S.board("TurboSwitch"), noUpgrades).RollsPerSecond):toBeCloseTo(
				GameConfig.RollsPerSecond * 1.15,
				1e-9
			)
		end)

		it("caps speed at MaxRollsPerSecond", function()
			local levels = { Luck = 0, Speed = 6, Slots = Upgrades.ById.Slots.MaxLevel }
			local uncapped = GameConfig.RollsPerSecond + 6 * Upgrades.ById.Speed.PerLevel
			expect(uncapped < GameConfig.MaxRollsPerSecond):toBe(true)
			expect(Stats.Compute({}, levels).RollsPerSecond):toBe(uncapped)
			local board = S.board("TurboSwitch", "TurboSwitch", "TurboSwitch", "TurboSwitch")
			expect(Stats.Compute(board, levels).RollsPerSecond):toBe(GameConfig.MaxRollsPerSecond)
			local maxed =
				{ Luck = 0, Speed = Upgrades.ById.Speed.MaxLevel, Slots = Upgrades.ById.Slots.MaxLevel }
			expect(Stats.Compute(S.fill("TurboSwitch", 30), maxed).RollsPerSecond):toBe(
				GameConfig.MaxRollsPerSecond
			)
		end)

		it("applies the income perk to the whole board rate and floors it", function()
			local board = S.board("GoldPlate", "PlainClack", "CreamyThock")
			local stats = Stats.Compute(board, noUpgrades)
			expect(stats.IncomeMultiplier):toBeCloseTo(1.25, 1e-9)
			local sum = income("GoldPlate") + income("PlainClack") + income("CreamyThock")
			expect(stats.Rate):toBe(math.floor(sum * 1.25))
			local odd = Stats.Compute(S.board("GoldPlate", "PlainClack"), noUpgrades)
			expect(odd.Rate):toBe(math.floor((income("GoldPlate") + income("PlainClack")) * 1.25))
		end)

		it("stacks multiple income perks additively", function()
			local stats = Stats.Compute(S.board("GoldPlate", "GoldPlate"), noUpgrades)
			expect(stats.IncomeMultiplier):toBeCloseTo(1.5, 1e-9)
			expect(stats.Rate):toBe(math.floor(income("GoldPlate") * 2 * 1.5))
		end)

		it("ignores keys on locked slots, including their perks and income", function()
			local board = S.fill("", 30)
			board[GameConfig.BaseSlots + 1] = "CloverCap"
			board[GameConfig.BaseSlots + 2] = "GoldPlate"
			local locked = Stats.Compute(board, noUpgrades)
			expect(locked.Luck):toBe(1)
			expect(locked.IncomeMultiplier):toBe(1)
			expect(locked.Rate):toBe(0)
			local unlocked = Stats.Compute(board, { Luck = 0, Speed = 0, Slots = 2 })
			expect(unlocked.Luck):toBeCloseTo(1.1, 1e-9)
			expect(unlocked.IncomeMultiplier):toBeCloseTo(1.25, 1e-9)
			expect(unlocked.Rate):toBe(math.floor((income("CloverCap") + income("GoldPlate")) * 1.25))
		end)

		it("counts the last unlocked slot but not the one after it", function()
			local board = S.fill("", 30)
			board[GameConfig.BaseSlots] = "PlainClack"
			board[GameConfig.BaseSlots + 1] = "PlainClack"
			expect(Stats.Compute(board, noUpgrades).Rate):toBe(income("PlainClack"))
		end)

		it("ignores empty, unknown and non-string board entries", function()
			local board: any = { "", "Bogus", 7, "PlainClack" }
			expect(Stats.Compute(board, allSlots).Rate):toBe(1)
		end)
	end)
end)

describe("Upgrades.Cost", function()
	local Upgrades
	beforeEach(function()
		Upgrades = H.newWorld():require("ReplicatedStorage.Config.Upgrades")
	end)

	it("starts at the base cost", function()
		for _, upgrade in Upgrades.List do
			expect(Upgrades.Cost(upgrade, 0)):toBe(upgrade.BaseCost)
		end
	end)

	it("grows geometrically and floors", function()
		local luck = Upgrades.ById.Luck
		for level = 0, luck.MaxLevel - 1 do
			expect(Upgrades.Cost(luck, level)):toBe(math.floor(luck.BaseCost * luck.Growth ^ level))
		end
		expect(Upgrades.Cost(Upgrades.ById.Slots, 3)):toBe(
			math.floor(Upgrades.ById.Slots.BaseCost * Upgrades.ById.Slots.Growth ^ 3)
		)
	end)

	it("is strictly increasing up to the max level", function()
		for _, upgrade in Upgrades.List do
			local previous = 0
			for level = 0, upgrade.MaxLevel - 1 do
				local cost = Upgrades.Cost(upgrade, level)
				expect(cost):toBeGreaterThan(previous)
				previous = cost
			end
		end
	end)

	it("returns nil at and beyond the max level", function()
		for _, upgrade in Upgrades.List do
			expect(Upgrades.Cost(upgrade, upgrade.MaxLevel)):toBeNil()
			expect(Upgrades.Cost(upgrade, upgrade.MaxLevel + 5)):toBeNil()
			expect(Upgrades.Cost(upgrade, upgrade.MaxLevel - 1)).never:toBeNil()
		end
	end)
end)
