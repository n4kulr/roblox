--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Upgrades = require(ReplicatedStorage.Config.Upgrades)
local Types = require(script.Parent.Types)

export type Segment = {
	Name: string,
	Kind: string,
	Size: Vector3,
	Center: Vector3,
}

local defense = GameConfig.Defense
local folderName = "GlassWalls"
local fenceName = "Fence"
local edgeInset = 0.25
local pillarSize = 1.4
local glassThickness = 0.6
local railThickness = 0.9
local railHeight = 0.3
local pillarOvershoot = 0.4
local glassColor = Color3.fromRGB(180, 220, 255)
local glassTransparency = 0.55
local glassReflectance = 0.1
local steelColor = Color3.fromRGB(60, 64, 78)

local Walls = {
	FolderName = folderName,
	Inset = edgeInset + pillarSize / 2,
	PillarSize = pillarSize,
	GlassThickness = glassThickness,
	RailHeight = railHeight,
	PillarOvershoot = pillarOvershoot,
	Kinds = { Glass = "Glass", Rail = "Rail", Pillar = "Pillar" },
}

function Walls.Level(value: any): number
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, Upgrades.ById.Walls.MaxLevel)
end

function Walls.GlassHeight(level: any): number
	return Walls.Level(level) * Upgrades.ById.Walls.PerLevel
end

local function span(
	name: string,
	isAlongX: boolean,
	from: number,
	to: number,
	line: number,
	bottom: number,
	height: number
): { Segment }
	local length = math.abs(to - from)
	local middle = (from + to) / 2
	local glassY = bottom + height / 2
	local railY = bottom + height + railHeight / 2
	local glass: Segment
	local rail: Segment
	if isAlongX then
		glass = {
			Name = name,
			Kind = Walls.Kinds.Glass,
			Size = Vector3.new(length, height, glassThickness),
			Center = Vector3.new(middle, glassY, line),
		}
		rail = {
			Name = `Rail{name}`,
			Kind = Walls.Kinds.Rail,
			Size = Vector3.new(length, railHeight, railThickness),
			Center = Vector3.new(middle, railY, line),
		}
	else
		glass = {
			Name = name,
			Kind = Walls.Kinds.Glass,
			Size = Vector3.new(glassThickness, height, length),
			Center = Vector3.new(line, glassY, middle),
		}
		rail = {
			Name = `Rail{name}`,
			Kind = Walls.Kinds.Rail,
			Size = Vector3.new(railThickness, railHeight, length),
			Center = Vector3.new(line, railY, middle),
		}
	end
	return { glass, rail }
end

function Walls.Layout(baseSize: Vector3, height: number, bottom: number?): { Segment }
	local floorY = bottom or baseSize.Y / 2
	local centerX = math.max(0, baseSize.X / 2 - Walls.Inset)
	local centerZ = math.max(0, baseSize.Z / 2 - Walls.Inset)
	local gateX = math.clamp(defense.EntranceWidth, 0, centerX * 2) / 2 + pillarSize / 2
	local segments: { Segment } = {}
	local function add(list: { Segment })
		for _, segment in list do
			table.insert(segments, segment)
		end
	end
	add(span("Back", true, -centerX, centerX, centerZ, floorY, height))
	add(span("Left", false, -centerZ, centerZ, -centerX, floorY, height))
	add(span("Right", false, -centerZ, centerZ, centerX, floorY, height))
	local hasFront = gateX < centerX
	if hasFront then
		add(span("FrontLeft", true, -centerX, -gateX, -centerZ, floorY, height))
		add(span("FrontRight", true, gateX, centerX, -centerZ, floorY, height))
	end
	local pillarHeight = height + pillarOvershoot
	local pillarY = floorY + pillarHeight / 2
	local function pillar(name: string, x: number, z: number)
		table.insert(segments, {
			Name = `Pillar{name}`,
			Kind = Walls.Kinds.Pillar,
			Size = Vector3.new(pillarSize, pillarHeight, pillarSize),
			Center = Vector3.new(x, pillarY, z),
		})
	end
	pillar("BackLeft", -centerX, centerZ)
	pillar("BackRight", centerX, centerZ)
	pillar("FrontLeft", -centerX, -centerZ)
	pillar("FrontRight", centerX, -centerZ)
	if hasFront then
		pillar("GateLeft", -gateX, -centerZ)
		pillar("GateRight", gateX, -centerZ)
	end
	return segments
end

local function fenceRise(info: Types.PlotInfo): number
	local fence = info.Model:FindFirstChild(fenceName)
	if not fence then
		return 0
	end
	local baseTop = info.Base.Size.Y / 2
	local top = baseTop
	local function consider(part: BasePart)
		local relative = info.Base.CFrame:ToObjectSpace(part.CFrame)
		local size = part.Size
		local extent = (
			math.abs(relative.RightVector.Y) * size.X
			+ math.abs(relative.UpVector.Y) * size.Y
			+ math.abs(relative.LookVector.Y) * size.Z
		) / 2
		top = math.max(top, relative.Position.Y + extent)
	end
	if fence:IsA("BasePart") then
		consider(fence)
	end
	for _, descendant in fence:GetDescendants() do
		if descendant:IsA("BasePart") then
			consider(descendant)
		end
	end
	return top - baseTop
end

local function createPart(segment: Segment): Part
	local part = Instance.new("Part")
	part.Name = segment.Name
	part.Anchored = true
	part.CanTouch = false
	if segment.Kind == Walls.Kinds.Glass then
		part.Material = Enum.Material.Glass
		part.Color = glassColor
		part.Transparency = glassTransparency
		part.Reflectance = glassReflectance
		part.CastShadow = false
		part.CanCollide = true
		part.CanQuery = false
	else
		part.Material = Enum.Material.Metal
		part.Color = steelColor
		part.CastShadow = segment.Kind == Walls.Kinds.Pillar
		part.CanCollide = true
		part.CanQuery = false
	end
	return part
end

function Walls.Clear(info: Types.PlotInfo)
	local folder = info.GlassWalls
	info.GlassWalls = nil
	table.clear(info.GlassParts)
	if folder then
		folder:Destroy()
	end
end

function Walls.Build(info: Types.PlotInfo, level: any)
	info.FenceRise = fenceRise(info)
	Walls.Apply(info, level)
end

function Walls.Apply(info: Types.PlotInfo, level: any)
	local clamped = Walls.Level(level)
	local glass = Walls.GlassHeight(clamped)
	local total = info.FenceRise + glass
	if clamped > 0 then
		local folder: Folder = info.GlassWalls or Instance.new("Folder")
		folder.Name = folderName
		info.GlassWalls = folder
		local bottom = info.Base.Size.Y / 2 + info.FenceRise
		for _, segment in Walls.Layout(info.Base.Size, glass, bottom) do
			local existing = info.GlassParts[segment.Name]
			local part: BasePart = existing or createPart(segment)
			if not existing then
				info.GlassParts[segment.Name] = part
			end
			if not existing or part.Size ~= segment.Size then
				part.Size = segment.Size
				part.CFrame = info.Base.CFrame * CFrame.new(segment.Center)
			end
			if part.Parent ~= folder then
				part.Parent = folder
			end
		end
		if folder.Parent ~= info.Model then
			folder.Parent = info.Model
		end
	elseif info.GlassWalls then
		info.GlassWalls.Parent = nil
	end
	info.WallLevel = clamped
	info.WallHeight = total
	if info.Model:GetAttribute("WallHeight") ~= total then
		info.Model:SetAttribute("WallHeight", total)
	end
end

return Walls
