local H = require("../harness/Harness")
local S = require("../support")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

local maxCash

describe("KeyboardService", function()
	local world, services, Keyboard, GameConfig, Keys, Upgrades, Stats

	beforeEach(function()
		world = H.newWorld({ Time = 1700000000 })
		services = world:boot({ "KeyboardService" })
		Keyboard = services.KeyboardService
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		maxCash = GameConfig.MaxCash
		Keys = world:require("ReplicatedStorage.Config.Keys")
		Upgrades = world:require("ReplicatedStorage.Config.Upgrades")
		Stats = world:require("ReplicatedStorage.Rules.Stats")
	end)

	local function levelsFor(slots: number): { Slots: number }
		local perLevel = Upgrades.ById.Slots.PerLevel
		return { Slots = math.ceil((slots - GameConfig.BaseSlots) / perLevel) }
	end

	local function maxedUpgrades(): { Slots: number }
		return levelsFor(GameConfig.BoardSlots)
	end

	local function join(overrides: any?, fireLoaded: boolean?)
		return world:join(nil, overrides, fireLoaded == true)
	end

	local function boardKeys(data: any): { string }
		local out = {}
		for index = 1, GameConfig.BoardSlots do
			out[index] = data.Board[index]
		end
		return out
	end

	describe("settle", function()
		it("pays rate * elapsed seconds and moves the clock forward", function()
			local player, data =
				join({ Board = S.fill("PlainClack", 3), IncomeAt = world.now - 100, Cash = 5 })
			Keyboard:Settle(player)
			expect(data.Cash):toBe(5 + 3 * 100)
			expect(data.IncomeAt):toBe(world.now)
		end)

		it("is idempotent within the same second", function()
			local player, data = join({ Board = S.fill("PlainClack", 3), IncomeAt = world.now - 10 })
			Keyboard:Settle(player)
			local cash = data.Cash
			local writes = #world.Data:Replica(player).Log
			Keyboard:Settle(player)
			expect(data.Cash):toBe(cash)
			expect(#world.Data:Replica(player).Log):toBe(writes)
		end)

		it("starts the income clock without paying when IncomeAt is 0", function()
			local player, data = join({ Board = S.fill("PlainClack", 3), IncomeAt = 0, Cash = 7 })
			Keyboard:Settle(player)
			expect(data.Cash):toBe(7)
			expect(data.IncomeAt):toBe(world.now)
		end)

		it("never pays for a clock that went backwards", function()
			local player, data =
				join({ Board = S.fill("PlainClack", 3), IncomeAt = world.now + 500, Cash = 7 })
			Keyboard:Settle(player)
			expect(data.Cash):toBe(7)
			expect(data.IncomeAt):toBe(world.now + 500)
		end)

		it("includes the income perk multiplier", function()
			local board = S.board("GoldPlate", "PlainClack")
			local player, data = join({ Board = board, IncomeAt = world.now - 10 })
			Keyboard:Settle(player)
			expect(data.Cash):toBe(math.floor((Keys.GetIncome("GoldPlate") + 1) * 1.25) * 10)
		end)

		it("caps cash at the safe-integer maximum", function()
			local player, data =
				join({ Board = S.fill("LavaKey", 10), IncomeAt = world.now - 1e6, Cash = maxCash - 5 })
			Keyboard:Settle(player)
			expect(data.Cash):toBe(maxCash)
		end)

		it("does nothing for a player without data", function()
			local player = world:newPlayer()
			Keyboard:Settle(player)
			expect(world.Data.Service:GetData(player)):toBeNil()
		end)

		it("is run periodically for every online player", function()
			local a, dataA = join({ Board = S.fill("PlainClack", 2), IncomeAt = world.now })
			local b, dataB = join({ Board = S.fill("CreamyThock", 1), IncomeAt = world.now })
			expect(a ~= b):toBe(true)
			world:advance(GameConfig.SettleIntervalSeconds + 1)
			expect(dataA.Cash):toBe(2 * GameConfig.SettleIntervalSeconds)
			expect(dataB.Cash):toBe(Keys.GetIncome("CreamyThock") * GameConfig.SettleIntervalSeconds)
		end)

		it("settles a leaving player's pending earnings into their data", function()
			local player, data = join({
				Board = S.fill("PlainClack", 5),
				Upgrades = levelsFor(5),
				IncomeAt = world.now,
			})
			world:setTime(world.now + 30)
			world:removePlayer(player)
			expect(data.Cash):toBe(5 * Keys.GetIncome("PlainClack") * 30)
			expect(data.IncomeAt):toBe(world.now)
		end)
	end)

	describe("offline earnings", function()
		it("pays OfflineRate of the board rate for the time away", function()
			local _, data = join({
				Board = S.fill("PlainClack", 4),
				Upgrades = levelsFor(4),
				IncomeAt = world.now - 1000,
				Cash = 10,
			}, true)
			local rate = 4 * Keys.GetIncome("PlainClack")
			expect(data.Cash):toBe(10 + math.floor(rate * 1000 * GameConfig.OfflineRate))
			expect(data.IncomeAt):toBe(world.now)
		end)

		it("caps the time away at OfflineCapSeconds", function()
			local _, data = join({
				Board = S.fill("PlainClack", 4),
				Upgrades = levelsFor(4),
				IncomeAt = world.now - 10 * 86400,
			}, true)
			local rate = 4 * Keys.GetIncome("PlainClack")
			expect(data.Cash):toBe(math.floor(rate * GameConfig.OfflineCapSeconds * GameConfig.OfflineRate))
		end)

		it("pays nothing for a first session or a future timestamp", function()
			local _, fresh = join({ Board = S.fill("PlainClack", 4), IncomeAt = 0 }, true)
			expect(fresh.Cash):toBe(0)
			expect(fresh.IncomeAt):toBe(world.now)
			local _, future = join({ Board = S.fill("PlainClack", 4), IncomeAt = world.now + 9999 }, true)
			expect(future.Cash):toBe(0)
			expect(future.IncomeAt):toBe(world.now)
		end)

		it("uses only unlocked slots for the rate", function()
			local unlocked = Stats.Slots({})
			local _, data = join(
				{ Board = S.fill("PlainClack", GameConfig.BoardSlots), IncomeAt = world.now - 100 },
				true
			)
			expect(data.Cash):toBe(math.floor(unlocked * 100 * GameConfig.OfflineRate))
		end)

		it("announces the loaded board", function()
			local fired = 0
			Keyboard.BoardChanged:Connect(function()
				fired += 1
			end)
			join(nil, true)
			expect(fired):toBe(1)
		end)
	end)

	describe("normalize on load", function()
		it("moves keys on locked slots into the inventory without losing any", function()
			local unlocked = Stats.Slots({})
			local board = S.fill("PlainClack", GameConfig.BoardSlots)
			board[GameConfig.BoardSlots] = "GlassTink"
			local before = S.totals({ Board = board, Inventory = { GlassTink = 1 } })
			local _, data = join({ Board = board, Inventory = { GlassTink = 1 } }, true)
			local placed = 0
			for index = 1, GameConfig.BoardSlots do
				if data.Board[index] ~= "" then
					placed += 1
					expect(index <= unlocked):toBe(true)
				end
			end
			expect(placed):toBe(unlocked)
			expect(S.totals(data)):toEqual(before)
		end)

		it("repairs short boards and rescues keys stored past the board end", function()
			local board: any = { "PlainClack", "", [61] = "CreamyThock", [99] = "Bogus" }
			local _, data = join({ Board = board }, true)
			expect(#data.Board):toBe(GameConfig.BoardSlots)
			expect(data.Board[61]):toBeNil()
			expect(S.totals(data)):toEqual({ PlainClack = 1, CreamyThock = 1 })
			expect(data.Inventory.Bogus):toBeNil()
		end)

		it("shrinks a 60-slot save to the best keys without losing any", function()
			local board: any = S.fill("PlainClack", 60)
			board[10] = "LavaKey"
			board[33] = "GlassTink"
			board[60] = "CreamyThock"
			local tags: any = S.fill("", 60)
			tags[40] = "@Old"
			local upgrades = levelsFor(5)
			local save = { Board = board, BoardTags = tags, Inventory = { GlassTink = 2 }, Upgrades = upgrades }
			local before = S.totals(save)
			local _, data = join(save, true)
			local unlocked = Stats.Slots(upgrades)
			expect(unlocked > 3):toBe(true)
			expect(#data.Board):toBe(GameConfig.BoardSlots)
			expect(#data.BoardTags):toBe(GameConfig.BoardSlots)
			expect(data.Board[GameConfig.BoardSlots + 1]):toBeNil()
			expect(S.totals(data)):toEqual(before)
			local placed: { string } = {}
			for index = 1, GameConfig.BoardSlots do
				expect(data.BoardTags[index]):toBe("")
				if data.Board[index] ~= "" then
					expect(index <= unlocked):toBe(true)
					table.insert(placed, data.Board[index])
				end
			end
			expect(#placed):toBe(unlocked)
			local onBoard = {}
			for _, keyId in placed do
				onBoard[keyId] = (onBoard[keyId] or 0) + 1
			end
			expect(onBoard.LavaKey):toBe(1)
			expect(onBoard.GlassTink):toBe(1)
			expect(onBoard.CreamyThock):toBe(1)
			expect(onBoard.PlainClack):toBe(unlocked - 3)
		end)

		it("pads a 30-slot save to BoardSlots for both Board and BoardTags", function()
			local board: any = S.fill("", 30)
			board[1] = "PlainClack"
			local tags: any = S.fill("", 30)
			tags[1] = "@Zed"
			local _, data = join({ Board = board, BoardTags = tags }, true)
			expect(#data.Board):toBe(GameConfig.BoardSlots)
			expect(#data.BoardTags):toBe(GameConfig.BoardSlots)
			for index = 1, GameConfig.BoardSlots do
				expect(type(data.Board[index])):toBe("string")
				expect(type(data.BoardTags[index])):toBe("string")
			end
			expect(data.Board[1]):toBe("PlainClack")
			expect(data.BoardTags[1]):toBe("@Zed")
			expect(data.BoardTags[GameConfig.BoardSlots]):toBe("")
		end)

		it("pads a missing or short BoardTags and clears tags on locked slots", function()
			local board: any = S.fill("", 30)
			board[25] = "GlassTink"
			local tags: any = S.fill("", 30)
			tags[25] = "@Old"
			local _, data = join({ Board = board, BoardTags = tags }, true)
			expect(data.Board[25]):toBeNil()
			expect(data.BoardTags[25]):toBeNil()
			for index = 1, GameConfig.BoardSlots do
				expect(data.BoardTags[index]):toBe("")
			end
			expect(#data.BoardTags):toBe(GameConfig.BoardSlots)
			local _, other = join({ Board = S.board("PlainClack"), BoardTags = {} }, true)
			expect(#other.BoardTags):toBe(GameConfig.BoardSlots)
		end)

		it("leaves a valid board untouched", function()
			local player, data = join({ Board = S.board("PlainClack") }, true)
			local replica = world.Data:Replica(player)
			for _, entry in replica.Log do
				expect(entry.Path[1] == "Board"):toBe(false)
			end
			expect(data.Board[1]):toBe("PlainClack")
		end)
	end)

	describe("AddKey", function()
		local function add(player: any, keyId: string)
			return Keyboard:AddKey(player, keyId)
		end

		it("auto-places into the first empty slot", function()
			local player, data = join({ Board = S.board("PlainClack", "", "CreamyThock") })
			local changed = 0
			Keyboard.BoardChanged:Connect(function()
				changed += 1
			end)
			expect(add(player, "GlassTink")):toBe(true)
			expect(data.Board[2]):toBe("GlassTink")
			expect(next(data.Inventory)):toBeNil()
			expect(changed):toBe(1)
		end)

		it("rejects unknown keys and players without data", function()
			local player, data = join()
			expect(add(player, "Bogus")):toBe(false)
			expect(next(data.Inventory)):toBeNil()
			expect(add(world:newPlayer(), "PlainClack")):toBe(false)
		end)

		it("swaps out the lowest-income key when the board is full", function()
			local board = S.fill("CreamyThock", GameConfig.BoardSlots)
			board[4] = "PlainClack"
			local player, data = join({ Board = board, Upgrades = maxedUpgrades() })
			expect(add(player, "GlassTink")):toBe(true)
			expect(data.Board[4]):toBe("GlassTink")
			expect(data.Inventory.PlainClack):toBe(1)
		end)

		it("displaces the first of several equally weak keys", function()
			local board = S.fill("CreamyThock", GameConfig.BoardSlots)
			board[3] = "PlainClack"
			board[7] = "PlainClack"
			local player, data = join({ Board = board, Upgrades = maxedUpgrades() })
			add(player, "GlassTink")
			expect(data.Board[3]):toBe("GlassTink")
			expect(data.Board[7]):toBe("PlainClack")
		end)

		it("stores keys that are not better than the weakest slot", function()
			local player, data = join({ Board = S.fill("CreamyThock", GameConfig.BoardSlots), Upgrades = maxedUpgrades() })
			expect(add(player, "PlainClack")):toBe(true)
			expect(add(player, "CreamyThock")):toBe(true)
			expect(data.Inventory.PlainClack):toBe(1)
			expect(data.Inventory.CreamyThock):toBe(1)
			for index = 1, GameConfig.BoardSlots do
				expect(data.Board[index]):toBe("CreamyThock")
			end
		end)

		it("never displaces perk keys", function()
			local board = S.fill("CloverCap", GameConfig.BoardSlots)
			local player, data = join({ Board = board, Upgrades = maxedUpgrades() })
			expect(add(player, "LavaKey")):toBe(true)
			expect(data.Inventory.LavaKey):toBe(1)
			for index = 1, GameConfig.BoardSlots do
				expect(data.Board[index]):toBe("CloverCap")
			end
		end)

		it("skips a low-income perk key to displace a plain key instead", function()
			local board = S.fill("CreamyThock", GameConfig.BoardSlots)
			board[1] = "CloverCap"
			board[2] = "PlainClack"
			local player, data = join({ Board = board, Upgrades = maxedUpgrades() })
			add(player, "GlassTink")
			expect(data.Board[1]):toBe("CloverCap")
			expect(data.Board[2]):toBe("GlassTink")
			expect(data.Inventory.PlainClack):toBe(1)
		end)

		it("never auto-places a perk key over an occupied slot", function()
			local player, data = join({ Board = S.fill("PlainClack", GameConfig.BoardSlots), Upgrades = maxedUpgrades() })
			expect(add(player, "FourLeafArtisan")):toBe(true)
			expect(data.Inventory.FourLeafArtisan):toBe(1)
			expect(data.Board[1]):toBe("PlainClack")
		end)

		it("does place a perk key into an empty slot", function()
			local player, data = join()
			add(player, "GoldPlate")
			expect(data.Board[1]):toBe("GoldPlate")
		end)

		it("only considers unlocked slots", function()
			local locked = GameConfig.BoardSlots - GameConfig.BaseSlots
			local player, data = join({ Board = S.fill("PlainClack", GameConfig.BoardSlots) }, true)
			add(player, "CreamyThock")
			expect(data.Board[GameConfig.BaseSlots + 1]):toBe("")
			expect(data.Board[1]):toBe("CreamyThock")
			expect(data.Inventory.PlainClack):toBe(locked + 1)
		end)

		it("uses the newly unlocked slots after a Slots upgrade", function()
			local base = GameConfig.BaseSlots
			local player, data = join({ Board = S.fill("PlainClack", base), Upgrades = { Slots = 1 } })
			add(player, "PlainClack")
			expect(data.Board[base + 1]):toBe("PlainClack")
		end)

		it("sends everything to the inventory when AutoPlace is off", function()
			local player, data = join({ Settings = { AutoPlace = false } })
			add(player, "LavaKey")
			add(player, "LavaKey")
			expect(data.Inventory.LavaKey):toBe(2)
			expect(data.Board[1]):toBe("")
		end)

		it("settles earnings before changing the board", function()
			local base = GameConfig.BaseSlots
			local player, data = join({ Board = S.fill("PlainClack", base), IncomeAt = world.now - 10 })
			add(player, "LavaKey")
			expect(data.Cash):toBe(base * 10)
		end)

		it("requests a save only for announced rarities", function()
			local player = join()
			add(player, "PlainClack")
			expect(world.saves[player]):toBeNil()
			add(player, "ThunderKey")
			expect(world.saves[player]):toBe(1)
		end)

		it("conserves key counts across many random additions", function()
			local player, data = join()
			local rng = world.Random.new(9)
			local added: { [string]: number } = {}
			for _ = 1, 300 do
				local key = Keys.Catalog[rng:NextInteger(1, #Keys.Catalog)]
				add(player, key.Id)
				added[key.Id] = (added[key.Id] or 0) + 1
			end
			expect(S.totals(data)):toEqual(added)
		end)
	end)

	describe("PlaceKey", function()
		local function place(player: any, slot: any, keyId: any)
			return world:invoke("PlaceKey", player, slot, keyId)
		end

		it("moves a key from the inventory into the slot", function()
			local player, data = join({ Inventory = { GlassTink = 2 } })
			expect(place(player, 3, "GlassTink")):toBe(true)
			expect(data.Board[3]):toBe("GlassTink")
			expect(data.Inventory.GlassTink):toBe(1)
		end)

		it("removes the inventory entry when the last copy is placed", function()
			local player, data = join({ Inventory = { GlassTink = 1 } })
			place(player, 1, "GlassTink")
			expect(data.Inventory.GlassTink):toBeNil()
		end)

		it("returns the replaced key to the inventory", function()
			local player, data = join({ Board = S.board("PlainClack"), Inventory = { GlassTink = 1 } })
			expect(place(player, 1, "GlassTink")):toBe(true)
			expect(data.Board[1]):toBe("GlassTink")
			expect(data.Inventory.PlainClack):toBe(1)
		end)

		it("conserves counts when placing a key over an identical one", function()
			local player, data = join({ Board = S.board("PlainClack"), Inventory = { PlainClack = 2 } })
			local before = S.totals(data)
			expect(place(player, 1, "PlainClack")):toBe(true)
			expect(S.totals(data)):toEqual(before)
			expect(data.Inventory.PlainClack):toBe(2)
		end)

		it("fires BoardChanged and settles first", function()
			local player, data = join({
				Inventory = { GlassTink = 1 },
				Board = S.fill("PlainClack", 1),
				IncomeAt = world.now - 5,
			})
			local changed = 0
			Keyboard.BoardChanged:Connect(function()
				changed += 1
			end)
			place(player, 2, "GlassTink")
			expect(changed):toBe(1)
			expect(data.Cash):toBe(5)
		end)

		it("accepts the newly unlocked slot range after an upgrade", function()
			local maxed = { Slots = Upgrades.ById.Slots.MaxLevel }
			local slot = Stats.Slots(maxed)
			local player, data = join({ Inventory = { GlassTink = 1 }, Upgrades = maxed })
			expect(place(player, slot, "GlassTink")):toBe(true)
			expect(data.Board[slot]):toBe("GlassTink")
		end)

		it("rejects invalid input without touching data", function()
			local player, data = join({ Inventory = { GlassTink = 1 }, Board = S.board("PlainClack") })
			local before = S.snapshot(data)
			local cases: { { any } } = {
				{ 0, "GlassTink" },
				{ -1, "GlassTink" },
				{ 11, "GlassTink" },
				{ 31, "GlassTink" },
				{ 1.5, "GlassTink" },
				{ S.nan(), "GlassTink" },
				{ math.huge, "GlassTink" },
				{ -math.huge, "GlassTink" },
				{ "1", "GlassTink" },
				{ nil, "GlassTink" },
				{ {}, "GlassTink" },
				{ true, "GlassTink" },
				{ 1, 5 },
				{ 1, nil },
				{ 1, "Bogus" },
				{ 1, "" },
				{ 1, "LavaKey" },
				{ 2, "PlainClack" },
			}
			for _, case in cases do
				expect(place(player, case[1], case[2])):toBe(false)
				expect(data):toEqual(before)
			end
		end)

		it("rejects every slot past BoardSlots even with every slot unlocked", function()
			local player, data = join({
				Inventory = { GlassTink = 3 },
				Upgrades = { Slots = Upgrades.ById.Slots.MaxLevel },
			})
			local before = S.snapshot(data)
			for _, slot in { GameConfig.BoardSlots + 1, GameConfig.BoardSlots + 2, 60, 255 } do
				expect(place(player, slot, "GlassTink")):toBe(false)
			end
			expect(data):toEqual(before)
		end)

		it("fails for players without data", function()
			expect(place(world:newPlayer(), 1, "PlainClack")):toBe(false)
		end)
	end)

	describe("ClearSlot", function()
		local function clear(player: any, slot: any)
			return world:invoke("ClearSlot", player, slot)
		end

		it("returns the slot's key to the inventory", function()
			local player, data =
				join({ Board = S.board("PlainClack", "GlassTink"), Inventory = { GlassTink = 1 } })
			expect(clear(player, 2)):toBe(true)
			expect(data.Board[2]):toBe("")
			expect(data.Inventory.GlassTink):toBe(2)
		end)

		it("rejects empty slots, bad slots and locked slots", function()
			local board = S.board("PlainClack")
			local player, data = join({ Board = board })
			local before = S.snapshot(data)
			for _, slot in { 2, 0, -3, 11, GameConfig.BoardSlots + 1, 60, 1.5, S.nan(), math.huge, "1", {}, true } do
				expect(clear(player, slot)):toBe(false)
			end
			expect(clear(player, nil)):toBe(false)
			expect(data):toEqual(before)
		end)

		it("settles earnings before the key leaves the board", function()
			local player, data = join({ Board = S.board("PlainClack"), IncomeAt = world.now - 10 })
			clear(player, 1)
			expect(data.Cash):toBe(10)
			expect(data.IncomeAt):toBe(world.now)
		end)
	end)

	describe("SellKey", function()
		local function sell(player: any, keyId: any, count: any)
			return world:invoke("SellKey", player, keyId, count)
		end

		it("pays the sell value per key and removes them", function()
			local player, data = join({ Inventory = { GlassTink = 5 }, Cash = 3 })
			expect(sell(player, "GlassTink", 3)):toBe(true)
			expect(data.Cash):toBe(3 + Keys.GetSellValue("GlassTink") * 3)
			expect(data.Inventory.GlassTink):toBe(2)
		end)

		it("removes the inventory entry when everything is sold", function()
			local player, data = join({ Inventory = { PlainClack = 2 } })
			sell(player, "PlainClack", 2)
			expect(data.Inventory.PlainClack):toBeNil()
			expect(data.Cash):toBe(Keys.GetSellValue("PlainClack") * 2)
		end)

		it("does not sell keys that are on the board", function()
			local player, data = join({ Board = S.board("PlainClack"), Inventory = {} })
			expect(sell(player, "PlainClack", 1)):toBe(false)
			expect(data.Board[1]):toBe("PlainClack")
			expect(data.Cash):toBe(0)
		end)

		it("rejects invalid input without touching data", function()
			local player, data = join({ Inventory = { GlassTink = 2 } })
			local before = S.snapshot(data)
			local cases: { { any } } = {
				{ "GlassTink", 0 },
				{ "GlassTink", -1 },
				{ "GlassTink", 3 },
				{ "GlassTink", 1.5 },
				{ "GlassTink", S.nan() },
				{ "GlassTink", math.huge },
				{ "GlassTink", "1" },
				{ "GlassTink", nil },
				{ "Bogus", 1 },
				{ "PlainClack", 1 },
				{ 5, 1 },
				{ nil, 1 },
			}
			for _, case in cases do
				expect(sell(player, case[1], case[2])):toBe(false)
				expect(data):toEqual(before)
			end
		end)

		it("settles first and caps cash at the safe-integer maximum", function()
			local player, data = join({ Inventory = { LavaKey = 1 }, Cash = maxCash - 1 })
			expect(sell(player, "LavaKey", 1)):toBe(true)
			expect(data.Cash):toBe(maxCash)
			local player2, data2 = join({
				Inventory = { PlainClack = 1 },
				Board = S.fill("PlainClack", 2),
				IncomeAt = world.now - 10,
			})
			sell(player2, "PlainClack", 1)
			expect(data2.Cash):toBe(20 + Keys.GetSellValue("PlainClack"))
		end)
	end)

	describe("EquipBest", function()
		local function equip(player: any)
			return world:invoke("EquipBest", player)
		end

		it("fills slots by income and keeps the rest in the inventory", function()
			local player, data = join({
				Board = S.board("LavaKey"),
				Inventory = { PlainClack = 8, CreamyThock = 3, GlassTink = 2, CloverCap = 1 },
				Upgrades = levelsFor(GameConfig.BoardSlots),
			})
			local before = S.totals(data)
			expect(equip(player)):toBe(true)
			local expected = {
				"LavaKey",
				"GlassTink",
				"GlassTink",
				"CloverCap",
				"CreamyThock",
				"CreamyThock",
				"CreamyThock",
			}
			for index = #expected + 1, GameConfig.BoardSlots do
				expected[index] = "PlainClack"
			end
			expect(boardKeys(data)):toEqual(expected)
			expect(data.Inventory):toEqual({ PlainClack = 8 - (GameConfig.BoardSlots - 7) })
			expect(S.totals(data)):toEqual(before)
		end)

		it("ranks perk keys ahead of plain keys of equal income, then by catalog order", function()
			local player, data = join({ Inventory = { CreamyThock = 1, MintLinear = 1, CloverCap = 1 } })
			equip(player)
			expect({ data.Board[1], data.Board[2], data.Board[3] }):toEqual({
				"CloverCap",
				"CreamyThock",
				"MintLinear",
			})
		end)

		it("pulls board keys into the ranking so a weaker board is rebuilt", function()
			local player, data = join({
				Board = S.fill("PlainClack", GameConfig.BoardSlots),
				Inventory = { GlassTink = 4 },
				Upgrades = levelsFor(GameConfig.BoardSlots),
			})
			local before = S.totals(data)
			equip(player)
			for index = 1, 4 do
				expect(data.Board[index]):toBe("GlassTink")
			end
			expect(data.Board[5]):toBe("PlainClack")
			expect(S.totals(data)):toEqual(before)
			expect(data.Inventory):toEqual({ PlainClack = 4 })
		end)

		it("fills only the unlocked slots", function()
			local base = GameConfig.BaseSlots
			local player, data = join({ Inventory = { PlainClack = 30 } })
			equip(player)
			for index = base + 1, GameConfig.BoardSlots do
				expect(data.Board[index]):toBe("")
			end
			expect(data.Inventory.PlainClack):toBe(30 - base)
			local upgraded = { Slots = Upgrades.ById.Slots.MaxLevel }
			local unlocked = Stats.Slots(upgraded)
			local player2, data2 = join({ Inventory = { PlainClack = 30 }, Upgrades = upgraded })
			equip(player2)
			expect(data2.Board[unlocked]):toBe("PlainClack")
			expect(data2.Board[unlocked + 1]):toBeNil()
			expect(data2.Inventory.PlainClack):toBe(30 - unlocked)
		end)

		it("is a harmless no-op with nothing to equip and idempotent afterwards", function()
			local player, data = join()
			expect(equip(player)):toBe(true)
			expect(S.totals(data)):toEqual({})
			data.Inventory.GlassTink = 2
			equip(player)
			local once = S.snapshot(data)
			equip(player)
			expect(data):toEqual(once)
		end)

		it("fires BoardChanged", function()
			local player = join()
			local changed = 0
			Keyboard.BoardChanged:Connect(function()
				changed += 1
			end)
			equip(player)
			expect(changed):toBe(1)
		end)

		it("fails without data", function()
			expect(equip(world:newPlayer())):toBe(false)
		end)

		it("conserves counts for a large random inventory", function()
			local rng = world.Random.new(21)
			local inventory = {}
			for _, key in Keys.Catalog do
				inventory[key.Id] = rng:NextInteger(1, 6)
			end
			local player, data = join({ Inventory = inventory, Board = S.board("PlainClack", "GoldPlate") })
			local before = S.totals(data)
			equip(player)
			expect(S.totals(data)):toEqual(before)
		end)
	end)

	describe("GetRate", function()
		it("returns the board rate, or 0 without data", function()
			local player = join({ Board = S.board("PlainClack", "GlassTink") })
			expect(Keyboard:GetRate(player)):toBe(Keys.GetIncome("PlainClack") + Keys.GetIncome("GlassTink"))
			expect(Keyboard:GetRate(world:newPlayer())):toBe(0)
		end)
	end)
end)
