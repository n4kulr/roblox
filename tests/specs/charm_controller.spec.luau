local roblox = require("@lune/roblox")
local H = require("../harness/Harness")

local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

local controllers = "StarterPlayer.StarterPlayerScripts.Controllers"

describe("CharmController", function()
	local world, controller, plotController, pets

	local function newPet(seed: number): any
		local model = world:newInstance("Model")
		model.Name = `Pet{seed}`
		model:SetAttribute("Seed", seed)
		model:SetAttribute("Lift", 0.4)
		model.PivotCFrame = CFrame.new(-999, 0, 0)
		model.Parent = pets
		return model
	end

	local function beat()
		world.fakeServices.RunService.Heartbeat:Fire(0.1)
	end

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
		local player = world:newPlayer({ UserId = 3 })
		world.Players.LocalPlayer = player
		world.workspace.CurrentCamera = world:newInstance("Camera")
		local plots = world:newInstance("Folder")
		plots.Name = "Plots"
		plots.Parent = world.workspace
		local plot = world:newInstance("Model")
		plot.Name = "Plot1"
		plot:SetAttribute("Owner", 3)
		local base = world:newPart("Base", 0, 0, 0)
		base.Size = Vector3.new(44, 1, 44)
		base.Parent = plot
		pets = world:newInstance("Folder")
		pets.Name = "Pets"
		pets.Parent = plot
		plot.Parent = plots
		plotController = world:require(`{controllers}.PlotController`)
		plotController:Init({})
		plotController:Start()
		world:flush()
		controller = world:require(`{controllers}.CharmController`)
		controller:Init({
			PlotController = plotController,
			UIController = { Toast = function() end },
		})
		controller:Start()
	end)

	afterEach(function()
		controller:Destroy()
		plotController:Destroy()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	it("walks pets that appear on the plot", function()
		local pet = newPet(11)
		beat()
		expect(pet.PivotCFrame.Position.X ~= -999):toBe(true)
	end)

	it("stops moving pets that are removed", function()
		local pet = newPet(11)
		beat()
		pet.Parent = nil
		pet.PivotCFrame = CFrame.new(-999, 0, 0)
		beat()
		expect(pet.PivotCFrame.Position.X):toBe(-999)
	end)

	it("skips pets that are far from the camera", function()
		world.workspace.CurrentCamera.CFrame = CFrame.new(9000, 0, 0)
		local pet = newPet(11)
		beat()
		expect(pet.PivotCFrame.Position.X):toBe(-999)
	end)

	it("ignores pets without a seed", function()
		local pet = world:newInstance("Model")
		pet.PivotCFrame = CFrame.new(-999, 0, 0)
		pet.Parent = pets
		beat()
		expect(pet.PivotCFrame.Position.X):toBe(-999)
	end)
end)
