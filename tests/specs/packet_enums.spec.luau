local H = require("../harness/Harness")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

describe("Packet enums", function()
	local world, Steal, Trade, Keyfall

	beforeEach(function()
		world = H.newWorld()
		Steal = world:require("ReplicatedStorage.Rules.Steal")
		Trade = world:require("ReplicatedStorage.Rules.Trade")
		Keyfall = world:require("ReplicatedStorage.Rules.Keyfall")
	end)

	local function expectDistinctIntegers(enum: any)
		local seen = {}
		for name, value in enum do
			expect(`{name}:{type(value)}`):toBe(`{name}:number`)
			expect(value % 1):toBe(0)
			expect(tostring(seen[value])):toBe("nil")
			seen[value] = name
		end
	end

	it("freezes every enum", function()
		expect(table.isfrozen(Steal.AlertPhase)):toBe(true)
		expect(table.isfrozen(Trade.Phase)):toBe(true)
		expect(table.isfrozen(Keyfall.Events)):toBe(true)
	end)

	it("keeps ids distinct integers", function()
		expectDistinctIntegers(Steal.AlertPhase)
		expectDistinctIntegers(Trade.Phase)
		expectDistinctIntegers(Keyfall.Events)
	end)

	it("pins the steal alert phases the server sends", function()
		expect(Steal.AlertPhase.Stealing):toBe(1)
		expect(Steal.AlertPhase.Stolen):toBe(2)
		expect(Steal.AlertPhase.Returned):toBe(3)
		expect(Steal.AlertPhase.GotAway):toBe(4)
		expect(Steal.AlertPhase.Rejected):toBe(9)
		expect(Steal.AlertPhase.Info):toBe(10)
		expect(Steal.AlertPhase.Good):toBe(11)
	end)

	it("pins the trade phases the server sends", function()
		expect(Trade.Phase.Open):toBe(1)
		expect(Trade.Phase.Countdown):toBe(2)
		expect(Trade.Phase.Done):toBe(3)
		expect(Trade.Phase.Cancelled):toBe(4)
	end)

	it("pins the keyfall event ids the server sends", function()
		expect(Keyfall.Events.Announce):toBe(1)
		expect(Keyfall.Events.Grabbed):toBe(2)
		expect(Keyfall.Events.Claimed):toBe(3)
		expect(Keyfall.Events.Delivered):toBe(4)
		expect(Keyfall.Events.Vanished):toBe(5)
	end)
end)
