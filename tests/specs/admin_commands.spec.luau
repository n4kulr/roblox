local H = require("../harness/Harness")

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

describe("AdminService commands", function()
	local world, owner, ownerData, friend, friendData, admin, Amount, Keys, Eggs, Charms, Upgrades, GameConfig

	local function run(command: string, argument: string?, player: any?)
		return admin:Execute(player or owner, command, argument or "")
	end

	beforeEach(function()
		world = H.newWorld({ Time = 1700001000 })
		world:boot({ "KeyboardService", "EggService", "RebirthService", "AdminService" })
		admin = world.registry.AdminService
		owner, ownerData = world:join({ UserId = 1, Name = "Owner" }, {
			IncomeAt = world.now,
			Board = { "PlainClack", "CreamyThock" },
			Upgrades = { Slots = 1 },
		}, true)
		friend, friendData = world:join({ UserId = 42, Name = "Buddy", DisplayName = "Buddy" }, {
			IncomeAt = world.now,
		}, true)
		Amount = world:require("ServerScriptService.Services.AdminService.Amount")
		Keys = world:require("ReplicatedStorage.Config.Keys")
		Eggs = world:require("ReplicatedStorage.Config.Eggs")
		Charms = world:require("ReplicatedStorage.Config.Charms")
		Upgrades = world:require("ReplicatedStorage.Config.Upgrades")
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
	end)

	afterEach(function()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	describe("amount parsing", function()
		it("understands k, m, b and t suffixes", function()
			expect(Amount.Parse("1k")):toBe(1000)
			expect(Amount.Parse("2.5m")):toBe(2500000)
			expect(Amount.Parse("1b")):toBe(1000000000)
			expect(Amount.Parse("1t")):toBe(1000000000000)
			expect(Amount.Parse("1.5K")):toBe(1500)
			expect(Amount.Parse("1,234")):toBe(1234)
			expect(Amount.Parse("750")):toBe(750)
			expect(Amount.Parse("1e6")):toBe(1000000)
		end)

		it("rejects junk and negatives", function()
			expect(Amount.Parse("")):toBe(nil)
			expect(Amount.Parse("abc")):toBe(nil)
			expect(Amount.Parse("-5")):toBe(nil)
			expect(Amount.Parse("1x")):toBe(nil)
			expect(Amount.Parse(nil)):toBe(nil)
		end)
	end)

	describe("authorization", function()
		it("rejects non-admins over the packet and changes nothing", function()
			local result = world:invoke("AdminCommand", friend, "money", "1m")
			expect(result):toBe("Not allowed")
			expect(friendData.Cash):toBe(0)
		end)

		it("rejects non-admins over chat silently", function()
			friend.Chatted:Fire("/money 1m")
			friend.Chatted:Fire("/maxmoney")
			expect(friendData.Cash):toBe(0)
		end)

		it("rejects a non-admin targeting someone else", function()
			local ok, message = run("money", "1m Owner", friend)
			expect(ok):toBe(false)
			expect(message):toBe("Not allowed")
			expect(ownerData.Cash):toBe(0)
		end)

		it("flags admins on join with the IsAdmin attribute", function()
			expect(owner:GetAttribute("IsAdmin")):toBe(true)
			expect(friend:GetAttribute("IsAdmin")):toBe(false)
		end)

		it("tells only admins to show the dev button with the IsDeveloper attribute", function()
			expect(owner:GetAttribute("IsDeveloper")):toBe(true)
			expect(friend:GetAttribute("IsDeveloper")):toBe(false)
		end)

		it("still refuses commands from a non-developer over the packet", function()
			expect(world:invoke("AdminCommand", friend, "money", "1k")):toBe("Not allowed")
		end)

		it("serves the same command over the packet for admins", function()
			local result = world:invoke("AdminCommand", owner, "money", "1k")
			expect(result):toBe("Added 1K Clicks")
			expect(ownerData.Cash):toBe(1000)
		end)

		it("works over chat for admins", function()
			owner.Chatted:Fire("/money 2.5m")
			expect(ownerData.Cash):toBe(2500000)
		end)

		it("answers bad packet input without erroring", function()
			expect(world:invoke("AdminCommand", owner, "nope", "")):toBe('Unknown command "nope". Try help')
			expect(world:invoke("AdminCommand", owner, "money", "")):toBe("Usage: /money <amount> [player|all]")
			expect(world:invoke("AdminCommand", owner, "money", "abc")):toBe("Bad amount")
		end)

		it("lists commands on help", function()
			local ok, message = run("help")
			expect(ok):toBe(true)
			expect(string.find(message, "/money", 1, true) ~= nil):toBe(true)
			expect(string.find(message, "/resetdata", 1, true) ~= nil):toBe(true)
		end)
	end)

	describe("money", function()
		it("adds Clicks with suffixes and counts them as earned", function()
			run("money", "1k")
			run("money", "1m")
			expect(ownerData.Cash):toBe(1001000)
			expect(ownerData.TotalEarned):toBe(1001000)
		end)

		it("accepts a leading slash on the command name", function()
			run("/money", "5")
			expect(ownerData.Cash):toBe(5)
		end)

		it("sets, resets and maxes Clicks", function()
			run("setmoney", "2.5m")
			expect(ownerData.Cash):toBe(2500000)
			run("setmoney", "100")
			expect(ownerData.Cash):toBe(100)
			run("resetmoney")
			expect(ownerData.Cash):toBe(0)
			run("maxmoney")
			expect(ownerData.Cash):toBe(1e15)
		end)

		it("never exceeds the cash ceiling", function()
			run("setmoney", "9007199254740990")
			local ok = run("money", "1t")
			expect(ownerData.Cash <= 9007199254740991):toBe(true)
			expect(ok):toBe(true)
			local again = run("money", "1t")
			expect(again):toBe(false)
		end)

		it("targets another player by name and by all", function()
			run("money", "1k Buddy")
			expect(friendData.Cash):toBe(1000)
			expect(ownerData.Cash):toBe(0)
			run("money", "1k all")
			expect(friendData.Cash):toBe(2000)
			expect(ownerData.Cash):toBe(1000)
		end)

		it("reports an unknown target", function()
			local ok, message = run("money", "1k Nobody")
			expect(ok):toBe(false)
			expect(message):toBe('No player matches "Nobody"')
		end)

		it("grants seconds of the current income", function()
			local rate = world.registry.KeyboardService:GetRate(owner)
			expect(rate):toBeGreaterThan(0)
			run("income", "60")
			expect(ownerData.Cash):toBe(math.floor(rate * 60))
		end)

		it("refuses income when nothing earns", function()
			local ok, message = run("income", "60 Buddy")
			expect(ok):toBe(false)
			expect(message):toBe("No income to grant")
			expect(friendData.Cash):toBe(0)
		end)
	end)

	describe("progress", function()
		it("adds rolls without touching golden progress", function()
			ownerData.GoldenProgress = 7
			run("rolls", "100")
			expect(ownerData.Rolls):toBe(100)
			expect(ownerData.GoldenProgress):toBe(7)
		end)

		it("makes the next roll golden", function()
			run("golden")
			local every = GameConfig.GoldenRollEvery
			expect(ownerData.GoldenProgress):toBe(every - 1)
		end)

		it("maxes and resets every upgrade", function()
			run("maxupgrades")
			for _, upgrade in Upgrades.List do
				expect(ownerData.Upgrades[upgrade.Id]):toBe(upgrade.MaxLevel)
			end
			run("resetupgrades")
			for _, upgrade in Upgrades.List do
				expect(ownerData.Upgrades[upgrade.Id]):toBe(0)
			end
		end)

		it("forces a rebirth without the cost", function()
			ownerData.Cash = 5
			ownerData.Upgrades.Luck = 4
			local ok = run("rebirth")
			expect(ok):toBe(true)
			expect(ownerData.Rebirths):toBe(1)
			expect(ownerData.Cash):toBe(0)
			expect(ownerData.Upgrades.Luck):toBe(0)
		end)

		it("does not let the rebirth packet skip the cost", function()
			ownerData.Cash = 5
			expect(world:invoke("Rebirth", owner)):toBe(false)
			expect(ownerData.Rebirths):toBe(0)
		end)
	end)

	describe("items", function()
		it("gives a key by id", function()
			local ok = run("givekey", "PlainClack 3")
			expect(ok):toBe(true)
			local total = ownerData.Discovered.PlainClack
			expect(total):toBe(3)
			local held = (ownerData.Inventory.PlainClack or 0)
			for _, keyId in ownerData.Board do
				if keyId == "PlainClack" then
					held += 1
				end
			end
			expect(held >= 3):toBe(true)
		end)

		it("gives a random key of a rarity", function()
			run("givekey", "legendary 4 Buddy")
			local total = 0
			for keyId, count in friendData.Discovered do
				expect(Keys.ById[keyId].Rarity):toBe("Legendary")
				total += count
			end
			expect(total):toBe(4)
		end)

		it("rejects an unknown key or rarity", function()
			local ok, message = run("givekey", "Bogus")
			expect(ok):toBe(false)
			expect(message):toBe('Unknown key or rarity "Bogus"')
		end)

		it("holds the first granted egg and queues the rest", function()
			local egg = Eggs.Catalog[1]
			run("giveegg", `{egg.Id} 5`)
			expect(ownerData.HeldEgg):toBe(egg.Id)
			expect(ownerData.EggInventory[egg.Id]):toBe(4)
			run("giveegg", egg.Id)
			expect(ownerData.HeldEgg):toBe(egg.Id)
			expect(ownerData.EggInventory[egg.Id]):toBe(5)
		end)

		it("rejects an unknown egg", function()
			local ok = run("giveegg", "Nope")
			expect(ok):toBe(false)
		end)

		it("gives pets and equips the best", function()
			local pet = Charms.Catalog[1]
			run("givepet", `{pet.Id} 2`)
			expect(ownerData.Charms[pet.Id]):toBe(2)
			expect(#ownerData.EquippedCharms > 0):toBe(true)
		end)

		it("readies and hatches placed eggs", function()
			table.insert(ownerData.PlacedEggs, { Id = "Linear", ReadyAt = world.now + 500, X = 5, Z = 5 })
			run("readyeggs")
			expect(ownerData.PlacedEggs[1].ReadyAt):toBe(world.now)
			run("hatchall")
			expect(ownerData.PlacedEggs):toEqual({})
		end)

		it("defaults egg commands to the sender and not everyone", function()
			table.insert(friendData.PlacedEggs, { Id = "Linear", ReadyAt = world.now + 500, X = 5, Z = 5 })
			run("readyeggs")
			expect(friendData.PlacedEggs[1].ReadyAt):toBe(world.now + 500)
		end)
	end)

	describe("boosts", function()
		it("extends the luck and clicks potions", function()
			run("luckpotion", "10")
			expect(ownerData.Boosts.LuckUntil):toBe(world.now + 600)
			run("clickspotion", "10")
			expect(ownerData.Boosts.ClicksUntil):toBe(world.now + 600)
		end)

		it("rejects a bad duration", function()
			local ok, message = run("luckpotion", "0")
			expect(ok):toBe(false)
			expect(message):toBe("Bad minutes")
		end)
	end)

	describe("resetdata", function()
		beforeEach(function()
			ownerData.Cash = 777
			ownerData.Rebirths = 3
			ownerData.Inventory = { PlainClack = 4 }
			ownerData.Receipts = { ["abc"] = 5 }
		end)

		it("needs the confirm word", function()
			local ok, message = run("resetdata", "nope")
			expect(ok):toBe(false)
			expect(message):toBe("Type resetdata confirm to wipe data")
			expect(ownerData.Cash):toBe(777)
			local missing, usage = run("resetdata")
			expect(missing):toBe(false)
			expect(usage):toBe("Usage: /resetdata confirm [player]")
		end)

		it("wipes progress to the template but keeps receipts", function()
			local ok = run("resetdata", "confirm")
			expect(ok):toBe(true)
			expect(ownerData.Cash):toBe(0)
			expect(ownerData.Rebirths):toBe(0)
			expect(ownerData.Inventory):toEqual({})
			expect(ownerData.Receipts):toEqual({ ["abc"] = 5 })
		end)

		it("cannot wipe everyone at once", function()
			local ok, message = run("resetdata", "confirm all")
			expect(ok):toBe(false)
			expect(message):toBe("This command cannot target all players")
			expect(ownerData.Cash):toBe(777)
		end)

		it("is refused for non-admins", function()
			friendData.Cash = 50
			local result = world:invoke("AdminCommand", friend, "resetdata", "confirm")
			expect(result):toBe("Not allowed")
			expect(friendData.Cash):toBe(50)
		end)
	end)

	describe("removepets", function()
		it("clears owned and active pets for the target and syncs", function()
			local pet = Charms.Catalog[1]
			run("givepet", `{pet.Id} 2`)
			run("givepet", `{pet.Id} 1 Buddy`)
			expect(#ownerData.EquippedCharms > 0):toBe(true)
			local ok, message = run("removepets", "Buddy")
			expect(ok):toBe(true)
			expect(message):toBe("Removed 1 pet (Buddy)")
			expect(friendData.Charms):toEqual({})
			expect(friendData.EquippedCharms):toEqual({})
			expect(ownerData.Charms[pet.Id]):toBe(2)
			local mine = run("removepets")
			expect(mine):toBe(true)
			expect(ownerData.Charms):toEqual({})
			expect(ownerData.EquippedCharms):toEqual({})
			expect(owner:GetAttribute("EquippedCharms")):toBe("")
		end)

		it("is refused for non-admins", function()
			friendData.Charms = { [Charms.Catalog[1].Id] = 1 }
			local result = world:invoke("AdminCommand", friend, "removepets", "")
			expect(result):toBe("Not allowed")
			expect(friendData.Charms[Charms.Catalog[1].Id]):toBe(1)
		end)
	end)

	describe("rewards fired to the target", function()
		local function fired()
			return world:firedOf("AdminReward")
		end

		beforeEach(function()
			world:clearFired()
		end)

		it("fires a Key reward to the target only", function()
			run("givekey", "PlainClack 5 Buddy")
			local list = fired()
			expect(#list):toBe(1)
			expect(list[1].Target):toBe(friend)
			expect(list[1].Args[1]):toBe("Key")
			expect(list[1].Args[2]):toBe("PlainClack,PlainClack,PlainClack")
			expect(list[1].Args[3]):toBe(5)
		end)

		it("fires a Pet reward with the id and count", function()
			local pet = Charms.Catalog[1]
			run("givepet", `{pet.Id} 3`)
			local list = fired()
			expect(#list):toBe(1)
			expect(list[1].Target):toBe(owner)
			expect(list[1].Args[1]):toBe("Pet")
			expect(list[1].Args[2]):toBe(pet.Id)
			expect(list[1].Args[3]):toBe(3)
		end)

		it("fires an Egg reward", function()
			local egg = Eggs.Catalog[1]
			run("giveegg", `{egg.Id} 2 Buddy`)
			local list = fired()
			expect(#list):toBe(1)
			expect(list[1].Target):toBe(friend)
			expect(list[1].Args[1]):toBe("Egg")
			expect(list[1].Args[2]):toBe(egg.Id)
			expect(list[1].Args[3]):toBe(2)
		end)

		it("fires Cash for money, income and maxmoney", function()
			run("money", "1m")
			local list = fired()
			expect(#list):toBe(1)
			expect(list[1].Args[1]):toBe("Cash")
			expect(tonumber(list[1].Args[2])):toBe(1000000)
			run("maxmoney", "")
			list = fired()
			expect(#list):toBe(2)
			expect(list[2].Args[1]):toBe("Cash")
			expect(tonumber(list[2].Args[2]) > 0):toBe(true)
			expect(list[2].Target):toBe(owner)
		end)

		it("fires nothing for failures and non-admins", function()
			run("givekey", "Bogus")
			run("giveegg", "Nope")
			run("givepet", "Nope")
			run("money", "abc")
			world:invoke("AdminCommand", friend, "money", "1m")
			world:invoke("AdminCommand", friend, "givekey", "PlainClack 2")
			expect(#fired()):toBe(0)
		end)

		it("fires to each target when targeting all", function()
			run("money", "1k all")
			local list = fired()
			expect(#list):toBe(2)
			expect(list[1].Target ~= list[2].Target):toBe(true)
		end)
	end)
end)
