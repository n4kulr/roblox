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

type SpotSpec = {
	Center: Vector3,
	Size: Vector3,
	Theta: number,
	Phi: number,
	Width: number,
}

local baseHeight = 3.2
local lowerSize = Vector3.new(2.4, 2.6, 2.4)
local upperSize = Vector3.new(1.8, 2, 1.8)
local lowerCenter = Vector3.new(0, -0.3, 0)
local upperCenter = Vector3.new(0, 0.6, 0)
local spots: { SpotSpec } = {
	{ Center = lowerCenter, Size = lowerSize, Theta = -90, Phi = 15, Width = 0.62 },
	{ Center = lowerCenter, Size = lowerSize, Theta = -30, Phi = -25, Width = 0.5 },
	{ Center = lowerCenter, Size = lowerSize, Theta = -150, Phi = -30, Width = 0.5 },
	{ Center = lowerCenter, Size = lowerSize, Theta = 30, Phi = 20, Width = 0.48 },
	{ Center = lowerCenter, Size = lowerSize, Theta = 150, Phi = 10, Width = 0.5 },
	{ Center = lowerCenter, Size = lowerSize, Theta = 90, Phi = -20, Width = 0.46 },
	{ Center = upperCenter, Size = upperSize, Theta = -60, Phi = 35, Width = 0.4 },
}
local ghostTransparency = 0.5

local EggModel = {}

EggModel.Height = baseHeight
EggModel.PlacedScale = 1.2

function EggModel.PivotOffset(scale: number): Vector3
	return lowerCenter * scale
end

function EggModel.PivotDrop(scale: number): number
	return baseHeight * scale / 2 + lowerCenter.Y * scale
end

function EggModel.HeightOf(scale: number): number
	return baseHeight * scale
end

local function sphere(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	part.Parent = parent
	return part
end

function EggModel.Build(parent: Instance, egg: Eggs.Egg, options: Options): { BasePart }
	local scale = options.Scale
	local origin = options.Origin or CFrame.new()
	local ghost = options.Ghost
	local parts: { BasePart } = {}
	local function add(name: string, size: Vector3, offset: CFrame, color: Color3)
		local part = sphere(parent, name, size * scale, origin * offset, if ghost then ghost else color)
		part.Anchored = options.Anchored
		part.Massless = not options.Anchored
		if ghost then
			part.Transparency = ghostTransparency
			part.Material = Enum.Material.Neon
		end
		table.insert(parts, part)
		return part
	end
	local body = add(options.BodyName or "EggBody", lowerSize, CFrame.new(lowerCenter * scale), egg.Color)
	add("EggTop", upperSize, CFrame.new(upperCenter * scale), egg.Color)
	for index, spec in spots do
		local center = spec.Center * scale
		local size = spec.Size * scale
		local theta = math.rad(spec.Theta)
		local phi = math.rad(spec.Phi)
		local radial = Vector3.new(
			math.cos(phi) * math.cos(theta) * size.X / 2,
			math.sin(phi) * size.Y / 2,
			math.cos(phi) * math.sin(theta) * size.Z / 2
		)
		local position = center + radial * 0.97
		local width = spec.Width * scale
		add(
			`EggSpot{index}`,
			Vector3.new(width, width, width * 0.4),
			CFrame.lookAt(position, position + radial),
			egg.SpotColor
		)
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

function EggModel.Tint(parts: { BasePart }, color: Color3)
	for _, part in parts do
		part.Color = color
	end
end

return table.freeze(EggModel)
