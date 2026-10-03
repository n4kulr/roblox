local H = require("../harness/Harness")
local S = require("../support")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

local assetIds = {
	DoubleLuck = 101,
	DoubleClicks = 102,
	Vip = 103,
}

describe("Boosts.Modifiers", function()
	local Boosts, GameConfig
	local now = 1700000000

	beforeEach(function()
		local world = H.newWorld()
		Boosts = world:require("ReplicatedStorage.Rules.Boosts")
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
	end)

	it("is neutral with nothing active", function()
		expect(Boosts.Modifiers({ LuckUntil = 0, ClicksUntil = 0 }, {}, now, 0)):toEqual({ Luck = 1, Income = 1 })
	end)

	it("covers every combination of passes, potions and server luck", function()
		local cfg = GameConfig.Boosts
		for mask = 0, 63 do
			local doubleLuck = mask % 2 >= 1
			local doubleClicks = mask % 4 >= 2
			local vip = mask % 8 >= 4
			local luckPotion = mask % 16 >= 8
			local clicksPotion = mask % 32 >= 16
			local serverLuck = mask % 64 >= 32
			local result = Boosts.Modifiers(
				{ LuckUntil = if luckPotion then now + 5 else now - 5, ClicksUntil = if clicksPotion then now + 5 else 0 },
				{ DoubleLuck = doubleLuck, DoubleClicks = doubleClicks, Vip = vip },
				now,
				if serverLuck then now + 5 else 0
			)
			local luck = (if doubleLuck then cfg.DoubleLuckPassMultiplier else 1)
				* (if luckPotion then cfg.PotionMultiplier else 1)
				* (if serverLuck then cfg.ServerLuckMultiplier else 1)
			local income = (if doubleClicks then cfg.DoubleClicksPassMultiplier else 1)
				* (if vip then cfg.VipIncomeMultiplier else 1)
				* (if clicksPotion then cfg.PotionMultiplier else 1)
			expect(result.Luck):toBeCloseTo(luck)
			expect(result.Income):toBeCloseTo(income)
		end
	end)

	it("treats a boost ending exactly now as expired", function()
		local result = Boosts.Modifiers({ LuckUntil = now, ClicksUntil = now }, {}, now, now)
		expect(result):toEqual({ Luck = 1, Income = 1 })
	end)

	it("ignores false passes", function()
		local result = Boosts.Modifiers({ LuckUntil = 0, ClicksUntil = 0 }, { DoubleLuck = false }, now, 0)
		expect(result.Luck):toBe(1)
	end)

	it("splits pass income from the clicks potion", function()
		expect(Boosts.PassIncome({ DoubleClicks = true, Vip = true })):toBeCloseTo(2.2)
		expect(Boosts.PassIncome({})):toBe(1)
	end)
end)

describe("Boosts.Extend", function()
	local Boosts, GameConfig
	local now = 1700000000

	beforeEach(function()
		local world = H.newWorld()
		Boosts = world:require("ReplicatedStorage.Rules.Boosts")
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
	end)

	it("starts from now when nothing is active", function()
		expect(Boosts.Extend(0, now, 900)):toBe(now + 900)
		expect(Boosts.Extend(now - 100, now, 900)):toBe(now + 900)
	end)

	it("stacks onto an active boost", function()
		expect(Boosts.Extend(now + 300, now, 900)):toBe(now + 1200)
	end)

	it("caps at the maximum stack", function()
		local cap = now + GameConfig.Boosts.MaxStackSeconds
		expect(Boosts.Extend(now + 7000, now, 900)):toBe(cap)
		expect(Boosts.Extend(cap, now, 900)):toBe(cap)
		expect(Boosts.Extend(0, now, 999999)):toBe(cap)
	end)

	it("reports remaining time without going negative", function()
		expect(Boosts.Remaining(now + 30, now)):toBe(30)
		expect(Boosts.Remaining(now - 30, now)):toBe(0)
	end)
end)

describe("PassService", function()
	local world, services, PassService

	local function setup()
		world = H.newWorld({ AssetIds = assetIds })
		services = world:boot({ "KeyboardService", "PassService" })
		PassService = services.PassService
	end

	beforeEach(setup)

	it("marks owned passes as player attributes when data loads", function()
		local player = world:newPlayer()
		world:own(player, 101)
		world:own(player, 103)
		world.Data:Load(player)
		world:flush()
		expect(PassService:Owns(player, "DoubleLuck")):toBe(true)
		expect(PassService:Owns(player, "Vip")):toBe(true)
		expect(PassService:Owns(player, "DoubleClicks")):toBe(false)
		expect(player:GetAttribute("Pass_DoubleLuck")):toBe(true)
		expect(player:GetAttribute("Pass_DoubleClicks")):toBeNil()
		expect(PassService:GetPasses(player)):toEqual({ DoubleLuck = true, Vip = true })
	end)

	it("does not check passes with asset id 0", function()
		world:destroy()
		world = H.newWorld({ AssetIds = { DoubleLuck = 101 } })
		services = world:boot({ "KeyboardService", "PassService" })
		local player = world:newPlayer()
		world:own(player, 0)
		world.Data:Load(player)
		world:flush()
		expect(services.PassService:Owns(player, "DoubleClicks")):toBe(false)
		expect(services.PassService:Owns(player, "Vip")):toBe(false)
	end)

	it("retries once when the marketplace check fails", function()
		local player = world:newPlayer()
		world:own(player, 101)
		world.passCheckFailures = 1
		world.Data:Load(player)
		world:advance(5)
		expect(PassService:Owns(player, "DoubleLuck")):toBe(true)
	end)

	it("gives up quietly after two failures", function()
		local player = world:newPlayer()
		world:own(player, 101)
		world.passCheckFailures = 2
		world.Data:Load(player)
		world:advance(5)
		expect(PassService:Owns(player, "DoubleLuck")):toBe(false)
		expect(#world.warnings > 0):toBe(true)
		expect(#world.errors):toBe(0)
	end)

	it("grants a pass when the purchase prompt finishes", function()
		local player = world:join()
		expect(PassService:Owns(player, "DoubleLuck")):toBe(false)
		world.fakeServices.MarketplaceService.PromptGamePassPurchaseFinished:Fire(player, 101, true)
		expect(PassService:Owns(player, "DoubleLuck")):toBe(true)
	end)

	it("ignores cancelled and unknown passes", function()
		local player = world:join()
		local finished = world.fakeServices.MarketplaceService.PromptGamePassPurchaseFinished
		finished:Fire(player, 101, false)
		finished:Fire(player, 999, true)
		expect(PassService:GetPasses(player)):toEqual({})
	end)

	it("settles income at the old rate before a pass changes it", function()
		local player, data = world:join(nil, { Board = S.fill("PlainClack", 10), IncomeAt = world.now - 10 }, false)
		world.fakeServices.MarketplaceService.PromptGamePassPurchaseFinished:Fire(player, 102, true)
		expect(data.Cash):toBe(100)
		expect(data.IncomeAt):toBe(world.now)
		world:advance(10)
		services.KeyboardService:Settle(player)
		expect(data.Cash):toBe(100 + 200)
	end)

	it("feeds owned passes into the modifiers", function()
		local Boosts = world:require("ReplicatedStorage.Rules.Boosts")
		local player = world:join()
		world.fakeServices.MarketplaceService.PromptGamePassPurchaseFinished:Fire(player, 101, true)
		world.fakeServices.MarketplaceService.PromptGamePassPurchaseFinished:Fire(player, 103, true)
		local modifiers = Boosts.Modifiers({ LuckUntil = 0, ClicksUntil = 0 }, PassService:GetPasses(player), world.now, 0)
		expect(modifiers.Luck):toBe(2)
		expect(modifiers.Income):toBeCloseTo(1.1)
	end)
end)

describe("RollService luck boosts", function()
	local world, Keys, data, player, services

	beforeEach(function()
		world = H.newWorld({ Seed = 11, AssetIds = assetIds })
		services = world:boot({ "KeyboardService", "PassService", "RollService" })
		Keys = world:require("ReplicatedStorage.Config.Keys")
		player, data = world:join()
	end)

	local function rareOrBetter(trials: number): number
		local hits = 0
		for _ = 1, trials do
			data.Rolls = 10
			world:advance(1)
			local index = world:invoke("Roll", player)
			if Keys.RarityByName[Keys.Catalog[index].Rarity].Chance >= 50 then
				hits += 1
			end
		end
		return hits
	end

	it("raises rare odds with a luck potion", function()
		local base = rareOrBetter(1500)
		data.Boosts.LuckUntil = world.now + 100000
		local boosted = rareOrBetter(1500)
		expect(boosted):toBeGreaterThan(base * 1.5)
	end)

	it("stops boosting once the potion expires", function()
		data.Boosts.LuckUntil = world.now + 100000
		world.tree.ReplicatedStorage:SetAttribute("ServerLuckUntil", world.now + 100000)
		local boosted = rareOrBetter(1500)
		data.Boosts.LuckUntil = world.now - 1
		world.tree.ReplicatedStorage:SetAttribute("ServerLuckUntil", world.now - 1)
		local expired = rareOrBetter(1500)
		expect(boosted):toBeGreaterThan(expired * 1.5)
	end)

	it("stacks pass, potion and server luck", function()
		local base = rareOrBetter(1500)
		world.fakeServices.MarketplaceService.PromptGamePassPurchaseFinished:Fire(player, 101, true)
		data.Boosts.LuckUntil = world.now + 100000
		world.tree.ReplicatedStorage:SetAttribute("ServerLuckUntil", world.now + 100000)
		local boosted = rareOrBetter(1500)
		expect(services.PassService:Owns(player, "DoubleLuck")):toBe(true)
		expect(boosted):toBeGreaterThan(base * 3)
	end)

	it("uses server luck only while it is active", function()
		local base = rareOrBetter(1500)
		world.tree.ReplicatedStorage:SetAttribute("ServerLuckUntil", world.now + 100000)
		local on = rareOrBetter(1500)
		world.tree.ReplicatedStorage:SetAttribute("ServerLuckUntil", world.now - 1)
		local off = rareOrBetter(1500)
		expect(on):toBeGreaterThan(base * 1.5)
		expect(on):toBeGreaterThan(off * 1.5)
	end)
end)
