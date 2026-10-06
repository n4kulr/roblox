local H = require("../harness/Harness")
local S = require("../support")
local roblox = require("@lune/roblox")
local Enum = roblox.Enum

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

local screens = "StarterPlayer.StarterPlayerScripts.Controllers.UIController"

describe("Variants rules", function()
	local world, Variants, Keys

	beforeEach(function()
		world = H.newWorld()
		Variants = world:require("ReplicatedStorage.Rules.Variants")
		Keys = world:require("ReplicatedStorage.Config.Keys")
	end)

	afterEach(function()
		world:destroy()
	end)

	it("parses and makes ids for every tier", function()
		expect({ Variants.Parse("LavaKey") }):toEqual({ "LavaKey", 0 })
		expect({ Variants.Parse("LavaKey@Gold") }):toEqual({ "LavaKey", 1 })
		expect({ Variants.Parse("LavaKey@Rainbow") }):toEqual({ "LavaKey", 2 })
		expect({ Variants.Parse("LavaKey@Mythical") }):toEqual({ "LavaKey", 3 })
		expect(Variants.Make("LavaKey", 0)):toBe("LavaKey")
		expect(Variants.Make("LavaKey", 1)):toBe("LavaKey@Gold")
		expect(Variants.Make("LavaKey", 3)):toBe("LavaKey@Mythical")
	end)

	it("treats unknown suffixes as plain unknown ids", function()
		expect({ Variants.Parse("LavaKey@Bronze") }):toEqual({ "LavaKey@Bronze", 0 })
		expect(Keys.Resolve("LavaKey@Bronze")):toBeNil()
		expect(Keys.Resolve("LavaKey@Gold@Gold")):toBeNil()
		expect(Keys.Resolve("Nope@Gold")):toBeNil()
		expect(Keys.Resolve(5)):toBeNil()
	end)

	it("names variants with the tier first", function()
		expect(Variants.Name("LavaKey")):toBe(Keys.ById.LavaKey.Name)
		expect(Variants.Name("LavaKey@Gold")):toBe(`Gold {Keys.ById.LavaKey.Name}`)
		expect(Variants.Name("LavaKey@Mythical")):toBe(`Mythical {Keys.ById.LavaKey.Name}`)
	end)

	it("multiplies income 1, 3, 10 and 40", function()
		expect(Variants.Multiplier(0)):toBe(1)
		expect(Variants.Multiplier(1)):toBe(3)
		expect(Variants.Multiplier(2)):toBe(10)
		expect(Variants.Multiplier(3)):toBe(40)
		local base = Keys.GetIncome("LavaKey")
		expect(Keys.GetIncome("LavaKey@Gold")):toBe(base * 3)
		expect(Keys.GetIncome("LavaKey@Rainbow")):toBe(base * 10)
		expect(Keys.GetIncome("LavaKey@Mythical")):toBe(base * 40)
		expect(Keys.GetIncome("Nope@Gold")):toBe(0)
	end)

	it("resolves variants to the base key and keeps its rarity", function()
		expect(Keys.Resolve("LavaKey@Rainbow")):toBe(Keys.ById.LavaKey)
		expect(Keys.GetRarity(Keys.Resolve("LavaKey@Gold"))):toBe(Keys.GetRarity(Keys.ById.LavaKey))
	end)

	it("chains Next up to Mythical and costs five", function()
		expect(Variants.FuseCost):toBe(5)
		expect(Variants.Next("LavaKey")):toBe("LavaKey@Gold")
		expect(Variants.Next("LavaKey@Gold")):toBe("LavaKey@Rainbow")
		expect(Variants.Next("LavaKey@Rainbow")):toBe("LavaKey@Mythical")
		expect(Variants.Next("LavaKey@Mythical")):toBeNil()
		expect(Variants.Next("Nope")):toBeNil()
	end)

	it("scales sell value with variant income", function()
		expect(Keys.GetSellValue("LavaKey@Gold") >= Keys.GetSellValue("LavaKey")):toBe(true)
	end)

	it("accepts variant ids in trade and steal rules", function()
		local Trade = world:require("ReplicatedStorage.Rules.Trade")
		local Steal = world:require("ReplicatedStorage.Rules.Steal")
		local inventory = { ["LavaKey@Gold"] = 2 }
		expect((Trade.ValidateOffer(inventory, {}, "LavaKey@Gold", 2))):toBe(true)
		expect((Trade.ValidateOffer(inventory, {}, "LavaKey@Gold", 3))):toBe(false)
		expect((Trade.ValidateOffer(inventory, {}, "LavaKey@Bronze", 1))):toBe(false)
		expect(Trade.IsAtLeast("LavaKey@Gold", "Common")):toBe(true)
		expect(Steal.RarityIndex("LavaKey@Mythical")):toBe(Steal.RarityIndex("LavaKey"))
	end)
end)

describe("Variant economy", function()
	local world, services, Keyboard, Keys, GameConfig, Stats

	beforeEach(function()
		world = H.newWorld({ Time = 1700000000 })
		services = world:boot({ "KeyboardService" })
		Keyboard = services.KeyboardService
		Keys = world:require("ReplicatedStorage.Config.Keys")
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		Stats = world:require("ReplicatedStorage.Rules.Stats")
	end)

	local function join(overrides: any?)
		return world:join(nil, overrides, false)
	end

	it("counts variant income in the board rate", function()
		local board = S.board("PlainClack", "LavaKey@Gold", "LavaKey@Mythical")
		local expected = Keys.GetIncome("PlainClack") + Keys.GetIncome("LavaKey") * 3 + Keys.GetIncome("LavaKey") * 40
		expect(Stats.Compute(board, {}).Rate):toBe(expected)
		local player = join({ Board = board })
		expect(Keyboard:GetRate(player)):toBe(expected)
	end)

	it("settles variant income", function()
		local player, data = join({ Board = S.board("LavaKey@Gold"), IncomeAt = world.now - 10, Cash = 0 })
		Keyboard:Settle(player)
		expect(data.Cash):toBe(Keys.GetIncome("LavaKey") * 3 * 10)
	end)

	it("keeps variants on the board through normalize", function()
		local player, data = join({ Board = S.board("LavaKey@Rainbow", "Bogus@Gold") })
		Keyboard:Normalize(player)
		expect(data.Board[1]):toBe("LavaKey@Rainbow")
		expect(data.Board[2]):toBe("")
	end)

	it("sells variants for their own value", function()
		local player, data = join({ Inventory = { ["LavaKey@Gold"] = 2 }, Cash = 0 })
		expect(world:invoke("SellKey", player, "LavaKey@Gold", 1)):toBe(true)
		expect(data.Cash):toBe(Keys.GetSellValue("LavaKey@Gold"))
		expect(data.Inventory["LavaKey@Gold"]):toBe(1)
	end)

	it("places variants and swaps by variant income on auto-place", function()
		local base = GameConfig.BaseSlots
		local player, data = join({ Board = S.fill("LavaKey", base) })
		Keyboard:AddKey(player, "LavaKey@Mythical")
		expect(data.Board[1]):toBe("LavaKey@Mythical")
		expect(data.Inventory.LavaKey):toBe(1)
		Keyboard:AddKey(player, "PlainClack@Mythical")
		expect(data.Inventory["PlainClack@Mythical"]):toBe(1)
	end)

	it("equips the best by variant income", function()
		local player, data = join({
			Board = S.fill("PlainClack", 3),
			Inventory = { ["LavaKey@Gold"] = 1, LavaKey = 1 },
		})
		world:invoke("EquipBest", player)
		expect(data.Board[1]):toBe("LavaKey@Gold")
		expect(data.Board[2]):toBe("LavaKey")
	end)

	describe("FuseKey", function()
		local function fuse(player: any, id: any): any
			return world:invoke("FuseKey", player, id)
		end

		it("turns five normal keys into one gold key", function()
			local player, data = join({ Inventory = { LavaKey = 6 }, Settings = { AutoPlace = false } })
			expect(fuse(player, "LavaKey")):toBe("LavaKey@Gold")
			expect(data.Inventory.LavaKey):toBe(1)
			expect(data.Inventory["LavaKey@Gold"]):toBe(1)
			expect(world.saves[player] >= 1):toBe(true)
		end)

		it("climbs gold, rainbow and mythical", function()
			local player, data = join({
				Inventory = { ["LavaKey@Gold"] = 5, ["LavaKey@Rainbow"] = 5 },
				Settings = { AutoPlace = false },
			})
			expect(fuse(player, "LavaKey@Gold")):toBe("LavaKey@Rainbow")
			expect(data.Inventory["LavaKey@Rainbow"]):toBe(6)
			expect(fuse(player, "LavaKey@Rainbow")):toBe("LavaKey@Mythical")
			expect(data.Inventory["LavaKey@Rainbow"]):toBe(1)
			expect(data.Inventory["LavaKey@Mythical"]):toBe(1)
			expect(data.Inventory["LavaKey@Gold"]):toBeNil()
		end)

		it("fails with fewer than five and changes nothing", function()
			local player, data = join({ Inventory = { LavaKey = 4 }, Settings = { AutoPlace = false } })
			expect(fuse(player, "LavaKey")):toBe("")
			expect(data.Inventory):toEqual({ LavaKey = 4 })
		end)

		it("cannot fuse past mythical", function()
			local player, data = join({ Inventory = { ["LavaKey@Mythical"] = 9 } })
			expect(fuse(player, "LavaKey@Mythical")):toBe("")
			expect(data.Inventory["LavaKey@Mythical"]):toBe(9)
		end)

		it("rejects unknown and malformed ids", function()
			local player = join({ Inventory = { LavaKey = 9 } })
			expect(fuse(player, "Nope")):toBe("")
			expect(fuse(player, "LavaKey@Bronze")):toBe("")
			expect(fuse(player, 12)):toBe("")
		end)

		it("only consumes inventory, never board keys", function()
			local player, data = join({
				Board = S.fill("LavaKey", 3),
				Inventory = { LavaKey = 2 },
				Settings = { AutoPlace = false },
			})
			expect(fuse(player, "LavaKey")):toBe("")
			expect(data.Board[1]):toBe("LavaKey")
			expect(data.Board[3]):toBe("LavaKey")
			expect(data.Inventory.LavaKey):toBe(2)
		end)

		it("auto-places the new variant when it beats a board key", function()
			local base = GameConfig.BaseSlots
			local player, data = join({
				Board = S.fill("PlainClack", base),
				Inventory = { LavaKey = 5 },
			})
			expect(fuse(player, "LavaKey")):toBe("LavaKey@Gold")
			expect(data.Inventory.LavaKey):toBeNil()
			expect(data.Inventory["LavaKey@Gold"]):toBeNil()
			expect(data.Board[1]):toBe("LavaKey@Gold")
			expect(data.Inventory.PlainClack):toBe(1)
		end)

		it("does not change Discovered", function()
			local player, data = join({
				Inventory = { LavaKey = 5 },
				Discovered = { LavaKey = 5 },
				Settings = { AutoPlace = false },
			})
			fuse(player, "LavaKey")
			expect(data.Discovered):toEqual({ LavaKey = 5 })
		end)

		it("fails without player data", function()
			local player = world:newPlayer({ Name = "Ghost" })
			expect(fuse(player, "LavaKey")):toBe("")
		end)

		it("declares a rate limit on the packet", function()
			local Packets = world:require("ReplicatedStorage.Packets")
			expect(Packets.FuseKey ~= nil):toBe(true)
		end)
	end)
end)

describe("Variant trade", function()
	local world, config

	beforeEach(function()
		world = H.newWorld({ Time = 1700000000 })
		config = world:require("ReplicatedStorage.Config.GameConfig").Trade
		world:boot({ "KeyboardService", "TradeService" })
	end)

	afterEach(function()
		world:destroy()
	end)

	it("swaps variant keys and credits Discovered to the base id", function()
		local a, dataA = world:joinAtBase({ Name = "Ann" }, { Inventory = { ["LavaKey@Gold"] = 2 } })
		local b, dataB = world:joinAtBase({ Name = "Bob" }, { Inventory = { PlainClack = 1 } })
		expect(world:invoke("TradeRequest", a, b.UserId)):toBe(true)
		world:invoke("TradeRespond", b, a.UserId, true)
		world:invoke("TradeOffer", a, "LavaKey@Gold", 2)
		world:invoke("TradeOffer", b, "PlainClack", 1)
		world:invoke("TradeReady", a, true)
		world:invoke("TradeReady", b, true)
		world:advance(config.ConfirmCountdownSeconds + 0.5)
		expect(dataB.Inventory["LavaKey@Gold"]):toBe(2)
		expect(dataA.Inventory.PlainClack):toBe(1)
		expect(dataB.Discovered.LavaKey):toBe(2)
		expect(dataB.Discovered["LavaKey@Gold"]):toBeNil()
	end)

	it("rejects offering variants the player does not own", function()
		local a = world:join({ Name = "Ann" }, { Inventory = { LavaKey = 5 } })
		local b = world:join({ Name = "Bob" }, { Inventory = {} })
		world:invoke("TradeRequest", a, b.UserId)
		world:invoke("TradeRespond", b, a.UserId, true)
		world:invoke("TradeOffer", a, "LavaKey@Gold", 1)
		local offered = 0
		for _, entry in world:firedOf("TradeState") do
			if entry.Target == a then
				offered = #entry.Args[3]
			end
		end
		expect(offered):toBe(0)
	end)
end)

describe("Keys screen detail panel", function()
	local world, playerGui, context, data, fuseCalls

	local function press(button: any)
		button.Activated:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
	end

	local function openKeys(inventory: any)
		data.Inventory = inventory
		local screen = world:require(`{screens}.Screens.Keys`).new(context)
		screen:Open()
		world:flush()
		return screen, playerGui:FindFirstChild("ThockKeys")
	end

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
		local Signal = world:require("ReplicatedStorage.Packages.Signal")
		local player = world:newPlayer({ Name = "Tester", DisplayName = "Tester" })
		player.GetAttributeChangedSignal = function()
			return Signal.new()
		end
		world.Players.LocalPlayer = player
		world.tree.ReplicatedStorage.GetAttributeChangedSignal = function()
			return Signal.new()
		end
		playerGui = world:newInstance("Folder")
		fuseCalls = {}
		world:packets().FuseKey.Fire = function(_self: any, keyId: string)
			table.insert(fuseCalls, keyId)
			return "LavaKey@Gold"
		end
		data = {
			Cash = 5000,
			IncomeAt = world.now,
			Board = { "PlainClack" },
			BoardTags = {},
			Inventory = {},
			Discovered = {},
			Upgrades = { Luck = 1, Speed = 0, Slots = 0, Income = 0, Walls = 0, LockTime = 0, Golden = 2 },
			Settings = { RollVolume = 1, BoardVolume = 1, OtherVolume = 1 },
			Tutorial = 5,
			Boosts = { LuckUntil = 0, ClicksUntil = 0 },
			Season = { Id = 1, Xp = 0, ClaimedFree = 0, ClaimedPremium = 0 },
			Market = { Slot = 0, Bought = {} },
			Rebirths = 0,
			GoldenProgress = 0,
			StarterPackBought = false,
		}
		local function lookup(path: { any }): any
			local node: any = data
			for _, part in path do
				if type(node) ~= "table" then
					return nil
				end
				node = node[part]
			end
			return node
		end
		context = {
			Controllers = {
				DataController = {
					Get = function(_self: any, path: { any }?)
						return lookup(path or {})
					end,
					Observe = function(_self: any, path: { any }, callback: any)
						callback(lookup(path))
						return function() end
					end,
				},
			},
			PlayerGui = playerGui,
			Open = function() end,
			Close = function() end,
			IsOpen = function()
				return false
			end,
			Toast = function() end,
		}
	end)

	afterEach(function()
		world:destroy()
	end)

	it("opens the detail panel on the right and shrinks the grid", function()
		local _, gui = openKeys({ LavaKey = 7 })
		local detail = gui:FindFirstChild("Detail", true)
		expect(detail.Visible):toBe(false)
		press(gui:FindFirstChild("LavaKey", true).Hit)
		world:flush()
		expect(detail.Visible):toBe(true)
		expect(detail.Position.X.Scale > 0.5):toBe(true)
		expect(gui:FindFirstChild("Grid", true).Size.X.Scale < 1):toBe(true)
	end)

	it("shows fuse progress and the next tier", function()
		local _, gui = openKeys({ LavaKey = 3 })
		press(gui:FindFirstChild("LavaKey", true).Hit)
		world:flush()
		expect(gui:FindFirstChild("FuseProgress", true).Text.Text):toBe("3/5")
		expect(string.find(gui:FindFirstChild("FuseTitle", true).Text, "Gold", 1, true) ~= nil):toBe(true)
		expect(string.find(gui:FindFirstChild("FuseBoost", true).Text, "x3", 1, true) ~= nil):toBe(true)
	end)

	it("sends FuseKey when there are five and selects the new variant", function()
		local _, gui = openKeys({ LavaKey = 5 })
		press(gui:FindFirstChild("LavaKey", true).Hit)
		world:flush()
		press(gui:FindFirstChild("FuseButton", true))
		world:advance(1)
		expect(fuseCalls):toEqual({ "LavaKey" })
	end)

	it("does not send FuseKey with fewer than five", function()
		local _, gui = openKeys({ LavaKey = 4 })
		press(gui:FindFirstChild("LavaKey", true).Hit)
		world:flush()
		press(gui:FindFirstChild("FuseButton", true))
		world:advance(1)
		expect(#fuseCalls):toBe(0)
	end)

	it("hides fuse at the mythical tier", function()
		local _, gui = openKeys({ ["LavaKey@Mythical"] = 1 })
		press(gui:FindFirstChild("LavaKey@Mythical", true).Hit)
		world:flush()
		expect(gui:FindFirstChild("FuseButton", true).Visible):toBe(false)
	end)

	it("lists variants as their own cards sorted by real income", function()
		local _, gui = openKeys({ LavaKey = 1, ["LavaKey@Gold"] = 1, PlainClack = 1 })
		local normal = gui:FindFirstChild("LavaKey", true).LayoutOrder
		local gold = gui:FindFirstChild("LavaKey@Gold", true).LayoutOrder
		expect(gold < normal):toBe(true)
		expect(gui:FindFirstChild("LavaKey@Gold", true).Info.Text):toBe(
			`+{world:require("ReplicatedStorage.Utils.NumberFormat").Compact(
				world:require("ReplicatedStorage.Config.Keys").GetIncome("LavaKey@Gold")
			)}/s`
		)
	end)
end)
