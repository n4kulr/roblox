local H = require("../harness/Harness")
local roblox = require("@lune/roblox")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

describe("Egg and pet models", function()
	local world, Eggs, Charms, EggModel, PetModels

	local function partsOf(model: any): { any }
		local found = {}
		for _, item in model:GetDescendants() do
			if item.ClassName == "Part" then
				table.insert(found, item)
			end
		end
		return found
	end

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
		Eggs = world:require("ReplicatedStorage.Config.Eggs")
		Charms = world:require("ReplicatedStorage.Config.Charms")
		EggModel = world:require("ReplicatedStorage.Utils.EggModel")
		PetModels = world:require("ReplicatedStorage.Utils.PetModels")
	end)

	it("builds every egg within the part limit and without neon", function()
		for _, egg in Eggs.Catalog do
			local model = EggModel.Model(egg, 1)
			local parts = partsOf(model)
			local meshParts = {}
			for _, item in model:GetDescendants() do
				if item.ClassName == "MeshPart" then
					table.insert(meshParts, item)
				end
			end
			local total = #parts + #meshParts
			expect(total >= 1):toBe(true)
			expect(total <= EggModel.MaxParts):toBe(true)
			expect(model.PrimaryPart.Color):toBe(egg.Color)
			if #meshParts == 0 then
				expect(#parts >= 8):toBe(true)
				expect(model:FindFirstChild("EggRing") ~= nil):toBe(true)
				expect(model:FindFirstChild("EggSpot1").Color):toBe(egg.SpotColor)
			end
			for _, part in parts do
				expect(part.Material == roblox.Enum.Material.Neon):toBe(false)
				expect(part.Anchored):toBe(true)
				expect(part.CanCollide):toBe(false)
			end
			for _, part in meshParts do
				expect(part.Material == roblox.Enum.Material.Neon):toBe(false)
				expect(part.Anchored):toBe(true)
				expect(part.CanCollide):toBe(false)
			end
		end
	end)

	it("gives each tier its own look when using placeholder eggs", function()
		local linear = EggModel.Model(Eggs.ById.Linear, 1)
		if linear.PrimaryPart and linear.PrimaryPart.ClassName == "MeshPart" then
			expect(EggModel.HeightOf(1)):toBe(3.2)
			return
		end
		local counts = {}
		for _, egg in Eggs.Catalog do
			counts[egg.Id] = #partsOf(EggModel.Model(egg, 1))
		end
		expect(EggModel.Model(Eggs.ById.Rainbow, 1):FindFirstChild("EggBand5") ~= nil):toBe(true)
		expect(EggModel.Model(Eggs.ById.Clicky, 1):FindFirstChild("EggKeyTop1") ~= nil):toBe(true)
		expect(EggModel.Model(Eggs.ById.Golden, 1):FindFirstChild("EggBody").Material == roblox.Enum.Material.Metal):toBe(
			true
		)
		expect(counts.Tactile > counts.Linear):toBe(true)
	end)

	it("keeps the egg height the placement code relies on", function()
		expect(EggModel.HeightOf(1)):toBe(3.2)
		local model = EggModel.Model(Eggs.ById.Linear, 1)
		if model.PrimaryPart and model.PrimaryPart.ClassName == "MeshPart" then
			expect(math.abs(model.PrimaryPart.Size.Y - 3.2) < 1e-3):toBe(true)
			return
		end
		local lowest = math.huge
		for _, part in partsOf(model) do
			lowest = math.min(lowest, part.CFrame.Position.Y - part.Size.Y / 2)
		end
		expect(math.abs(lowest + 1.6) < 1e-3):toBe(true)
	end)

	it("builds every pet within the part limit, tinted by rarity and without neon", function()
		for _, charm in Charms.Catalog do
			local model, size = PetModels.Build(charm)
			local parts = partsOf(model)
			local meshParts = {}
			for _, item in model:GetDescendants() do
				if item.ClassName == "MeshPart" then
					table.insert(meshParts, item)
				end
			end
			expect(#parts + #meshParts <= PetModels.MaxParts):toBe(true)
			expect(model.PrimaryPart.Name):toBe("Body")
			expect(model.PrimaryPart.Color == charm.Color):toBe(true)
			expect(size):toBe(PetModels.SizeOf(charm.Rarity))
			if #meshParts == 0 then
				expect(model:FindFirstChild("Head") ~= nil):toBe(true)
				expect(model:FindFirstChild("LeftEar") ~= nil):toBe(true)
			end
			for _, part in parts do
				expect(part.Material == roblox.Enum.Material.Neon):toBe(false)
				expect(part.Anchored):toBe(true)
			end
			for _, part in meshParts do
				expect(part.Material == roblox.Enum.Material.Neon):toBe(false)
				expect(part.Anchored):toBe(true)
			end
		end
	end)

	it("grows pets with rarity and crowns placeholder legendary ones", function()
		local common = Charms.ByRarity.Common[1]
		local mythic = Charms.ByRarity.Mythic[1]
		expect(PetModels.SizeOf("Mythic") > PetModels.SizeOf("Common")):toBe(true)
		local commonModel = PetModels.Build(common)
		local mythicModel = PetModels.Build(mythic)
		if commonModel.PrimaryPart and commonModel.PrimaryPart.ClassName ~= "MeshPart" then
			expect(commonModel:FindFirstChild("Crown")):toBeNil()
		end
		if mythicModel.PrimaryPart and mythicModel.PrimaryPart.ClassName ~= "MeshPart" then
			expect(mythicModel:FindFirstChild("Crown") ~= nil):toBe(true)
		end
		expect(PetModels.LiftOf(2) > 0.275 * 2):toBe(true)
	end)

	it("builds a MeshPart pet when PetMeshes has an id", function()
		local charm = Charms.Catalog[1]
		local meshId = "rbxassetid://123456789"
		local meshWorld = H.newWorld({ PrintErrors = false })
		meshWorld.overrides[meshWorld.tree.ReplicatedStorage.Config.PetMeshes] = {
			[charm.Id] = meshId,
		}
		local meshCharms = meshWorld:require("ReplicatedStorage.Config.Charms")
		local meshPets = meshWorld:require("ReplicatedStorage.Utils.PetModels")
		local model, size = meshPets.Build(meshCharms.ById[charm.Id])
		expect(size):toBe(meshPets.SizeOf(charm.Rarity))
		expect(model.PrimaryPart.ClassName):toBe("MeshPart")
		expect(model.PrimaryPart.Name):toBe("Body")
		expect(model.PrimaryPart.Color == charm.Color):toBe(true)
		expect(model:GetAttribute("Lift")):toBe(0)
		expect(meshWorld.meshRequests[1]):toBe(meshId)
		meshWorld:destroy()
	end)
end)
