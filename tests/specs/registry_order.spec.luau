local fs = require("@lune/fs")
local H = require("../harness/Harness")

local describe, it, expect = H.describe, H.it, H.expect

describe("Server registry order", function()
	local dependencies = {
		KeyboardService = { "DataService", "PassService" },
		PlotService = { "DataService", "KeyboardService", "MeshService" },
		CosmeticService = { "MeshService" },
		StealService = { "DataService", "KeyboardService", "PlotService", "PlaytimeService" },
		RollService = { "DataService", "KeyboardService", "PlotService", "SeasonService" },
		EggService = { "DataService", "PlotService", "KeyboardService" },
		MarketService = { "DataService", "EggService" },
		UpgradeService = { "DataService", "KeyboardService" },
		RebirthService = { "DataService", "KeyboardService" },
		AdminService = { "DataService", "KeyboardService", "EggService", "PlotService" },
	}

	local function names(): { string }
		local out = {}
		for name in string.gmatch(fs.readFile("src/server/Registry.luau"), "Services%.(%w+)%)") do
			table.insert(out, name)
		end
		return out
	end

	it("registers every system after the systems it depends on", function()
		local position = {}
		for index, name in names() do
			position[name] = index
		end
		for name, needs in dependencies do
			expect(position[name] ~= nil):toBe(true)
			for _, need in needs do
				expect(position[need] ~= nil):toBe(true)
				expect(position[need] < position[name]):toBe(true)
			end
		end
	end)

	it("has unique system names", function()
		local seen = {}
		for _, name in names() do
			expect(seen[name]):toBe(nil)
			seen[name] = true
		end
		expect(next(seen) ~= nil):toBe(true)
	end)
end)
