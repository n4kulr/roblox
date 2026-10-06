local roblox = require("@lune/roblox")
local H = require("../harness/Harness")

local Vector3, Color3, CFrame = roblox.Vector3, roblox.Color3, roblox.CFrame
local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

local controllers = "StarterPlayer.StarterPlayerScripts.Controllers"

describe("RollController KeyVisual", function()
	local world, KeyVisual, visual, plot, key, isLow, isDestroyed

	local rarity = { Color = Color3.new(1, 0, 0), BuildUpSeconds = 1 }

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
		KeyVisual = world:require(`{controllers}.RollController.KeyVisual`)
		isLow = false
		isDestroyed = false
		visual = KeyVisual.new(function()
			return isLow
		end, function()
			return isDestroyed
		end)
		plot = world:newInstance("Model")
		key = world:newPart("RollKey", 0, 2, 0)
		key.Size = Vector3.new(8, 3, 8)
		key.Color = Color3.new(1, 1, 1)
		key.Parent = plot
	end)

	it("binds the roll key and remembers its origin", function()
		KeyVisual.Bind(visual, plot)
		expect(visual.Key == key):toBe(true)
		expect(visual.OriginSize == Vector3.new(8, 3, 8)):toBe(true)
	end)

	it("clears the key when there is no plot or no key", function()
		KeyVisual.Bind(visual, plot)
		KeyVisual.Bind(visual, nil)
		expect(visual.Key):toBeNil()
		KeyVisual.Bind(visual, world:newInstance("Model"))
		expect(visual.Key):toBeNil()
	end)

	it("rebinds when a replacement roll key appears", function()
		KeyVisual.Bind(visual, plot)
		key.Parent = nil
		local replacement = world:newPart("RollKey", 0, 2, 0)
		replacement.Size = Vector3.new(6, 3, 6)
		replacement.Parent = plot
		expect(visual.Key == replacement):toBe(true)
		expect(visual.OriginSize == Vector3.new(6, 3, 6)):toBe(true)
	end)

	it("squashes the key and keeps the tweens for cancelling", function()
		KeyVisual.Bind(visual, plot)
		KeyVisual.Squash(visual)
		expect(#visual.SquashTweens):toBe(2)
		expect(key.Size.Y < 3):toBe(true)
	end)

	it("does nothing without a key", function()
		KeyVisual.Squash(visual)
		expect(#visual.SquashTweens):toBe(0)
	end)

	it("builds up towards the rarity colour and restores the key afterwards", function()
		KeyVisual.Bind(visual, plot)
		local done = false
		world.task.spawn(function()
			KeyVisual.BuildUp(visual, rarity)
			done = true
		end)
		expect(visual.BuildingCount):toBe(1)
		world.fakeServices.RunService.RenderStepped:Fire(1 / 60)
		world:advance(0.5)
		world.fakeServices.RunService.RenderStepped:Fire(1 / 60)
		expect(key.Color ~= Color3.new(1, 1, 1)):toBe(true)
		world:advance(0.6)
		expect(done):toBe(true)
		expect(visual.BuildingCount):toBe(0)
		expect(key.Color == Color3.new(1, 1, 1)):toBe(true)
		expect(key.CFrame == visual.OriginCFrame):toBe(true)
	end)

	it("tints the key and restores it unless a build up is running or it was destroyed", function()
		KeyVisual.Bind(visual, plot)
		KeyVisual.Tint(visual, Color3.new(0, 1, 0))
		expect(key.Color == Color3.new(0, 1, 0)):toBe(true)
		world:advance(1)
		expect(key.Color == Color3.new(1, 1, 1)):toBe(true)
		KeyVisual.Tint(visual, Color3.new(0, 1, 0))
		isDestroyed = true
		world:advance(1)
		expect(key.Color == Color3.new(0, 1, 0)):toBe(true)
	end)

	it("punches the camera field of view once at a time and not on low graphics", function()
		local camera = world:newInstance("Camera")
		world.workspace.CurrentCamera = camera
		isLow = true
		KeyVisual.PunchCamera(visual)
		expect(visual.Punching):toBe(false)
		isLow = false
		KeyVisual.PunchCamera(visual)
		expect(visual.Punching):toBe(true)
		expect(camera.FieldOfView):toBe(78)
		world:advance(1)
		expect(visual.Punching):toBe(false)
		expect(camera.FieldOfView):toBe(70)
	end)

	it("clears its connections and key", function()
		KeyVisual.Bind(visual, plot)
		KeyVisual.Clear(visual)
		expect(visual.Key):toBeNil()
		expect(#visual.Connections):toBe(0)
		expect(CFrame.new() == CFrame.new()):toBe(true)
	end)
end)
