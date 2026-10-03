local roblox = require("@lune/roblox")
local H = require("../harness/Harness")

local Vector3, Enum = roblox.Vector3, roblox.Enum
local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

describe("Keyfall rules", function()
	local Keyfall, GameConfig, config, world

	beforeEach(function()
		world = H.newWorld()
		Keyfall = world:require("ReplicatedStorage.Rules.Keyfall")
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		config = GameConfig.Keyfall
	end)

	describe("RandomPointInDisc", function()
		it("stays inside the disc and keeps the height", function()
			local rng = world.Random.new(7)
			local center = Vector3.new(10, 4, -20)
			for _ = 1, 500 do
				local point = Keyfall.RandomPointInDisc(rng, center, 40)
				local dx, dz = point.X - center.X, point.Z - center.Z
				expect(math.sqrt(dx * dx + dz * dz)):toBeLessThan(40.0001)
				expect(point.Y):toBe(4)
			end
		end)

		it("spreads uniformly rather than clustering at the centre", function()
			local rng = world.Random.new(11)
			local inner = 0
			local total = 4000
			for _ = 1, total do
				local point = Keyfall.RandomPointInDisc(rng, Vector3.new(0, 0, 0), 40)
				if math.sqrt(point.X * point.X + point.Z * point.Z) < 20 then
					inner += 1
				end
			end
			expect(inner / total):toBeCloseTo(0.25, 0.04)
		end)

		it("reaches every quadrant", function()
			local rng = world.Random.new(3)
			local seen: { [string]: boolean } = {}
			for _ = 1, 200 do
				local point = Keyfall.RandomPointInDisc(rng, Vector3.new(0, 0, 0), 10)
				seen[`{point.X > 0}{point.Z > 0}`] = true
			end
			expect(seen["truetrue"] and seen["truefalse"] and seen["falsetrue"] and seen["falsefalse"]):toBe(true)
		end)
	end)

	describe("CanPickup", function()
		local function state(overrides: any?): any
			local base = {
				CarryCount = 0,
				CarryingStolen = false,
				IsLanded = true,
				IsReady = true,
				Distance = 1,
			}
			for key, value in overrides or {} do
				base[key] = value
			end
			return base
		end

		it("allows a pickup in range", function()
			expect(Keyfall.CanPickup(state())):toBe(true)
			expect(Keyfall.CanPickup(state({ Distance = config.PickupRange }))):toBe(true)
		end)

		it("refuses out of range", function()
			expect(Keyfall.CanPickup(state({ Distance = config.PickupRange + 0.1 }))):toBe(false)
		end)

		it("refuses at the carry limit", function()
			expect(Keyfall.CanPickup(state({ CarryCount = config.CarryLimit - 1 }))):toBe(true)
			expect(Keyfall.CanPickup(state({ CarryCount = config.CarryLimit }))):toBe(false)
		end)

		it("refuses while carrying a stolen key", function()
			expect(Keyfall.CanPickup(state({ CarryingStolen = true }))):toBe(false)
		end)

		it("refuses caps that are still falling or not yet ready", function()
			expect(Keyfall.CanPickup(state({ IsLanded = false }))):toBe(false)
			expect(Keyfall.CanPickup(state({ IsReady = false }))):toBe(false)
		end)
	end)

	describe("CarrySpeed", function()
		it("slows per carried cap", function()
			local normal = GameConfig.Steal.NormalWalkSpeed
			expect(Keyfall.CarrySpeed(0)):toBe(normal)
			expect(Keyfall.CarrySpeed(1)):toBe(normal - config.CarrySlowPerCap)
			expect(Keyfall.CarrySpeed(3)):toBe(normal - config.CarrySlowPerCap * 3)
		end)

		it("never stops the player completely", function()
			expect(Keyfall.CarrySpeed(1000)):toBeGreaterThan(0)
			expect(Keyfall.CarrySpeed(-5)):toBe(GameConfig.Steal.NormalWalkSpeed)
		end)
	end)

	describe("CanKnock", function()
		local function context(overrides: any?): any
			local base = {
				CallerUserId = 1,
				TargetUserId = 2,
				Distance = 3,
				TargetCarryCount = 1,
				Now = 100,
				LastKnockAt = nil,
			}
			for key, value in overrides or {} do
				base[key] = value
			end
			return base
		end

		it("allows a knock in range on a carrier", function()
			local ok, reason = Keyfall.CanKnock(context())
			expect(ok):toBe(true)
			expect(reason):toBe("")
		end)

		it("refuses knocking yourself", function()
			local ok, reason = Keyfall.CanKnock(context({ TargetUserId = 1 }))
			expect(ok):toBe(false)
			expect(reason):toBe(Keyfall.Reasons.Self)
		end)

		it("refuses out of range", function()
			expect(Keyfall.CanKnock(context({ Distance = config.KnockRange }))):toBe(true)
			local ok, reason = Keyfall.CanKnock(context({ Distance = config.KnockRange + 0.1 }))
			expect(ok):toBe(false)
			expect(reason):toBe(Keyfall.Reasons.TooFar)
		end)

		it("refuses targets that carry nothing", function()
			local ok, reason = Keyfall.CanKnock(context({ TargetCarryCount = 0 }))
			expect(ok):toBe(false)
			expect(reason):toBe(Keyfall.Reasons.Empty)
		end)

		it("enforces the cooldown", function()
			local ok, reason = Keyfall.CanKnock(context({ LastKnockAt = 100 - config.KnockCooldown + 0.1 }))
			expect(ok):toBe(false)
			expect(reason):toBe(Keyfall.Reasons.Cooldown)
			expect(Keyfall.CanKnock(context({ LastKnockAt = 100 - config.KnockCooldown }))):toBe(true)
		end)
	end)

	describe("NextSpacebarDelay", function()
		it("stays inside the configured window", function()
			local rng = world.Random.new(5)
			local lowest, highest = math.huge, 0
			for _ = 1, 500 do
				local delay = Keyfall.NextSpacebarDelay(rng)
				lowest = math.min(lowest, delay)
				highest = math.max(highest, delay)
				expect(delay >= config.GoldenSpacebarMinSeconds and delay <= config.GoldenSpacebarMaxSeconds):toBe(true)
			end
			expect(highest - lowest):toBeGreaterThan(100)
		end)
	end)
end)
