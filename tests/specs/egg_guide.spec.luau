local roblox = require("@lune/roblox")
local H = require("../harness/Harness")

local Vector3, Vector2, CFrame = roblox.Vector3, roblox.Vector2, roblox.CFrame
local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

local controllers = "StarterPlayer.StarterPlayerScripts.Controllers"

local function descendantsOfClass(root: any, className: string): { any }
	local found = {}
	for _, item in root:GetDescendants() do
		if item.ClassName == className then
			table.insert(found, item)
		end
	end
	return found
end

describe("EdgeIndicator", function()
	local world, EdgeIndicator
	local viewport = Vector2.new(1000, 600)
	local margin = 50

	beforeEach(function()
		world = H.newWorld()
		EdgeIndicator = world:require("ReplicatedStorage.Utils.EdgeIndicator")
	end)

	it("clamps a point beyond the right edge and points right", function()
		local position, rotation = EdgeIndicator.Place(Vector2.new(5000, 300), false, viewport, margin)
		expect(position.X):toBeCloseTo(viewport.X - margin, 1e-6)
		expect(position.Y):toBeCloseTo(300, 1e-6)
		expect(rotation):toBeCloseTo(0, 1e-6)
	end)

	it("clamps a point above the top edge and points up", function()
		local position, rotation = EdgeIndicator.Place(Vector2.new(500, -4000), false, viewport, margin)
		expect(position.Y):toBeCloseTo(margin, 1e-6)
		expect(rotation):toBeCloseTo(-90, 1e-6)
	end)

	it("keeps the result inside the margin for diagonal points", function()
		for _, point in { Vector2.new(-900, -900), Vector2.new(2000, 1500), Vector2.new(-300, 2500) } do
			local position = EdgeIndicator.Place(point, false, viewport, margin)
			expect(position.X >= margin - 1e-6 and position.X <= viewport.X - margin + 1e-6):toBe(true)
			expect(position.Y >= margin - 1e-6 and position.Y <= viewport.Y - margin + 1e-6):toBe(true)
		end
	end)

	it("mirrors points behind the camera", function()
		local position, rotation = EdgeIndicator.Place(Vector2.new(700, 300), true, viewport, margin)
		expect(position.X):toBeCloseTo(margin, 1e-6)
		expect(math.abs(rotation)):toBeCloseTo(180, 1e-6)
	end)

	it("points down when the point sits exactly at the center", function()
		local _, rotation = EdgeIndicator.Place(Vector2.new(500, 300), false, viewport, margin)
		expect(rotation):toBeCloseTo(90, 1e-6)
	end)
end)

describe("Egg guide", function()
	local world, Guide, Eggs, base, playerGui, camera, root, guide

	local function folder(): any
		return world.workspace:FindFirstChild("EggGuide")
	end

	local function gui(): any
		return playerGui:FindFirstChild("EggGuide")
	end

	local function beam(): any
		return folder():FindFirstChild("GuideBeam")
	end

	local function arrowParts(): { any }
		local arrow = folder():FindFirstChild("Arrow")
		return if arrow then arrow:GetChildren() else {}
	end

	local function standAt(x: number, y: number, z: number)
		root.CFrame = CFrame.new(x, y, z)
		root.Position = Vector3.new(x, y, z)
	end

	local function look(position: any, yaw: number)
		camera.CFrame = CFrame.new(position.X, position.Y, position.Z) * CFrame.Angles(0, yaw, 0)
	end

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
		Guide = world:require(`{controllers}.EggController.Guide`)
		Eggs = world:require("ReplicatedStorage.Config.Eggs")
		base = world:newPart("Base", 0, 0, 0)
		base.Size = Vector3.new(44, 1, 44)
		playerGui = world:newInstance("Folder")
		camera = world:newInstance("Camera")
		root = world:newPart("HumanoidRootPart", 0, 3, 100)
		root.Position = Vector3.new(0, 3, 100)
		look(Vector3.new(0, 20, 60), 0)
		guide = Guide.new(base, playerGui)
	end)

	afterEach(function()
		if guide then
			guide:Destroy()
			guide = nil
		end
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	it("builds a solid gold beam from the character to a target on the base", function()
		guide:Update(1, root, camera)
		local line = beam()
		local config = Eggs.Guide
		expect(line.Enabled):toBe(true)
		expect(line.Attachment0.Parent == root):toBe(true)
		expect(line.Attachment1.Parent.Parent == folder()):toBe(true)
		expect(line.Attachment1.Name):toBe("GuideTarget")
		expect(line.Color.Keypoints[1].Value):toBe(config.Color)
		expect(line.LightEmission):toBe(0)
		expect(line.Texture):toBe("")
		expect(line.CurveSize0 ~= 0):toBe(true)
		expect(line.CurveSize1 ~= 0):toBe(true)
		expect(line.Width0 > 0):toBe(true)
	end)

	it("places the beam target over the base placement area", function()
		guide:Update(1, root, camera)
		local target = beam().Attachment1.Parent
		expect(target.CFrame.Position.X):toBeCloseTo(0, 1e-6)
		expect(target.CFrame.Position.Z):toBeCloseTo(0, 1e-6)
		expect(target.CFrame.Position.Y > base.Size.Y / 2):toBe(true)
		expect(target.Transparency):toBe(1)
		expect(target.CanCollide):toBe(false)
	end)

	it("pulses the beam width and transparency over time", function()
		guide:Update(0, root, camera)
		local widthA = beam().Width0
		local alphaA = beam().Transparency.Keypoints[1].Value
		guide:Update(0.52, root, camera)
		local widthB = beam().Width0
		local alphaB = beam().Transparency.Keypoints[1].Value
		expect(widthA ~= widthB):toBe(true)
		expect(alphaA ~= alphaB):toBe(true)
		expect(alphaB >= 0 and alphaB <= 1):toBe(true)
	end)

	it("builds a part-made arrow without neon above the base", function()
		guide:Update(1, root, camera)
		local parts = arrowParts()
		expect(#parts):toBeGreaterThan(2)
		for _, part in parts do
			expect(part.Material):toBe(roblox.Enum.Material.SmoothPlastic)
			expect(part.Color):toBe(Eggs.Guide.Color)
			expect(part.Anchored):toBe(true)
			expect(part.CanCollide):toBe(false)
			expect(part.CFrame.Position.Y > base.Size.Y / 2 + 4):toBe(true)
		end
		expect(#descendantsOfClass(folder(), "Beam")):toBe(1)
	end)

	it("bounces the arrow", function()
		guide:Update(0, root, camera)
		local first = arrowParts()[3].CFrame.Position.Y
		guide:Update(0.5, root, camera)
		local second = arrowParts()[3].CFrame.Position.Y
		expect(first ~= second):toBe(true)
	end)

	it("hides the beam and arrow and shows a placement hint inside the base", function()
		guide:Update(1, root, camera)
		expect(gui().Hint.Visible):toBe(false)
		standAt(0, 3, 0)
		guide:Update(1.1, root, camera)
		expect(beam().Enabled):toBe(false)
		expect(folder():FindFirstChild("Arrow")):toBeNil()
		expect(gui().Edge.Visible):toBe(false)
		expect(gui().Hint.Visible):toBe(true)
		expect(gui().Hint.Text):toBe(Eggs.Guide.HintText)
		standAt(0, 3, 100)
		guide:Update(1.2, root, camera)
		expect(beam().Enabled):toBe(true)
		expect(folder():FindFirstChild("Arrow") ~= nil):toBe(true)
		expect(gui().Hint.Visible):toBe(false)
	end)

	it("hides the beam when there is no character", function()
		guide:Update(1, nil, camera)
		expect(beam().Enabled):toBe(false)
		expect(#descendantsOfClass(root, "Attachment")):toBe(0)
	end)

	it("shows no edge indicator while the base is on screen", function()
		guide:Update(1, root, camera)
		expect(gui().Edge.Visible):toBe(false)
	end)

	it("shows an edge arrow with the label when the base is off screen", function()
		look(Vector3.new(0, 20, 60), -math.pi / 2)
		guide:Update(1, root, camera)
		local edge = gui().Edge
		expect(edge.Visible):toBe(true)
		expect(edge.Text.Text):toBe("PLACE YOUR EGG")
		local viewport = camera.ViewportSize
		expect(edge.Position.X.Offset >= 0 and edge.Position.X.Offset <= viewport.X):toBe(true)
		expect(edge.Position.Y.Offset >= 0 and edge.Position.Y.Offset <= viewport.Y):toBe(true)
	end)

	it("clamps the edge arrow to the screen edge when the base is behind the camera", function()
		look(Vector3.new(0, 20, 60), math.pi)
		guide:Update(1, root, camera)
		local edge = gui().Edge
		expect(edge.Visible):toBe(true)
		local viewport = camera.ViewportSize
		local x, y = edge.Position.X.Offset, edge.Position.Y.Offset
		local margin = Eggs.Guide.EdgeMargin
		local onEdge = math.abs(x - margin) < 1e-3
			or math.abs(x - (viewport.X - margin)) < 1e-3
			or math.abs(y - margin) < 1e-3
			or math.abs(y - (viewport.Y - margin)) < 1e-3
		expect(onEdge):toBe(true)
	end)

	it("rotates the edge arrow toward the base", function()
		look(Vector3.new(0, 20, 60), -math.pi / 2)
		guide:Update(1, root, camera)
		local arrow = gui().Edge:FindFirstChild("Arrow")
		local first = arrow.Rotation
		look(Vector3.new(0, 20, 60), math.pi / 2)
		guide:Update(1.1, root, camera)
		expect(math.abs(first - arrow.Rotation) > 90):toBe(true)
	end)

	it("cleans up everything on Destroy", function()
		guide:Update(1, root, camera)
		guide:Destroy()
		guide = nil
		expect(folder()):toBeNil()
		expect(gui()):toBeNil()
		expect(#descendantsOfClass(root, "Attachment")):toBe(0)
	end)

	it("does not leak attachments when the character changes", function()
		guide:Update(1, root, camera)
		local other = world:newPart("HumanoidRootPart", 5, 3, 100)
		other.Position = Vector3.new(5, 3, 100)
		guide:Update(1.1, other, camera)
		expect(#descendantsOfClass(root, "Attachment")):toBe(0)
		expect(#descendantsOfClass(other, "Attachment")):toBe(1)
		expect(beam().Attachment0.Parent == other):toBe(true)
	end)
end)

describe("EggController guide lifecycle", function()
	local world, controller, plotController, player, playerGui, camera, data, toasts, character

	local function folder(): any
		return world.workspace:FindFirstChild("EggGuide")
	end

	local function setHeld(value: string)
		data:Set({ "HeldEgg" }, value)
	end

	local function frame()
		world.fakeServices.RunService.RenderStepped:Fire(1 / 60)
	end

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
		local Signal = world:require("ReplicatedStorage.Packages.Signal")
		player = world:newPlayer({ Name = "Tester" })
		player.GetAttributeChangedSignal = function()
			return Signal.new()
		end
		world.Players.LocalPlayer = player
		playerGui = world:newInstance("Folder")
		playerGui.Name = "PlayerGui"
		playerGui.Parent = player
		camera = world:newInstance("Camera")
		camera.CFrame = CFrame.new(0, 20, 60)
		world.workspace.CurrentCamera = camera
		local plots = world:newInstance("Folder")
		plots.Name = "Plots"
		plots.Parent = world.workspace
		local plot = world:newInstance("Model")
		plot.Name = "Plot1"
		plot:SetAttribute("Owner", player.UserId)
		plot.Parent = plots
		local base = world:newPart("Base", 0, 0, 0)
		base.Size = Vector3.new(44, 1, 44)
		base.Parent = plot
		character = world:spawnCharacter(player, 0, 3, 100)
		character.HumanoidRootPart.Position = Vector3.new(0, 3, 100)
		data = H.fakeDataController({ HeldEgg = "" })
		toasts = {}
		plotController = world:require(`{controllers}.PlotController`)
		plotController:Init({})
		plotController:Start()
		world:flush()
		controller = world:require(`{controllers}.EggController`)
		controller:Init({
			PlotController = plotController,
			DataController = data,
			UIController = {
				Toast = function(_self: any, text: string, kind: string)
					table.insert(toasts, { Text = text, Kind = kind })
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

	it("creates no guide while no egg is held", function()
		frame()
		expect(folder()):toBeNil()
	end)

	it("creates the guide while an egg is held", function()
		setHeld("Linear")
		frame()
		expect(folder() ~= nil):toBe(true)
		expect(folder():FindFirstChild("GuideBeam").Enabled):toBe(true)
		expect(playerGui:FindFirstChild("EggGuide") ~= nil):toBe(true)
	end)

	it("keeps a single guide across frames", function()
		setHeld("Linear")
		frame()
		frame()
		frame()
		local count = 0
		for _, child in world.workspace:GetChildren() do
			if child.Name == "EggGuide" then
				count += 1
			end
		end
		expect(count):toBe(1)
	end)

	it("destroys the guide when the egg is placed", function()
		setHeld("Linear")
		frame()
		setHeld("")
		expect(folder()):toBeNil()
		expect(playerGui:FindFirstChild("EggGuide")):toBeNil()
		frame()
		expect(folder()):toBeNil()
	end)

	it("ignores unknown held egg ids", function()
		setHeld("Mystery")
		frame()
		expect(folder()):toBeNil()
	end)

	it("keeps the guide when the next queued egg becomes held", function()
		setHeld("Linear")
		frame()
		setHeld("Golden")
		frame()
		expect(folder() ~= nil):toBe(true)
	end)

	it("removes the guide on Destroy", function()
		setHeld("Linear")
		frame()
		controller:Destroy()
		expect(folder()):toBeNil()
		expect(playerGui:FindFirstChild("EggGuide")):toBeNil()
		controller:Init({})
	end)
end)
