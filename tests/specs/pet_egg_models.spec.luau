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
			expect(#parts >= 8):toBe(true)
			expect(#parts <= EggModel.MaxParts):toBe(true)
			expect(model.PrimaryPart.Color):toBe(egg.Color)
			expect(model:FindFirstChild("EggRing") ~= nil):toBe(true)
			expect(model:FindFirstChild("EggSpot1").Color):toBe(egg.SpotColor)
			for _, part in parts do
				expect(part.Material == roblox.Enum.Material.Neon):toBe(false)
				expect(part.Anchored):toBe(true)
				expect(part.CanCollide):toBe(false)
			end
		end
	end)

	it("gives each tier its own look", function()
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
			expect(#parts <= PetModels.MaxParts):toBe(true)
			expect(model.PrimaryPart.Name):toBe("Body")
			expect(model.PrimaryPart.Color == charm.Color):toBe(true)
			expect(model:FindFirstChild("Head") ~= nil):toBe(true)
			expect(model:FindFirstChild("LeftEar") ~= nil):toBe(true)
			expect(size):toBe(PetModels.SizeOf(charm.Rarity))
			for _, part in parts do
				expect(part.Material == roblox.Enum.Material.Neon):toBe(false)
				expect(part.Anchored):toBe(true)
			end
		end
	end)

	it("grows pets with rarity and crowns the legendary ones", function()
		local common = Charms.ByRarity.Common[1]
		local mythic = Charms.ByRarity.Mythic[1]
		expect(PetModels.SizeOf("Mythic") > PetModels.SizeOf("Common")):toBe(true)
		expect(PetModels.Build(common):FindFirstChild("Crown")):toBeNil()
		expect(PetModels.Build(mythic):FindFirstChild("Crown") ~= nil):toBe(true)
		expect(PetModels.LiftOf(2) > 0.275 * 2):toBe(true)
	end)
end)
