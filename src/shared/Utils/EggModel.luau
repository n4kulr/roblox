--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Eggs = require(ReplicatedStorage.Config.Eggs)

export type Options = {
	Scale: number,
	BodyName: string?,
	Anchored: boolean,
	Origin: CFrame?,
	Ghost: Color3?,
}

type Ellipsoid = {
	Center: Vector3,
	Size: Vector3,
}

type Band = {
	Y: number,
	Height: number,
	Color: Color3?,
}

type Dot = {
	Y: number,
	Theta: number,
	Width: number,
}

type Style = {
	Bands: { Band },
	Dots: { Dot },
	Keycaps: { Dot },
	Diamonds: { Dot },
	Metal: boolean,
}

local baseHeight = 3.2
local lower: Ellipsoid = { Center = Vector3.new(0, -0.3, 0), Size = Vector3.new(2.4, 2.6, 2.4) }
local middle: Ellipsoid = { Center = Vector3.new(0, 0.15, 0), Size = Vector3.new(2.1, 2.2, 2.1) }
local upper: Ellipsoid = { Center = Vector3.new(0, 0.6, 0), Size = Vector3.new(1.8, 2, 1.8) }
local shapes: { Ellipsoid } = { lower, middle, upper }
local ringSize = Vector3.new(2.3, 0.2, 2.3)
local ringY = -1.5
local ghostTransparency = 0.5
local surfaceInset = 0.97
local bandInflate = 1.02
local shade = Color3.fromRGB(34, 28, 52)
local white = Color3.new(1, 1, 1)
local rainbow: { Color3 } = {
	Color3.fromRGB(255, 80, 90),
	Color3.fromRGB(255, 170, 60),
	Color3.fromRGB(255, 235, 90),
	Color3.fromRGB(110, 220, 120),
	Color3.fromRGB(90, 160, 255),
}

local function around(y: number, count: number, width: number, turn: number): { Dot }
	local dots: { Dot } = {}
	for index = 1, count do
		table.insert(dots, { Y = y, Theta = turn + (index - 1) * 360 / count, Width = width })
	end
	return dots
end

local function join(...: { Dot }): { Dot }
	local merged: { Dot } = {}
	for _, group in { ... } do
		for _, dot in group do
			table.insert(merged, dot)
		end
	end
	return merged
end

local styles: { [string]: Style } = {
	Linear = {
		Bands = { { Y = -0.55, Height = 0.2 }, { Y = 0.5, Height = 0.2 } },
		Dots = around(-0.02, 5, 0.46, 20),
		Keycaps = {},
		Diamonds = {},
		Metal = false,
	},
	Tactile = {
		Bands = {},
		Dots = join(around(-0.95, 5, 0.4, 0), around(-0.1, 6, 0.42, 30), around(0.85, 4, 0.34, 15)),
		Keycaps = {},
		Diamonds = {},
		Metal = false,
	},
	Clicky = {
		Bands = { { Y = -0.95, Height = 0.18 } },
		Dots = {},
		Keycaps = around(-0.05, 4, 0.72, 45),
		Diamonds = {},
		Metal = false,
	},
	Golden = {
		Bands = { { Y = -0.8, Height = 0.22 } },
		Dots = {},
		Keycaps = {},
		Diamonds = join(around(-0.1, 6, 0.5, 0), around(0.95, 4, 0.34, 45)),
		Metal = true,
	},
	Rainbow = {
		Bands = {
			{ Y = -1.0, Height = 0.2, Color = rainbow[1] },
			{ Y = -0.55, Height = 0.2, Color = rainbow[2] },
			{ Y = -0.1, Height = 0.2, Color = rainbow[3] },
			{ Y = 0.35, Height = 0.2, Color = rainbow[4] },
			{ Y = 0.8, Height = 0.2, Color = rainbow[5] },
		},
		Dots = join(around(-0.32, 6, 0.3, 0), around(0.12, 6, 0.3, 30)),
		Keycaps = {},
		Diamonds = {},
		Metal = false,
	},
}

local fallbackStyle: Style = {
	Bands = {},
	Dots = around(0, 5, 0.5, 0),
	Keycaps = {},
	Diamonds = {},
	Metal = false,
}

local EggModel = {}

EggModel.Height = baseHeight
EggModel.PlacedScale = 1.2
EggModel.MaxParts = 40

function EggModel.PivotOffset(scale: number): Vector3
	return lower.Center * scale
end

function EggModel.PivotDrop(scale: number): number
	return baseHeight * scale / 2 + lower.Center.Y * scale
end

function EggModel.HeightOf(scale: number): number
	return baseHeight * scale
end

local function radiusAt(shape: Ellipsoid, y: number): number
	local halfHeight = shape.Size.Y / 2
	local ratio = (y - shape.Center.Y) / halfHeight
	if math.abs(ratio) >= 1 then
		return 0
	end
	return shape.Size.X / 2 * math.sqrt(1 - ratio * ratio)
end

local function widest(y: number): (number, Ellipsoid)
	local best, bestShape = 0, lower
	for _, shape in shapes do
		local radius = radiusAt(shape, y)
		if radius > best then
			best, bestShape = radius, shape
		end
	end
	return best, bestShape
end

local function surface(y: number, thetaDegrees: number): (Vector3, Vector3)
	local radius, shape = widest(y)
	local theta = math.rad(thetaDegrees)
	local position = Vector3.new(math.cos(theta) * radius, y, math.sin(theta) * radius)
	local relative = position - shape.Center
	local half = shape.Size / 2
	local normal = Vector3.new(relative.X / (half.X * half.X), relative.Y / (half.Y * half.Y), relative.Z / (half.Z * half.Z))
	return position, if normal.Magnitude > 0 then normal.Unit else Vector3.new(0, 1, 0)
end

local function piece(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	mesh: Enum.MeshType?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if mesh then
		local special = Instance.new("SpecialMesh")
		special.MeshType = mesh
		special.Parent = part
	end
	part.Parent = parent
	return part
end

function EggModel.StyleOf(eggId: string): Style
	return styles[eggId] or fallbackStyle
end

function EggModel.Build(parent: Instance, egg: Eggs.Egg, options: Options): { BasePart }
	local scale = options.Scale
	local origin = options.Origin or CFrame.new()
	local ghost = options.Ghost
	local look = EggModel.StyleOf(egg.Id)
	local parts: { BasePart } = {}
	local function add(
		name: string,
		size: Vector3,
		offset: CFrame,
		color: Color3,
		mesh: Enum.MeshType?
	): Part
		local scaled = CFrame.new(offset.Position * scale) * (offset - offset.Position)
		local part = piece(parent, name, size * scale, origin * scaled, if ghost then ghost else color, mesh)
		part.Anchored = options.Anchored
		part.Massless = not options.Anchored
		if ghost then
			part.Transparency = ghostTransparency
			part.Material = Enum.Material.Neon
		end
		table.insert(parts, part)
		return part
	end
	local bodyName = options.BodyName or "EggBody"
	local body = add(bodyName, lower.Size, CFrame.new(lower.Center), egg.Color, Enum.MeshType.Sphere)
	add("EggTop", upper.Size, CFrame.new(upper.Center), egg.Color, Enum.MeshType.Sphere)
	add("EggMid", middle.Size, CFrame.new(middle.Center), egg.Color, Enum.MeshType.Sphere)
	if look.Metal and not ghost then
		for _, part in parts do
			part.Material = Enum.Material.Metal
		end
	end
	if not ghost then
		local count = 0
		for _, dot in look.Dots do
			count += 1
			local position, normal = surface(dot.Y, dot.Theta)
			add(
				`EggSpot{count}`,
				Vector3.new(dot.Width, dot.Width, dot.Width * 0.4),
				CFrame.lookAt(position * surfaceInset, position * surfaceInset + normal),
				egg.SpotColor,
				Enum.MeshType.Sphere
			)
		end
		for _, key in look.Keycaps do
			count += 1
			local position, normal = surface(key.Y, key.Theta)
			local anchor = position * 0.98
			local facing = CFrame.lookAt(anchor, anchor + normal)
			add(`EggSpot{count}`, Vector3.new(key.Width, key.Width, 0.22), facing, egg.SpotColor, nil)
			add(
				`EggKeyTop{count}`,
				Vector3.new(key.Width * 0.68, key.Width * 0.68, 0.14),
				facing * CFrame.new(0, 0, -0.16),
				egg.SpotColor:Lerp(white, 0.6),
				nil
			)
		end
		for _, gem in look.Diamonds do
			count += 1
			local position, normal = surface(gem.Y, gem.Theta)
			local anchor = position * surfaceInset
			add(
				`EggSpot{count}`,
				Vector3.new(gem.Width, gem.Width, gem.Width * 0.3),
				CFrame.lookAt(anchor, anchor + normal) * CFrame.Angles(0, 0, math.rad(45)),
				egg.SpotColor,
				nil
			)
		end
		for index, band in look.Bands do
			local radius = widest(band.Y)
			local diameter = radius * 2 * bandInflate + 0.08
			add(
				`EggBand{index}`,
				Vector3.new(diameter, band.Height, diameter),
				CFrame.new(0, band.Y, 0),
				band.Color or egg.SpotColor,
				Enum.MeshType.Cylinder
			)
		end
		add("EggRing", ringSize, CFrame.new(0, ringY, 0), egg.Color:Lerp(shade, 0.65), Enum.MeshType.Cylinder)
	end
	if not options.Anchored then
		for _, part in parts do
			if part ~= body then
				local weld = Instance.new("WeldConstraint")
				weld.Name = "EggWeld"
				weld.Part0 = body
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end
	return parts
end

function EggModel.Model(egg: Eggs.Egg, scale: number?): Model
	local model = Instance.new("Model")
	model.Name = `Egg_{egg.Id}`
	local parts = EggModel.Build(model, egg, { Scale = scale or 1, Anchored = true })
	model.PrimaryPart = parts[1]
	return model
end

function EggModel.Tint(parts: { BasePart }, color: Color3)
	for _, part in parts do
		part.Color = color
	end
end

return table.freeze(EggModel)
