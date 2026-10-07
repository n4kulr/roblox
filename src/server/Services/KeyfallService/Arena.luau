--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local WorldNames = require(ReplicatedStorage.Config.WorldNames)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Parts = require(ReplicatedStorage.Utils.Parts)
local Types = require(script.Parent.Types)

local keyfall = GameConfig.Keyfall
local floorThickness = 2
local rimMargin = 3
local floorColor = Color3.fromRGB(255, 120, 190)
local rimColor = Color3.fromRGB(70, 60, 120)
local sideways = CFrame.Angles(0, 0, math.pi / 2)

local Arena = {}

local function disc(name: string, center: Vector3, topY: number, radius: number, color: Color3): Part
	return Parts.New({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(floorThickness, radius * 2, radius * 2),
		CFrame = CFrame.new(center.X, topY - floorThickness / 2, center.Z) * sideways,
		Anchored = true,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
	})
end

local function build(): Types.Arena
	local trove = Trove.new()
	local center = keyfall.ArenaCenter
	local folder = Instance.new("Folder")
	folder.Name = WorldNames.Folders.KeyfallArena
	local rim = disc("Rim", center, center.Y - 0.2, keyfall.ArenaRadius + rimMargin, rimColor)
	rim.Parent = folder
	local floor = disc("Floor", center, center.Y, keyfall.ArenaRadius, floorColor)
	floor.Parent = folder
	folder.Parent = workspace
	trove:Add(folder)
	return { Center = center, Radius = keyfall.ArenaRadius, SurfaceY = center.Y, Trove = trove }
end

local function fromFloor(floor: BasePart): Types.Arena
	local position = floor.CFrame.Position
	local size = floor.Size
	local extents = { size.X, size.Y, size.Z }
	table.sort(extents, function(a: number, b: number)
		return a > b
	end)
	local surfaceY = position.Y + extents[3] / 2
	return {
		Center = Vector3.new(position.X, surfaceY, position.Z),
		Radius = extents[2] / 2,
		SurfaceY = surfaceY,
		Trove = Trove.new(),
	}
end

function Arena.Resolve(): Types.Arena
	local authored = workspace:FindFirstChild(WorldNames.Folders.Arena)
	local floor = if authored then authored:FindFirstChild(WorldNames.Parts.Floor) else nil
	if floor and floor:IsA("BasePart") then
		return fromFloor(floor)
	end
	return build()
end

return Arena
