local H = require("../harness/Harness")
local S = require("../support")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

describe("RollService handler", function()
	local world, Keys, GameConfig

	beforeEach(function()
		world = H.newWorld({ Seed = 7 })
		world:boot({ "KeyboardService", "RollService" })
		Keys = world:require("ReplicatedStorage.Config.Keys")
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
	end)

	local function roll(player: any): (number, boolean)
		return world:invoke("Roll", player)
	end

	local function rarityOf(index: number): string
		return Keys.Catalog[index].Rarity
	end

	describe("token bucket", function()
		it("allows a burst of 3 then rejects spam", function()
			local player, data = world:join()
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
			local player, data = world:join()
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
			local player = world:join()
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
			local player = world:join(nil, { Upgrades = { Speed = 10 } })
			for _ = 1, 3 do
				roll(player)
			end
			world:advance(0.15)
			expect(roll(player) > 0):toBe(true)
		end)

		it("never stores more than the burst capacity", function()
			local player = world:join()
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
			local a = world:join()
			local b = world:join()
			for _ = 1, 10 do
				roll(a)
			end
			expect(roll(a)):toBe(0)
			expect(roll(b) > 0):toBe(true)
		end)

		it("forgets a player's bucket when they leave", function()
			local player = world:join()
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
			for _ = 1, 10 do
				local index, golden = roll(stranger)
				expect(index):toBe(0)
				expect(golden):toBe(false)
			end
			world.Data:Load(stranger)
			expect(roll(stranger) > 0):toBe(true)
		end)

		it("returns (0, false) when the player has no plot", function()
			local player = world:join()
			table.remove(world.Players._list, table.find(world.Players._list, player))
			local index, golden = roll(player)
			expect(index):toBe(0)
			expect(golden):toBe(false)
		end)
	end)

	describe("guaranteed and golden rolls", function()
		it("guarantees a Rare on the configured roll", function()
			local player, data = world:join()
			for _ = 1, 150 do
				data.Rolls = GameConfig.GuaranteedRareRoll - 1
				world:advance(1)
				local index, golden = roll(player)
				expect(rarityOf(index)):toBe("Rare")
				expect(golden):toBe(false)
				expect(data.Rolls):toBe(GameConfig.GuaranteedRareRoll)
			end
		end)

		it("flags every GoldenRollEvery-th roll as golden", function()
			local player, data = world:join()
			for _, rolls in { 99, 199, 999 } do
				data.Rolls = rolls
				world:advance(1)
				local index, golden = roll(player)
				expect(index > 0):toBe(true)
				expect(golden):toBe(true)
			end
		end)

		it("does not flag other rolls as golden", function()
			local player, data = world:join()
			for _, rolls in { 0, 1, 3, 50, 98, 100, 101, 198 } do
				data.Rolls = rolls
				world:advance(1)
				local _, golden = roll(player)
				expect(golden):toBe(false)
			end
		end)

		it("counts rolls exactly through a whole golden cycle", function()
			local player, data = world:join()
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
			local player, data = world:join()
			local function rareOrBetter(startRolls: number, trials: number): number
				local hits = 0
				for _ = 1, trials do
					data.Rolls = startRolls
					world:advance(1)
					local index = roll(player)
					local chance = Keys.RarityByName[rarityOf(index)].Chance
					if chance >= 50 then
						hits += 1
					end
				end
				return hits
			end
			local normal = rareOrBetter(10, 1500)
			local golden = rareOrBetter(99, 1500)
			expect(normal):toBeLessThan(120)
			expect(golden):toBeGreaterThan(normal * 4)
			expect(golden):toBeGreaterThan(150)
		end)
	end)

	describe("bookkeeping", function()
		it("increments Rolls and Discovered consistently with returned keys", function()
			local player, data = world:join()
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
			local player, data = world:join({ DisplayName = "Alice" }, { Board = board })
			local announced = 0
			local announcedKeys = {}
			for _ = 1, 600 do
				data.Rolls = 99
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
			local player = world:join()
			for _ = 1, 3 do
				roll(player)
			end
			for _, entry in world:firedOf("RareRoll") do
				expect(Keys.RarityByName[rarityOf(entry.Args[2])].Announce):toBe(true)
			end
		end)

		it("places rolled keys through the keyboard", function()
			local player, data = world:join()
			local index = roll(player)
			expect(data.Board[1]):toBe(Keys.Catalog[index].Id)
		end)
	end)

	describe("tutorial", function()
		it("steps 0 -> 1 on the first roll and 1 -> 2 on the guaranteed-rare roll", function()
			local player, data = world:join()
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
			local player, data = world:join(nil, { Tutorial = 3 })
			roll(player)
			expect(data.Tutorial):toBe(3)
			local player2, data2 = world:join(nil, { Tutorial = 7 })
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
