local H = require("../harness/Harness")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

describe("WorldNames", function()
	local world, WorldNames

	beforeEach(function()
		world = H.newWorld()
		WorldNames = world:require("ReplicatedStorage.Config.WorldNames")
	end)

	it("exposes every name group", function()
		for _, group in { "Attributes", "Tags", "Folders", "Parts", "Prompts", "Channels" } do
			expect(type(WorldNames[group])):toBe("table")
		end
	end)

	it("freezes the root and every group", function()
		expect(table.isfrozen(WorldNames)):toBe(true)
		for _, group in WorldNames do
			expect(table.isfrozen(group)):toBe(true)
		end
	end)

	it("maps each key to an identical non-empty string", function()
		for groupName, group in WorldNames do
			for key, value in group do
				expect(`{groupName}.{key}:{type(value)}`):toBe(`{groupName}.{key}:string`)
				expect(value):toBe(key)
				expect(#value > 0):toBe(true)
			end
		end
	end)

	it("keeps values unique inside a group", function()
		for groupName, group in WorldNames do
			local seen = {}
			for _, value in group do
				expect(`{groupName}.{value}:{tostring(seen[value])}`):toBe(`{groupName}.{value}:nil`)
				seen[value] = true
			end
		end
	end)

	it("does not reuse a prompt, folder or part name as an attribute", function()
		local attributes = WorldNames.Attributes
		for _, groupName in { "Folders", "Parts", "Prompts" } do
			for _, value in WorldNames[groupName] do
				expect(`{groupName}.{value}:{tostring(attributes[value])}`):toBe(`{groupName}.{value}:nil`)
			end
		end
	end)

	it("matches the names the loading screen copies", function()
		local Config = world:require("ReplicatedFirst.Loading.Config")
		expect(Config.ReadyAttribute):toBe(WorldNames.Attributes.ClientReady)
	end)
end)
