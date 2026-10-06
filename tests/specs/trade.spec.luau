local H = require("../harness/Harness")
local S = require("../support")

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

describe("TradeService", function()
	local world, GameConfig, config

	beforeEach(function()
		world = H.newWorld({ Time = 1700000000 })
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		config = GameConfig.Trade
		world:boot({ "KeyboardService", "TradeService" })
	end)

	afterEach(function()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	local function join(name: string, inventory: any?)
		local player, data = world:joinAtBase({ Name = name, DisplayName = `{name}!` }, { Inventory = inventory or {} })
		return player, data
	end

	local function request(from: any, to: any): any
		return world:invoke("TradeRequest", from, to.UserId)
	end

	local function moveApart(player: any, distance: number)
		world:moveCharacter(player, distance, 3, 0)
	end

	local function respond(responder: any, sender: any, accept: boolean)
		world:invoke("TradeRespond", responder, sender.UserId, accept)
	end

	local function open(a: any, b: any)
		expect(request(a, b)):toBe(true)
		respond(b, a, true)
	end

	local function lastState(player: any): any
		local found
		for _, entry in world:firedOf("TradeState") do
			if entry.Target == player then
				found = entry.Args
			end
		end
		return found
	end

	local function offer(player: any, keyId: string, count: number)
		world:invoke("TradeOffer", player, keyId, count)
	end

	local function ready(player: any, isReady: boolean)
		world:invoke("TradeReady", player, isReady)
	end

	local function countOf(list: any, keyId: string): number
		for _, entry in list do
			if entry.KeyId == keyId then
				return entry.Count
			end
		end
		return 0
	end

	local function setup()
		local a, dataA = join("Ann", { PlainClack = 3, GlassTink = 1, GoldenSpacebar = 1 })
		local b, dataB = join("Bob", { OfficeTap = 2, PlainClack = 1 })
		open(a, b)
		return a, dataA, b, dataB
	end

	local function totals(dataA: any, dataB: any): { [string]: number }
		local out = S.totals(dataA)
		for keyId, count in S.totals(dataB) do
			out[keyId] = (out[keyId] or 0) + count
		end
		return out
	end

	describe("requests", function()
		it("sends an invite to the target", function()
			local a = join("Ann")
			local b = join("Bob")
			expect(request(a, b)):toBe(true)
			local invites = world:firedOf("TradeInvite")
			expect(#invites):toBe(1)
			expect(invites[1].Target):toBe(b)
			expect(invites[1].Args[1]):toBe("Ann!")
			expect(invites[1].Args[2]):toBe(a.UserId)
		end)

		it("rejects a request from beyond the maximum range and accepts one at the edge", function()
			expect(config.MaxRange > 0):toBe(true)
			local a = join("Ann")
			local b = join("Bob")
			moveApart(b, config.MaxRange + 1)
			expect(request(a, b)):toBe(false)
			expect(#world:firedOf("TradeInvite")):toBe(0)
			moveApart(b, config.MaxRange)
			expect(request(a, b)):toBe(true)
		end)

		it("rejects a request when a character is missing", function()
			local a = join("Ann")
			local b = join("Bob")
			world:resetCharacter(b)
			expect(request(a, b)):toBe(false)
		end)

		it("refuses to open the session when the players moved apart before accepting", function()
			local a = join("Ann")
			local b = join("Bob")
			expect(request(a, b)):toBe(true)
			moveApart(b, config.MaxRange + 10)
			respond(b, a, true)
			expect(lastState(a)[1]):toBe(4)
			expect(lastState(b)[1]):toBe(4)
		end)

		it("rejects yourself, strangers and bad ids", function()
			local a = join("Ann")
			expect(world:invoke("TradeRequest", a, a.UserId)):toBe(false)
			expect(world:invoke("TradeRequest", a, 424242)):toBe(false)
			expect(world:invoke("TradeRequest", a, 0 / 0)):toBe(false)
			expect(#world:firedOf("TradeInvite")):toBe(0)
		end)

		it("rejects players whose data is not loaded", function()
			local a = join("Ann")
			local ghost = world:newPlayer({ Name = "Ghost" })
			expect(request(a, ghost)):toBe(false)
			expect(request(ghost, a)):toBe(false)
		end)

		it("rejects a second outgoing request", function()
			local a = join("Ann")
			local b = join("Bob")
			local c = join("Cy")
			expect(request(a, b)):toBe(true)
			expect(request(a, c)):toBe(false)
		end)

		it("rejects players already trading", function()
			local a, _, b = setup()
			local c = join("Cy")
			expect(request(c, a)):toBe(false)
			expect(request(a, c)):toBe(false)
			expect(request(c, b)):toBe(false)
		end)

		it("rejects carrying a stolen key or holding keyfall keys on either side", function()
			local a = join("Ann")
			local b = join("Bob")
			world:spawnCharacter(a, 0, 3, 0)
			world:spawnCharacter(b, 5, 3, 0)
			a.Character:SetAttribute("CarryingKey", "PlainClack")
			expect(request(a, b)):toBe(false)
			expect(request(b, a)):toBe(false)
			a.Character:SetAttribute("CarryingKey", nil)
			b.Character:SetAttribute("KeyfallCount", 2)
			expect(request(a, b)):toBe(false)
			expect(request(b, a)):toBe(false)
			b.Character:SetAttribute("KeyfallCount", 0)
			expect(request(a, b)):toBe(true)
		end)

		it("expires after the timeout", function()
			local a = join("Ann")
			local b = join("Bob")
			expect(request(a, b)):toBe(true)
			world:advance(config.RequestTimeoutSeconds + 1)
			respond(b, a, true)
			expect(#world:firedOf("TradeState")):toBe(0)
			expect(request(a, b)):toBe(true)
		end)

		it("tells the sender when declined and frees them to ask again", function()
			local a = join("Ann")
			local b = join("Bob")
			request(a, b)
			respond(b, a, false)
			local state = lastState(a)
			expect(state[1]):toBe(4)
			expect(state[2]):toBe("Bob! said no thanks")
			expect(request(a, b)):toBe(true)
		end)

		it("ignores responses that match no request", function()
			local a = join("Ann")
			local b = join("Bob")
			local c = join("Cy")
			respond(b, a, true)
			request(a, c)
			respond(b, a, true)
			expect(#world:firedOf("TradeState")):toBe(0)
		end)

		it("opens a session on accept for both players", function()
			local a, _, b = setup()
			local stateA, stateB = lastState(a), lastState(b)
			expect(stateA[1]):toBe(1)
			expect(stateA[2]):toBe("Bob!")
			expect(stateB[2]):toBe("Ann!")
			expect(#stateA[3]):toBe(0)
			expect(stateA[5]):toBe(false)
			expect(world.registry.TradeService:IsTrading(a)):toBe(true)
		end)

		it("keeps a player out of a second trade", function()
			local a = join("Ann")
			local b = join("Bob")
			local c = join("Cy")
			request(a, b)
			request(c, b)
			respond(b, a, true)
			respond(b, c, true)
			expect(world.registry.TradeService:IsTrading(c)):toBe(false)
			expect(lastState(c)[1]):toBe(4)
		end)

		it("drops the responder's own pending request when a session opens", function()
			local a = join("Ann")
			local b = join("Bob")
			local c = join("Cy")
			request(b, c)
			request(a, b)
			respond(b, a, true)
			respond(c, b, true)
			expect(world.registry.TradeService:IsTrading(c)):toBe(false)
		end)
	end)

	describe("offers", function()
		it("records valid offers and shows them to both sides", function()
			local a, _, b = setup()
			offer(a, "PlainClack", 2)
			expect(countOf(lastState(a)[3], "PlainClack")):toBe(2)
			expect(countOf(lastState(b)[4], "PlainClack")):toBe(2)
			offer(a, "PlainClack", 0)
			expect(#lastState(a)[3]):toBe(0)
		end)

		it("rejects counts above the inventory and keys not owned", function()
			local a = setup()
			offer(a, "PlainClack", 4)
			offer(a, "OfficeTap", 1)
			offer(a, "NopeKey", 1)
			expect(#lastState(a)[3]):toBe(0)
		end)

		it("never offers board keys", function()
			local a = join("Ann", { PlainClack = 1 })
			local b = join("Bob", { OfficeTap = 1 })
			world.Data:Replica(a):Set({ "Board", 1 }, "GlassTink")
			open(a, b)
			offer(a, "GlassTink", 1)
			expect(#lastState(a)[3]):toBe(0)
			offer(a, "PlainClack", 2)
			expect(#lastState(a)[3]):toBe(0)
		end)

		it("allows exclusive keys", function()
			local a = setup()
			offer(a, "GoldenSpacebar", 1)
			expect(countOf(lastState(a)[3], "GoldenSpacebar")):toBe(1)
		end)

		it("enforces the distinct key limit", function()
			local keys = world:require("ReplicatedStorage.Config.Keys")
			local inventory = {}
			for _, key in keys.Catalog do
				inventory[key.Id] = 1
			end
			local a = join("Ann", inventory)
			local b = join("Bob")
			open(a, b)
			for _, key in keys.Catalog do
				offer(a, key.Id, 1)
			end
			expect(#lastState(a)[3]):toBe(config.MaxDistinctKeys)
		end)

		it("ignores offers from players not trading", function()
			local a = join("Ann", { PlainClack = 1 })
			offer(a, "PlainClack", 1)
			expect(#world:firedOf("TradeState")):toBe(0)
		end)

		it("resets both ready flags when an offer changes", function()
			local a, _, b = setup()
			offer(a, "PlainClack", 1)
			ready(a, true)
			ready(b, false)
			expect(lastState(b)[6]):toBe(true)
			offer(b, "OfficeTap", 1)
			expect(lastState(a)[5]):toBe(false)
			expect(lastState(a)[6]):toBe(false)
			expect(lastState(b)[5]):toBe(false)
		end)

		it("cancels a running countdown when an offer changes", function()
			local a, dataA, b, dataB = setup()
			offer(a, "PlainClack", 1)
			offer(b, "OfficeTap", 1)
			ready(a, true)
			ready(b, true)
			expect(lastState(a)[1]):toBe(2)
			world:advance(1)
			offer(a, "PlainClack", 2)
			expect(lastState(a)[1]):toBe(1)
			expect(lastState(a)[7]):toBe(0)
			world:advance(10)
			expect(dataA.Inventory.PlainClack):toBe(3)
			expect(dataB.Inventory.OfficeTap):toBe(2)
		end)
	end)

	describe("ready and countdown", function()
		it("ignores ready when nothing is offered", function()
			local a = setup()
			ready(a, true)
			expect(lastState(a)[5]):toBe(false)
		end)

		it("starts a countdown only when both are ready", function()
			local a, _, b = setup()
			offer(a, "PlainClack", 1)
			ready(a, true)
			expect(lastState(a)[1]):toBe(1)
			ready(b, true)
			expect(lastState(a)[1]):toBe(2)
			expect(lastState(a)[7]):toBe(config.ConfirmCountdownSeconds)
		end)

		it("stops the countdown when someone unreadies", function()
			local a, dataA, b = setup()
			offer(a, "PlainClack", 1)
			ready(a, true)
			ready(b, true)
			world:advance(1)
			ready(b, false)
			expect(lastState(a)[1]):toBe(1)
			world:advance(10)
			expect(dataA.Inventory.PlainClack):toBe(3)
		end)

		it("sends the state every second", function()
			local a, _, b = setup()
			offer(a, "PlainClack", 1)
			ready(a, true)
			ready(b, true)
			world:advance(1)
			expect(lastState(a)[7]):toBe(config.ConfirmCountdownSeconds - 1)
			world:advance(1)
			expect(lastState(a)[7]):toBe(config.ConfirmCountdownSeconds - 2)
		end)

		it("swaps the keys atomically and conserves every count", function()
			local a, dataA, b, dataB = setup()
			local before = totals(dataA, dataB)
			offer(a, "PlainClack", 2)
			offer(a, "GoldenSpacebar", 1)
			offer(b, "OfficeTap", 2)
			ready(a, true)
			ready(b, true)
			world:advance(config.ConfirmCountdownSeconds + 0.5)
			expect(dataA.Inventory):toEqual({ PlainClack = 1, GlassTink = 1, OfficeTap = 2 })
			expect(dataB.Inventory):toEqual({ PlainClack = 3, GoldenSpacebar = 1 })
			expect(totals(dataA, dataB)):toEqual(before)
			expect(lastState(a)[1]):toBe(3)
			expect(lastState(b)[1]):toBe(3)
			expect(world.registry.TradeService:IsTrading(a)):toBe(false)
		end)

		it("increments Discovered for received keys only", function()
			local a, dataA, b, dataB = setup()
			offer(a, "GoldenSpacebar", 1)
			offer(b, "OfficeTap", 2)
			ready(a, true)
			ready(b, true)
			world:advance(config.ConfirmCountdownSeconds + 0.5)
			expect(dataA.Discovered.OfficeTap):toBe(2)
			expect(dataB.Discovered.GoldenSpacebar):toBe(1)
			expect(dataA.Discovered.GoldenSpacebar):toBeNil()
		end)

		it("requests a save for both players", function()
			local a, _, b = setup()
			offer(a, "PlainClack", 1)
			ready(a, true)
			ready(b, true)
			world:advance(config.ConfirmCountdownSeconds + 0.5)
			expect(world.saves[a]):toBe(1)
			expect(world.saves[b]):toBe(1)
		end)

		it("logs the completed trade and flags mythic keys", function()
			local a, _, b = setup()
			offer(a, "GoldenSpacebar", 1)
			offer(b, "OfficeTap", 1)
			ready(a, true)
			ready(b, true)
			world:advance(config.ConfirmCountdownSeconds + 0.5)
			local line
			for _, log in world.logs do
				if string.find(log, "[Trade]", 1, true) then
					line = log
				end
			end
			expect(line ~= nil):toBe(true)
			expect(string.find(line, "Ann <-> Bob", 1, true) ~= nil):toBe(true)
			expect(string.find(line, "GoldenSpacebar [MYTHIC+]", 1, true) ~= nil):toBe(true)
		end)

		it("allows a new trade after completing", function()
			local a, _, b = setup()
			offer(a, "PlainClack", 1)
			ready(a, true)
			ready(b, true)
			world:advance(config.ConfirmCountdownSeconds + 0.5)
			expect(request(a, b)):toBe(true)
		end)

		it("cancels without writing when an offered key was sold", function()
			local a, dataA, b, dataB = setup()
			local beforeA, beforeB = S.snapshot(dataA), S.snapshot(dataB)
			offer(a, "PlainClack", 3)
			offer(b, "OfficeTap", 1)
			ready(a, true)
			ready(b, true)
			world:advance(1)
			expect(world:invoke("SellKey", a, "PlainClack", 1)):toBe(true)
			local cash = dataA.Cash
			world:advance(config.ConfirmCountdownSeconds)
			local state = lastState(a)
			expect(state[1]):toBe(4)
			expect(state[2]):toBe("Trade cancelled: items changed")
			expect(lastState(b)[2]):toBe("Trade cancelled: items changed")
			expect(dataA.Inventory):toEqual({ PlainClack = 2, GlassTink = 1, GoldenSpacebar = 1 })
			expect(dataB.Inventory):toEqual(beforeB.Inventory)
			expect(dataB.Discovered):toEqual(beforeB.Discovered)
			expect(dataA.Discovered):toEqual(beforeA.Discovered)
			expect(dataA.Cash >= cash):toBe(true)
			expect(world.saves[a]):toBeNil()
			expect(world.saves[b]):toBeNil()
			expect(world.registry.TradeService:IsTrading(b)):toBe(false)
		end)

		it("cancels when an offered key moves to the board", function()
			local a, dataA, b, dataB = setup()
			offer(a, "GlassTink", 1)
			offer(b, "OfficeTap", 1)
			ready(a, true)
			ready(b, true)
			expect(world:invoke("PlaceKey", a, 1, "GlassTink")):toBe(true)
			world:advance(config.ConfirmCountdownSeconds + 0.5)
			expect(lastState(a)[1]):toBe(4)
			expect(dataA.Inventory.GlassTink):toBeNil()
			expect(dataB.Inventory.OfficeTap):toBe(2)
			expect(dataA.Inventory.OfficeTap):toBeNil()
		end)
	end)

	describe("cancelling", function()
		it("cancels for both on TradeCancel", function()
			local a, dataA, b, dataB = setup()
			offer(a, "PlainClack", 1)
			world:invoke("TradeCancel", a)
			expect(lastState(a)[1]):toBe(4)
			expect(lastState(a)[2]):toBe("Trade cancelled")
			expect(lastState(b)[1]):toBe(4)
			expect(lastState(b)[2]):toBe("Ann! cancelled the trade")
			expect(world.registry.TradeService:IsTrading(b)):toBe(false)
			expect(dataA.Inventory.PlainClack):toBe(3)
			expect(dataB.Inventory.PlainClack):toBe(1)
		end)

		it("cancels when a player leaves and notifies the other", function()
			local a, _, b = setup()
			offer(a, "PlainClack", 1)
			ready(a, true)
			ready(b, true)
			world:removePlayer(a)
			local state = lastState(b)
			expect(state[1]):toBe(4)
			expect(state[2]):toBe("Ann! left the trade")
			world:advance(10)
			expect(lastState(b)[1]):toBe(4)
			expect(world.registry.TradeService:IsTrading(b)):toBe(false)
		end)

		it("drops pending requests when a player leaves", function()
			local a = join("Ann")
			local b = join("Bob")
			request(a, b)
			world:removePlayer(a)
			expect(#world:firedOf("TradeState")):toBe(0)
		end)

		it("cancels when a participant starts carrying a stolen key", function()
			local a, dataA, b = setup()
			world:spawnCharacter(a, 0, 3, 0)
			world:spawnCharacter(b, 5, 3, 0)
			offer(a, "PlainClack", 1)
			ready(a, true)
			ready(b, true)
			a.Character:SetAttribute("CarryingKey", "PlainClack")
			world:advance(config.ConfirmCountdownSeconds + 1)
			expect(lastState(b)[1]):toBe(4)
			expect(dataA.Inventory.PlainClack):toBe(3)
		end)
	end)
end)
