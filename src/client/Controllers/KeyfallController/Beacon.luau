--!strict

local beamHeight = 220
local beamWidth = 4
local beamColor = Color3.fromRGB(255, 214, 64)

local Beacon = {}

function Beacon.Create(): Part
	local part = Instance.new("Part")
	part.Name = "GoldenSpacebarBeacon"
	part.Size = Vector3.new(beamWidth, beamHeight, beamWidth)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Neon
	part.Color = beamColor
	part.Transparency = 0.6
	part.Parent = workspace
	return part
end

function Beacon.Place(part: Part, target: Vector3)
	part.CFrame = CFrame.new(target.X, target.Y + beamHeight / 2, target.Z)
end

return Beacon
