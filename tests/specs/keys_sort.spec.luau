local H = require("../harness/Harness")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

local keysPath = "StarterPlayer.StarterPlayerScripts.Controllers.UIController.Screens.Keys"

describe("Keys screen sorting", function()
	local world, Sort, Inventory

	local function entry(id: string, tier: number, income: number, rank: number, name: string)
		return { Id = id, Tier = tier, Income = income, Rank = rank, Name = name }
	end

	local function ids(list: { any }): { string }
		local out = {}
		for _, item in list do
			table.insert(out, item.Id)
		end
		return out
	end

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
		Sort = world:require(`{keysPath}.Sort`)
		Inventory = world:require(`{keysPath}.Inventory`)
	end)

	it("lists the four modes in order", function()
		expect(Sort.Modes):toEqual({ "BEST", "RARITY", "AMOUNT", "NAME" })
	end)

	it("sorts BEST by income then rarity then name", function()
		local list = {
			entry("a", 0, 5, 1, "Alpha"),
			entry("b", 0, 9, 1, "Bravo"),
			entry("c", 0, 5, 3, "Charlie"),
			entry("d", 0, 5, 3, "Able"),
		}
		Sort.Order(list, {}, "BEST")
		expect(ids(list)):toEqual({ "b", "d", "c", "a" })
	end)

	it("sorts RARITY by rank then tier", function()
		local list = {
			entry("a", 0, 1, 2, "A"),
			entry("b", 2, 1, 2, "B"),
			entry("c", 0, 1, 5, "C"),
		}
		Sort.Order(list, {}, "RARITY")
		expect(ids(list)):toEqual({ "c", "b", "a" })
	end)

	it("sorts AMOUNT by total owned and NAME alphabetically", function()
		local list = {
			entry("a", 0, 1, 1, "Zed"),
			entry("b", 0, 1, 1, "Amy"),
			entry("c", 0, 1, 1, "Max"),
		}
		Sort.Order(list, { a = 1, b = 4, c = 2 }, "AMOUNT")
		expect(ids(list)):toEqual({ "b", "c", "a" })
		Sort.Order(list, {}, "NAME")
		expect(ids(list)):toEqual({ "b", "c", "a" })
	end)

	it("sanitises inventory and board tag payloads", function()
		expect(Inventory.ReadCounts({ PlainClack = 2, [1] = 5, Bad = "x" })):toEqual({ PlainClack = 2 })
		expect(Inventory.ReadCounts(nil)):toEqual({})
		expect(Inventory.ReadTags({ "Pal", [2] = 7, x = "no" })):toEqual({ "Pal" })
	end)
end)
