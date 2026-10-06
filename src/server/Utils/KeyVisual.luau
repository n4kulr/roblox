--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Keys = require(ReplicatedStorage.Config.Keys)
local KeyModels = require(ReplicatedStorage.Utils.KeyModels)
local MeshTemplates = require(script.Parent.MeshTemplates)

local KeyVisual = {}

local carriedScale = 0.6

function KeyVisual.NewCap(keyId: string, name: string, size: Vector3): BasePart?
	local key = Keys.ById[keyId]
	if not key then
		return nil
	end
	local rarity = Keys.GetRarity(key)
	local template = MeshTemplates.Get("Keycap")
	local part: BasePart = if template then template:Clone() else Instance.new("Part")
	part.Name = name
	part.Anchored = false
	part.Size = size
	part.Color = rarity.Color
	Keys.ApplyFinish(part, rarity)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	return part
end

function KeyVisual.Attach(character: Model, root: BasePart, keyId: string, name: string): Model?
	if not Keys.ById[keyId] then
		return nil
	end
	local model = KeyModels.BuildScaled(keyId, carriedScale)
	model.Name = name
	local primary = model.PrimaryPart
	if not primary then
		model:Destroy()
		return nil
	end
	model:PivotTo(root.CFrame * CFrame.new(0, 4.5, 0))
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.Massless = true
			if descendant ~= primary then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = primary
				weld.Part1 = descendant
				weld.Parent = descendant
			end
		end
	end
	local anchorWeld = Instance.new("WeldConstraint")
	anchorWeld.Part0 = root
	anchorWeld.Part1 = primary
	anchorWeld.Parent = primary
	model.Parent = character
	return model
end

return KeyVisual
