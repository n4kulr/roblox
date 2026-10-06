local H = require("../harness/Harness")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

describe("ResultSlots", function()
	local ResultSlots

	beforeEach(function()
		local world = H.newWorld({ Time = 1700000000 })
		ResultSlots = world:require("StarterPlayer.StarterPlayerScripts.Controllers.RollController.ResultSlots")
	end)

	local function kinds(actions: { any }): { string }
		local out = {}
		for _, action in actions do
			table.insert(out, `{action.Kind}:{action.Slot}`)
		end
		return out
	end

	it("shows a lone result at center and fades it after its hold", function()
		local slots = ResultSlots.new()
		expect(kinds(slots:Push("a", 0.7, 10))):toEqual({ "Show:Center" })
		expect(#slots:Tick(10.5)):toBe(0)
		expect(kinds(slots:Tick(10.7))):toEqual({ "Fade:Center" })
		expect(#slots:Tick(11)):toBe(0)
	end)

	it("shows a legendary centered and replaces it in the center on the next roll", function()
		local slots = ResultSlots.new()
		local first = slots:Push("legendary", 5, 10)
		expect(kinds(first)):toEqual({ "Show:Center" })
		expect(first[1].Payload):toBe("legendary")
		expect(#slots:Tick(11)):toBe(0)
		expect(#slots:Tick(12)):toBe(0)
		local second = slots:Push("common", 0.7, 12.5)
		expect(kinds(second)):toEqual({ "Show:Center" })
		expect(second[1].Payload):toBe("common")
		expect(kinds(slots:Tick(13.2))):toEqual({ "Fade:Center" })
	end)

	it("never uses a side slot or slide for any sequence of rolls", function()
		local slots = ResultSlots.new()
		local now = 10
		for roll = 1, 40 do
			local hold = if roll % 5 == 0 then 5 else 0.7
			for _, action in slots:Push(roll, hold, now) do
				expect(action.Slot):toBe("Center")
				expect(action.Kind == "Show" or action.Kind == "Fade"):toBe(true)
			end
			now += 0.2
			for _, action in slots:Tick(now) do
				expect(action.Slot):toBe("Center")
			end
		end
	end)

	it("fades the previous card when the next roll arrives after its hold", function()
		local slots = ResultSlots.new()
		slots:Push("a", 0.5, 10)
		expect(kinds(slots:Push("b", 0.5, 10.6))):toEqual({ "Fade:Center", "Show:Center" })
	end)
end)
