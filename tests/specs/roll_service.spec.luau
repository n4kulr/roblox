local H = require("../harness/Harness")
local S = require("../support")
local roblox = require("@lune/roblox")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

describe("RollService handler", function()
	local world, Keys, GameConfig, Upgrades

	beforeEach(function()
		world = H.newWorld({ Seed = 7 })
		world:boot({ "KeyboardService", "RollService" })
		Keys = world:require("ReplicatedStorage.Config.Keys")
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		Upgrades = world:require("ReplicatedStorage.Config.Upgrades")
	end)

	local function roll(player: any): (number, boolean)
		return world:invoke("Roll", player)
	end

	local function rarityOf(index: number): string
		return Keys.Catalog[index].Rarity
	end

	describe("token bucket", function()
		it("allows a burst of 3 then rejects spam", function()
			local player, data = world:joinAtBase()
			local accepted = 0
			for _ = 1, 50 do
				local index = roll(player)
				if index > 0 then
					accepted += 1
				end
			end
			expect(accepted):toBe(3)
			expect(data.Rolls):toBe(3)
		end)

		it("returns (0, false) for rejected rolls and does not change data", function()
			local player, data = world:joinAtBase()
			for _ = 1, 3 do
				roll(player)
			end
			local before = H.deepCopy(data)
			local index, golden = roll(player)
			expect(index):toBe(0)
			expect(golden):toBe(false)
			expect(data):toEqual(before)
		end)

		it("refills at RollsPerSecond", function()
			local player = world:joinAtBase()
			for _ = 1, 3 do
				roll(player)
			end
			world:advance(0.15)
			expect(roll(player)):toBe(0)
			world:advance(0.1)
			expect(roll(player) > 0):toBe(true)
			expect(roll(player)):toBe(0)
			world:advance(0.1)
			expect(roll(player)):toBe(0)
		end)

		it("refills faster with Speed upgrades", function()
			local player = world:joinAtBase(nil, { Upgrades = { Speed = 10 } })
			for _ = 1, 3 do
				roll(player)
			end
			world:advance(0.15)
			expect(roll(player) > 0):toBe(true)
		end)

		it("never stores more than the burst capacity", function()
			local player = world:joinAtBase()
			world:advance(3600)
			local accepted = 0
			for _ = 1, 10 do
				if roll(player) > 0 then
					accepted += 1
				end
			end
			expect(accepted):toBe(3)
		end)

		it("is tracked per player", function()
			local a = world:joinAtBase()
			local b = world:joinAtBase()
			for _ = 1, 10 do
				roll(a)
			end
			expect(roll(a)):toBe(0)
			expect(roll(b) > 0):toBe(true)
		end)

		it("forgets a player's bucket when they leave", function()
			local player = world:joinAtBase()
			for _ = 1, 3 do
				roll(player)
			end
			expect(roll(player)):toBe(0)
			world.Players.PlayerRemoving:Fire(player)
			expect(roll(player) > 0):toBe(true)
		end)
	end)

	describe("preconditions", function()
		it("returns (0, false) without data and does not consume tokens", function()
			local stranger = world:newPlayer()
			world:placeAtBase(stranger)
			for _ = 1, 10 do
				local index, golden = roll(stranger)
				expect(index):toBe(0)
				expect(golden):toBe(false)
			end
			world.Data:Load(stranger)
			expect(roll(stranger) > 0):toBe(true)
		end)

		it("returns (0, false) when the player has no plot", function()
			local player = world:joinAtBase()
			table.remove(world.Players._list, table.find(world.Players._list, player))
			local index, golden = roll(player)
			expect(index):toBe(0)
			expect(golden):toBe(false)
		end)
	end)

	describe("roll in base", function()
		local function placeAt(player: any, x: number, y: number, z: number)
			world:moveCharacter(player, x, y, z)
		end

		it("accepts rolls anywhere over the base footprint", function()
			local player = world:joinAtBase()
			for _, spot in { { 0, 3, 0 }, { 21, 3, 21 }, { -21, 3, -21 }, { 0, 30, 0 } } do
				world:advance(5)
				placeAt(player, spot[1], spot[2], spot[3])
				expect(roll(player) > 0):toBe(true)
			end
		end)

		it("accepts exactly at the margin and rejects just past it", function()
			local player = world:joinAtBase()
			local edge = 22 + GameConfig.RollInBaseMargin
			placeAt(player, edge, 3, 0)
			expect(roll(player) > 0):toBe(true)
			world:advance(5)
			placeAt(player, edge + 0.1, 3, 0)
			expect(roll(player)):toBe(0)
			world:advance(5)
			placeAt(player, 0, 3, -(edge + 0.1))
			expect(roll(player)):toBe(0)
			world:advance(5)
			placeAt(player, 0, 3, -edge)
			expect(roll(player) > 0):toBe(true)
		end)

		it("rejects far away, too high and below the base", function()
			local player, data = world:joinAtBase()
			for _, spot in { { 200, 3, 0 }, { 0, 60, 0 }, { 0, -40, 0 } } do
				world:advance(5)
				placeAt(player, spot[1], spot[2], spot[3])
				expect(roll(player)):toBe(0)
			end
			expect(data.Rolls):toBe(0)
		end)

		it("does not spend tokens on rejected rolls", function()
			local player = world:joinAtBase()
			placeAt(player, 500, 3, 0)
			for _ = 1, 20 do
				roll(player)
			end
			placeAt(player, 0, 3, 0)
			local accepted = 0
			for _ = 1, 10 do
				if roll(player) > 0 then
					accepted += 1
				end
			end
			expect(accepted):toBe(3)
		end)

		it("rejects players without a character", function()
			local player = world:joinAtBase()
			player.Character = nil
			expect(roll(player)):toBe(0)
		end)

		it("follows a rotated base", function()
			local player = world:joinAtBase()
			local base = world.fakeRegistry.PlotService:GetBase(player)
			base.CFrame = roblox.CFrame.new(100, 0, 0) * roblox.CFrame.Angles(0, math.pi / 2, 0)
			base.Size = roblox.Vector3.new(44, 1, 20)
			local margin = GameConfig.RollInBaseMargin
			placeAt(player, 100, 3, 22 + margin - 0.5)
			expect(roll(player) > 0):toBe(true)
			world:advance(5)
			placeAt(player, 100 + 10 + margin + 0.5, 3, 0)
			expect(roll(player)):toBe(0)
			world:advance(5)
			placeAt(player, 100 + 10 + margin - 0.5, 3, 0)
			expect(roll(player) > 0):toBe(true)
		end)
	end)

	describe("guaranteed and golden rolls", function()
		it("guarantees a Rare on the configured roll", function()
			local player, data = world:joinAtBase()
			for _ = 1, 150 do
				data.Rolls = GameConfig.GuaranteedRareRoll - 1
				world:advance(1)
				local index, golden = roll(player)
				expect(rarityOf(index)):toBe("Rare")
				expect(golden):toBe(false)
				expect(data.Rolls):toBe(GameConfig.GuaranteedRareRoll)
			end
		end)

		it("flags the roll that completes GoldenRollEvery as golden and resets progress", function()
			local player, data = world:joinAtBase()
			for _, rolls in { 99, 199, 999 } do
				data.Rolls = rolls
				data.GoldenProgress = GameConfig.GoldenRollEvery - 1
				world:advance(1)
				local index, golden = roll(player)
				expect(index > 0):toBe(true)
				expect(golden):toBe(true)
				expect(data.GoldenProgress):toBe(0)
			end
		end)

		it("does not flag other rolls as golden and counts progress up", function()
			local player, data = world:joinAtBase()
			for _, progress in { 0, 1, 3, 50, 97, 98 } do
				data.Rolls = 500
				data.GoldenProgress = progress
				world:advance(1)
				local _, golden = roll(player)
				expect(golden):toBe(false)
				expect(data.GoldenProgress):toBe(progress + 1)
			end
		end)

		it("reaches a golden roll sooner with Golden Touch", function()
			local player, data = world:joinAtBase()
			data.Upgrades.Golden = 4
			local every = GameConfig.GoldenRollEvery - 4 * Upgrades.ById.Golden.PerLevel
			data.Rolls = 500
			data.GoldenProgress = every - 2
			world:advance(1)
			local _, first = roll(player)
			expect(first):toBe(false)
			world:advance(1)
			local _, second = roll(player)
			expect(second):toBe(true)
			expect(data.GoldenProgress):toBe(0)
		end)

		it("never needs fewer than one roll at max Golden Touch", function()
			local Stats = world:require("ReplicatedStorage.Rules.Stats")
			expect(Stats.GoldenEvery({ Golden = Upgrades.ById.Golden.MaxLevel })):toBe(
				GameConfig.GoldenRollEvery - Upgrades.ById.Golden.MaxLevel * Upgrades.ById.Golden.PerLevel
			)
			expect(Stats.GoldenEvery({ Golden = 1000 })):toBe(1)
			expect(Stats.GoldenEvery({})):toBe(GameConfig.GoldenRollEvery)
		end)

		it("counts rolls exactly through a whole golden cycle", function()
			local player, data = world:joinAtBase()
			local goldens = {}
			for n = 1, 205 do
				world:advance(1)
				local index, golden = roll(player)
				expect(index > 0):toBe(true)
				if golden then
					table.insert(goldens, n)
				end
			end
			expect(goldens):toEqual({ 100, 200 })
			expect(data.Rolls):toBe(205)
		end)

		it("boosts luck on golden rolls", function()
			local player, data = world:joinAtBase()
			local function rareOrBetter(progress: number, trials: number): number
				local hits = 0
				for _ = 1, trials do
					data.Rolls = 500
					data.GoldenProgress = progress
					world:advance(1)
					local index = roll(player)
					local chance = Keys.RarityByName[rarityOf(index)].Chance
					if chance >= Keys.RarityByName.Rare.Chance then
						hits += 1
					end
				end
				return hits
			end
			local normal = rareOrBetter(10, 6000)
			local golden = rareOrBetter(GameConfig.GoldenRollEvery - 1, 6000)
			expect(normal):toBeLessThan(120)
			expect(golden):toBeGreaterThan(normal * 4)
			expect(golden):toBeGreaterThan(150)
		end)
	end)

	describe("bookkeeping", function()
		it("increments Rolls and Discovered consistently with returned keys", function()
			local player, data = world:joinAtBase()
			local tally: { [string]: number } = {}
			for _ = 1, 120 do
				world:advance(1)
				local index = roll(player)
				local id = Keys.Catalog[index].Id
				tally[id] = (tally[id] or 0) + 1
			end
			expect(data.Rolls):toBe(120)
			expect(data.Discovered):toEqual(tally)
			expect(S.totals(data)):toEqual(tally)
		end)

		it("announces rare finds to everyone with the display name and key index", function()
			local board = S.fill("FourLeafArtisan", 10)
			local player, data = world:joinAtBase({ DisplayName = "Alice" }, { Board = board })
			local announced = 0
			local announcedKeys = {}
			local attempts = 0
			while announced < 2 and attempts < 100000 do
				attempts += 1
				data.Rolls = 99
				data.GoldenProgress = GameConfig.GoldenRollEvery - 1
				world:advance(1)
				local index = roll(player)
				if Keys.RarityByName[rarityOf(index)].Announce then
					announced += 1
					table.insert(announcedKeys, index)
				end
			end
			expect(announced):toBeGreaterThan(0)
			local fired = world:firedOf("RareRoll")
			expect(#fired):toBe(announced)
			for position, entry in fired do
				expect(entry.Target):toBe("All")
				expect(entry.Args[1]):toBe("Alice")
				expect(entry.Args[2]):toBe(announcedKeys[position])
			end
		end)

		it("does not announce common finds", function()
			local player = world:joinAtBase()
			for _ = 1, 3 do
				roll(player)
			end
			for _, entry in world:firedOf("RareRoll") do
				expect(Keys.RarityByName[rarityOf(entry.Args[2])].Announce):toBe(true)
			end
		end)

		it("places rolled keys through the keyboard", function()
			local player, data = world:joinAtBase()
			local index = roll(player)
			expect(data.Board[1]):toBe(Keys.Catalog[index].Id)
		end)
	end)

	describe("tutorial", function()
		it("steps 0 -> 1 on the first roll and 1 -> 2 on the guaranteed-rare roll", function()
			local player, data = world:joinAtBase()
			expect(data.Tutorial):toBe(0)
			roll(player)
			expect(data.Tutorial):toBe(1)
			roll(player)
			expect(data.Tutorial):toBe(1)
			roll(player)
			expect(data.Tutorial):toBe(2)
			world:advance(1)
			roll(player)
			expect(data.Tutorial):toBe(2)
		end)

		it("never moves the tutorial backwards", function()
			local player, data = world:joinAtBase(nil, { Tutorial = 3 })
			roll(player)
			expect(data.Tutorial):toBe(3)
			local player2, data2 = world:joinAtBase(nil, { Tutorial = 7 })
			roll(player2)
			expect(data2.Tutorial):toBe(7)
		end)
	end)

	it("clears its packet handler on Destroy", function()
		expect(world:packets().Roll.OnServerInvoke).never:toBeNil()
		world:destroy()
		expect(world:packets().Roll.OnServerInvoke):toBeNil()
	end)
end)
