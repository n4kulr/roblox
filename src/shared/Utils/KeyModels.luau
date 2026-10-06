--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Keys = require(ReplicatedStorage.Config.Keys)

local KeyModels = {}

local outline = Color3.fromRGB(26, 21, 48)

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Anchored = true
	piece.CanCollide = false
	piece.CanQuery = false
	piece.CanTouch = false
	piece.CastShadow = false
	piece.Size = size
	piece.CFrame = cframe
	piece.Color = color
	piece.Material = Enum.Material.SmoothPlastic
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Parent = parent
	return piece
end

function KeyModels.Build(keyId: string): Model
	local model = Instance.new("Model")
	model.Name = keyId
	local key = Keys.ById[keyId]
	local rarity = if key then Keys.GetRarity(key) else nil
	local color = if rarity then rarity.Color else Color3.fromRGB(200, 200, 205)
	local skirt =
		part(model, "Skirt", Vector3.new(4, 1.4, 4), CFrame.new(0, 0.7, 0), color:Lerp(outline, 0.35))
	local top = part(model, "Top", Vector3.new(3.2, 0.6, 3.2), CFrame.new(0, 1.7, 0), color)
	if rarity then
		Keys.ApplyFinish(top, rarity)
	end
	model.PrimaryPart = skirt
	return model
end

return KeyModels
