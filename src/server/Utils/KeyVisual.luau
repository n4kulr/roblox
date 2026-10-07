--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Keys = require(ReplicatedStorage.Config.Keys)
local KeyModels = require(ReplicatedStorage.Utils.KeyModels)
local MeshParts = require(ReplicatedStorage.Utils.MeshParts)
local Parts = require(ReplicatedStorage.Utils.Parts)
local MeshTemplates = require(script.Parent.MeshTemplates)

local KeyVisual = {}

local carriedScale = 0.6

function KeyVisual.NewCap(keyId: string, name: string, size: Vector3): BasePart?
	if not Keys.Resolve(keyId) then
		return nil
	end
	local meshId = KeyModels.MeshIdOf(keyId)
	local part: BasePart
	local cloned = if meshId then MeshParts.Clone(meshId, name) else nil
	if cloned then
		part = cloned
	else
		local template = MeshTemplates.Get("Keycap")
		if template then
			part = template:Clone()
		else
			part = Instance.new("Part")
		end
		part.Name = name
	end
	part.Anchored = false
	part.Size = size
	Keys.ApplyVariantFinish(part, keyId)
	Parts.Passive(part)
	part.Massless = true
	return part
end

function KeyVisual.Attach(character: Model, root: BasePart, keyId: string, name: string): Model?
	if not Keys.Resolve(keyId) then
		return nil
	end
	local model: Model
	local meshId = KeyModels.MeshIdOf(keyId)
	if meshId then
		local template = MeshParts.Template(meshId)
		local built = if template then KeyModels.BuildMesh(keyId, template, carriedScale, true) else nil
		model = built or KeyModels.BuildScaled(keyId, carriedScale)
	else
		model = KeyModels.BuildScaled(keyId, carriedScale)
	end
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
