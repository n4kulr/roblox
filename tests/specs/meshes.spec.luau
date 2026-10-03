local roblox = require("@lune/roblox")
local H = require("../harness/Harness")

local Vector3, Color3 = roblox.Vector3, roblox.Color3

local describe, it, expect, afterEach = H.describe, H.it, H.expect, H.afterEach

describe("Mesh skins", function()
	local world, GameConfig, plots

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
		local plotService = world:require("ServerScriptService.Services.PlotService")
		world:boot({ "PlotService" }, { KeyboardService = keyboard, PlotService = plotService })
		plots = world.workspace.Plots
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

	it("re-skins existing caps and moves their children after a late load", function()
		setup({ Keycap = "k", RollKey = "r", KeyboardCase = "c" }, 5)
		local plot = plots.Plot1
		local first = slotCaps(plot)[2]
		expect(first.ClassName):toBe("Part")
		first:SetAttribute("KeyId", "PlainClack")
		first.Color = Color3.fromRGB(1, 2, 3)
		local prompt = world:newInstance("ProximityPrompt")
		prompt.Name = "StealPrompt"
		prompt.Parent = first
		world:advance(6)
		local after = slotCaps(plot)[2]
		expect(after.ClassName):toBe("MeshPart")
		expect(after == first):toBe(false)
		expect(after:GetAttribute("KeyId")):toBe("PlainClack")
		expect(after:GetAttribute("Slot")):toBe(2)
		expect(after.Color):toBe(Color3.fromRGB(1, 2, 3))
		expect(after:FindFirstChild("StealPrompt") == prompt):toBe(true)
		expect(plot.RollKey.ClassName):toBe("MeshPart")
		expect(plot.BoardCase.ClassName):toBe("MeshPart")
	end)
end)
