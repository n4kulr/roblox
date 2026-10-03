local H = require("../harness/Harness")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

describe("SettingsService", function()
	local world, player, data

	beforeEach(function()
		world = H.newWorld()
		world:boot({ "SettingsService" })
		player, data = world:join()
	end)

	local function set(name: any, value: any)
		world:invoke("SetSetting", player, name, value)
	end

	it("stores boolean settings as value ~= 0", function()
		set("LowGraphics", 1)
		expect(data.Settings.LowGraphics):toBe(true)
		set("LowGraphics", 0)
		expect(data.Settings.LowGraphics):toBe(false)
		set("AutoPlace", 0)
		expect(data.Settings.AutoPlace):toBe(false)
		set("AutoPlace", 0.4)
		expect(data.Settings.AutoPlace):toBe(true)
		set("AutoPlace", -1)
		expect(data.Settings.AutoPlace):toBe(true)
	end)

	it("clamps volumes to 0..1 and rounds to two decimals", function()
		set("RollVolume", 2)
		expect(data.Settings.RollVolume):toBe(1)
		set("RollVolume", -3)
		expect(data.Settings.RollVolume):toBe(0)
		set("BoardVolume", 0.337)
		expect(data.Settings.BoardVolume):toBeCloseTo(0.34, 1e-9)
		set("OtherVolume", 0.5)
		expect(data.Settings.OtherVolume):toBe(0.5)
	end)

	it("ignores names outside the whitelist", function()
		local before = H.deepCopy(data)
		for _, name in { "Cash", "Tutorial", "Rolls", "Settings", "__index", "", "lowgraphics", " AutoPlace" } do
			set(name, 1)
		end
		expect(data):toEqual(before)
		expect(data.Settings.Cash):toBeNil()
	end)

	it("ignores non-string names and non-number values", function()
		local before = H.deepCopy(data)
		set(5, 1)
		set(nil, 1)
		set({}, 1)
		set("AutoPlace", "0")
		set("AutoPlace", true)
		set("RollVolume", {})
		set("RollVolume", nil)
		expect(data):toEqual(before)
	end)

	it("rejects NaN and infinities", function()
		local before = H.deepCopy(data)
		for _, name in { "LowGraphics", "AutoPlace", "RollVolume", "BoardVolume", "OtherVolume" } do
			set(name, 0 / 0)
			set(name, math.huge)
			set(name, -math.huge)
		end
		expect(data):toEqual(before)
	end)

	it("does not store non-finite junk in the volume even when mixed with valid writes", function()
		set("RollVolume", 0.25)
		set("RollVolume", 0 / 0)
		expect(data.Settings.RollVolume):toBe(0.25)
	end)

	it("does not error for players without data", function()
		local stranger = world:newPlayer()
		world:invoke("SetSetting", stranger, "AutoPlace", 0)
		expect(#world.errors):toBe(0)
	end)

	it("stops listening after Destroy", function()
		world:destroy()
		set("AutoPlace", 0)
		expect(data.Settings.AutoPlace):toBe(true)
	end)
end)
