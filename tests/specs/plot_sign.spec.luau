local roblox = require("@lune/roblox")
local H = require("../harness/Harness")

local Vector3, Color3, CFrame = roblox.Vector3, roblox.Color3, roblox.CFrame
local describe, it, expect, afterEach = H.describe, H.it, H.expect, H.afterEach

describe("Plot owner sign", function()
	local world, registry, plots

	local function authoredPlot(position: any, panelSize: any)
		local folder = world:newInstance("Folder")
		folder.Name = "Plots"
		local model = world:newInstance("Model")
		model.Name = "Plot1"
		local origin = CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
		for name, size in
			{ Base = Vector3.new(44, 1, 44), RollKey = Vector3.new(8, 3, 8), Board = Vector3.new(31, 1.5, 9.6) }
		do
			local part = world:newInstance("Part")
			part.Name = name
			part.Size = size
			part.CFrame = if name == "Base" then origin else origin * CFrame.new(0, 2, 0)
			part.Color = Color3.new(1, 1, 1)
			part.Material = roblox.Enum.Material.SmoothPlastic
			part.Parent = model
		end
		local sign = world:newInstance("Folder")
		sign.Name = "Sign"
		local panel = world:newInstance("Part")
		panel.Name = "Panel"
		panel.Size = panelSize
		panel.CFrame = origin * CFrame.new(-15, 6.5, -17)
		panel.Parent = sign
		sign.Parent = model
		model.Parent = folder
		folder.Parent = world.workspace
	end

	local function setup(authored: boolean?, panelSize: any?)
		world = H.newWorld()
		local Signal = world:require("ReplicatedStorage.Packages.Signal")
		world.workspace = world:newInstance("Folder")
		if authored then
			authoredPlot(Vector3.new(80, 0.5, 0), panelSize or Vector3.new(10, 5, 0.5))
		end
		local keyboard = { Name = "KeyboardService", BoardChanged = Signal.new() }
		local plotService = world:require("ServerScriptService.Services.PlotService")
		registry = world:boot({ "PlotService" }, { KeyboardService = keyboard, PlotService = plotService })
		plots = world.workspace:FindFirstChild("Plots")
	end

	local function contentOf(gui: any)
		local plate = gui:FindFirstChild("Plate")
		return {
			Head = plate:FindFirstChild("Headshot"),
			Name = plate:FindFirstChild("DisplayName"),
			Tag = plate:FindFirstChild("UserName"),
			Empty = plate:FindFirstChild("Empty"),
		}
	end

	local function signsOf(parent: any): { any }
		local out = {}
		for _, child in parent:GetChildren() do
			if child.Name == "OwnerSign" then
				table.insert(out, child)
			end
		end
		return out
	end

	local function expectEmpty(gui: any)
		local content = contentOf(gui)
		expect(content.Empty.Visible):toBe(true)
		expect(content.Empty.Text):toBe("🔓 EMPTY BASE")
		expect(content.Head.Visible):toBe(false)
		expect(content.Name.Visible):toBe(false)
		expect(content.Tag.Visible):toBe(false)
	end

	local function expectOwned(gui: any, player: any)
		local content = contentOf(gui)
		expect(content.Empty.Visible):toBe(false)
		expect(content.Head.Visible):toBe(true)
		expect(content.Head.Image):toBe(`rbxthumb://type=AvatarHeadShot&id={player.UserId}&w=150&h=150`)
		expect(content.Name.Text):toBe(player.DisplayName)
		expect(content.Tag.Text):toBe(`@{player.Name}`)
	end

	afterEach(function()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	it("gives placeholder plots an empty billboard on the base", function()
		setup()
		for _, plot in plots:GetChildren() do
			local guis = signsOf(plot.Base)
			expect(#guis):toBe(1)
			expect(guis[1].ClassName):toBe("BillboardGui")
			expect(guis[1].Adornee == plot.Base):toBe(true)
			expect(guis[1].StudsOffset):toBe(Vector3.new(0, 9, 0))
			expect(guis[1].MaxDistance):toBe(150)
			expect(guis[1].LightInfluence):toBe(0)
			expect(guis[1].AlwaysOnTop):toBe(false)
			expectEmpty(guis[1])
		end
	end)

	it("shows the owner name, handle and headshot after assign and resets on release", function()
		setup()
		local player = world:join({ UserId = 4242, Name = "keyboardfan", DisplayName = "Key Fan" })
		local plot = registry.PlotService:GetPlot(player)
		local guis = signsOf(plot.Base)
		expect(#guis):toBe(1)
		local gui = guis[1]
		expectOwned(gui, player)
		expect(contentOf(gui).Head.Image):toBe("rbxthumb://type=AvatarHeadShot&id=4242&w=150&h=150")
		world:removePlayer(player)
		local again = signsOf(plot.Base)
		expect(#again):toBe(1)
		expect(again[1] == gui):toBe(true)
		expectEmpty(gui)
	end)

	it("reuses the same gui when another player takes the plot", function()
		setup()
		local first = world:join({ UserId = 11, Name = "one", DisplayName = "One" })
		local plot = registry.PlotService:GetPlot(first)
		local gui = signsOf(plot.Base)[1]
		world:removePlayer(first)
		local second = world:join({ UserId = 22, Name = "two", DisplayName = "Two" })
		expect(registry.PlotService:GetPlot(second) == plot):toBe(true)
		expect(#signsOf(plot.Base)):toBe(1)
		expect(signsOf(plot.Base)[1] == gui):toBe(true)
		expectOwned(gui, second)
	end)

	it("puts surface guis on both faces of an authored sign panel", function()
		setup(true)
		local plot = plots.Plot1
		local panel = plot.Sign.Panel
		expect(#signsOf(plot.Base)):toBe(0)
		local guis = signsOf(panel)
		expect(#guis):toBe(2)
		local faces = {}
		for _, gui in guis do
			expect(gui.ClassName):toBe("SurfaceGui")
			expect(gui.SizingMode == roblox.Enum.SurfaceGuiSizingMode.PixelsPerStud):toBe(true)
			expect(gui.PixelsPerStud):toBe(50)
			expect(gui.LightInfluence):toBe(0)
			expect(gui.AlwaysOnTop):toBe(false)
			expect(gui.Adornee == panel):toBe(true)
			faces[gui.Face.Name] = true
			expectEmpty(gui)
		end
		expect(faces.Front):toBe(true)
		expect(faces.Back):toBe(true)
		local player = world:join({ UserId = 77, Name = "signer", DisplayName = "Signer" })
		expect(registry.PlotService:GetPlot(player) == plot):toBe(true)
		for _, gui in guis do
			expectOwned(gui, player)
		end
		world:removePlayer(player)
		for _, gui in guis do
			expectEmpty(gui)
		end
	end)

	it("picks the face toward the plot front as the primary", function()
		setup(true)
		local OwnerSign = world:require("ServerScriptService.Utils.OwnerSign")
		local panel = plots.Plot1.Sign.Panel
		local base = plots.Plot1.Base
		local front, back, aspect = OwnerSign.Faces(panel, base)
		expect(front.Face == roblox.Enum.NormalId.Front):toBe(true)
		expect(back.Face == roblox.Enum.NormalId.Back):toBe(true)
		expect(aspect):toBeCloseTo(2, 1e-6)
		panel.CFrame = panel.CFrame * CFrame.Angles(0, math.pi, 0)
		local flipped = OwnerSign.Faces(panel, base)
		expect(flipped.Face == roblox.Enum.NormalId.Back):toBe(true)
	end)

	it("removes its guis when the service is destroyed", function()
		setup(true)
		local panel = plots.Plot1.Sign.Panel
		expect(#signsOf(panel)):toBe(2)
		registry.PlotService:Destroy()
		expect(#signsOf(panel)):toBe(0)
	end)
end)
