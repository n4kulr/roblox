local H = require("../harness/Harness")
local S = require("../support")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

local hour = 3600

describe("Daily.Status", function()
	local Daily, GameConfig
	local now = 1700000000

	beforeEach(function()
		local world = H.newWorld()
		Daily = world:require("ReplicatedStorage.Rules.Daily")
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
	end)

	it("lets a new player claim day 1", function()
		expect(Daily.Status({ Streak = 0, LastClaim = 0 }, now)):toEqual({
			CanClaim = true,
			Day = 1,
			SecondsLeft = 0,
			StreakBroken = false,
		})
	end)

	it("blocks claiming during the cooldown and counts down", function()
		local status = Daily.Status({ Streak = 1, LastClaim = now - 1000 }, now)
		expect(status.CanClaim):toBe(false)
		expect(status.SecondsLeft):toBe(GameConfig.DailyCooldownSeconds - 1000)
		expect(status.Day):toBe(2)
		expect(status.StreakBroken):toBe(false)
	end)

	it("allows the claim exactly when the cooldown ends", function()
		local status = Daily.Status({ Streak = 1, LastClaim = now - GameConfig.DailyCooldownSeconds }, now)
		expect(status.CanClaim):toBe(true)
		expect(status.SecondsLeft):toBe(0)
		expect(status.Day):toBe(2)
	end)

	it("continues the streak until the reset window", function()
		local status = Daily.Status({ Streak = 3, LastClaim = now - (GameConfig.DailyStreakResetSeconds - 1) }, now)
		expect(status.CanClaim):toBe(true)
		expect(status.Day):toBe(4)
		expect(status.StreakBroken):toBe(false)
	end)

	it("breaks the streak at the reset window", function()
		local status = Daily.Status({ Streak = 3, LastClaim = now - GameConfig.DailyStreakResetSeconds }, now)
		expect(status.CanClaim):toBe(true)
		expect(status.Day):toBe(1)
		expect(status.StreakBroken):toBe(true)
	end)

	it("wraps to day 1 after day 7 without breaking the streak", function()
		local status = Daily.Status({ Streak = 7, LastClaim = now - 21 * hour }, now)
		expect(status.CanClaim):toBe(true)
		expect(status.Day):toBe(1)
		expect(status.StreakBroken):toBe(false)
	end)

	it("tolerates malformed values", function()
		local status = Daily.Status({}, now)
		expect(status.CanClaim):toBe(true)
		expect(status.Day):toBe(1)
	end)
end)
