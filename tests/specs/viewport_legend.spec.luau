local roblox = require("@lune/roblox")
local H = require("../harness/Harness")

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

local viewportPixels = roblox.Vector2.new(400, 300)
local viewportPath = "StarterPlayer.StarterPlayerScripts.Controllers.UIController.Viewport"

local world: any

local function makeCamera(position: any, target: any): any
	local camera = world:newInstance("Camera")
	camera.FieldOfView = 40
	camera.ViewportSize = viewportPixels
	local offset = position - target
	camera.CFrame = roblox.CFrame.new(position) * roblox.CFrame.Angles(-math.atan2(offset.Y, offset.Z), 0, 0)
	return camera
end

describe("Viewport legend overlay", function()
	local Keys, KeyModels, Viewport, key, frame, model, cap

	local function labelsIn(root: any): { any }
		local found = {}
		for _, item in root:GetDescendants() do
			if item.ClassName == "TextLabel" and item.Name == "Legend" and item.Parent.ClassName == "ViewportFrame" then
				table.insert(found, item)
			end
		end
		return found
	end

	local function renderStepped(): any
		return world.fakeServices.RunService.RenderStepped
	end

	local function step()
		renderStepped():Fire(1 / 60)
	end

	beforeEach(function()
		world = H.newWorld()
		Keys = world:require("ReplicatedStorage.Config.Keys")
		KeyModels = world:require("ReplicatedStorage.Utils.KeyModels")
		Viewport = world:require(viewportPath)
		key = Keys.ByRarity.Rare[1]
		frame = world:newInstance("ViewportFrame")
		frame.AbsoluteSize = viewportPixels
		model = KeyModels.Build(key.Id)
		model.Parent = frame
		cap = model:FindFirstChild("LegendAnchor", true).Parent
		cap.CFrame = roblox.CFrame.new(0, 1, 0)
	end)

	afterEach(function()
		world:destroy()
	end)

	it("marks the model with the anchor and legend attributes", function()
		local anchor = model:FindFirstChild("LegendAnchor", true)
		expect(anchor.ClassName):toBe("Attachment")
		expect(anchor.Position.Y):toBe(cap.Size.Y / 2)
		expect(model:GetAttribute("LegendText")):toBe(string.upper(string.sub(key.Name, 1, 1)))
		expect(model:GetAttribute("LegendColor") == roblox.Color3.new(1, 1, 1)):toBe(true)
		expect(model:GetAttribute("LegendFont")):toBe("FredokaOne")
	end)

	it("creates one label with the legend text, colour and stroke", function()
		local camera = makeCamera(roblox.Vector3.new(0, 6, 8), roblox.Vector3.new(0, 1, 0))
		local stop = Viewport.TrackLegend(frame, model, camera)
		local list = labelsIn(frame)
		expect(#list):toBe(1)
		expect(list[1].Text):toBe(model:GetAttribute("LegendText"))
		expect(list[1].TextColor3 == model:GetAttribute("LegendColor")):toBe(true)
		expect(list[1].Parent == frame):toBe(true)
		expect(list[1]:FindFirstChild("Stroke").Color == model:GetAttribute("LegendStrokeColor")):toBe(true)
		step()
		expect(list[1].Visible):toBe(true)
		expect(list[1].TextSize > 4):toBe(true)
		stop()
	end)

	it("places the label on the projected anchor and scales with distance", function()
		local near = makeCamera(roblox.Vector3.new(0, 4, 5), roblox.Vector3.new(0, 1, 0))
		local stopNear = Viewport.TrackLegend(frame, model, near)
		step()
		local nearLabel = labelsIn(frame)[1]
		local nearSize = nearLabel.TextSize
		expect(math.abs(nearLabel.Position.X.Offset - viewportPixels.X / 2) < 1):toBe(true)
		stopNear()
		local far = makeCamera(roblox.Vector3.new(0, 8, 10), roblox.Vector3.new(0, 1, 0))
		local stopFar = Viewport.TrackLegend(frame, model, far)
		step()
		expect(labelsIn(frame)[1].TextSize < nearSize):toBe(true)
		stopFar()
	end)

	it("hides when the top face points away and shows again when it returns", function()
		local camera = makeCamera(roblox.Vector3.new(0, 6, 8), roblox.Vector3.new(0, 1, 0))
		local stop = Viewport.TrackLegend(frame, model, camera)
		local label = labelsIn(frame)[1]
		step()
		expect(label.Visible):toBe(true)
		cap.CFrame = roblox.CFrame.new(0, 1, 0) * roblox.CFrame.Angles(math.pi, 0, 0)
		step()
		expect(label.Visible):toBe(false)
		cap.CFrame = roblox.CFrame.new(0, 1, 0)
		step()
		expect(label.Visible):toBe(true)
		stop()
	end)

	it("hides edge-on faces below the facing threshold", function()
		local camera = makeCamera(roblox.Vector3.new(0, 1.2, 8), roblox.Vector3.new(0, 1, 0))
		local stop = Viewport.TrackLegend(frame, model, camera)
		step()
		expect(labelsIn(frame)[1].Visible):toBe(false)
		stop()
	end)

	it("destroys the label and disconnects on cleanup", function()
		local camera = makeCamera(roblox.Vector3.new(0, 6, 8), roblox.Vector3.new(0, 1, 0))
		local stop = Viewport.TrackLegend(frame, model, camera)
		expect(#renderStepped():GetConnections()):toBe(1)
		stop()
		expect(#labelsIn(frame)):toBe(0)
		expect(#renderStepped():GetConnections()):toBe(0)
		step()
		expect(#labelsIn(frame)):toBe(0)
	end)

	it("does not leak over repeated reuse of a handle", function()
		local handle = Viewport.new({ Parent = world:newInstance("Folder") })
		for _ = 1, 25 do
			Viewport.Set(handle, KeyModels.Build(key.Id))
			step()
		end
		expect(#labelsIn(handle.Frame)):toBe(1)
		expect(#renderStepped():GetConnections()):toBe(1)
		Viewport.Clear(handle)
		expect(#labelsIn(handle.Frame)):toBe(0)
		expect(#renderStepped():GetConnections()):toBe(0)
		Viewport.Destroy(handle)
	end)

	it("returns a no-op for models without an anchor", function()
		local plain = world:newInstance("Model")
		plain.Parent = frame
		local camera = makeCamera(roblox.Vector3.new(0, 5, 5), roblox.Vector3.zero)
		local stop = Viewport.TrackLegend(frame, plain, camera)
		expect(#labelsIn(frame)):toBe(0)
		stop()
	end)
end)
