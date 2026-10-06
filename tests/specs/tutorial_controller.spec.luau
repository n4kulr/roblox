local H = require("../harness/Harness")

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

local controllers = "StarterPlayer.StarterPlayerScripts.Controllers"

describe("TutorialController", function()
	local world, controller, plotController, data, rollKey

	local function setStep(value: any)
		data:Set({ "Tutorial" }, value)
	end

	local function beat()
		world.fakeServices.RunService.Heartbeat:Fire(1 / 30)
	end

	local function hint(): any
		return world.workspace:FindFirstChild("ThockRollHint")
	end

	local function heartbeatListeners(): number
		return #world.fakeServices.RunService.Heartbeat:GetConnections()
	end

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
		local player = world:newPlayer({ UserId = 4 })
		world.Players.LocalPlayer = player
		local plots = world:newInstance("Folder")
		plots.Name = "Plots"
		plots.Parent = world.workspace
		local plot = world:newInstance("Model")
		plot.Name = "Plot1"
		plot:SetAttribute("Owner", 4)
		rollKey = world:newPart("RollKey", 0, 2, 0)
		rollKey.Parent = plot
		plot.Parent = plots
		plotController = world:require(`{controllers}.PlotController`)
		plotController:Init({})
		plotController:Start()
		world:flush()
		data = H.fakeDataController()
		controller = world:require(`{controllers}.TutorialController`)
		controller:Init({
			PlotController = plotController,
			DataController = data,
		})
		controller:Start()
		world.workspace.ThockRollHint.Adornee = world:newPart("Dummy", 0, 0, 0)
	end)

	afterEach(function()
		controller:Destroy()
		plotController:Destroy()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	it("builds a hidden hint and listens to no frames before the tutorial data says so", function()
		expect(hint() ~= nil):toBe(true)
		expect(hint().Enabled):toBe(false)
		expect(heartbeatListeners()):toBe(0)
	end)

	it("shows the tap hint over the roll key on step 0", function()
		setStep(0)
		beat()
		expect(hint().Enabled):toBe(true)
		expect(hint().Adornee == rollKey):toBe(true)
		expect(hint().Hint.Text):toBe("TAP THE KEY!")
	end)

	it("switches to the roll again hint on step 1", function()
		setStep(0)
		beat()
		setStep(1)
		beat()
		expect(hint().Hint.Text):toBe("ROLL AGAIN!")
	end)

	it("bounces the hint", function()
		setStep(0)
		beat()
		local first = hint().StudsOffset.Y
		beat()
		expect(hint().StudsOffset.Y ~= first):toBe(true)
	end)

	it("hides the hint without a roll key", function()
		rollKey.Parent = nil
		setStep(0)
		beat()
		expect(hint().Enabled):toBe(false)
	end)

	it("disconnects its frame listener once the tutorial is finished", function()
		setStep(0)
		expect(heartbeatListeners()):toBe(1)
		setStep(99)
		expect(heartbeatListeners()):toBe(0)
		expect(hint().Enabled):toBe(false)
		setStep(nil)
		expect(heartbeatListeners()):toBe(0)
	end)

	it("never stacks frame listeners across steps", function()
		setStep(0)
		setStep(1)
		setStep(0)
		expect(heartbeatListeners()):toBe(1)
	end)

	it("removes the hint on Destroy", function()
		setStep(0)
		controller:Destroy()
		expect(hint()):toBeNil()
		expect(heartbeatListeners()):toBe(0)
	end)
end)
