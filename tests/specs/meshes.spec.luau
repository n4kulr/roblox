local roblox = require("@lune/roblox")
local H = require("../harness/Harness")

local Vector3, Color3, CFrame = roblox.Vector3, roblox.Color3, roblox.CFrame

local describe, it, expect, afterEach = H.describe, H.it, H.expect, H.afterEach

describe("Mesh skins", function()
	local world, GameConfig, FloorGrid, plots, registry, boardChanges
	local authoredPlots = false
	local authoredUseMeshes = false

	local function setup(ids: { [string]: string }, delay: number?, failures: { string }?, authored: { string }?)
		world = H.newWorld()
		if authored then
			local folder = world:newInstance("Folder")
			folder.Name = "Meshes"
			for _, name in authored do
				local part = world:newInstance("MeshPart")
				part.Name = name
				part.Parent = folder
			end
			folder.Parent = world.fakeServices.ServerStorage
		end
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		FloorGrid = world:require("ReplicatedStorage.Rules.FloorGrid")
		local Signal = world:require("ReplicatedStorage.Packages.Signal")
		world.workspace = world:newInstance("Folder")
		if authoredPlots then
			local folder = world:newInstance("Folder")
			folder.Name = "Plots"
			local model = world:newInstance("Model")
			model.Name = "Plot1"
			if authoredUseMeshes then
				model:SetAttribute("UseMeshes", true)
			end
			for name, size in
				{ Base = Vector3.new(44, 1, 44), RollKey = Vector3.new(8, 3, 8), Board = Vector3.new(31, 1.5, 9.6) }
			do
				local part = world:newInstance("Part")
				part.Name = name
				part.Size = size
				part.CFrame = CFrame.new(0, 0.5, 0)
				part.Color = Color3.new(1, 1, 1)
				part.Material = roblox.Enum.Material.SmoothPlastic
				part.Parent = model
			end
			model.Parent = folder
			folder.Parent = world.workspace
		end
		world.overrides[world.tree.ReplicatedStorage.Config.Meshes] =
			{ Keycap = ids.Keycap or "", RollKey = ids.RollKey or "", KeyboardCase = ids.KeyboardCase or "" }
		world.meshDelay = delay or 0
		for _, id in failures or {} do
			world.meshFailures[id] = true
		end
		local keyboard = { Name = "KeyboardService", BoardChanged = Signal.new() }
		boardChanges = {}
		keyboard.BoardChanged:Connect(function(player: any)
			table.insert(boardChanges, player)
		end)
		local plotService = world:require("ServerScriptService.Services.PlotService")
		registry = world:boot({ "PlotService" }, { KeyboardService = keyboard, PlotService = plotService })
		plots = world.workspace:FindFirstChild("Plots")
	end

	local function floorCaps(plot: any): { any }
		return plot.Keys:GetChildren()
	end

	local function slotCaps(plot: any): { [number]: any }
		local out = {}
		for _, child in plot.Keys:GetChildren() do
			local slot = child:GetAttribute("Slot")
			if slot then
				out[slot] = child
			end
		end
		return out
	end

	afterEach(function()
		authoredPlots = false
		authoredUseMeshes = false
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	it("keeps plain parts when no ids are set", function()
		setup({})
		expect(#world.meshRequests):toBe(0)
		local plot = plots.Plot1
		expect(plot.RollKey.ClassName):toBe("Part")
		expect(plot:FindFirstChild("BoardCase")):toBeNil()
		for _, cap in slotCaps(plot) do
			expect(cap.ClassName):toBe("Part")
		end
	end)

	it("uses authored MeshParts from ServerStorage.Meshes without loading ids", function()
		setup({ Keycap = "k", RollKey = "r", KeyboardCase = "c" }, nil, { "k", "r", "c" }, {
			"Keycap",
			"RollKey",
			"KeyboardCase",
		})
		expect(#world.meshRequests):toBe(0)
		local plot = plots.Plot1
		expect(plot.RollKey.ClassName):toBe("MeshPart")
		expect(plot:FindFirstChild("BoardCase")):toBeNil()
		for _, cap in slotCaps(plot) do
			expect(cap.ClassName):toBe("MeshPart")
		end
	end)

	it("keeps plain parts when mesh creation fails", function()
		setup({ Keycap = "k", RollKey = "r", KeyboardCase = "c" }, nil, { "k", "r", "c" })
		expect(#world.meshRequests):toBe(2)
		local plot = plots.Plot1
		expect(plot.RollKey.ClassName):toBe("Part")
		expect(plot:FindFirstChild("BoardCase")):toBeNil()
		for _, cap in slotCaps(plot) do
			expect(cap.ClassName):toBe("Part")
		end
		expect(#world.warnings > 0):toBe(true)
	end)

	it("builds mesh caps that keep attributes and state", function()
		setup({ Keycap = "k", RollKey = "r", KeyboardCase = "c" })
		local plot = plots.Plot1
		local slots = 0
		local fillers = 0
		for _, cap in floorCaps(plot) do
			if cap.Name ~= "Walkway" then
				expect(cap.ClassName):toBe("MeshPart")
				expect(cap.CanCollide):toBe(false)
				expect(cap.CanQuery):toBe(false)
				expect(cap.CanTouch):toBe(false)
				expect(cap.Anchored):toBe(true)
				expect(cap.Transparency):toBe(0)
				expect(cap.Size):toBe(Vector3.new(FloorGrid.CapSize(), FloorGrid.CapHeight, FloorGrid.CapSize()))
				expect(cap:GetAttribute("Cell") ~= nil):toBe(true)
				if cap:GetAttribute("Slot") then
					slots += 1
					expect(cap:GetAttribute("Filler")):toBeNil()
				else
					fillers += 1
					expect(cap:GetAttribute("Filler")):toBe(true)
					expect(cap.Color):toBe(Color3.fromRGB(222, 218, 208))
					expect(cap.CastShadow):toBe(false)
				end
			end
		end
		expect(slots):toBe(GameConfig.BoardSlots)
		expect(fillers):toBe(#plot.Keys:GetChildren() - 1 - GameConfig.BoardSlots)
		expect(fillers > 0):toBe(true)
		expect(plot.RollKey.ClassName):toBe("MeshPart")
		expect(plot.RollKey.Size):toBe(Vector3.new(8, 3, 8))
		expect(plot:FindFirstChild("BoardCase")):toBeNil()
		expect(plot.Board.Transparency):toBe(1)
		expect(plot.Board.CanCollide):toBe(false)
		expect(plot:GetAttribute("FloorCell")):toBe(FloorGrid.CellSize)
		expect(plot:GetAttribute("FloorColumns")):toBe(math.floor((44 - FloorGrid.EdgeMargin * 2) / FloorGrid.CellSize))
	end)

	it("covers the whole base with a collidable walkway at cap-top height", function()
		setup({ Keycap = "k" })
		local plot = plots.Plot1
		local walkway = plot.Keys.Walkway
		expect(walkway.ClassName):toBe("Part")
		expect(walkway.CanCollide):toBe(true)
		expect(walkway.CanQuery):toBe(true)
		expect(walkway.Size.X):toBe(plot.Base.Size.X)
		expect(walkway.Size.Z):toBe(plot.Base.Size.Z)
		local top = plot.Base.CFrame.Position.Y + plot.Base.Size.Y / 2 + FloorGrid.CapHeight
		expect(walkway.CFrame.Position.Y + walkway.Size.Y / 2):toBeCloseTo(top, 1e-4)
		local cap = slotCaps(plot)[1]
		expect(cap.CFrame.Position.Y + FloorGrid.CapHeight / 2):toBeCloseTo(top, 1e-4)
	end)

	it("returns only the slot caps from GetCaps", function()
		setup({ Keycap = "k" })
		local player = world:join({ Name = "Owner" })
		local caps = registry.PlotService:GetCaps(player)
		local count = 0
		for slot, cap in caps do
			count += 1
			expect(cap:GetAttribute("Slot")):toBe(slot)
		end
		expect(count):toBe(GameConfig.BoardSlots)
		expect(#registry.PlotService:GetFloorCaps(player)):toBe(#registry.PlotService:GetPlot(player).Keys:GetChildren() - 1)
	end)

	it("waits for slow meshes before building plots and assigning players", function()
		setup({ Keycap = "k", RollKey = "r", KeyboardCase = "c" }, 3)
		expect(plots):toBeNil()
		local player = world:join({ Name = "Early" })
		expect(registry.PlotService:GetPlot(player)):toBeNil()
		world:advance(3.5)
		plots = world.workspace:FindFirstChild("Plots")
		local caps = registry.PlotService:GetCaps(player)
		expect(caps ~= nil):toBe(true)
		expect(registry.PlotService:GetPlot(player) ~= nil):toBe(true)
		for _, cap in caps do
			expect(cap.ClassName):toBe("MeshPart")
		end
		expect(slotCaps(registry.PlotService:GetPlot(player))[1] == caps[1]):toBe(true)
		expect(boardChanges):toEqual({ player })
		expect(plots.Plot1.RollKey.ClassName):toBe("MeshPart")
	end)

	it("builds plain plots after the timeout and ignores late meshes", function()
		setup({ Keycap = "k" }, 10)
		local player = world:join({ Name = "Early" })
		world:advance(6.5)
		plots = world.workspace:FindFirstChild("Plots")
		local caps = registry.PlotService:GetCaps(player)
		expect(caps ~= nil):toBe(true)
		local before = caps[1]
		expect(before.ClassName):toBe("Part")
		world:advance(10)
		expect(registry.PlotService:GetCaps(player)[1] == before):toBe(true)
		expect(before.ClassName):toBe("Part")
		expect(before.Parent ~= nil):toBe(true)
		local warned = false
		for _, message in world.warnings do
			if string.find(message, "ignored", 1, true) then
				warned = true
			end
		end
		expect(warned):toBe(true)
	end)

	it("uses keycap meshes on authored plots and leaves RollKey and Board alone", function()
		authoredPlots = true
		setup({ Keycap = "k", RollKey = "r", KeyboardCase = "c" })
		local plot = plots.Plot1
		expect(plot.RollKey.ClassName):toBe("Part")
		expect(plot.Board.ClassName):toBe("Part")
		expect(plot:FindFirstChild("BoardCase")):toBeNil()
		local count = 0
		for _, cap in slotCaps(plot) do
			count += 1
			expect(cap.ClassName):toBe("MeshPart")
		end
		expect(count):toBe(GameConfig.BoardSlots)
	end)
it("skins authored plots marked UseMeshes like placeholder plots", function()
		authoredPlots = true
		authoredUseMeshes = true
		setup({ Keycap = "k", RollKey = "r", KeyboardCase = "c" })
		local plot = plots.Plot1
		expect(plot.RollKey.ClassName):toBe("MeshPart")
		expect(plot:FindFirstChild("BoardCase")):toBeNil()
		for _, cap in slotCaps(plot) do
			expect(cap.ClassName):toBe("MeshPart")
		end
	end)
end)
