local roblox = require("@lune/roblox")
local H = require("../harness/Harness")
local S = require("../support")

local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

describe("Plot lock sweep", function()
	local world, registry, GameConfig, defense

	beforeEach(function()
		world = H.newWorld({ Time = 1700000000 })
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		defense = GameConfig.Defense
		world.workspace = world:newInstance("Folder")
		local plotService = world:require("ServerScriptService.Services.PlotService")
		registry = world:boot({ "KeyboardService", "PlotService" }, { PlotService = plotService })
		world:flush()
	end)

	afterEach(function()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	local function join(name: string)
		local data: any = { Board = S.board("GlassTink", "PlainClack"), TheftLessonDone = true }
		return world:join({ Name = name }, data, true)
	end

	it("runs no sweep while nothing is locked", function()
		local owner = join("Owner")
		world:flush()
		local idle = world:pendingTasks()
		world:advance(3)
		expect(world:pendingTasks()):toBe(idle)
	end)

	it("runs the sweep only while a lock is active", function()
		local owner = join("Owner")
		world:flush()
		local idle = world:pendingTasks()
		expect(registry.PlotService:Lock(owner)):toBe(true)
		expect(world:pendingTasks()):toBe(idle + 1)
		world:advance(defense.LockBaseSeconds + 1)
		expect(registry.PlotService:IsLocked(owner)):toBe(false)
		expect(world:pendingTasks()):toBe(idle)
	end)

	it("announces the end of the lock once", function()
		local owner = join("Owner")
		local changes = 0
		registry.PlotService.LockChanged:Connect(function()
			changes += 1
		end)
		registry.PlotService:Lock(owner)
		expect(changes):toBe(1)
		world:advance(defense.LockBaseSeconds + 2)
		expect(changes):toBe(2)
		world:advance(defense.LockCooldownSeconds + 5)
		expect(changes):toBe(2)
	end)

	it("writes the lock attributes only when the values change", function()
		local owner = join("Owner")
		local plot = registry.PlotService:GetPlot(owner)
		registry.PlotService:Lock(owner)
		local lockedUntil = world.now + defense.LockBaseSeconds
		expect(plot:GetAttribute("LockedUntil")):toBe(lockedUntil)
		plot:SetAttribute("LockedUntil", 1)
		world:advance(2)
		expect(plot:GetAttribute("LockedUntil")):toBe(1)
	end)

	it("clears the attributes when the owner leaves mid-lock and stops sweeping", function()
		local owner = join("Owner")
		local plot = registry.PlotService:GetPlot(owner)
		world:flush()
		local idle = world:pendingTasks()
		registry.PlotService:Lock(owner)
		world:removePlayer(owner)
		expect(plot:GetAttribute("LockedUntil")):toBeNil()
		world:advance(1)
		expect(world:pendingTasks() <= idle):toBe(true)
	end)

	it("knocks back an intruder standing in an active entrance and ignores everyone else", function()
		local owner = join("Owner")
		local intruder = join("Intruder")
		local bystander = join("Bystander")
		local plotService = registry.PlotService
		local base = plotService:GetBase(owner)
		local size = base.Size
		local entrance = base.CFrame * CFrame.new(0, size.Y / 2 + 1, -(size.Z / 2 - 2))
		world:spawnCharacter(intruder, entrance.Position.X, entrance.Position.Y, entrance.Position.Z)
		world:spawnCharacter(bystander, 400, 3, 400)
		local before = intruder.Character.HumanoidRootPart.CFrame.Position
		world:advance(1)
		expect(intruder.Character.HumanoidRootPart.CFrame.Position):toEqual(before)
		plotService:Lock(owner)
		world:advance(0.5)
		expect(intruder.Character.HumanoidRootPart.CFrame.Position ~= before):toBe(true)
		expect(bystander.Character.HumanoidRootPart.CFrame.Position):toEqual(Vector3.new(400, 3, 400))
	end)
end)
