local H = require("../harness/Harness")
local S = require("../support")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

local assetIds = {
	DoubleLuck = 101,
	DoubleClicks = 102,
	Vip = 103,
	StarterPack = 201,
	LuckPotion = 202,
	ClicksPotion = 203,
	ServerLuck = 204,
	ClicksSmall = 205,
	ClicksLarge = 206,
}

local function granted(decision: any): boolean
	return string.find(tostring(decision), "PurchaseGranted", 1, true) ~= nil
end

describe("Products registry", function()
	it("registers nothing while every asset id is 0", function()
		local world = H.newWorld()
		local products = world:require("ServerScriptService.Services.PurchaseService.Products")
		expect(next(products)):toBeNil()
	end)

	it("registers only products that have an asset id", function()
		local world = H.newWorld({ AssetIds = { LuckPotion = 202, ServerLuck = 204 } })
		local products = world:require("ServerScriptService.Services.PurchaseService.Products")
		local ids = {}
		for id in products do
			table.insert(ids, id)
		end
		table.sort(ids)
		expect(ids):toEqual({ 202, 204 })
	end)

	it("registers every product kind when all ids are set", function()
		local world = H.newWorld({ AssetIds = assetIds })
		local products = world:require("ServerScriptService.Services.PurchaseService.Products")
		for _, id in { 201, 202, 203, 204, 205, 206 } do
			expect(type(products[id])):toBe("function")
		end
		expect(products[101]):toBeNil()
	end)

	it("leaves unconfigured products unprocessed so Roblox retries", function()
		local world = H.newWorld()
		world:boot({ "KeyboardService", "PurchaseService" })
		local player = world:join()
		expect(granted(world:receipt(player, 999))):toBe(false)
		expect(#world.warnings > 0):toBe(true)
	end)
end)

describe("PurchaseService grants", function()
	local world, services, player, data, GameConfig, Keys

	beforeEach(function()
		world = H.newWorld({ Time = 1700000000, AssetIds = assetIds })
		services = world:boot({ "KeyboardService", "PassService", "PurchaseService" })
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		Keys = world:require("ReplicatedStorage.Config.Keys")
		player, data = world:join(nil, { Settings = { AutoPlace = false } })
	end)

	local function buy(id: number, purchaseId: number?): boolean
		return granted(world:receipt(player, id, purchaseId))
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

	it("installs the receipt handler and clears it on Destroy", function()
		expect(type(world.fakeServices.MarketplaceService.ProcessReceipt)):toBe("function")
		services.PurchaseService:Destroy()
		expect(world.fakeServices.MarketplaceService.ProcessReceipt):toBeNil()
	end)

	it("extends the luck potion", function()
		expect(buy(202)):toBe(true)
		expect(data.Boosts.LuckUntil):toBe(world.now + 900)
		expect(buy(202)):toBe(true)
		expect(data.Boosts.LuckUntil):toBe(world.now + 1800)
	end)

	it("caps stacked potions", function()
		data.Boosts.LuckUntil = world.now + 7000
		expect(buy(202)):toBe(true)
		expect(data.Boosts.LuckUntil):toBe(world.now + GameConfig.Boosts.MaxStackSeconds)
	end)

	it("extends the clicks potion after settling income at the old rate", function()
		data.Board = S.fill("PlainClack", 3)
		data.IncomeAt = world.now - 10
		expect(buy(203)):toBe(true)
		expect(data.Cash):toBe(30)
		expect(data.IncomeAt):toBe(world.now)
		expect(data.Boosts.ClicksUntil):toBe(world.now + 900)
		world:advance(10)
		services.KeyboardService:Settle(player)
		expect(data.Cash):toBe(30 + 60)
	end)

	it("adds clicks for both bundles", function()
		expect(buy(205)):toBe(true)
		expect(data.Cash):toBe(25000)
		expect(buy(206)):toBe(true)
		expect(data.Cash):toBe(325000)
	end)

	it("activates server luck for everyone and credits the buyer", function()
		local root = world.tree.ReplicatedStorage
		player.DisplayName = "Buyer"
		expect(buy(204)):toBe(true)
		expect(root:GetAttribute("ServerLuckUntil")):toBe(world.now + 600)
		expect(root:GetAttribute("ServerLuckBy")):toBe("Buyer")
		expect(buy(204)):toBe(true)
		expect(root:GetAttribute("ServerLuckUntil")):toBe(world.now + 1200)
	end)

	it("caps server luck", function()
		local root = world.tree.ReplicatedStorage
		root:SetAttribute("ServerLuckUntil", world.now + 7000)
		expect(buy(204)):toBe(true)
		expect(root:GetAttribute("ServerLuckUntil")):toBe(world.now + GameConfig.Boosts.MaxStackSeconds)
	end)

	it("treats an expired server luck as a fresh start", function()
		local root = world.tree.ReplicatedStorage
		root:SetAttribute("ServerLuckUntil", world.now - 500)
		expect(buy(204)):toBe(true)
		expect(root:GetAttribute("ServerLuckUntil")):toBe(world.now + 600)
	end)

	it("gives the starter pack contents once", function()
		expect(buy(201)):toBe(true)
		expect(data.Cash):toBe(10000)
		expect(data.Boosts.LuckUntil):toBe(world.now + 900)
		expect(keysOfRarity("Epic")):toBe(1)
		expect(data.StarterPackBought):toBe(true)
		local discovered = 0
		for _, count in data.Discovered do
			discovered += count
		end
		expect(discovered):toBe(1)
	end)

	it("gives only the clicks when the starter pack is bought again", function()
		expect(buy(201)):toBe(true)
		local luckUntil = data.Boosts.LuckUntil
		expect(buy(201)):toBe(true)
		expect(data.Cash):toBe(20000)
		expect(data.Boosts.LuckUntil):toBe(luckUntil)
		expect(keysOfRarity("Epic")):toBe(1)
		expect(data.StarterPackBought):toBe(true)
	end)

	it("grants nothing from the starter pack when the key cannot be added, then grants once on retry", function()
		local keyboard = services.KeyboardService
		local original = keyboard.AddKey
		keyboard.AddKey = function()
			return false
		end
		expect(buy(201, 900)):toBe(false)
		keyboard.AddKey = original
		expect(data.Cash):toBe(0)
		expect(data.TotalEarned):toBe(0)
		expect(data.Boosts.LuckUntil):toBe(0)
		expect(data.StarterPackBought):toBe(false)
		expect(data.Receipts["900"]):toBeNil()
		expect(buy(201, 900)):toBe(true)
		expect(buy(201, 900)):toBe(true)
		expect(data.Cash):toBe(10000)
		expect(data.Boosts.LuckUntil):toBe(world.now + 900)
		expect(keysOfRarity("Epic")):toBe(1)
		expect(data.StarterPackBought):toBe(true)
	end)

	it("never grants the same receipt twice", function()
		expect(buy(205, 777)):toBe(true)
		expect(buy(205, 777)):toBe(true)
		expect(data.Cash):toBe(25000)
		expect(data.Receipts["777"] ~= nil):toBe(true)
		expect(buy(205, 778)):toBe(true)
		expect(data.Cash):toBe(50000)
	end)

	it("does not double-grant server luck on a replayed receipt", function()
		local root = world.tree.ReplicatedStorage
		expect(buy(204, 5)):toBe(true)
		expect(buy(204, 5)):toBe(true)
		expect(root:GetAttribute("ServerLuckUntil")):toBe(world.now + 600)
	end)

	it("leaves the purchase pending when the player is gone", function()
		local other = world:newPlayer()
		expect(granted(world:receipt(other, 205))):toBe(false)
	end)

	it("keeps only the most recent receipts", function()
		for purchaseId = 1, 105 do
			world:advance(1)
			buy(205, purchaseId)
		end
		local count = 0
		for _ in data.Receipts do
			count += 1
		end
		expect(count):toBe(100)
		expect(data.Receipts["105"] ~= nil):toBe(true)
		expect(data.Receipts["1"]):toBeNil()
	end)

	it("does not grant products from game pass purchases", function()
		world.fakeServices.MarketplaceService.PromptGamePassPurchaseFinished:Fire(player, 101, true)
		expect(data.Cash):toBe(0)
		expect(services.PassService:Owns(player, "DoubleLuck")):toBe(true)
	end)
end)

describe("Pass ownership to modifiers", function()
	it("applies each owned pass on top of the potions", function()
		local world = H.newWorld({ Time = 1700000000, AssetIds = assetIds })
		local services = world:boot({ "KeyboardService", "PassService" })
		local Boosts = world:require("ReplicatedStorage.Rules.Boosts")
		local player = world:newPlayer()
		world:own(player, 101)
		world:own(player, 102)
		world.Data:Load(player)
		world:flush()
		local boosts = { LuckUntil = world.now + 10, ClicksUntil = world.now + 10 }
		local modifiers = Boosts.Modifiers(boosts, services.PassService:GetPasses(player), world.now, world.now + 10)
		expect(modifiers.Luck):toBe(2 * 2 * 2)
		expect(modifiers.Income):toBe(2 * 2)
	end)
end)
