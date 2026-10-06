local H = require("../harness/Harness")

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

describe("PlaytimeService play seconds", function()
	local world, services

	beforeEach(function()
		world = H.newWorld({ Time = 1700000000 })
		services = world:boot({ "KeyboardService", "PlaytimeService" })
	end)

	afterEach(function()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	it("reports the unsaved whole seconds of a player", function()
		local player = world:join(nil, { PlaySeconds = 100 })
		expect(services.PlaytimeService:GetPendingSeconds(player)):toBe(0)
		world:advance(12)
		expect(services.PlaytimeService:GetPendingSeconds(player)):toBe(12)
	end)

	it("folds pending seconds into the data on the save interval", function()
		local player, data = world:join(nil, { PlaySeconds = 100 })
		world:advance(services.PlaytimeService.SaveSeconds + 1)
		expect(data.PlaySeconds):toBe(100 + services.PlaytimeService.SaveSeconds)
		expect(services.PlaytimeService:GetPendingSeconds(player)):toBe(1)
	end)

	it("writes the remainder when the player leaves", function()
		local player, data = world:join(nil, { PlaySeconds = 100 })
		world:advance(47)
		world:removePlayer(player)
		expect(data.PlaySeconds):toBe(147)
		expect(services.PlaytimeService:GetPendingSeconds(player)):toBe(0)
	end)

	it("stops the save timer on destroy", function()
		local _, data = world:join(nil, { PlaySeconds = 100 })
		services.PlaytimeService:Destroy()
		world:advance(120)
		expect(data.PlaySeconds):toBe(100)
	end)
end)
