local roblox = require("@lune/roblox")
local H = require("../harness/Harness")

local Enum = roblox.Enum

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

describe("Admin access", function()
	local world, Access, Config

	beforeEach(function()
		world = H.newWorld({ Time = 1700001000 })
		Access = world:require("ServerScriptService.Services.AdminService.Access")
		Config = world:require("ServerScriptService.Config.Admin")
	end)

	afterEach(function()
		world:destroy()
	end)

	local function env(overrides: any)
		local base = {
			IsStudio = false,
			CreatorType = Enum.CreatorType.User,
			CreatorId = 7,
			RankInGroup = function(_player: any, _groupId: number)
				return 0
			end,
		}
		for key, value in overrides do
			base[key] = value
		end
		return base
	end

	it("ships an empty allowlist and a top group rank", function()
		expect(next(Config.UserIds)):toBeNil()
		expect(Config.GroupRank):toBe(255)
	end)

	it("lets everyone in Studio", function()
		local player = world:newPlayer({ UserId = 99 })
		expect(Access.Check(player, env({ IsStudio = true }))):toBe(true)
	end)

	it("lets only the creator in a user-owned live game", function()
		local owner = world:newPlayer({ UserId = 7 })
		local other = world:newPlayer({ UserId = 8 })
		expect(Access.Check(owner, env({}))):toBe(true)
		expect(Access.Check(other, env({}))):toBe(false)
	end)

	it("lets allowlisted user ids in", function()
		local other = world:newPlayer({ UserId = 8 })
		local config = { UserIds = { [8] = true }, GroupRank = 255 }
		expect(Access.Check(other, env({}), config :: any)):toBe(true)
	end)

	it("requires the configured group rank in a group-owned game", function()
		local player = world:newPlayer({ UserId = 8 })
		local ranks = { [8] = 254 }
		local group = env({
			CreatorType = Enum.CreatorType.Group,
			CreatorId = 55,
			RankInGroup = function(who: any, groupId: number)
				expect(groupId):toBe(55)
				return ranks[who.UserId] or 0
			end,
		})
		expect(Access.Check(player, group)):toBe(false)
		ranks[8] = 255
		expect(Access.Check(player, group)):toBe(true)
		local lenient = { UserIds = {}, GroupRank = 200 }
		ranks[8] = 200
		expect(Access.Check(player, group, lenient :: any)):toBe(true)
	end)

	it("rejects a player who is not the creator", function()
		local player = world:newPlayer({ UserId = 8 })
		expect(Access.Check(player, env({ CreatorType = Enum.CreatorType.User, CreatorId = 1 }))):toBe(false)
	end)

	describe("console", function()
		local friend

		beforeEach(function()
			world:boot({ "KeyboardService", "EggService", "AdminService" })
			world:join({ UserId = 1, Name = "Owner" }, nil, true)
			friend = world:join({ UserId = 42, Name = "Buddy" }, nil, true)
		end)

		it("refuses to run commands for non-admins", function()
			local console = world.registry.AdminService.Console
			local ok, message = console.Run(friend, "money", "1k")
			expect(ok):toBe(false)
			expect(message):toBe("Not allowed")
		end)

		it("does not publish the global handle outside Studio", function()
			expect((_G :: any).ThockAdmin):toBeNil()
		end)
	end)
end)
