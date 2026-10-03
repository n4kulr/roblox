local H = require("../harness/Harness")

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

describe("Trade rules", function()
	local world, Trade, GameConfig, Keys

	beforeEach(function()
		world = H.newWorld()
		Trade = world:require("ReplicatedStorage.Rules.Trade")
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		Keys = world:require("ReplicatedStorage.Config.Keys")
	end)

	afterEach(function()
		world:destroy()
	end)

	describe("ValidateOffer", function()
		it("accepts counts from zero up to the owned amount", function()
			local inventory = { PlainClack = 3 }
			expect((Trade.ValidateOffer(inventory, {}, "PlainClack", 0))):toBe(true)
			expect((Trade.ValidateOffer(inventory, {}, "PlainClack", 3))):toBe(true)
		end)

		it("rejects more than owned, keys not owned and unknown keys", function()
			local inventory = { PlainClack = 3 }
			expect((Trade.ValidateOffer(inventory, {}, "PlainClack", 4))):toBe(false)
			expect((Trade.ValidateOffer(inventory, {}, "OfficeTap", 1))):toBe(false)
			expect((Trade.ValidateOffer(inventory, {}, "NopeKey", 1))):toBe(false)
			local _, reason = Trade.ValidateOffer(inventory, {}, "NopeKey", 1)
			expect(reason):toBe(Trade.Reasons.UnknownKey)
		end)

		it("rejects negative, fractional and non-finite counts", function()
			local inventory = { PlainClack = 3 }
			for _, count in { -1, 1.5, 0 / 0, math.huge } do
				expect((Trade.ValidateOffer(inventory, {}, "PlainClack", count))):toBe(false)
			end
		end)

		it("limits distinct keys but still lets existing ones change", function()
			local inventory = {}
			local offer = {}
			local added = 0
			for _, key in Keys.Catalog do
				if added < GameConfig.Trade.MaxDistinctKeys then
					inventory[key.Id] = 2
					offer[key.Id] = 1
					added += 1
				end
			end
			expect(added):toBe(GameConfig.Trade.MaxDistinctKeys)
			local extra
			for _, key in Keys.Catalog do
				if inventory[key.Id] == nil then
					extra = key.Id
					break
				end
			end
			inventory[extra] = 1
			local ok, reason = Trade.ValidateOffer(inventory, offer, extra, 1)
			expect(ok):toBe(false)
			expect(reason):toBe(Trade.Reasons.TooMany)
			expect((Trade.ValidateOffer(inventory, offer, next(offer), 2))):toBe(true)
		end)
	end)

	describe("CanExecute and Apply", function()
		it("requires both sides to still hold what they offered", function()
			local a = { PlainClack = 2 }
			local b = { OfficeTap = 1 }
			expect(Trade.CanExecute(a, { PlainClack = 2 }, b, { OfficeTap = 1 })):toBe(true)
			expect(Trade.CanExecute(a, { PlainClack = 3 }, b, { OfficeTap = 1 })):toBe(false)
			expect(Trade.CanExecute(a, { PlainClack = 2 }, b, { OfficeTap = 2 })):toBe(false)
			expect(Trade.CanExecute(a, { PlainClack = 1 }, b, { GlassTink = 1 })):toBe(false)
		end)

		it("refuses an empty trade", function()
			expect(Trade.CanExecute({ PlainClack = 1 }, {}, {}, {})):toBe(false)
		end)

		it("allows a one-sided gift", function()
			expect(Trade.CanExecute({ PlainClack = 1 }, { PlainClack = 1 }, {}, {})):toBe(true)
		end)

		it("swaps the keys and conserves every count", function()
			local a = { PlainClack = 3, GlassTink = 1 }
			local b = { OfficeTap = 2, PlainClack = 1 }
			local newA, newB = Trade.Apply(a, { PlainClack = 2, GlassTink = 1 }, b, { OfficeTap = 2 })
			expect(newA):toEqual({ PlainClack = 1, OfficeTap = 2 })
			expect(newB):toEqual({ PlainClack = 3, GlassTink = 1 })
			for _, keyId in { "PlainClack", "GlassTink", "OfficeTap" } do
				local before = (a[keyId] or 0) + (b[keyId] or 0)
				local after = (newA[keyId] or 0) + (newB[keyId] or 0)
				expect(after):toBe(before)
			end
		end)

		it("does not mutate its inputs", function()
			local a = { PlainClack = 1 }
			local b = { OfficeTap = 1 }
			Trade.Apply(a, { PlainClack = 1 }, b, { OfficeTap = 1 })
			expect(a):toEqual({ PlainClack = 1 })
			expect(b):toEqual({ OfficeTap = 1 })
		end)
	end)

	it("compares rarity by rank", function()
		expect(Trade.IsAtLeast("CrystalChime", "Epic")):toBe(true)
		expect(Trade.IsAtLeast("LavaKey", "Epic")):toBe(true)
		expect(Trade.IsAtLeast("PlainClack", "Epic")):toBe(false)
		expect(Trade.IsAtLeast("LavaKey", "Mythic")):toBe(true)
	end)
end)
