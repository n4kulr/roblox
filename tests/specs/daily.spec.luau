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

describe("DailyService", function()
	local world, services, DailyRewards, Keys, player, data

	beforeEach(function()
		world = H.newWorld({ Time = 1700000000 })
		services = world:boot({ "KeyboardService", "DailyService" })
		DailyRewards = world:require("ReplicatedStorage.Config.DailyRewards")
		Keys = world:require("ReplicatedStorage.Config.Keys")
		player, data = world:join(nil, { Settings = { AutoPlace = false } })
	end)

	local function claim(): number
		return world:invoke("ClaimDaily", player)
	end

	local function nextDay()
		world:advance(21 * hour)
	end

	local function keysOfRarity(rarity: string): number
		local total = 0
		for keyId, count in S.totals(data) do
			if Keys.ById[keyId].Rarity == rarity then
				total += count
			end
		end
		return total
	end

	it("grants day 1 Clicks and records the claim", function()
		local before = data.Cash
		expect(claim()):toBe(1)
		expect(data.Cash):toBe(before + 500)
		expect(data.Daily):toEqual({ Streak = 1, LastClaim = world.now })
	end)

	it("rejects a second claim inside the cooldown", function()
		expect(claim()):toBe(1)
		local snapshot = S.snapshot(data)
		expect(claim()):toBe(0)
		world:advance(10 * hour)
		expect(claim()):toBe(0)
		expect(data.Cash):toBe(snapshot.Cash)
		expect(data.Daily):toEqual(snapshot.Daily)
		expect(data.Boosts):toEqual(snapshot.Boosts)
		expect(data.Inventory):toEqual(snapshot.Inventory)
	end)

	it("walks the whole week granting each reward kind", function()
		expect(claim()):toBe(1)
		expect(data.Cash):toBe(500)

		nextDay()
		expect(claim()):toBe(2)
		expect(data.Boosts.LuckUntil):toBe(world.now + 600)

		nextDay()
		expect(claim()):toBe(3)
		expect(data.Cash):toBe(500 + 2500)

		nextDay()
		expect(claim()):toBe(4)
		expect(keysOfRarity("Rare")):toBe(1)

		nextDay()
		expect(claim()):toBe(5)
		expect(data.Boosts.ClicksUntil):toBe(world.now + 1800)

		nextDay()
		expect(claim()):toBe(6)
		expect(data.Cash):toBe(500 + 2500 + 15000)

		nextDay()
		expect(claim()):toBe(7)
		expect(keysOfRarity("Epic")):toBe(1)
		expect(data.Daily.Streak):toBe(7)
	end)

	it("counts claimed keys as discovered", function()
		data.Daily = { Streak = 3, LastClaim = world.now - 21 * hour }
		expect(claim()):toBe(4)
		local discovered = 0
		for keyId, count in data.Discovered do
			expect(Keys.ById[keyId].Rarity):toBe("Rare")
			discovered += count
		end
		expect(discovered):toBe(1)
	end)

	it("wraps to day 1 after day 7", function()
		data.Daily = { Streak = 7, LastClaim = world.now - 21 * hour }
		expect(claim()):toBe(1)
		expect(data.Daily.Streak):toBe(1)
	end)

	it("restarts at day 1 after missing the streak window", function()
		data.Daily = { Streak = 5, LastClaim = world.now - 3 * 86400 }
		expect(claim()):toBe(1)
		expect(data.Daily.Streak):toBe(1)
	end)

	it("stacks a luck potion onto an active one and respects the cap", function()
		data.Daily = { Streak = 1, LastClaim = world.now - 21 * hour }
		data.Boosts.LuckUntil = world.now + 300
		expect(claim()):toBe(2)
		expect(data.Boosts.LuckUntil):toBe(world.now + 900)
		data.Daily = { Streak = 1, LastClaim = world.now - 21 * hour }
		data.Boosts.LuckUntil = world.now + 7000
		expect(claim()):toBe(2)
		expect(data.Boosts.LuckUntil):toBe(world.now + 7200)
	end)

	it("settles income before a clicks potion starts", function()
		data.Board = S.fill("PlainClack", 3)
		data.IncomeAt = world.now - 10
		data.Daily = { Streak = 4, LastClaim = world.now - 21 * hour }
		expect(claim()):toBe(5)
		expect(data.Cash):toBe(30)
		expect(data.IncomeAt):toBe(world.now)
	end)

	it("returns 0 for a player without data", function()
		local stranger = world:newPlayer()
		expect(world:invoke("ClaimDaily", stranger)):toBe(0)
	end)

	it("defines seven rewards matched by the service", function()
		expect(#DailyRewards.Rewards):toBe(7)
	end)

	it("clears its packet handler on Destroy", function()
		services.DailyService:Destroy()
		expect(world:packets().ClaimDaily.OnServerInvoke):toBeNil()
	end)
end)

describe("TimeFormat", function()
	local TimeFormat

	beforeEach(function()
		TimeFormat = H.newWorld():require("ReplicatedStorage.Utils.TimeFormat")
	end)

	it("formats boost clocks as minutes and seconds", function()
		expect(TimeFormat.Clock(751)):toBe("12:31")
		expect(TimeFormat.Clock(245)):toBe("4:05")
		expect(TimeFormat.Clock(0)):toBe("0:00")
		expect(TimeFormat.Clock(-5)):toBe("0:00")
	end)

	it("formats daily countdowns as hours and minutes", function()
		expect(TimeFormat.Hours(3 * 3600 + 12 * 60)):toBe("3h 12m")
		expect(TimeFormat.Hours(3 * 3600 + 12 * 60 - 30)):toBe("3h 12m")
		expect(TimeFormat.Hours(59 * 60)):toBe("59m")
		expect(TimeFormat.Hours(0)):toBe("0m")
	end)
end)
