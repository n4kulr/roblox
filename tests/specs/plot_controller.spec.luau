local H = require("../harness/Harness")

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

describe("PlotController", function()
	local world, controller, plots, player

	local function newPlot(name: string, ownerId: number?): any
		local plot = world:newInstance("Model")
		plot.Name = name
		if ownerId then
			plot:SetAttribute("Owner", ownerId)
		end
		local base = world:newPart("Base", 0, 0, 0)
		base.Parent = plot
		plot.Parent = plots
		return plot
	end

	local function start()
		controller = world:require("StarterPlayer.StarterPlayerScripts.Controllers.PlotController")
		controller:Init({})
		controller:Start()
		table.insert(world.started, controller)
		world:flush()
	end

	beforeEach(function()
		world = H.newWorld()
		player = world:newPlayer({ UserId = 77 })
		world.Players.LocalPlayer = player
		plots = world:newInstance("Folder")
		plots.Name = "Plots"
		plots.Parent = world.workspace
	end)

	afterEach(function()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	it("finds the plot already owned by the local player", function()
		newPlot("A", 5)
		local mine = newPlot("B", 77)
		start()
		expect(controller:GetPlot() == mine):toBe(true)
		expect(controller:GetBase() == mine.Base):toBe(true)
	end)

	it("has no plot until one is claimed, then follows the Owner attribute", function()
		local free = newPlot("A", nil)
		start()
		expect(controller:GetPlot() == nil):toBe(true)
		local seen = {}
		controller:Observe(function(plot: any)
			table.insert(seen, { Plot = plot })
		end)
		expect(#seen):toBe(1)
		free:SetAttribute("Owner", 77)
		expect(controller:GetPlot() == free):toBe(true)
		expect(#seen):toBe(2)
		expect(seen[2].Plot == free):toBe(true)
		free:SetAttribute("Owner", nil)
		expect(controller:GetPlot() == nil):toBe(true)
		expect(#seen):toBe(3)
	end)

	it("does not fire Changed when an unrelated plot changes owner", function()
		local mine = newPlot("A", 77)
		local other = newPlot("B", nil)
		start()
		local fired = 0
		controller.Changed:Connect(function()
			fired += 1
		end)
		other:SetAttribute("Owner", 12)
		expect(fired):toBe(0)
		expect(controller:GetPlot() == mine):toBe(true)
	end)

	it("picks up plots added later and drops removed ones", function()
		start()
		local late = newPlot("Late", 77)
		expect(controller:GetPlot() == late):toBe(true)
		late.Parent = nil
		expect(controller:GetPlot() == nil):toBe(true)
	end)

	it("finds and revalidates the roll key without scanning plots", function()
		local mine = newPlot("A", 77)
		start()
		expect(controller:GetRollKey() == nil):toBe(true)
		local key = world:newPart("RollKey", 0, 2, 0)
		key.Parent = mine
		expect(controller:GetRollKey() == key):toBe(true)
		key.Parent = nil
		expect(controller:GetRollKey() == nil):toBe(true)
		local replacement = world:newPart("RollKey", 0, 2, 0)
		replacement.Parent = mine
		expect(controller:GetRollKey() == replacement):toBe(true)
	end)

	it("clears its state when destroyed", function()
		newPlot("A", 77)
		start()
		controller:Destroy()
		expect(controller:GetPlot() == nil):toBe(true)
		expect(controller:GetBase() == nil):toBe(true)
	end)
end)
