local H = require("../harness/Harness")
local S = require("../support")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

describe("UpgradeService", function()
	local world, Upgrades, Stats

	beforeEach(function()
		world = H.newWorld()
		world:boot({ "KeyboardService", "UpgradeService" })
		Upgrades = world:require("ReplicatedStorage.Config.Upgrades")
		Stats = world:require("ReplicatedStorage.Rules.Stats")
	end)

	local function buy(player: any, id: any, amount: any)
		if amount == nil then
			amount = 1
		end
		return world:invoke("BuyUpgrade", player, id, amount)
	end

	it("charges the level cost and raises the level", function()
		local player, data = world:join(nil, { Cash = 1000 })
		expect(buy(player, "Luck")):toBe(true)
		expect(data.Cash):toBe(1000 - Upgrades.Cost(Upgrades.ById.Luck, 0))
		expect(data.Upgrades.Luck):toBe(1)
		expect(buy(player, "Luck")):toBe(true)
		expect(data.Cash):toBe(1000 - 100 - Upgrades.Cost(Upgrades.ById.Luck, 1))
		expect(data.Upgrades.Luck):toBe(2)
	end)

	it("only touches the purchased upgrade", function()
		local player, data = world:join(nil, { Cash = 10000, Upgrades = { Speed = 2 } })
		buy(player, "Slots")
		expect(data.Upgrades):toEqual({ Luck = 0, Speed = 2, Slots = 1, Income = 0, Walls = 0, LockTime = 0, Golden = 0 })
	end)

	it("accepts an exact-cost purchase and rejects one coin short", function()
		local player, data = world:join(nil, { Cash = 99 })
		expect(buy(player, "Luck")):toBe(false)
		expect(data.Cash):toBe(99)
		expect(data.Upgrades.Luck):toBe(0)
		local player2, data2 = world:join(nil, { Cash = 100 })
		expect(buy(player2, "Luck")):toBe(true)
		expect(data2.Cash):toBe(0)
	end)

	it("rejects purchases at the max level", function()
		local max = Upgrades.ById.Speed.MaxLevel
		local player, data = world:join(nil, { Cash = 1e12, Upgrades = { Speed = max } })
		expect(buy(player, "Speed")):toBe(false)
		expect(data.Upgrades.Speed):toBe(max)
		expect(data.Cash):toBe(1e12)
	end)

	it("buys up to the max level then stops", function()
		local player, data = world:join(nil, { Cash = 1e12 })
		local bought = 0
		for _ = 1, Upgrades.ById.Luck.MaxLevel + 10 do
			if buy(player, "Luck") then
				bought += 1
			end
		end
		expect(bought):toBe(Upgrades.ById.Luck.MaxLevel)
		expect(data.Upgrades.Luck):toBe(Upgrades.ById.Luck.MaxLevel)
	end)

	it("rejects unknown ids and non-string input", function()
		local player, data = world:join(nil, { Cash = 1e6 })
		local before = S.snapshot(data)
		for _, id in { "Bogus", "", "luck", 1, true, {} } do
			expect(buy(player, id)):toBe(false)
		end
		expect(buy(player, nil)):toBe(false)
		expect(data):toEqual(before)
	end)

	it("fails without player data", function()
		expect(buy(world:newPlayer(), "Luck")):toBe(false)
	end)

	it("settles earned income before checking the price", function()
		local player, data = world:join(nil, {
			Cash = 0,
			Board = S.fill("PlainClack", 5),
			IncomeAt = world.now - 10,
		}, false)
		expect(buy(player, "Luck")):toBe(false)
		expect(data.Cash):toBe(50)
		world:setTime(world.now + 10)
		expect(buy(player, "Luck")):toBe(true)
		expect(data.Cash):toBe(0)
	end)

	it("unlocks slots and announces a board change when buying Slots", function()
		local player, data = world:join(nil, { Cash = 1e6 })
		local changed = 0
		world.registry.KeyboardService.BoardChanged:Connect(function()
			changed += 1
		end)
		expect(Stats.Slots(data.Upgrades)):toBe(10)
		buy(player, "Slots")
		expect(Stats.Slots(data.Upgrades)):toBe(12)
		expect(changed):toBe(1)
		buy(player, "Luck")
		expect(changed):toBe(1)
	end)

	it("advances the tutorial to step 3 once", function()
		local player, data = world:join(nil, { Cash = 1e6, Tutorial = 2 })
		buy(player, "Luck")
		expect(data.Tutorial):toBe(3)
		local player2, data2 = world:join(nil, { Cash = 1e6, Tutorial = 0 })
		buy(player2, "Luck")
		expect(data2.Tutorial):toBe(3)
		local player3, data3 = world:join(nil, { Cash = 1e6, Tutorial = 5 })
		buy(player3, "Luck")
		expect(data3.Tutorial):toBe(5)
	end)

	it("does not advance the tutorial on a failed purchase", function()
		local player, data = world:join(nil, { Cash = 0, Tutorial = 2 })
		buy(player, "Luck")
		expect(data.Tutorial):toBe(2)
	end)

	it("clears its packet handler on Destroy", function()
		expect(world:packets().BuyUpgrade.OnServerInvoke).never:toBeNil()
		world:destroy()
		expect(world:packets().BuyUpgrade.OnServerInvoke):toBeNil()
	end)
end)
