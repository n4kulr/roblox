local H = require("../harness/Harness")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

local controller = "StarterPlayer.StarterPlayerScripts.Controllers.UIController"

describe("Kit theme tokens", function()
	local world, Kit

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
		Kit = world:require(`{controller}.Kit`)
	end)

	it("exposes named motion presets", function()
		for _, name in { "Press", "Fast", "Base", "Slow", "Fade", "Exit", "Spring", "Pop", "Badge", "Bounce", "Spin" } do
			expect(Kit.Motion[name] ~= nil):toBe(true)
		end
	end)

	it("retimes a preset without losing its easing", function()
		local retimed = Kit.Retime(Kit.Motion.Pop, 0.4, 0.1)
		expect(retimed.Time):toBe(0.4)
		expect(retimed.DelayTime):toBe(0.1)
		expect(retimed.EasingStyle):toBe(Kit.Motion.Pop.EasingStyle)
		expect(retimed.EasingDirection):toBe(Kit.Motion.Pop.EasingDirection)
	end)

	it("keeps the text scale ascending", function()
		local sizes = {}
		for _, size in Kit.Text do
			table.insert(sizes, size)
		end
		table.sort(sizes)
		for index = 2, #sizes do
			expect(sizes[index] > sizes[index - 1]):toBe(true)
		end
	end)

	it("derives the rainbow sequence from the shared palette", function()
		local sequence = Kit.RainbowSequence()
		expect(#sequence.Keypoints):toBe(#Kit.Rainbow + 1)
		expect(sequence.Keypoints[1].Value):toBe(sequence.Keypoints[#sequence.Keypoints].Value)
	end)

	it("freezes the token tables", function()
		expect(table.isfrozen(Kit.Motion)):toBe(true)
		expect(table.isfrozen(Kit.Text)):toBe(true)
		expect(table.isfrozen(Kit.Layer)):toBe(true)
		expect(table.isfrozen(Kit.ZIndex)):toBe(true)
		expect(table.isfrozen(Kit.Theme)):toBe(true)
	end)
end)
