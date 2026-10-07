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
end)
