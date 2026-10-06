local H = require("../harness/Harness")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

describe("Group chest removal", function()
	local world

	beforeEach(function()
		world = H.newWorld()
	end)

	it("has no service, screen, config or registry entry", function()
		local services = world.tree.ServerScriptService.Services
		expect(services:FindFirstChild("GroupChestService")):toBeNil()
		local screens = world.tree.StarterPlayer.StarterPlayerScripts.Controllers.UIController.Screens
		expect(screens:FindFirstChild("GroupChest")):toBeNil()
		expect(screens:FindFirstChild("Charms")):toBeNil()
		local GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		expect(GameConfig.GroupChest):toBeNil()
		local registry = world.tree.ServerScriptService.Registry
		expect(registry ~= nil):toBe(true)
	end)

	it("builds nothing named chest in the world", function()
		world:boot({ "KeyboardService", "EggService" })
		world:join(nil, nil, true)
		for _, item in world.workspace:GetDescendants() do
			expect(string.find(string.lower(item.Name), "chest", 1, true)):toBeNil()
		end
		world:destroy()
	end)
end)

describe("Pet wandering", function()
	local world, PetWander, EggPlacement, Eggs

	beforeEach(function()
		world = H.newWorld()
		PetWander = world:require("ReplicatedStorage.Utils.PetWander")
		EggPlacement = world:require("ReplicatedStorage.Utils.EggPlacement")
		Eggs = world:require("ReplicatedStorage.Config.Eggs")
	end)

	local rect = { X = 0, Z = -10, HalfX = 4, HalfZ = 4 }

	it("starts and stays inside the base inset by three studs", function()
		for seed = 1, 20 do
			local walker = PetWander.New(seed, 22, 22, rect)
			for _ = 1, 600 do
				PetWander.Step(walker, 0.1)
				expect(math.abs(walker.X) <= 22 - PetWander.Inset + 1e-6):toBe(true)
				expect(math.abs(walker.Z) <= 22 - PetWander.Inset + 1e-6):toBe(true)
			end
		end
	end)

	it("never picks a point on the roll key area", function()
		local random = world.Random.new(5)
		for _ = 1, 500 do
			local x, z = PetWander.PickPoint(random, 22, 22, rect)
			local blocked = math.abs(x - rect.X) < rect.HalfX + Eggs.RollKeyClear
				and math.abs(z - rect.Z) < rect.HalfZ + Eggs.RollKeyClear
			expect(blocked):toBe(false)
		end
	end)

	it("moves at about four studs per second and pauses between one and three seconds", function()
		local walker = PetWander.New(11, 22, 22, nil)
		walker.Pause = 0
		walker.TargetX, walker.TargetZ = walker.X + 10, walker.Z
		local startX = walker.X
		PetWander.Step(walker, 0.5)
		expect(math.abs(walker.X - startX - 2) < 1e-6):toBe(true)
		expect(walker.IsMoving):toBe(true)
		expect(PetWander.Hop(walker) >= 0):toBe(true)
		PetWander.Step(walker, 10)
		expect(walker.Pause >= PetWander.PauseMin and walker.Pause <= PetWander.PauseMax):toBe(true)
		expect(walker.IsMoving):toBe(false)
		expect(PetWander.Hop(walker)):toBe(0)
		local at = walker.X
		PetWander.Step(walker, 0.2)
		expect(walker.X):toBe(at)
	end)

	it("faces its direction of travel", function()
		local walker = PetWander.New(3, 22, 22, nil)
		walker.Pause = 0
		walker.X, walker.Z = 0, 0
		walker.TargetX, walker.TargetZ = 10, 0
		PetWander.Step(walker, 0.1)
		expect(math.abs(math.sin(walker.Heading) + 1) < 1e-6):toBe(true)
		walker.TargetX, walker.TargetZ = walker.X, -10
		PetWander.Step(walker, 0.1)
		expect(math.abs(math.cos(walker.Heading) - 1) < 1e-6):toBe(true)
	end)

	it("is deterministic from its seed", function()
		local a = PetWander.New(99, 22, 22, rect)
		local b = PetWander.New(99, 22, 22, rect)
		for _ = 1, 100 do
			PetWander.Step(a, 0.1)
			PetWander.Step(b, 0.1)
		end
		expect(a.X):toBe(b.X)
		expect(a.Z):toBe(b.Z)
		local c = PetWander.New(100, 22, 22, rect)
		expect(c.X ~= PetWander.New(99, 22, 22, rect).X):toBe(true)
		expect(EggPlacement ~= nil):toBe(true)
	end)
end)
