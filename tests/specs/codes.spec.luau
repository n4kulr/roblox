local H = require("../harness/Harness")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

local success, invalid, used, expired = 1, 2, 3, 4

describe("CodeService", function()
	local world, services, player, data

	beforeEach(function()
		world = H.newWorld({ Time = 1700000000 })
		world.overrides[world:node("ServerScriptService.Config.Codes")] = {
			ByCode = {
				THOCK = { Code = "THOCK", Reward = { Kind = "Clicks", Amount = 1000, Label = "1K Clicks" } },
				RELEASE = {
					Code = "RELEASE",
					Reward = { Kind = "LuckPotion", Amount = 900, Label = "2x Luck (15 min)" },
				},
				CLACKY = {
					Code = "CLACKY",
					Reward = { Kind = "Key", Amount = 1, Rarity = "Rare", Label = "Rare Key" },
				},
				OLD = {
					Code = "OLD",
					Reward = { Kind = "Clicks", Amount = 50, Label = "50 Clicks" },
					ExpiresAt = 1699999999,
				},
				LATE = {
					Code = "LATE",
					Reward = { Kind = "Clicks", Amount = 70, Label = "70 Clicks" },
					ExpiresAt = 1700000001,
				},
			},
		}
		local byCode = world:require("ServerScriptService.Config.Codes").ByCode
		byCode[string.rep("A", 32)] = { Code = string.rep("A", 32), Reward = { Kind = "Clicks", Amount = 5 } }
		byCode[string.rep("A", 33)] = { Code = string.rep("A", 33), Reward = { Kind = "Clicks", Amount = 5 } }
		services = world:boot({ "KeyboardService", "CodeService" })
		player, data = world:join(nil, { IncomeAt = world.now, Settings = { AutoPlace = false } })
	end)

	local function redeem(text: any): number
		return world:invoke("RedeemCode", player, text)
	end

	it("grants Clicks and counts them as earned", function()
		expect(redeem("THOCK")):toBe(success)
		expect(data.Cash):toBe(1000)
		expect(data.TotalEarned):toBe(1000)
		expect(data.RedeemedCodes.THOCK):toBe(true)
	end)

	it("grants potions", function()
		expect(redeem("RELEASE")):toBe(success)
		expect(data.Boosts.LuckUntil):toBe(world.now + 900)
	end)

	it("grants keys of the right rarity", function()
		local Keys = world:require("ReplicatedStorage.Config.Keys")
		expect(redeem("CLACKY")):toBe(success)
		local total = 0
		for keyId, count in data.Inventory do
			total += count
			expect(Keys.ById[keyId].Rarity):toBe("Rare")
		end
		expect(total):toBe(1)
	end)

	it("normalizes case and surrounding whitespace", function()
		expect(redeem("  thock \t")):toBe(success)
		expect(data.RedeemedCodes.THOCK):toBe(true)
	end)

	it("rejects a code that was already redeemed without granting again", function()
		expect(redeem("THOCK")):toBe(success)
		expect(redeem("thock")):toBe(used)
		expect(data.Cash):toBe(1000)
	end)

	it("keeps codes independent", function()
		expect(redeem("THOCK")):toBe(success)
		expect(redeem("RELEASE")):toBe(success)
		expect(data.RedeemedCodes):toEqual({ THOCK = true, RELEASE = true })
	end)

	it("rejects unknown codes", function()
		expect(redeem("NOPE")):toBe(invalid)
		expect(data.RedeemedCodes):toEqual({})
	end)

	it("rejects empty and whitespace-only codes", function()
		expect(redeem("")):toBe(invalid)
		expect(redeem("   ")):toBe(invalid)
	end)

	it("rejects codes longer than 32 characters even when configured", function()
		expect(redeem(string.rep("A", 33))):toBe(invalid)
		expect(data.Cash):toBe(0)
		expect(redeem(string.rep("A", 32))):toBe(success)
	end)

	it("rejects non-printable characters", function()
		expect(redeem("TH\0OCK")):toBe(invalid)
		expect(redeem("THOCK\n\nX")):toBe(invalid)
		expect(redeem("THÖCK")):toBe(invalid)
	end)

	it("rejects non-string input", function()
		expect(redeem(5)):toBe(invalid)
		expect(redeem(nil)):toBe(invalid)
	end)

	it("reports expired codes and grants nothing", function()
		expect(redeem("OLD")):toBe(expired)
		expect(data.Cash):toBe(0)
		expect(data.RedeemedCodes.OLD):toBeNil()
	end)

	it("accepts a code until it expires", function()
		expect(redeem("LATE")):toBe(success)
		expect(data.Cash):toBe(70)
	end)

	it("expires codes at the deadline", function()
		world:setTime(1700000001)
		expect(redeem("LATE")):toBe(expired)
	end)

	it("fails for players without data", function()
		local stranger = world:newPlayer()
		expect(world:invoke("RedeemCode", stranger, "THOCK")):toBe(invalid)
	end)

	it("clears its packet handler on Destroy", function()
		services.CodeService:Destroy()
		expect(world:packets().RedeemCode.OnServerInvoke):toBeNil()
	end)
end)

describe("Server codes config", function()
	it("ships uppercase lookups for every code", function()
		local world = H.newWorld()
		local Codes = world:require("ServerScriptService.Config.Codes")
		for key, code in Codes.ByCode do
			expect(key):toBe(string.upper(code.Code))
			expect(code.Reward.Amount > 0):toBe(true)
		end
		expect(Codes.ByCode.THOCK ~= nil):toBe(true)
	end)
end)
