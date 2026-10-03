--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Upgrades = require(ReplicatedStorage.Config.Upgrades)
local Types = require(script.Parent.Types)

export type Segment = {
	Name: string,
	Size: Vector3,
	Center: Vector3,
}

local defense = GameConfig.Defense
local wallInk = Color3.fromRGB(26, 28, 36)
local wallMix = 0.5
local fenceInset = 0.2
local folderName = "Walls"
local fenceName = "Fence"

local Walls = {}

function Walls.Level(value: any): number
	if type(value) ~= "number" or value ~= value then
		return 0
	end
	return math.clamp(math.floor(value), 0, Upgrades.ById.Walls.MaxLevel)
end

function Walls.Height(level: any): number
	return defense.WallBaseHeight + Walls.Level(level) * Upgrades.ById.Walls.PerLevel
end

function Walls.Layout(baseSize: Vector3, height: number, inset: number?): { Segment }
	local gap = math.clamp(inset or 0, 0, defense.WallThickness / 2)
	local thickness = defense.WallThickness - gap
	local halfX, halfZ = baseSize.X / 2 - gap, baseSize.Z / 2 - gap
	local entrance = math.clamp(defense.EntranceWidth, 0, math.max(0, halfX * 2 - thickness * 2))
	local centerY = baseSize.Y / 2 + height / 2
	local frontZ = -halfZ + thickness / 2
	local segments: { Segment } = {
		{
			Name = "Back",
			Size = Vector3.new(halfX * 2 - thickness * 2, height, thickness),
			Center = Vector3.new(0, centerY, halfZ - thickness / 2),
		},
		{
			Name = "Left",
			Size = Vector3.new(thickness, height, halfZ * 2),
			Center = Vector3.new(-halfX + thickness / 2, centerY, 0),
		},
		{
			Name = "Right",
			Size = Vector3.new(thickness, height, halfZ * 2),
			Center = Vector3.new(halfX - thickness / 2, centerY, 0),
		},
	}
	local run = halfX - thickness - entrance / 2
	if run > 0 then
		table.insert(segments, {
			Name = "FrontLeft",
			Size = Vector3.new(run, height, thickness),
			Center = Vector3.new(-(entrance / 2 + run / 2), centerY, frontZ),
		})
		table.insert(segments, {
			Name = "FrontRight",
			Size = Vector3.new(run, height, thickness),
			Center = Vector3.new(entrance / 2 + run / 2, centerY, frontZ),
		})
	end
	return segments
end

function Walls.Clear(info: Types.PlotInfo)
	local folder = info.Walls
	local isAuthored = info.WallsAuthored
	info.Walls = nil
	info.WallsAuthored = false
	table.clear(info.WallParts)
	if folder and not isAuthored then
		folder:Destroy()
	end
end

local function authoredFolder(model: Model): Folder?
	local child = model:FindFirstChild(folderName)
	if not child or not child:IsA("Folder") then
		return nil
	end
	for _, part in child:GetChildren() do
		if part:IsA("BasePart") then
			return child
		end
	end
	return nil
end

local function createParts(info: Types.PlotInfo)
	local folder = Instance.new("Folder")
	folder.Name = folderName
	local inset = if info.Model:FindFirstChild(fenceName) then fenceInset else 0
	local color = info.Base.Color:Lerp(wallInk, wallMix)
	for _, segment in Walls.Layout(info.Base.Size, Walls.Height(0), inset) do
		local part = Instance.new("Part")
		part.Name = segment.Name
		part.Anchored = true
		part.CanCollide = true
		part.CanTouch = false
		part.CanQuery = false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.Color = color
		part.Size = segment.Size
		part.CFrame = info.Base.CFrame * CFrame.new(segment.Center)
		part.Parent = folder
		info.WallParts[segment.Name] = part
	end
	folder.Parent = info.Model
	info.Walls = folder
	info.WallsAuthored = false
end

local function adoptParts(info: Types.PlotInfo, folder: Folder)
	for _, part in folder:GetChildren() do
		if part:IsA("BasePart") then
			info.WallParts[part.Name] = part
		end
	end
	info.Walls = folder
	info.WallsAuthored = true
end

local function setHeight(info: Types.PlotInfo, part: BasePart, height: number)
	local size = part.Size
	local relative = info.Base.CFrame:ToObjectSpace(part.CFrame)
	local centerY = info.Base.Size.Y / 2 + height / 2
	if size.Y == height and math.abs(relative.Position.Y - centerY) < 1e-4 then
		return
	end
	local rotation = CFrame.new(-relative.Position) * relative
	part.Size = Vector3.new(size.X, height, size.Z)
	part.CFrame = info.Base.CFrame * CFrame.new(relative.Position.X, centerY, relative.Position.Z) * rotation
end

function Walls.Build(info: Types.PlotInfo, level: any)
	if not info.Walls then
		local authored = authoredFolder(info.Model)
		if authored then
			adoptParts(info, authored)
		else
			createParts(info)
		end
	end
	Walls.Apply(info, level)
end

function Walls.Apply(info: Types.PlotInfo, level: any)
	local clamped = Walls.Level(level)
	local height = Walls.Height(clamped)
	if info.WallsAuthored then
		for _, part in info.WallParts do
			setHeight(info, part, height)
		end
	else
		local inset = if info.Model:FindFirstChild(fenceName) then fenceInset else 0
		for _, segment in Walls.Layout(info.Base.Size, height, inset) do
			local part = info.WallParts[segment.Name]
			if part and part.Size.Y ~= height then
				part.Size = segment.Size
				part.CFrame = info.Base.CFrame * CFrame.new(segment.Center)
			end
		end
	end
	info.WallLevel = clamped
	if info.Model:GetAttribute("WallHeight") ~= height then
		info.Model:SetAttribute("WallHeight", height)
	end
end

return Walls
