local roblox = require("@lune/roblox")
local H = require("../harness/Harness")

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

local legendaryIndex = 5

local function partsOf(model: any): { any }
	local out = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(out, descendant)
		end
	end
	return out
end

local function signature(model: any): string
	local names = {}
	for _, part in partsOf(model) do
		table.insert(names, part.Name)
	end
	table.sort(names)
	return table.concat(names, ",")
end

describe("Key models", function()
	local world, Keys, KeyModels, Steal

	beforeEach(function()
		world = H.newWorld()
		Keys = world:require("ReplicatedStorage.Config.Keys")
		KeyModels = world:require("ReplicatedStorage.Utils.KeyModels")
		Steal = world:require("ReplicatedStorage.Rules.Steal")
	end)

	afterEach(function()
		world:destroy()
	end)

	local function rarityIndex(key: any): number
		for index, rarity in Keys.Rarities do
			if rarity.Name == key.Rarity then
				return index
			end
		end
		return 0
	end

	it("builds a model with a primary part and a modest part count for every key", function()
		for _, key in Keys.Catalog do
			local model = KeyModels.Build(key.Id)
			expect(model.PrimaryPart ~= nil):toBe(true)
			local count = #partsOf(model)
			expect(count >= 3):toBe(true)
			expect(count <= KeyModels.PartLimit):toBe(true)
			expect(model.Name):toBe(key.Id)
		end
	end)

	it("never uses neon and keeps every part non-colliding", function()
		for _, key in Keys.Catalog do
			for _, part in partsOf(KeyModels.Build(key.Id)) do
				expect(part.Material ~= roblox.Enum.Material.Neon):toBe(true)
				expect(part.CanCollide):toBe(false)
			end
		end
	end)

	it("builds a plain fallback model for unknown ids", function()
		local model = KeyModels.Build("NoSuchKey")
		expect(model.PrimaryPart ~= nil):toBe(true)
		expect(KeyModels.HasDecoration("NoSuchKey")):toBe(false)
	end)

	it("gives every legend a letter and a darker skirt", function()
		for _, key in Keys.Catalog do
			local model = KeyModels.Build(key.Id)
			local dish = model:FindFirstChild("Dish")
			expect(dish:FindFirstChild("Legend").Letter.Text):toBe(string.upper(string.sub(key.Name, 1, 1)))
			local skirt, top = model.Skirt.Color, model.Top.Color
			expect(skirt.R + skirt.G + skirt.B < top.R + top.G + top.B):toBe(true)
		end
	end)

	it("has a unique decoration for exactly the Legendary and higher keys", function()
		local names: { [string]: string } = {}
		local signatures: { [string]: string } = {}
		for _, key in Keys.Catalog do
			local expected = rarityIndex(key) >= legendaryIndex
			expect(KeyModels.HasDecoration(key.Id)):toBe(expected)
			if expected then
				local decoration = KeyModels.Decorations[key.Id]
				expect(names[decoration.Name]):toBeNil()
				names[decoration.Name] = key.Id
				local sig = signature(KeyModels.BuildDecoration(key.Id, roblox.CFrame.new(), 1, true))
				expect(signatures[sig]):toBeNil()
				signatures[sig] = key.Id
			end
		end
		for keyId in KeyModels.Decorations do
			expect(Keys.ById[keyId] ~= nil):toBe(true)
		end
	end)

	it("builds Legendary and higher models with more parts than the plain keycap", function()
		local plain = #partsOf(KeyModels.Build("PlainClack"))
		for _, key in Keys.Catalog do
			if rarityIndex(key) >= legendaryIndex then
				expect(#partsOf(KeyModels.Build(key.Id)) > plain):toBe(true)
			end
		end
	end)

	it("makes lava from smooth plastic with embers and no neon", function()
		local model = KeyModels.Build("LavaKey")
		local emitters = 0
		for _, descendant in model:GetDescendants() do
			if descendant.ClassName == "ParticleEmitter" then
				emitters += 1
			end
		end
		expect(emitters):toBe(1)
		expect(model.BlobCore.Material):toBe(roblox.Enum.Material.SmoothPlastic)
		expect(model.BlobCore.Reflectance > 0):toBe(true)
	end)

	it("scales decorations with the requested scale", function()
		local full = KeyModels.BuildDecoration("ThunderKey", roblox.CFrame.new(), 1, true)
		local half = KeyModels.BuildDecoration("ThunderKey", roblox.CFrame.new(), 0.5, true)
		expect(math.abs(half.CloudB.Size.X * 2 - full.CloudB.Size.X) < 1e-4):toBe(true)
		expect(KeyModels.BuildDecoration("PlainClack", roblox.CFrame.new(), 1, true)):toBeNil()
	end)

	it("resolves every new key everywhere the catalog is used", function()
		local newIds = {
			"DustyKeycap",
			"StickyShift",
			"PencilPad",
			"CoffeeCap",
			"MintTactile",
			"PeachPastel",
			"LemonLinear",
			"SkyClick",
			"OceanLinear",
			"CoralClick",
			"MochiPink",
			"ForestTactile",
			"NebulaClicky",
			"SakuraPop",
			"ArcadeClacker",
			"FrostbiteClick",
			"DragonSpacebar",
			"PhoenixPlume",
			"FrostCrown",
			"TreasureTab",
			"GalaxyEnter",
			"AuroraAlt",
			"EclipseShift",
			"VoidEsc",
			"PrismReturn",
			"GlitchTab",
		}
		local seen: { [string]: boolean } = {}
		for _, key in Keys.Catalog do
			expect(seen[key.Id]):toBeNil()
			seen[key.Id] = true
			expect(Keys.ById[key.Id]):toBe(key)
			expect(Keys.GetIncome(key.Id)):toBe(Keys.GetRarity(key).Income)
			expect(Keys.GetSellValue(key.Id) >= 10):toBe(true)
			expect(Steal.RarityIndex(key.Id)):toBe(rarityIndex(key))
		end
		local perRarity: { [string]: number } = {}
		for _, keyId in newIds do
			local key = Keys.ById[keyId]
			expect(key ~= nil):toBe(true)
			expect(key.Exclusive):toBe(false)
			expect(key.Perk):toBeNil()
			perRarity[key.Rarity] = (perRarity[key.Rarity] or 0) + 1
			local listed = false
			for _, entry in Keys.ByRarity[key.Rarity] do
				listed = listed or entry == key
			end
			expect(listed):toBe(true)
		end
		for _, rarity in Keys.Rarities do
			expect((perRarity[rarity.Name] or 0) >= 3):toBe(true)
		end
	end)
end)

describe("Base slot decorations", function()
	local world, registry, plots, Keys

	beforeEach(function()
		world = H.newWorld({ Time = 1700000000 })
		Keys = world:require("ReplicatedStorage.Config.Keys")
		world.workspace = world:newInstance("Folder")
		local plotService = world:require("ServerScriptService.Services.PlotService")
		registry = world:boot({ "KeyboardService", "PlotService" }, { PlotService = plotService })
		plots = world.workspace:FindFirstChild("Plots")
	end)

	afterEach(function()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	local function join()
		local player, data =
			world:join({ Name = "Typist" }, { PlaySeconds = 5000, Board = { "PlainClack" } }, true)
		for _, plot in plots:GetChildren() do
			if plot:GetAttribute("Owner") == player.UserId then
				return player, data, plot
			end
		end
		error("no plot")
	end

	local function decorOf(cap: any): any
		for _, child in cap:GetChildren() do
			if child.ClassName == "Model" then
				return child
			end
		end
		return nil
	end

	local function setSlot(player: any, data: any, slot: number, keyId: string)
		data.Board[slot] = keyId
		registry.KeyboardService.BoardChanged:Fire(player)
	end

	it("mounts welded, unanchored decorations only for Legendary and higher keys", function()
		local player, data, plot = join()
		local cap = plot.Keys:FindFirstChild("Slot1")
		expect(decorOf(cap)):toBeNil()
		setSlot(player, data, 1, "GlassTink")
		expect(decorOf(cap)):toBeNil()
		for _, key in Keys.Catalog do
			setSlot(player, data, 1, key.Id)
			local decor = decorOf(cap)
			local isTall = false
			for index, rarity in Keys.Rarities do
				if rarity.Name == key.Rarity then
					isTall = index >= legendaryIndex
				end
			end
			expect(decor ~= nil):toBe(isTall)
			if decor then
				for _, part in partsOf(decor) do
					expect(part.Anchored):toBe(false)
					expect(part.CanCollide):toBe(false)
					expect(part.CapWeld.Part0):toBe(cap)
				end
			end
		end
	end)

	it("removes decorations when the slot empties or changes to a plain key", function()
		local player, data, plot = join()
		local cap = plot.Keys:FindFirstChild("Slot2")
		setSlot(player, data, 2, "ThunderKey")
		local first = decorOf(cap)
		expect(first ~= nil):toBe(true)
		setSlot(player, data, 2, "LavaKey")
		local second = decorOf(cap)
		expect(second ~= nil and second ~= first):toBe(true)
		expect(second.Name):toBe("LavaDecor")
		local count = 0
		for _, child in cap:GetChildren() do
			if child.ClassName == "Model" then
				count += 1
			end
		end
		expect(count):toBe(1)
		setSlot(player, data, 2, "PlainClack")
		expect(decorOf(cap)):toBeNil()
		setSlot(player, data, 2, "VoidEsc")
		expect(decorOf(cap) ~= nil):toBe(true)
		setSlot(player, data, 2, "")
		expect(decorOf(cap)):toBeNil()
	end)

	it("scales decorations to the cap", function()
		local player, data, plot = join()
		local cap = plot.Keys:FindFirstChild("Slot1")
		setSlot(player, data, 1, "ThunderKey")
		local KeyModels = world:require("ReplicatedStorage.Utils.KeyModels")
		local expected =
			KeyModels.BuildDecoration("ThunderKey", cap.CFrame, cap.Size.X / KeyModels.BaseWidth, true)
		expect(math.abs(decorOf(cap).CloudB.Size.X - expected.CloudB.Size.X) < 1e-4):toBe(true)
	end)
end)
