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
local epsilon = 1e-3
local squareRatio = 1.5
local fenceBlend = 0.5
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

function Walls.Layout(baseSize: Vector3, height: number, bottom: number?, frame: Types.Frame?): { Segment }
	local floorY = bottom or baseSize.Y / 2
	local left: number
	local right: number
	local front: number
	local back: number
	local gateLeft: number
	local gateRight: number
	if frame then
		left, right, front, back = frame.Left, frame.Right, frame.Front, frame.Back
		gateLeft, gateRight = frame.GateLeft, frame.GateRight
	else
		local centerX = math.max(0, baseSize.X / 2 - Walls.Inset)
		local centerZ = math.max(0, baseSize.Z / 2 - Walls.Inset)
		local gateX = math.clamp(defense.EntranceWidth, 0, centerX * 2) / 2 + pillarSize / 2
		left, right, front, back = -centerX, centerX, -centerZ, centerZ
		gateLeft, gateRight = -gateX, gateX
	end
	local segments: { Segment } = {}
	local function add(list: { Segment })
		for _, segment in list do
			table.insert(segments, segment)
		end
	end
	add(span("Back", true, left, right, back, floorY, height))
	add(span("Left", false, front, back, left, floorY, height))
	add(span("Right", false, front, back, right, floorY, height))
	local hasLeftFront = gateLeft - left > epsilon
	local hasRightFront = right - gateRight > epsilon
	if hasLeftFront then
		add(span("FrontLeft", true, left, gateLeft, front, floorY, height))
	end
	if hasRightFront then
		add(span("FrontRight", true, gateRight, right, front, floorY, height))
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
	pillar("BackLeft", left, back)
	pillar("BackRight", right, back)
	pillar("FrontLeft", left, front)
	pillar("FrontRight", right, front)
	if hasLeftFront then
		pillar("GateLeft", gateLeft, front)
	end
	if hasRightFront then
		pillar("GateRight", gateRight, front)
	end
	return segments
end

local function collectFenceParts(fence: Instance): { BasePart }
	local parts: { BasePart } = {}
	if fence:IsA("BasePart") then
		table.insert(parts, fence)
	end
	for _, descendant in fence:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

type Footprint = { MinX: number, MaxX: number, MinZ: number, MaxZ: number }

local function footprint(base: BasePart, part: BasePart): Footprint
	local relative = base.CFrame:ToObjectSpace(part.CFrame)
	local half = part.Size / 2
	local result: Footprint = { MinX = math.huge, MaxX = -math.huge, MinZ = math.huge, MaxZ = -math.huge }
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local corner = relative * Vector3.new(sx * half.X, sy * half.Y, sz * half.Z)
				result.MinX = math.min(result.MinX, corner.X)
				result.MaxX = math.max(result.MaxX, corner.X)
				result.MinZ = math.min(result.MinZ, corner.Z)
				result.MaxZ = math.max(result.MaxZ, corner.Z)
			end
		end
	end
	return result
end

local function median(values: { number }): number
	table.sort(values)
	local count = #values
	if count % 2 == 1 then
		return values[(count + 1) / 2]
	end
	return (values[count / 2] + values[count / 2 + 1]) / 2
end

local function largestGap(
	footprints: { Footprint },
	minX: number,
	maxX: number,
	frontLimit: number
): { number }?
	local intervals: { { number } } = {}
	for _, item in footprints do
		if item.MinZ <= frontLimit then
			table.insert(intervals, { item.MinX, item.MaxX })
		end
	end
	table.sort(intervals, function(a: { number }, b: { number })
		return a[1] < b[1]
	end)
	local bestFrom: number? = nil
	local bestTo = 0
	local cursor = minX
	local function consider(from: number, to: number)
		local width = to - from
		if width >= pillarSize and (not bestFrom or width > bestTo - bestFrom + epsilon) then
			bestFrom = from
			bestTo = to
		end
	end
	for _, interval in intervals do
		if interval[1] > cursor then
			consider(cursor, interval[1])
		end
		cursor = math.max(cursor, interval[2])
	end
	if maxX > cursor then
		consider(cursor, maxX)
	end
	if bestFrom then
		return { bestFrom, bestTo }
	end
	return nil
end

function Walls.Measure(info: Types.PlotInfo): Types.Frame?
	local fence = info.Model:FindFirstChild(fenceName)
	if not fence then
		return nil
	end
	local footprints: { Footprint } = {}
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	for _, part in collectFenceParts(fence) do
		local item = footprint(info.Base, part)
		table.insert(footprints, item)
		minX = math.min(minX, item.MinX)
		maxX = math.max(maxX, item.MaxX)
		minZ = math.min(minZ, item.MinZ)
		maxZ = math.max(maxZ, item.MaxZ)
	end
	if #footprints == 0 then
		return nil
	end
	local thicknesses: { number } = {}
	for _, item in footprints do
		local width = item.MaxX - item.MinX
		local depth = item.MaxZ - item.MinZ
		local thin = math.min(width, depth)
		local long = math.max(width, depth)
		if thin > epsilon and long >= thin * squareRatio then
			table.insert(thicknesses, thin)
		end
	end
	local thickness = if #thicknesses > 0 then median(thicknesses) else 1
	local insetX = math.max(0, info.Base.Size.X / 2 - Walls.Inset)
	local insetZ = math.max(0, info.Base.Size.Z / 2 - Walls.Inset)
	local function blend(measured: number, inset: number): number
		return inset + (measured - inset) * fenceBlend
	end
	local left = blend(minX + thickness / 2, -insetX)
	local right = blend(maxX - thickness / 2, insetX)
	local front = blend(minZ + thickness / 2, -insetZ)
	local back = blend(maxZ - thickness / 2, insetZ)
	if right - left < pillarSize or back - front < pillarSize then
		return nil
	end
	local gap = largestGap(footprints, minX, maxX, minZ + thickness + epsilon)
	local gapFrom: number
	local gapTo: number
	if gap then
		gapFrom, gapTo = gap[1], gap[2]
	else
		local middle = (left + right) / 2
		local half = math.clamp(defense.EntranceWidth, 0, right - left) / 2
		gapFrom, gapTo = middle - half, middle + half
	end
	return {
		Left = left,
		Right = right,
		Front = front,
		Back = back,
		GateLeft = math.clamp(gapFrom, left, right),
		GateRight = math.clamp(gapTo, left, right),
	}
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
	info.Frame = Walls.Measure(info)
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
		for _, segment in Walls.Layout(info.Base.Size, glass, bottom, info.Frame) do
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
