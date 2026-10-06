local H = require("../harness/Harness")
local S = require("../support")

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

describe("Per-player stat caching", function()
	local world, services, Keyboard, Pass, Keys, GameConfig, Upgrades

	beforeEach(function()
		world = H.newWorld({ Time = 1700000000, Seed = 3, AssetIds = { DoubleClicks = 102, DoubleLuck = 101 } })
		services = world:boot({ "PassService", "KeyboardService", "RollService" })
		Keyboard = services.KeyboardService
		Pass = services.PassService
		Keys = world:require("ReplicatedStorage.Config.Keys")
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		Upgrades = world:require("ReplicatedStorage.Config.Upgrades")
	end)

	afterEach(function()
		world:destroy()
	end)

	local function perkKey(kind: string): string
		for _, key in Keys.Catalog do
			if key.Perk and key.Perk.Kind == kind then
				return key.Id
			end
		end
		error("no perk key")
	end

	describe("roll stats", function()
		it("reuses the same table while nothing changed", function()
			local player = world:joinAtBase(nil, { Board = S.fill("PlainClack", 3) })
			local first = Keyboard:GetRollStats(player, 1)
			expect(rawequal(first, Keyboard:GetRollStats(player, 1))):toBe(true)
		end)

		it("recomputes after the board changes", function()
			local player, data = world:joinAtBase(nil, { Board = S.fill("PlainClack", 3) })
			local before = Keyboard:GetRollStats(player, 1)
			data.Board[1] = perkKey("Luck")
			Keyboard:NotifyBoardChanged(player)
			local after = Keyboard:GetRollStats(player, 1)
			expect(after.Luck > before.Luck):toBe(true)
		end)

		it("recomputes when the luck multiplier changes", function()
			local player = world:joinAtBase(nil, { Board = S.fill("PlainClack", 3) })
			local base = Keyboard:GetRollStats(player, 1)
			local boosted = Keyboard:GetRollStats(player, 2)
			expect(boosted.Luck):toBe(base.Luck * 2)
			expect(Keyboard:GetRollStats(player, 1).Luck):toBe(base.Luck)
		end)

		it("recomputes when an upgrade level or the equipped charms change", function()
			local player, data = world:joinAtBase(nil, { Board = S.fill("PlainClack", 3) })
			local base = Keyboard:GetRollStats(player, 1)
			data.Upgrades.Luck = 5
			expect(Keyboard:GetRollStats(player, 1).Luck > base.Luck):toBe(true)
			local charmed = Keyboard:GetRollStats(player, 1)
			data.EquippedCharms = {}
			expect(rawequal(charmed, Keyboard:GetRollStats(player, 1))):toBe(false)
		end)

		it("is nil for a player without data", function()
			expect(Keyboard:GetRollStats(world:newPlayer(), 1)):toBeNil()
		end)

		it("honours a luck potion in the roll handler", function()
			local player, data = world:joinAtBase(nil, { Board = S.fill("PlainClack", 3) })
			data.Boosts.LuckUntil = world.now + 100
			local index = world:invoke("Roll", player)
			expect(index > 0):toBe(true)
		end)
	end)

	describe("board rate", function()
		it("updates after a board change", function()
			local player, data = world:joinAtBase(nil, { Board = S.fill("PlainClack", 3) })
			expect(Keyboard:GetRate(player)):toBe(3)
			data.Board[1] = "GlassTink"
			Keyboard:NotifyBoardChanged(player)
			expect(Keyboard:GetRate(player)):toBe(Keys.GetIncome("GlassTink") + 2)
		end)

		it("updates when another service fires BoardChanged directly", function()
			local player, data = world:joinAtBase(nil, { Board = S.fill("PlainClack", 3) })
			expect(Keyboard:GetRate(player)):toBe(3)
			data.Board[1] = "GlassTink"
			Keyboard.BoardChanged:Fire(player)
			expect(Keyboard:GetRate(player)):toBe(Keys.GetIncome("GlassTink") + 2)
		end)

		it("updates when a pass is bought", function()
			local player = world:joinAtBase(nil, { Board = S.fill("PlainClack", 3) })
			expect(Keyboard:GetRate(player)):toBe(3)
			world.fakeServices.MarketplaceService.PromptGamePassPurchaseFinished:Fire(player, 102, true)
			expect(Keyboard:GetRate(player)):toBe(3 * GameConfig.Boosts.DoubleClicksPassMultiplier)
		end)

		it("updates when upgrades or rebirths change", function()
			local player, data = world:joinAtBase(nil, { Board = S.fill("PlainClack", 3) })
			local base = Keyboard:GetRate(player)
			data.Upgrades.Income = Upgrades.ById.Income.MaxLevel
			expect(Keyboard:GetRate(player) > base):toBe(true)
			local upgraded = Keyboard:GetRate(player)
			data.Rebirths = 3
			expect(Keyboard:GetRate(player) > upgraded):toBe(true)
		end)

		it("settles at the new rate after a change", function()
			local player, data = world:joinAtBase(nil, { Board = S.fill("PlainClack", 3), IncomeAt = world.now })
			Keyboard:GetRate(player)
			world:advance(10)
			Keyboard:Settle(player)
			expect(data.Cash):toBe(30)
			data.Board[1] = "GlassTink"
			Keyboard:NotifyBoardChanged(player)
			world:advance(10)
			Keyboard:Settle(player)
			expect(data.Cash):toBe(30 + (Keyboard:GetRate(player)) * 10)
		end)
	end)

	describe("pass ownership", function()
		it("returns one table per player and keeps it current", function()
			local player = world:joinAtBase()
			local passes = Pass:GetPasses(player)
			expect(rawequal(passes, Pass:GetPasses(player))):toBe(true)
			expect(Pass:Owns(player, "DoubleLuck")):toBe(false)
			world.fakeServices.MarketplaceService.PromptGamePassPurchaseFinished:Fire(player, 101, true)
			expect(Pass:Owns(player, "DoubleLuck")):toBe(true)
			expect(passes.DoubleLuck):toBe(true)
		end)

		it("follows attributes set outside the service", function()
			local player = world:joinAtBase()
			expect(Pass:Owns(player, "Vip")):toBe(false)
			player:SetAttribute("Pass_Vip", true)
			expect(Pass:Owns(player, "Vip")):toBe(true)
			player:SetAttribute("Pass_Vip", nil)
			expect(Pass:Owns(player, "Vip")):toBe(false)
		end)

		it("forgets a player who leaves", function()
			local player = world:joinAtBase()
			Pass:GetPasses(player)
			world:removePlayer(player)
			expect(world.errors):toEqual({})
		end)
	end)

	describe("roll counter", function()
		it("does not advance when the key cannot be added", function()
			local player, data = world:joinAtBase()
			Keyboard.AddKey = function()
				return false
			end
			local index = world:invoke("Roll", player)
			expect(index):toBe(0)
			expect(data.Rolls):toBe(0)
			expect(data.GoldenProgress):toBe(0)
		end)

		it("counts a successful roll with a single combined write", function()
			local player, data = world:joinAtBase()
			local replica = world.Data:Replica(player)
			local before = #replica.Log
			expect(world:invoke("Roll", player) > 0):toBe(true)
			expect(data.Rolls):toBe(1)
			expect(data.GoldenProgress):toBe(1)
			local rollWrites = 0
			for index = before + 1, #replica.Log do
				local entry = replica.Log[index]
				if entry.Op == "SetValues" and entry.Value.Rolls ~= nil then
					rollWrites += 1
					expect(entry.Value.GoldenProgress):toBe(1)
				end
			end
			expect(rollWrites):toBe(1)
		end)

		it("advances the tutorial at the guaranteed roll", function()
			local player, data = world:joinAtBase(nil, { Rolls = GameConfig.GuaranteedRareRoll - 1, Tutorial = 1 })
			world:invoke("Roll", player)
			expect(data.Tutorial):toBe(2)
		end)
	end)
end)

describe("Offline income and passes", function()
	local world, services, Keyboard, GameConfig, Stats

	beforeEach(function()
		world = H.newWorld({ Time = 1700000000, AssetIds = { DoubleClicks = 102, Vip = 103 } })
		services = world:boot({ "KeyboardService", "PassService" })
		Keyboard = services.KeyboardService
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		Stats = world:require("ReplicatedStorage.Rules.Stats")
	end)

	afterEach(function()
		world:destroy()
	end)

	local function load(player: any, elapsed: number)
		return world.Data:Load(player, { Board = S.fill("GlassTink", 3), IncomeAt = world.now - elapsed })
	end

	it("applies the DoubleClicks multiplier to offline income", function()
		local player = world:newPlayer()
		world:own(player, 102)
		local data = load(player, 1000)
		world:flush()
		local rate = Stats.Compute(data.Board, data.Upgrades).Rate * GameConfig.Boosts.DoubleClicksPassMultiplier
		expect(data.Cash):toBe(math.floor(rate * 1000 * GameConfig.OfflineRate))
	end)

	it("applies the VIP multiplier to offline income", function()
		local player = world:newPlayer()
		world:own(player, 103)
		local data = load(player, 1000)
		world:flush()
		local plain = Stats.Compute(data.Board, data.Upgrades).Rate
		expect(services.PassService:Owns(player, "Vip")):toBe(true)
		expect(Keyboard:GetRate(player) > plain):toBe(true)
		expect(data.Cash):toBe(math.floor(Keyboard:GetRate(player) * 1000 * GameConfig.OfflineRate))
	end)

	it("waits for a slow pass check and does not settle meanwhile", function()
		local player = world:newPlayer()
		world:own(player, 102)
		world.passCheckFailures = 1
		local data = load(player, 1000)
		local before = data.Cash
		Keyboard:Settle(player)
		expect(data.Cash):toBe(before)
		world:advance(5)
		local rate = Stats.Compute(data.Board, data.Upgrades).Rate * GameConfig.Boosts.DoubleClicksPassMultiplier
		expect(data.Cash >= math.floor(rate * 1000 * GameConfig.OfflineRate)):toBe(true)
	end)

	it("never hangs when the pass check keeps failing", function()
		local player = world:newPlayer()
		world:own(player, 102)
		world.passCheckFailures = 1000
		local data = load(player, 1000)
		world:advance(60)
		local rate = Stats.Compute(data.Board, data.Upgrades).Rate
		expect(data.Cash >= math.floor(rate * 1000 * GameConfig.OfflineRate)):toBe(true)
		expect(data.IncomeAt > world.now - 1000):toBe(true)
	end)

	it("pays offline income when the player leaves before passes resolve", function()
		local player = world:newPlayer()
		world:own(player, 102)
		world.passCheckFailures = 1
		local data = load(player, 1000)
		world:removePlayer(player)
		local rate = Stats.Compute(data.Board, data.Upgrades).Rate
		expect(data.Cash >= math.floor(rate * 1000 * GameConfig.OfflineRate)):toBe(true)
	end)
end)
