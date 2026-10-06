local roblox = require("@lune/roblox")
local H = require("../harness/Harness")

local describe, it, expect, afterEach = H.describe, H.it, H.expect, H.afterEach

describe("MeshService", function()
	local world, registry

	local function setup(ids: { [string]: string }, delay: number?)
		world = H.newWorld()
		world.overrides[world.tree.ReplicatedStorage.Config.Meshes] =
			{ Keycap = ids.Keycap or "", RollKey = ids.RollKey or "", KeyboardCase = "" }
		world.meshDelay = delay or 0
		registry = world:boot({ "MeshService" })
	end

	local function replicated(name: string): any
		local assets = world.tree.ReplicatedStorage:FindFirstChild("Assets")
		local meshes = if assets then assets:FindFirstChild("Meshes") else nil
		return if meshes then meshes:FindFirstChild(name) else nil
	end

	afterEach(function()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	it("loads templates on start and serves them through Get", function()
		setup({ Keycap = "k", RollKey = "r" })
		world:advance(0.1)
		expect(registry.MeshService:Get("Keycap") ~= nil):toBe(true)
		expect(registry.MeshService:Get("RollKey") ~= nil):toBe(true)
	end)

	it("replicates the templates once Wait returns", function()
		setup({ Keycap = "k" })
		registry.MeshService:Wait(1)
		expect(replicated("Keycap") ~= nil):toBe(true)
		expect(replicated("RollKey")):toBeNil()
	end)

	it("announces templates that arrive late and replicates them", function()
		setup({ Keycap = "k" }, 2)
		local arrived = {}
		registry.MeshService.Changed:Connect(function(name: string)
			table.insert(arrived, name)
		end)
		expect(registry.MeshService:Get("Keycap")):toBeNil()
		world:advance(3)
		expect(arrived):toEqual({ "Keycap" })
		expect(replicated("Keycap") ~= nil):toBe(true)
	end)

	it("clears templates and the replicated copies on destroy", function()
		setup({ Keycap = "k" })
		registry.MeshService:Wait(1)
		world:destroy()
		expect(registry.MeshService:Get("Keycap")):toBeNil()
		expect(replicated("Keycap")):toBeNil()
	end)

	it("starts before the systems that read meshes", function()
		local fs = require("@lune/fs")
		local text = fs.readFile("src/server/Registry.luau")
		local mesh = string.find(text, "Services.MeshService", 1, true)
		local plot = string.find(text, "Services.PlotService", 1, true)
		local cosmetic = string.find(text, "Services.CosmeticService", 1, true)
		expect(mesh < plot):toBe(true)
		expect(mesh < cosmetic):toBe(true)
	end)
end)
