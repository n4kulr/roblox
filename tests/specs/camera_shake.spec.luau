local roblox = require("@lune/roblox")
local H = require("../harness/Harness")

local Vector3 = roblox.Vector3
local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

describe("CameraShake", function()
	local CameraShake, humanoid

	beforeEach(function()
		local world = H.newWorld()
		CameraShake = world:require("StarterPlayer.StarterPlayerScripts.Controllers.RollController.CameraShake")
		humanoid = { CameraOffset = Vector3.new(0, 1, 0) }
	end)

	it("adds a single source to the original offset", function()
		CameraShake.Set(humanoid, "a", Vector3.new(1, 0, 0))
		expect(humanoid.CameraOffset == Vector3.new(1, 1, 0)):toBe(true)
	end)

	it("restores the original offset when the last source clears", function()
		CameraShake.Set(humanoid, "a", Vector3.new(1, 0, 0))
		CameraShake.Clear(humanoid, "a")
		expect(humanoid.CameraOffset == Vector3.new(0, 1, 0)):toBe(true)
		expect(CameraShake.IsShaking(humanoid)):toBe(false)
	end)

	it("sums overlapping sources and never captures a shaken offset as the base", function()
		CameraShake.Set(humanoid, "a", Vector3.new(1, 0, 0))
		CameraShake.Set(humanoid, "b", Vector3.new(0, 0, 2))
		expect(humanoid.CameraOffset == Vector3.new(1, 1, 2)):toBe(true)
		CameraShake.Clear(humanoid, "a")
		expect(humanoid.CameraOffset == Vector3.new(0, 1, 2)):toBe(true)
		CameraShake.Clear(humanoid, "b")
		expect(humanoid.CameraOffset == Vector3.new(0, 1, 0)):toBe(true)
	end)

	it("replaces a source's own contribution instead of accumulating it", function()
		CameraShake.Set(humanoid, "a", Vector3.new(1, 0, 0))
		CameraShake.Set(humanoid, "a", Vector3.new(3, 0, 0))
		expect(humanoid.CameraOffset == Vector3.new(3, 1, 0)):toBe(true)
	end)

	it("ignores clears from sources that never shook", function()
		CameraShake.Clear(humanoid, "ghost")
		expect(humanoid.CameraOffset == Vector3.new(0, 1, 0)):toBe(true)
	end)

	it("keeps humanoids independent", function()
		local other = { CameraOffset = Vector3.zero }
		CameraShake.Set(humanoid, "a", Vector3.new(1, 0, 0))
		CameraShake.Set(other, "a", Vector3.new(0, 5, 0))
		CameraShake.Clear(humanoid, "a")
		expect(other.CameraOffset == Vector3.new(0, 5, 0)):toBe(true)
	end)
end)
