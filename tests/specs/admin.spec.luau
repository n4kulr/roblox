local H = require("../harness/Harness")

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

describe("AdminService", function()
	local world, owner, friend, friendData

	beforeEach(function()
		world = H.newWorld({ Time = 1700001000 })
		world:boot({ "KeyboardService", "EggService", "AdminService" })
		owner = world:join({ UserId = 1, Name = "Owner" }, nil, true)
		friend, friendData = world:join({ UserId = 42, Name = "Buddy", DisplayName = "Buddy" }, {
			PlacedEggs = {
				{ Id = "Linear", ReadyAt = world.now + 120, X = 5, Z = 5 },
				{ Id = "Golden", ReadyAt = world.now + 60, X = 10, Z = 5 },
			},
		}, true)
	end)

	afterEach(function()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	it("lets the place creator ready a friend's eggs over chat", function()
		owner.Chatted:Fire("/readyeggs Buddy")
		expect(friendData.PlacedEggs[1].ReadyAt):toBe(world.now)
		expect(friendData.PlacedEggs[2].ReadyAt):toBe(world.now)
		expect(#friendData.PlacedEggs):toBe(2)
	end)

	it("lets the place creator hatch a friend's eggs over chat", function()
		owner.Chatted:Fire("/hatchall Buddy")
		expect(friendData.PlacedEggs):toEqual({})
		local total = 0
		for _, amount in friendData.Charms do
			total += amount
		end
		expect(total):toBe(2)
	end)

	it("ignores commands from non-admins", function()
		friend.Chatted:Fire("/hatchall Buddy")
		expect(#friendData.PlacedEggs):toBe(2)
		expect(friendData.PlacedEggs[1].ReadyAt):toBe(world.now + 120)
	end)

	it("exposes Studio console helpers on AdminService.Console", function()
		local admin = world.registry.AdminService.Console
		expect(admin ~= nil):toBe(true)
		expect(admin.ReadyEggs("Buddy")):toBe(2)
		expect(friendData.PlacedEggs[1].ReadyAt):toBe(world.now)
		expect(admin.HatchAll("Buddy")):toBe(2)
		expect(friendData.PlacedEggs):toEqual({})
	end)
end)
