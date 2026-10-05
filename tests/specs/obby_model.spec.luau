local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local H = require("../harness/Harness")

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

local function summarize(root: any): { Parts: number, Roles: { [string]: number }, Zone: any }
	local roles: { [string]: number } = {}
	local parts = 0
	local zone = nil
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			parts += 1
			local role = descendant:GetAttribute("ObbyRole")
			if type(role) == "string" then
				roles[role] = (roles[role] or 0) + 1
				if role == "Zone" then
					zone = descendant
				end
			end
		end
	end
	return { Parts = parts, Roles = roles, Zone = zone }
end

describe("Obby.rbxm", function()
	local world

	beforeEach(function()
		world = H.newWorld()
	end)

	afterEach(function()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	it("matches the runtime builder so the committed model cannot drift", function()
		local Obby = world:require("ReplicatedStorage.Rules.Obby")
		local Course = world:require("ServerScriptService.Services.ObbyService.Course")
		local built = Course.Build(Obby.Entrance(nil), Course.ModelName)
		local expected = summarize(built)
		local roots = roblox.deserializeModel(fs.readFile("assets/map/Obby.rbxm"))
		expect(#roots):toBe(1)
		local model = roots[1]
		expect(model.Name):toBe("Obby")
		local actual = summarize(model)
		expect(actual.Parts):toBe(expected.Parts)
		expect(actual.Roles):toEqual(expected.Roles)
		expect(actual.Roles.TapKey > 0):toBe(true)
		expect(actual.Roles.PopUpKey):toBe(2)
		expect(actual.Roles.Zone):toBe(1)
		local a, b = actual.Zone.CFrame.Position, expected.Zone.CFrame.Position
		expect((a - b).Magnitude < 0.01):toBe(true)
	end)

	it("ships anchored parts only", function()
		local roots = roblox.deserializeModel(fs.readFile("assets/map/Obby.rbxm"))
		for _, descendant in roots[1]:GetDescendants() do
			if descendant:IsA("BasePart") then
				expect(descendant.Anchored):toBe(true)
			end
		end
	end)
end)
