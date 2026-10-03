local roblox = require("@lune/roblox")
local H = require("../harness/Harness")

local Vector3, Color3 = roblox.Vector3, roblox.Color3

local describe, it, expect, afterEach = H.describe, H.it, H.expect, H.afterEach

describe("Mesh skins", function()
	local world, GameConfig, plots, registry, boardChanges

	local function setup(ids: { [string]: string }, delay: number?, failures: { string }?)
		world = H.newWorld()
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		local Signal = world:require("ReplicatedStorage.Packages.Signal")
		world.workspace = world:newInstance("Folder")
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

	it("keeps plain parts when mesh creation fails", function()
		setup({ Keycap = "k", RollKey = "r", KeyboardCase = "c" }, nil, { "k", "r", "c" })
		expect(#world.meshRequests):toBe(3)
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
		local count = 0
		for slot, cap in slotCaps(plot) do
			count += 1
			expect(cap.ClassName):toBe("MeshPart")
			expect(cap:GetAttribute("Slot")):toBe(slot)
			expect(cap.CanCollide):toBe(false)
			expect(cap.CanQuery):toBe(false)
			expect(cap.CanTouch):toBe(false)
			expect(cap.Anchored):toBe(true)
			expect(cap.Transparency):toBe(0.6)
		end
		expect(count):toBe(GameConfig.BoardSlots)
		expect(plot.Keys.Walkway.ClassName):toBe("Part")
		expect(plot.RollKey.ClassName):toBe("MeshPart")
		expect(plot.RollKey.Size):toBe(Vector3.new(8, 3, 8))
		expect(plot.BoardCase.ClassName):toBe("MeshPart")
		expect(plot.BoardCase.Size):toBe(plot.Board.Size)
		expect(plot.Board.Transparency):toBe(1)
	end)

	it("sits caps on the case floor", function()
		setup({ KeyboardCase = "c" })
		local plot = plots.Plot1
		local cap = slotCaps(plot)[1]
		local expected = plot.Board.CFrame.Position.Y + (-0.75 + 1.1) + 0.5
		expect(cap.CFrame.Position.Y):toBeCloseTo(expected, 1e-4)
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
		expect(plots.Plot1.BoardCase.ClassName):toBe("MeshPart")
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
end)
