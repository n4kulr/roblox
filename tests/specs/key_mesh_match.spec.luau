local H = require("../harness/Harness")

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

describe("Key model matches the base cap", function()
	local world, plots, KeyModels, FloorGrid

	local function boot(authored: { string })
		world = H.newWorld({ Time = 1700000000 })
		if #authored == 0 then
			world.overrides[world.tree.ReplicatedStorage.Config.Meshes] = { Keycap = "", RollKey = "", KeyboardCase = "" }
		end
		if #authored > 0 then
			local folder = world:newInstance("Folder")
			folder.Name = "Meshes"
			for _, name in authored do
				local part = world:newInstance("MeshPart")
				part.Name = name
				part.Parent = folder
			end
			folder.Parent = world.fakeServices.ServerStorage
		end
		KeyModels = world:require("ReplicatedStorage.Utils.KeyModels")
		FloorGrid = world:require("ReplicatedStorage.Rules.FloorGrid")
		world.workspace = world:newInstance("Folder")
		local plotService = world:require("ServerScriptService.Services.PlotService")
		local registry = world:boot({ "KeyboardService", "PlotService" }, { PlotService = plotService })
		plots = world.workspace:FindFirstChild("Plots")
		return registry
	end

	afterEach(function()
		expect(world.errors):toEqual({})
		local assets = world.tree.ReplicatedStorage:FindFirstChild("Assets")
		if assets then
			assets:Destroy()
		end
		world:destroy()
	end)

	it("replicates the Keycap and RollKey templates to ReplicatedStorage.Assets.Meshes", function()
		boot({ "Keycap", "RollKey" })
		local meshes = world.tree.ReplicatedStorage.Assets.Meshes
		expect(meshes.Keycap.ClassName):toBe("MeshPart")
		expect(meshes.RollKey.ClassName):toBe("MeshPart")
	end)

	it("replicates nothing when no meshes exist and builds the part keycap", function()
		boot({})
		local assets = world.tree.ReplicatedStorage:FindFirstChild("Assets")
		local meshes = if assets then assets:FindFirstChild("Meshes") else nil
		expect(meshes ~= nil and meshes:FindFirstChild("Keycap") or nil):toBeNil()
		local model = KeyModels.Build("PlainClack")
		expect(model:FindFirstChild("Skirt") ~= nil):toBe(true)
		expect(model:FindFirstChild("Cap")):toBeNil()
	end)

	it("clones the replicated mesh at base proportions scaled uniformly", function()
		boot({ "Keycap", "RollKey" })
		local model = KeyModels.Build("PlainClack")
		local cap = model:FindFirstChild("Cap")
		expect(cap.ClassName):toBe("MeshPart")
		expect(model.PrimaryPart):toBe(cap)
		local scale = KeyModels.ViewScale
		expect(math.abs(cap.Size.X - FloorGrid.CapSize() * scale) < 1e-6):toBe(true)
		expect(math.abs(cap.Size.Y - FloorGrid.CapHeight * scale) < 1e-6):toBe(true)
		expect(math.abs(cap.Size.Z - FloorGrid.CapSize() * scale) < 1e-6):toBe(true)
	end)

	it("matches the finish, legend and decoration of the base cap for every key", function()
		local ids = { "PlainClack", "GlassTink", "ThunderKey", "LavaKey", "DragonSpacebar", "VoidEsc", "GalaxyEnter" }
		local registry = boot({ "Keycap", "RollKey" })
		local player, data = world:join({ Name = "Typist" }, { PlaySeconds = 5000, Board = { "PlainClack" } }, true)
		local cap
		for _, plot in plots:GetChildren() do
			if plot:GetAttribute("Owner") == player.UserId then
				cap = plot.Keys:FindFirstChild("Slot1")
			end
		end
		for _, keyId in ids do
			data.Board[1] = keyId
			registry.KeyboardService.BoardChanged:Fire(player)
			local model = KeyModels.Build(keyId)
			local built = model:FindFirstChild("Cap")
			expect(built.Color):toBe(cap.Color)
			expect(built.Material):toBe(cap.Material)
			expect(built.Reflectance):toBe(cap.Reflectance)
			expect(built.Transparency):toBe(cap.Transparency)
			local baseLegend = cap.Top.Letter
			local legend = built.Top.Letter
			expect(legend.Text):toBe(baseLegend.Text)
			expect(legend.TextColor3):toBe(baseLegend.TextColor3)
			expect(legend.Font):toBe(baseLegend.Font)
			expect(legend.TextStrokeColor3):toBe(baseLegend.TextStrokeColor3)
			expect(legend.Size):toBe(baseLegend.Size)
			expect(built.Top.Rim.Stroke.Color):toBe(cap.Top.Rim.Stroke.Color)
			local baseDecor, decor
			for _, child in cap:GetChildren() do
				if child.ClassName == "Model" then
					baseDecor = child
				end
			end
			for _, child in built:GetChildren() do
				if child.ClassName == "Model" then
					decor = child
				end
			end
			expect(decor ~= nil):toBe(baseDecor ~= nil)
			if decor then
				expect(decor.Name):toBe(baseDecor.Name)
				local baseParts = baseDecor:GetChildren()
				local parts = decor:GetChildren()
				expect(#parts):toBe(#baseParts)
				local ratio = KeyModels.ViewScale
				for index, part in parts do
					local reference = baseParts[index]
					expect(part.Name):toBe(reference.Name)
					expect(part.Color):toBe(reference.Color)
					expect(math.abs(part.Size.X - reference.Size.X * ratio) < 1e-4):toBe(true)
				end
			end
		end
	end)

	it("tints variants like the base cap", function()
		local registry = boot({ "Keycap", "RollKey" })
		local player, data = world:join({ Name = "Typist" }, { PlaySeconds = 5000, Board = { "PlainClack" } }, true)
		local cap
		for _, plot in plots:GetChildren() do
			if plot:GetAttribute("Owner") == player.UserId then
				cap = plot.Keys:FindFirstChild("Slot1")
			end
		end
		for _, variant in { "PlainClack@Gold", "PlainClack@Rainbow", "PlainClack@Mythical" } do
			data.Board[1] = variant
			registry.KeyboardService.BoardChanged:Fire(player)
			local built = KeyModels.Build(variant):FindFirstChild("Cap")
			expect(built.Color):toBe(cap.Color)
			expect(built.Material):toBe(cap.Material)
			expect(built.Reflectance):toBe(cap.Reflectance)
		end
	end)

	it("uses an authored Assets.Keys model when present", function()
		boot({ "Keycap", "RollKey" })
		local assets = world.tree.ReplicatedStorage:FindFirstChild("Assets")
		local folder = world:newInstance("Folder")
		folder.Name = "Keys"
		local custom = world:newInstance("Model")
		custom.Name = "GlassTink"
		custom.Parent = folder
		folder.Parent = assets
		expect(KeyModels.Build("GlassTink").Name):toBe("GlassTink")
		expect(KeyModels.Build("GlassTink"):FindFirstChild("Cap")):toBeNil()
		expect(KeyModels.Build("PlainClack"):FindFirstChild("Cap") ~= nil):toBe(true)
	end)
end)
