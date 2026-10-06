--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharmConfig = require(ReplicatedStorage.Config.Charms)

export type Orbit = {
	Ids: string,
	Models: { Model },
}

local radius = 3.2
local spinSpeed = 1.6
local bobSpeed = 2.2
local bobHeight = 0.35
local baseHeight = 1.4
local plateSize = Vector3.new(0.8, 1, 0.16)
local ringSize = Vector3.new(0.12, 0.5, 0.5)

local Orbit = {}

local function newPart(parent: Instance, name: string, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

function Orbit.Parse(text: any): { string }
	local ids: { string } = {}
	if type(text) ~= "string" or text == "" then
		return ids
	end
	for id in string.gmatch(text, "[^,]+") do
		if CharmConfig.ById[id] and #ids < CharmConfig.EquipLimit then
			table.insert(ids, id)
		end
	end
	return ids
end

function Orbit.BuildCharm(parent: Instance, charmId: string): Model?
	local charm = CharmConfig.ById[charmId]
	if not charm then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = `Charm_{charmId}`
	local plate = newPart(model, "Plate", plateSize, charm.Color)
	plate.Material = Enum.Material.Neon
	local ring = newPart(model, "Ring", ringSize, Color3.fromRGB(220, 224, 235))
	ring.Shape = Enum.PartType.Cylinder
	model.PrimaryPart = plate
	model.Parent = parent
	return model
end

function Orbit.Place(model: Model, root: CFrame, index: number, count: number, now: number)
	local angle = now * spinSpeed + (index - 1) * math.pi * 2 / math.max(count, 1)
	local offset = Vector3.new(
		math.cos(angle) * radius,
		baseHeight + math.sin(now * bobSpeed + index) * bobHeight,
		math.sin(angle) * radius
	)
	local plate = model.PrimaryPart
	local ring = model:FindFirstChild("Ring")
	if not plate or not ring or not ring:IsA("BasePart") then
		return
	end
	local frame = CFrame.new(root.Position + offset) * CFrame.Angles(0, now * 3 + index, 0)
	plate.CFrame = frame
	ring.CFrame = frame * CFrame.new(0, plateSize.Y / 2 + 0.2, 0) * CFrame.Angles(0, 0, math.rad(90))
end

return Orbit
