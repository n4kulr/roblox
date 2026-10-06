local H = require("../harness/Harness")
local S = require("../support")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

describe("Income.Earned", function()
	local Income

	beforeEach(function()
		local world = H.newWorld()
		Income = world:require("ReplicatedStorage.Rules.Income")
	end)

	it("pays rate times seconds without a potion", function()
		expect(Income.Earned(7, 100, 160, 0, 2)):toBe(420)
	end)

	it("doubles the whole interval when the potion outlasts it", function()
		expect(Income.Earned(7, 100, 160, 1000, 2)):toBe(840)
	end)

	it("splits at the moment the potion ends mid-interval", function()
		expect(Income.Earned(5, 100, 200, 140, 2)):toBe(5 * (40 * 2 + 60))
	end)

	it("ignores a potion that ended before the interval", function()
		expect(Income.Earned(5, 100, 200, 100, 2)):toBe(500)
		expect(Income.Earned(5, 100, 200, 50, 2)):toBe(500)
	end)

	it("treats a potion ending exactly at the end as fully active", function()
		expect(Income.Earned(5, 100, 200, 200, 2)):toBe(1000)
	end)

	it("returns 0 for empty, reversed or zero-rate intervals", function()
		expect(Income.Earned(5, 100, 100, 500, 2)):toBe(0)
		expect(Income.Earned(5, 200, 100, 500, 2)):toBe(0)
		expect(Income.Earned(0, 100, 200, 500, 2)):toBe(0)
	end)

	it("floors fractional results", function()
		expect(Income.Earned(3, 0, 1, 0, 1.5)):toBe(3)
		expect(Income.Earned(3, 0, 1, 1, 1.5)):toBe(4)
	end)

	it("is additive across any split point", function()
		local whole = Income.Earned(9, 100, 200, 150, 2)
		for split = 100, 200, 10 do
			local parts = Income.Earned(9, 100, split, 150, 2) + Income.Earned(9, split, 200, 150, 2)
			expect(parts):toBe(whole)
		end
	end)
end)

describe("KeyboardService income with potions", function()
	local world, Keyboard, GameConfig

	beforeEach(function()
		world = H.newWorld({ Time = 1700000000 })
		Keyboard = world:boot({ "KeyboardService" }).KeyboardService
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
	end)

	local function join(overrides: any?, fireLoaded: boolean?)
		return world:join(nil, overrides, fireLoaded == true)
	end

	it("settles a potion that expires between settles exactly", function()
		local player, data = join({
			Board = S.fill("PlainClack", 3),
			IncomeAt = world.now - 100,
			Boosts = { ClicksUntil = world.now - 40 },
		})
		Keyboard:Settle(player)
		expect(data.Cash):toBe(3 * (60 * 2 + 40))
		expect(data.IncomeAt):toBe(world.now)
	end)

	it("pays double for the whole interval while the potion lasts", function()
		local player, data = join({
			Board = S.fill("PlainClack", 3),
			IncomeAt = world.now - 100,
			Boosts = { ClicksUntil = world.now + 500 },
		})
		Keyboard:Settle(player)
		expect(data.Cash):toBe(600)
	end)

	it("gives the same total whether or not a settle happens mid-potion", function()
		local playerA, dataA = join({
			Board = S.fill("PlainClack", 3),
			IncomeAt = world.now,
			Boosts = { ClicksUntil = world.now + 30 },
		})
		local playerB, dataB = join({
			Board = S.fill("PlainClack", 3),
			IncomeAt = world.now,
			Boosts = { ClicksUntil = world.now + 30 },
		})
		world:advance(10)
		Keyboard:Settle(playerA)
		world:advance(50)
		Keyboard:Settle(playerA)
		Keyboard:Settle(playerB)
		expect(dataA.Cash):toBe(dataB.Cash)
		expect(dataA.Cash):toBe(3 * (30 * 2 + 30))
	end)

	it("settles before the board changes using the active potion", function()
		local player, data = join({
			Board = S.fill("PlainClack", 3),
			Inventory = { PlainClack = 1 },
			IncomeAt = world.now - 10,
			Boosts = { ClicksUntil = world.now + 500 },
		})
		world:invoke("ClearSlot", player, 1)
		expect(data.Cash):toBe(60)
	end)

	it("pays offline time at the offline rate and only counts potion time while it was active", function()
		local _, data = join({
			Board = S.fill("PlainClack", 4),
			IncomeAt = world.now - 1000,
			Boosts = { ClicksUntil = world.now - 500 },
		}, true)
		expect(data.Cash):toBe(math.floor(4 * (500 * 2 + 500) * GameConfig.OfflineRate))
	end)

	it("does not count a potion that expired before the player left", function()
		local _, data = join({
			Board = S.fill("PlainClack", 4),
			IncomeAt = world.now - 1000,
			Boosts = { ClicksUntil = world.now - 2000 },
		}, true)
		expect(data.Cash):toBe(math.floor(4 * 1000 * GameConfig.OfflineRate))
	end)

	it("caps offline time and counts potion seconds inside the capped window only", function()
		local incomeAt = world.now - 10000
		local _, data = join({
			Board = S.fill("PlainClack", 4),
			IncomeAt = incomeAt,
			Boosts = { ClicksUntil = incomeAt + 1000 },
		}, true)
		local expected = math.floor(4 * (6200 + 1000 * 2) * GameConfig.OfflineRate)
		expect(data.Cash):toBe(expected)
	end)

	it("a potion running through the whole offline window doubles it", function()
		local _, data = join({
			Board = S.fill("PlainClack", 4),
			IncomeAt = world.now - 1000,
			Boosts = { ClicksUntil = world.now + 600 },
		}, true)
		expect(data.Cash):toBe(math.floor(4 * 1000 * 2 * GameConfig.OfflineRate))
	end)

	it("settles with the potion split when the player is released", function()
		local player, data = join({
			Board = S.fill("PlainClack", 3),
			IncomeAt = world.now - 100,
			Boosts = { ClicksUntil = world.now - 40 },
		})
		world:removePlayer(player)
		expect(data.Cash):toBe(3 * (60 * 2 + 40))
		expect(data.IncomeAt):toBe(world.now)
	end)

	it("applies owned pass multipliers to the rate", function()
		world:destroy()
		world = H.newWorld({ Time = 1700000000, AssetIds = { DoubleClicks = 102, Vip = 103 } })
		local services = world:boot({ "KeyboardService", "PassService" })
		local player, data = join({ Board = S.fill("PlainClack", GameConfig.BaseSlots), IncomeAt = world.now - 10 })
		world:own(player, 102)
		world.Data.Service.PlayerLoaded:Fire(player, data)
		world:flush()
		expect(services.PassService:Owns(player, "DoubleClicks")):toBe(true)
		data.Cash = 0
		data.IncomeAt = world.now - 10
		services.KeyboardService:Settle(player)
		expect(data.Cash):toBe(GameConfig.BaseSlots * 20)
		expect(services.KeyboardService:GetRate(player)):toBe(GameConfig.BaseSlots * 2)
	end)
end)
