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

function Walls.Layout(baseSize: Vector3, height: number): { Segment }
	local sizeX, sizeZ = baseSize.X, baseSize.Z
	local thickness = defense.WallThickness
	local entrance = math.clamp(defense.EntranceWidth, 0, math.max(0, sizeX - thickness * 2))
	local centerY = baseSize.Y / 2 + height / 2
	local frontZ = -sizeZ / 2 + thickness / 2
	local segments: { Segment } = {
		{
			Name = "Back",
			Size = Vector3.new(sizeX - thickness * 2, height, thickness),
			Center = Vector3.new(0, centerY, sizeZ / 2 - thickness / 2),
		},
		{
			Name = "Left",
			Size = Vector3.new(thickness, height, sizeZ),
			Center = Vector3.new(-sizeX / 2 + thickness / 2, centerY, 0),
		},
		{
			Name = "Right",
			Size = Vector3.new(thickness, height, sizeZ),
			Center = Vector3.new(sizeX / 2 - thickness / 2, centerY, 0),
		},
	}
	local run = sizeX / 2 - thickness - entrance / 2
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
	info.Walls = nil
	if folder then
		folder:Destroy()
	end
end

function Walls.Build(info: Types.PlotInfo, level: any)
	Walls.Clear(info)
	local clamped = Walls.Level(level)
	local height = Walls.Height(clamped)
	local folder = Instance.new("Folder")
	folder.Name = "Walls"
	local color = info.Base.Color:Lerp(wallInk, wallMix)
	for _, segment in Walls.Layout(info.Base.Size, height) do
		local part = Instance.new("Part")
		part.Name = segment.Name
		part.Anchored = true
		part.CanCollide = true
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.SmoothPlastic
		part.Color = color
		part.Size = segment.Size
		part.CFrame = info.Base.CFrame * CFrame.new(segment.Center)
		part.Parent = folder
	end
	info.WallLevel = clamped
	info.Model:SetAttribute("WallHeight", height)
	folder.Parent = info.Model
	info.Walls = folder
end

return Walls
