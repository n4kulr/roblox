local H = require("../harness/Harness")

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

describe("PlayerData.Validate", function()
	local world, PlayerData

	beforeEach(function()
		world = H.newWorld()
		PlayerData = world:require("ServerScriptService.Data.PlayerData")
	end)

	afterEach(function()
		world:destroy()
	end)

	local function withField(name: string, value: any): any
		local data = H.deepCopy(PlayerData.Template)
		data[name] = value
		return data
	end

	it("accepts the template", function()
		expect(PlayerData.Validate(H.deepCopy(PlayerData.Template))):toBe(true)
	end)

	it("accepts well formed charms, eggs and equipped charms", function()
		local data = H.deepCopy(PlayerData.Template)
		data.Charms = { ThockPad = 2 }
		data.EggInventory = { Linear = 3 }
		data.EquippedCharms = { "ThockPad" }
		data.PlacedEggs = { { Id = "Linear", ReadyAt = 1700000000, X = -4.5, Z = 12 } }
		expect(PlayerData.Validate(data)):toBe(true)
	end)

	it("rejects malformed Charms", function()
		expect(PlayerData.Validate(withField("Charms", "x"))):toBe(false)
		expect(PlayerData.Validate(withField("Charms", { ThockPad = "2" }))):toBe(false)
		expect(PlayerData.Validate(withField("Charms", { ThockPad = -1 }))):toBe(false)
		expect(PlayerData.Validate(withField("Charms", { ThockPad = 1.5 }))):toBe(false)
		expect(PlayerData.Validate(withField("Charms", { [1] = 2 }))):toBe(false)
	end)

	it("rejects malformed EggInventory", function()
		expect(PlayerData.Validate(withField("EggInventory", 4))):toBe(false)
		expect(PlayerData.Validate(withField("EggInventory", { Linear = true }))):toBe(false)
		expect(PlayerData.Validate(withField("EggInventory", { Linear = 0 / 0 }))):toBe(false)
	end)

	it("rejects malformed EquippedCharms", function()
		expect(PlayerData.Validate(withField("EquippedCharms", "ThockPad"))):toBe(false)
		expect(PlayerData.Validate(withField("EquippedCharms", { 5 }))):toBe(false)
		expect(PlayerData.Validate(withField("EquippedCharms", { Slot = "ThockPad" }))):toBe(false)
	end)

	it("rejects malformed PlacedEggs", function()
		local good = { Id = "Linear", ReadyAt = 1, X = 0, Z = 0 }
		expect(PlayerData.Validate(withField("PlacedEggs", { good }))):toBe(true)
		expect(PlayerData.Validate(withField("PlacedEggs", "none"))):toBe(false)
		expect(PlayerData.Validate(withField("PlacedEggs", { "Linear" }))):toBe(false)
		expect(PlayerData.Validate(withField("PlacedEggs", { { Id = 1, ReadyAt = 1, X = 0, Z = 0 } }))):toBe(false)
		expect(PlayerData.Validate(withField("PlacedEggs", { { Id = "Linear", X = 0, Z = 0 } }))):toBe(false)
		expect(PlayerData.Validate(withField("PlacedEggs", { { Id = "Linear", ReadyAt = 1, X = "0", Z = 0 } }))):toBe(false)
		expect(PlayerData.Validate(withField("PlacedEggs", { { Id = "Linear", ReadyAt = 1, X = 0, Z = math.huge } }))):toBe(false)
	end)

	it("no longer carries the daily reward record", function()
		expect(PlayerData.Template.Daily):toBeNil()
		expect(PlayerData.Validate(withField("Daily", { Streak = 1, LastClaim = 1 }))):toBe(true)
	end)

	it("keeps the group chest timestamp", function()
		expect(PlayerData.Template.GroupChestAt):toBe(0)
		expect(PlayerData.Validate(withField("GroupChestAt", -1))):toBe(false)
	end)
end)
