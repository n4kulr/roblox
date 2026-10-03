local H = require("../harness/Harness")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

describe("Steal rules", function()
	local Steal, Keys, GameConfig, steal

	beforeEach(function()
		local world = H.newWorld()
		Steal = world:require("ReplicatedStorage.Rules.Steal")
		Keys = world:require("ReplicatedStorage.Config.Keys")
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		steal = GameConfig.Steal
	end)

	local function context(overrides: any?): any
		local base = {
			ThiefUserId = 1,
			VictimUserId = 2,
			HasThiefData = true,
			HasVictimData = true,
			ThiefCarrying = false,
			ActiveThiefUserId = 0,
			VictimPlaySeconds = steal.ShieldPlaySeconds,
			VictimLockedUntil = 0,
			Now = 1000,
			ThiefRate = 10,
			VictimRate = 10,
			ExpectedKeyId = "GlassTink",
			SlotKeyId = "GlassTink",
			Distance = 3,
		}
		for key, value in overrides or {} do
			base[key] = value
		end
		return base
	end

	describe("HoldSeconds", function()
		it("starts at the base hold for the first rarity", function()
			expect(Steal.HoldSeconds(1, false)):toBe(steal.BaseHoldSeconds)
		end)

		it("adds time per rarity step", function()
			expect(Steal.HoldSeconds(3, false)):toBe(steal.BaseHoldSeconds + steal.HoldSecondsPerRarity * 2)
			expect(Steal.HoldSeconds(7, false)):toBeGreaterThan(Steal.HoldSeconds(6, false))
		end)

		it("multiplies by the lesson multiplier while the lesson is pending", function()
			expect(Steal.HoldSeconds(3, true)):toBe(Steal.HoldSeconds(3, false) * steal.LessonHoldMultiplier)
		end)

		it("never goes below the base hold for bad indices", function()
			expect(Steal.HoldSeconds(0, false)):toBe(steal.BaseHoldSeconds)
		end)
	end)

	describe("RarityIndex", function()
		it("follows the rarity order", function()
			expect(Steal.RarityIndex("PlainClack")):toBe(1)
			expect(Steal.RarityIndex("GlassTink")):toBe(3)
			expect(Steal.RarityIndex("MeowKey")):toBe(#Keys.Rarities)
		end)

		it("falls back to 1 for unknown keys", function()
			expect(Steal.RarityIndex("Nope")):toBe(1)
		end)
	end)

	describe("IsShielded", function()
		it("shields players below the play time threshold", function()
			expect(Steal.IsShielded(0)):toBe(true)
			expect(Steal.IsShielded(steal.ShieldPlaySeconds - 1)):toBe(true)
		end)

		it("drops the shield at the threshold", function()
			expect(Steal.IsShielded(steal.ShieldPlaySeconds)):toBe(false)
		end)
	end)

	describe("PowerGapBlocked", function()
		it("allows similar and weaker thieves", function()
			expect(Steal.PowerGapBlocked(10, 10)):toBe(false)
			expect(Steal.PowerGapBlocked(1, 100)):toBe(false)
		end)

		it("allows exactly the ratio and blocks above it", function()
			expect(Steal.PowerGapBlocked(10 * steal.PowerGapRatio, 10)):toBe(false)
			expect(Steal.PowerGapBlocked(10 * steal.PowerGapRatio + 1, 10)):toBe(true)
		end)

		it("blocks a thief with income against a victim with none", function()
			expect(Steal.PowerGapBlocked(1, 0)):toBe(true)
		end)

		it("allows two players with no income", function()
			expect(Steal.PowerGapBlocked(0, 0)):toBe(false)
		end)
	end)

	describe("CanSteal", function()
		it("accepts a clean attempt", function()
			local ok, reason = Steal.CanSteal(context())
			expect(ok):toBe(true)
			expect(reason):toBe("")
		end)

		it("rejects stealing from yourself", function()
			local ok, reason = Steal.CanSteal(context({ VictimUserId = 1 }))
			expect(ok):toBe(false)
			expect(reason):toBe(Steal.Reasons.Self)
		end)

		it("rejects missing data on either side", function()
			expect((Steal.CanSteal(context({ HasThiefData = false })))):toBe(false)
			expect((Steal.CanSteal(context({ HasVictimData = false })))):toBe(false)
		end)

		it("rejects a thief who is already carrying", function()
			local ok, reason = Steal.CanSteal(context({ ThiefCarrying = true }))
			expect(ok):toBe(false)
			expect(reason):toBe("You're already carrying a key!")
		end)

		it("rejects a victim another thief is already stealing from", function()
			local ok, reason = Steal.CanSteal(context({ ActiveThiefUserId = 9 }))
			expect(ok):toBe(false)
			expect(reason):toBe("Someone is already stealing from them!")
			expect(reason):toBe(Steal.Reasons.Busy)
		end)

		it("allows the thief who holds the active steal", function()
			expect((Steal.CanSteal(context({ ActiveThiefUserId = 1 })))):toBe(true)
		end)

		it("rejects shielded victims", function()
			local ok, reason = Steal.CanSteal(context({ VictimPlaySeconds = 10 }))
			expect(ok):toBe(false)
			expect(reason):toBe("They're protected by a new-player shield!")
		end)

		it("rejects locked bases until the lock expires", function()
			local ok, reason = Steal.CanSteal(context({ VictimLockedUntil = 1001 }))
			expect(ok):toBe(false)
			expect(reason):toBe("Their base is locked!")
			expect((Steal.CanSteal(context({ VictimLockedUntil = 1000 })))):toBe(true)
		end)

		it("rejects a thief far stronger than the victim", function()
			local ok, reason = Steal.CanSteal(context({ ThiefRate = 10000, VictimRate = 10 }))
			expect(ok):toBe(false)
			expect(reason):toBe("They're too weak to rob!")
		end)

		it("rejects when the slot no longer holds the key", function()
			expect((Steal.CanSteal(context({ SlotKeyId = "" })))):toBe(false)
			expect((Steal.CanSteal(context({ SlotKeyId = "PlainClack" })))):toBe(false)
		end)

		it("rejects thieves outside the allowed distance", function()
			expect((Steal.CanSteal(context({ Distance = steal.PromptRange + 2 })))):toBe(true)
			local ok, reason = Steal.CanSteal(context({ Distance = steal.PromptRange + 2.5 }))
			expect(ok):toBe(false)
			expect(reason):toBe(Steal.Reasons.TooFar)
		end)
	end)
end)
