local roblox = require("@lune/roblox")
local H = require("../harness/Harness")

local CFrame, Vector3 = roblox.CFrame, roblox.Vector3
local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

local controllers = "StarterPlayer.StarterPlayerScripts.Controllers"

describe("EggController placed eggs", function()
	local world, controller, plotController, plot, eggs, pets, player, hatched, charmController

	local function frame()
		world.fakeServices.RunService.RenderStepped:Fire(1 / 60)
	end

	local function newEgg(index: number, readyAt: number?, parent: any?): any
		local model = world:newInstance("Model")
		model.Name = `Egg{index}`
		model:SetAttribute("EggId", "Linear")
		model:SetAttribute("Index", index)
		model:SetAttribute("Phase", 0)
		model:SetAttribute("Drop", 0.5)
		model:SetAttribute("BaseCFrame", CFrame.new(index * 3, 5, 0))
		model:SetAttribute("ReadyAt", readyAt)
		model.PivotCFrame = CFrame.new(-999, 0, 0)
		local body = world:newPart("EggBody", 0, 0, 0)
		body.Parent = model
		model.Parent = parent or eggs
		return model
	end

	local function promptOf(model: any): any
		return model.EggBody:FindFirstChild("HatchPrompt")
	end

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
		player = world:newPlayer({ UserId = 9 })
		world.Players.LocalPlayer = player
		world.workspace.CurrentCamera = world:newInstance("Camera")
		local plots = world:newInstance("Folder")
		plots.Name = "Plots"
		plots.Parent = world.workspace
		plot = world:newInstance("Model")
		plot.Name = "Plot1"
		plot:SetAttribute("Owner", 9)
		local base = world:newPart("Base", 0, 0, 0)
		base.Size = Vector3.new(44, 1, 44)
		base.Parent = plot
		eggs = world:newInstance("Folder")
		eggs.Name = "PlacedEggs"
		eggs.Parent = plot
		pets = world:newInstance("Folder")
		pets.Name = "Pets"
		pets.Parent = plot
		plot.Parent = plots
		plotController = world:require(`{controllers}.PlotController`)
		plotController:Init({})
		plotController:Start()
		world:flush()
		hatched = {}
		charmController = {
			Hatch = function(_self: any, index: number, eggId: string)
				table.insert(hatched, { Index = index, EggId = eggId })
			end,
		}
		controller = world:require(`{controllers}.EggController`)
		controller:Init({
			PlotController = plotController,
			CharmController = charmController,
			UIController = { Toast = function() end },
			DataController = {
				Observe = function(_self: any, _path: any, callback: any)
					callback(nil)
					return { Disconnect = function() end }
				end,
			},
		})
		controller:Start()
	end)

	afterEach(function()
		controller:Destroy()
		plotController:Destroy()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	it("wobbles placed eggs from their cached attributes", function()
		local egg = newEgg(1, nil)
		frame()
		expect(egg.PivotCFrame.Position.X):toBeCloseTo(3, 0.5)
	end)

	it("picks up attribute changes without rescanning", function()
		local egg = newEgg(1, nil)
		frame()
		egg:SetAttribute("BaseCFrame", CFrame.new(40, 5, 0))
		frame()
		expect(egg.PivotCFrame.Position.X):toBeCloseTo(40, 0.5)
	end)

	it("does not wobble eggs far from the camera", function()
		local camera = world.workspace.CurrentCamera
		camera.CFrame = CFrame.new(5000, 0, 0)
		local egg = newEgg(1, nil)
		frame()
		expect(egg.PivotCFrame.Position.X):toBe(-999)
		camera.CFrame = CFrame.new(0, 0, 0)
		frame()
		expect(egg.PivotCFrame.Position.X):toBeCloseTo(3, 0.5)
	end)

	it("stops tracking eggs that leave the plot", function()
		local egg = newEgg(1, nil)
		frame()
		egg.Parent = nil
		egg.PivotCFrame = CFrame.new(-999, 0, 0)
		frame()
		expect(egg.PivotCFrame.Position.X):toBe(-999)
	end)

	it("adds a hatch prompt to ready eggs on the own plot and triggers a hatch", function()
		local egg = newEgg(2, world.now - 1)
		local prompt = promptOf(egg)
		expect(prompt ~= nil):toBe(true)
		expect(prompt.ActionText):toBe("Hatch")
		prompt.Triggered:Fire()
		expect(#hatched):toBe(1)
		expect(hatched[1].Index):toBe(2)
		expect(hatched[1].EggId):toBe("Linear")
	end)

	it("waits for the ready time without polling", function()
		local egg = newEgg(1, world.now + 5)
		expect(promptOf(egg)):toBeNil()
		world:advance(3)
		expect(promptOf(egg)):toBeNil()
		world:advance(3)
		expect(promptOf(egg) ~= nil):toBe(true)
	end)

	it("creates the prompt when ReadyAt is set later and removes it when cleared", function()
		local egg = newEgg(1, nil)
		expect(promptOf(egg)):toBeNil()
		egg:SetAttribute("ReadyAt", world.now - 1)
		expect(promptOf(egg) ~= nil):toBe(true)
		egg:SetAttribute("ReadyAt", world.now + 100)
		expect(promptOf(egg)):toBeNil()
	end)

	it("gives no prompt on plots the player does not own and follows ownership changes", function()
		plot:SetAttribute("Owner", 500)
		local egg = newEgg(1, world.now - 1)
		expect(promptOf(egg)):toBeNil()
		plot:SetAttribute("Owner", 9)
		expect(promptOf(egg) ~= nil):toBe(true)
		plot:SetAttribute("Owner", 500)
		expect(promptOf(egg)):toBeNil()
	end)

	it("never creates two prompts for one egg", function()
		local egg = newEgg(1, world.now - 1)
		egg:SetAttribute("ReadyAt", world.now - 2)
		egg:SetAttribute("EggId", "Linear")
		local count = 0
		for _, child in egg.EggBody:GetChildren() do
			if child.Name == "HatchPrompt" then
				count += 1
			end
		end
		expect(count):toBe(1)
	end)
end)
