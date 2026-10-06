local H = require("../harness/Harness")

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

describe("Server module layout", function()
	local world

	beforeEach(function()
		world = H.newWorld()
	end)

	afterEach(function()
		world:destroy()
	end)

	it("keeps every admin command registered across the command groups", function()
		local Commands = world:require("ServerScriptService.Services.AdminService.Commands")
		local help = Commands.Help()
		local expected = {
			"money",
			"setmoney",
			"resetmoney",
			"maxmoney",
			"income",
			"rolls",
			"golden",
			"givekey",
			"giveegg",
			"givepet",
			"removepets",
			"readyeggs",
			"hatchall",
			"maxupgrades",
			"resetupgrades",
			"rebirth",
			"luckpotion",
			"clickspotion",
			"resetdata",
		}
		for _, name in expected do
			expect(Commands.Has(name)):toBe(true)
			expect(string.find(help, `/{name} `, 1, true) ~= nil):toBe(true)
		end
		expect(Commands.Has("nonsense")):toBe(false)
	end)

	it("pins the steal alert phase numbers the client decodes", function()
		local Alerts = world:require("ServerScriptService.Utils.Alerts")
		expect(Alerts.Phase.Grab):toBe(1)
		expect(Alerts.Phase.Carry):toBe(2)
		expect(Alerts.Phase.Returned):toBe(3)
		expect(Alerts.Phase.Delivered):toBe(4)
		expect(Alerts.Phase.Rejected):toBe(9)
		expect(Alerts.Phase.Good):toBe(11)
	end)

	it("sends alerts through the StealAlert packet", function()
		local Alerts = world:require("ServerScriptService.Utils.Alerts")
		local player = world:newPlayer({})
		world:clearFired()
		Alerts.Bad(player, "no")
		Alerts.Good(player, "yes")
		Alerts.Send(player, "key", 7, Alerts.Phase.Grab)
		local fired = world:firedOf("StealAlert")
		expect(#fired):toBe(3)
		expect({ table.unpack(fired[1].Args) }):toEqual({ "no", 0, 9 })
		expect({ table.unpack(fired[2].Args) }):toEqual({ "yes", 0, 11 })
		expect({ table.unpack(fired[3].Args) }):toEqual({ "key", 7, 1 })
	end)
end)
