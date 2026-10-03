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
			table.insert(out, `{action.Kind}:{action.Slot}{if action.Fast then ":fast" else ""}`)
		end
		return out
	end

	it("shows a lone common at center and fades it after its hold", function()
		local slots = ResultSlots.new()
		expect(kinds(slots:Push("a", false, 0.7, 10, false))):toEqual({ "Show:Center" })
		expect(#slots:Tick(10.5)):toBe(0)
		expect(kinds(slots:Tick(10.7))):toEqual({ "Fade:Center" })
		expect(#slots:Tick(11)):toBe(0)
	end)

	it("shows a rare at center, then slides left after one second", function()
		local slots = ResultSlots.new()
		expect(kinds(slots:Push("r", true, 3, 10, false))):toEqual({ "Show:Center" })
		expect(#slots:Tick(10.9)):toBe(0)
		expect(kinds(slots:Tick(11))):toEqual({ "Slide:Left" })
		expect(#slots:Tick(11.2)):toBe(0)
		expect(slots:HasPinned()):toBe(true)
	end)

	it("counts the rare hold after the slide and then fades it", function()
		local slots = ResultSlots.new()
		slots:Push("r", true, 3, 10, false)
		slots:Tick(11)
		expect(#slots:Tick(14.2)):toBe(0)
		expect(kinds(slots:Tick(14.3))):toEqual({ "Fade:Left" })
	end)

	it("queues a common that arrives during the pause and shows it right after the slide", function()
		local slots = ResultSlots.new()
		slots:Push("r", true, 3, 10, false)
		expect(#slots:Push("c1", false, 0.7, 10.4, false)):toBe(0)
		expect(#slots:Push("c2", false, 0.7, 10.6, false)):toBe(0)
		expect(kinds(slots:Tick(11))):toEqual({ "Slide:Left" })
		local actions = slots:Tick(11.3)
		expect(kinds(actions)):toEqual({ "Show:Right" })
		expect(actions[1].Payload):toBe("c2")
		expect(actions[1].IsRare):toBe(false)
	end)

	it("shows commons on the right while pinned, replacing each other", function()
		local slots = ResultSlots.new()
		slots:Push("r", true, 5, 10, false)
		slots:Tick(11.3)
		expect(kinds(slots:Push("c1", false, 0.7, 12, false))):toEqual({ "Show:Right" })
		expect(kinds(slots:Push("c2", false, 0.7, 12.2, false))):toEqual({ "Show:Right" })
		expect(#slots:Tick(12.8)):toBe(0)
		expect(kinds(slots:Tick(12.9))):toEqual({ "Fade:Right" })
	end)

	it("fades the pinned rare fast when a new rare arrives and restarts the pause", function()
		local slots = ResultSlots.new()
		slots:Push("r1", true, 5, 10, false)
		slots:Tick(11.3)
		slots:Push("c", false, 3, 12, false)
		expect(kinds(slots:Push("r2", true, 5, 13, false))):toEqual({ "Fade:Left:fast", "Hide:Right", "Show:Center" })
		expect(#slots:Push("c2", false, 0.7, 13.5, false)):toBe(0)
		expect(kinds(slots:Tick(14))):toEqual({ "Slide:Left" })
		expect(kinds(slots:Tick(14.3))):toEqual({ "Show:Right" })
	end)

	it("replaces a rare that is still pausing", function()
		local slots = ResultSlots.new()
		slots:Push("r1", true, 5, 10, false)
		expect(kinds(slots:Push("r2", true, 5, 10.5, false))):toEqual({ "Fade:Center:fast", "Show:Center" })
		expect(#slots:Tick(11.4)):toBe(0)
		expect(kinds(slots:Tick(11.5))):toEqual({ "Slide:Left" })
	end)

	it("hides a center common when a rare arrives", function()
		local slots = ResultSlots.new()
		slots:Push("c", false, 0.7, 10, false)
		expect(kinds(slots:Push("r", true, 3, 10.2, false))):toEqual({ "Hide:Center", "Show:Center" })
		expect(#slots:Tick(11)):toBe(0)
	end)

	it("returns to center after the pinned rare finishes", function()
		local slots = ResultSlots.new()
		slots:Push("r", true, 3, 10, false)
		slots:Tick(11)
		expect(kinds(slots:Tick(14.3))):toEqual({ "Fade:Left" })
		expect(kinds(slots:Push("c", false, 0.7, 14.4, false))):toEqual({ "Show:Right" })
		expect(slots:HasPinned()):toBe(true)
		slots:Tick(14.6)
		expect(slots:HasPinned()):toBe(false)
		expect(kinds(slots:Push("c2", false, 0.7, 14.7, false))):toEqual({ "Show:Center" })
	end)

	it("puts a rare straight into the left slot on low graphics", function()
		local slots = ResultSlots.new()
		expect(kinds(slots:Push("r", true, 3, 10, true))):toEqual({ "Show:Left" })
		expect(#slots:Tick(11)):toBe(0)
		expect(kinds(slots:Push("c", false, 0.7, 10.1, true))):toEqual({ "Show:Right" })
		expect(kinds(slots:Tick(13))):toEqual({ "Fade:Right", "Fade:Left" })
	end)
end)
