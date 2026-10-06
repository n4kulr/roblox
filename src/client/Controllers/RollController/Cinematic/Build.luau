--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local Kit = require(script.Parent.Parent.Parent.UIController.Kit)
local Viewport = require(script.Parent.Parent.Parent.UIController.Viewport)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

type TroveInstance = typeof(Trove.new())
type Particle = Types.Particle
type Star = Types.Star
type Crack = Types.Crack
type Ring = Types.Ring
type Ray = Types.Ray
type Edge = Types.Edge
type TitleSet = Types.TitleSet
local displayOrder = Config.DisplayOrder
local capSize = Config.CapSize
local capY = Config.CapY
local titleY = Config.TitleY
local nameY = Config.NameY
local rayDiameters = Config.RayDiameters
local particleCap = Config.ParticleCap
local starCap = Config.StarCap
local crackCount = Config.CrackCount
local ringCap = Config.RingCap
local white = Config.White
local black = Config.Black
local rainbow = Config.Rainbow

local Build = {}

local function box(parent: Instance, name: string, z: number): Frame
	local item = Instance.new("Frame")
	item.Name = name
	item.BackgroundColor3 = white
	item.BackgroundTransparency = 1
	item.BorderSizePixel = 0
	item.AnchorPoint = Vector2.new(0.5, 0.5)
	item.Position = UDim2.fromScale(0.5, 0.5)
	item.Size = UDim2.fromOffset(10, 10)
	item.ZIndex = z
	item.Active = false
	item.Visible = false
	item.Parent = parent
	return item
end

function Build.Center(x: number, y: number): UDim2
	return UDim2.new(0.5, x, 0.5, y)
end

local function buildEdges(parent: Instance): { Edge }
	local edges: { Edge } = {}
	for _, side in { "Top", "Bottom", "Left", "Right" } do
		local frame = box(parent, `Edge{side}`, 16)
		frame.BackgroundTransparency = 0
		local isVertical = side == "Top" or side == "Bottom"
		frame.AnchorPoint = Vector2.new(if side == "Right" then 1 else 0, if side == "Bottom" then 1 else 0)
		frame.Position = UDim2.fromScale(if side == "Right" then 1 else 0, if side == "Bottom" then 1 else 0)
		frame.Size = if isVertical then UDim2.new(1, 0, 0, 16) else UDim2.new(0, 16, 1, 0)
		local gradient = Instance.new("UIGradient")
		gradient.Color = rainbow
		gradient.Parent = frame
		table.insert(edges, { Frame = frame, Gradient = gradient, Side = side })
	end
	return edges
end

local function buildVignette(parent: Instance): { Frame }
	local strips: { Frame } = {}
	local setups = {
		{ Name = "Left", Rotation = 0, Anchor = Vector2.new(0, 0), Position = UDim2.fromScale(0, 0) },
		{ Name = "Right", Rotation = 180, Anchor = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0) },
		{ Name = "Top", Rotation = 90, Anchor = Vector2.new(0, 0), Position = UDim2.fromScale(0, 0) },
		{ Name = "Bottom", Rotation = 270, Anchor = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1) },
	}
	for _, setup in setups do
		local frame = box(parent, `Vignette{setup.Name}`, 2)
		frame.BackgroundColor3 = black
		frame.AnchorPoint = setup.Anchor
		frame.Position = setup.Position
		local isSide = setup.Name == "Left" or setup.Name == "Right"
		frame.Size = if isSide then UDim2.fromScale(0.4, 1) else UDim2.fromScale(1, 0.45)
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = setup.Rotation
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.65),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = frame
		table.insert(strips, frame)
	end
	return strips
end

local function buildTitle(parent: Instance): TitleSet
	local function make(name: string, color: Color3, outline: boolean, z: number): TextLabel
		local label = Kit.Label({
			Parent = parent,
			Name = name,
			Text = "",
			Size = UDim2.fromOffset(1300, 130),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = Build.Center(0, titleY),
			TextSize = 96,
			Color = color,
			Align = Enum.TextXAlignment.Center,
			Title = true,
			Outline = outline,
			StrokeSize = 10,
		})
		label.ZIndex = z
		label.Visible = false
		local scale = Instance.new("UIScale")
		scale.Parent = label
		return label
	end
	local red = make("TitleRed", Color3.fromRGB(255, 50, 80), false, 13)
	local cyan = make("TitleCyan", Color3.fromRGB(40, 230, 255), false, 13)
	local main = make("Title", white, true, 14)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Parent = main
	return {
		Main = main,
		MainStroke = main:FindFirstChild("TextStroke") :: UIStroke,
		MainScale = main:FindFirstChildOfClass("UIScale") :: UIScale,
		MainGradient = gradient,
		Red = red,
		Cyan = cyan,
	}
end

function Build.Scene(playerGui: Instance, trove: TroveInstance): Types.Scene
	local gui, root = Kit.ScreenGui("RollCinematic", displayOrder, playerGui, trove)
	gui.IgnoreGuiInset = true
	gui.Enabled = false

	local dim = box(root, "Dim", 1)
	dim.AnchorPoint = Vector2.zero
	dim.Position = UDim2.fromScale(0, 0)
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = black
	dim.BackgroundTransparency = 1

	local vignette = buildVignette(root)

	local world = Instance.new("Frame")
	world.Name = "World"
	world.BackgroundTransparency = 1
	world.BorderSizePixel = 0
	world.Size = UDim2.fromScale(1, 1)
	world.ZIndex = 3
	world.Parent = root

	local stars: { Star } = {}
	for index = 1, starCap do
		table.insert(stars, {
			Frame = box(world, `Star{index}`, 1),
			Angle = math.random() * 360,
			Speed = 0.6 + math.random() * 0.8,
			Phase = math.random(),
		})
	end

	local rays: { Ray } = {}
	for index, diameter in rayDiameters do
		local holder = Kit.Burst({ Parent = world, Diameter = diameter, Position = Build.Center(0, capY) })
		holder.Name = `Rays{index}`
		holder.ZIndex = 2 + index
		holder.Visible = false
		local image = holder:FindFirstChild("Image")
		table.insert(rays, {
			Holder = holder,
			Image = if image and image:IsA("ImageLabel") then image else nil,
			Diameter = diameter,
		})
	end

	local glow = box(world, "Glow", 5)
	Kit.Round(glow)

	local rings: { Ring } = {}
	for index = 1, ringCap do
		local ring = box(world, `Ring{index}`, 6)
		Kit.Round(ring)
		local stroke = Kit.Stroke(ring, white, 12)
		table.insert(rings, { Frame = ring, Stroke = stroke })
	end

	local cracks: { Crack } = {}
	for index = 1, crackCount do
		local frame = box(world, `Crack{index}`, 7)
		frame.BackgroundTransparency = 0
		frame.BackgroundColor3 = white
		Kit.Corner(frame, 4)
		table.insert(cracks, {
			Frame = frame,
			Angle = (index - 1) * (360 / crackCount) + (math.random() - 0.5) * 14,
			Length = 380 + math.random() * 260,
		})
	end

	local model = Viewport.new({
		Parent = world,
		Name = "KeyModel",
		Size = UDim2.fromOffset(capSize, capSize),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = Build.Center(0, capY),
		ZIndex = 10,
	})
	model.Frame.Visible = false
	Viewport.Glint(model, 0)

	local particles: { Particle } = {}
	for index = 1, particleCap do
		table.insert(particles, {
			Frame = box(world, `Piece{index}`, 12),
			Born = 0,
			Life = 1,
			X = 0,
			Y = 0,
			VX = 0,
			VY = 0,
			Rot = 0,
			Spin = 0,
			Shape = 1,
			IsRain = false,
			Color = white,
			Used = false,
		})
	end
	for _, piece in particles do
		piece.Frame.BackgroundTransparency = 0
	end

	local title = buildTitle(world)

	local nameLabel = Kit.Label({
		Parent = world,
		Name = "KeyName",
		Text = "",
		Size = UDim2.fromOffset(1000, 80),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = Build.Center(0, nameY),
		TextSize = 64,
		Align = Enum.TextXAlignment.Center,
		Title = true,
		StrokeSize = 7,
	})
	nameLabel.ZIndex = 15
	nameLabel.Visible = false
	local nameScale = Instance.new("UIScale")
	nameScale.Parent = nameLabel

	local edges = buildEdges(root)

	local flash = box(root, "Flash", 20)
	flash.AnchorPoint = Vector2.zero
	flash.Position = UDim2.fromScale(0, 0)
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundTransparency = 1

	local hint = Kit.Label({
		Parent = root,
		Name = "Hint",
		Text = "TAP TO SKIP",
		Size = UDim2.fromOffset(300, 30),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		TextSize = 20,
		Align = Enum.TextXAlignment.Center,
		Title = true,
		StrokeSize = 3,
	})
	hint.ZIndex = 21
	hint.Visible = false
	return {
		Gui = gui,
		World = world,
		Dim = dim,
		Edges = edges,
		Vignette = vignette,
		Flash = flash,
		Hint = hint,
		Glow = glow,
		Model = model,
		Title = title,
		Name = nameLabel,
		NameScale = nameScale,
		NameStroke = nameLabel:FindFirstChild("TextStroke") :: UIStroke,
		Rays = rays,
		Rings = rings,
		Cracks = cracks,
		Stars = stars,
		Particles = particles,
	}
end

return Build
