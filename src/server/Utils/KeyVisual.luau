--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Keys = require(ReplicatedStorage.Config.Keys)
local MeshTemplates = require(script.Parent.MeshTemplates)

local KeyVisual = {}

function KeyVisual.NewCap(keyId: string, name: string, size: Vector3): BasePart?
	if not Keys.Resolve(keyId) then
		return nil
	end
	local template = MeshTemplates.Get("Keycap")
	local part: BasePart = if template then template:Clone() else Instance.new("Part")
	part.Name = name
	part.Anchored = false
	part.Size = size
	Keys.ApplyVariantFinish(part, keyId)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	return part
end

function KeyVisual.Attach(character: Model, root: BasePart, keyId: string, name: string): BasePart?
	local part = KeyVisual.NewCap(keyId, name, Vector3.new(2.4, 1.2, 2.4))
	if not part then
		return nil
	end
	part.CFrame = root.CFrame * CFrame.new(0, 4.5, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = character
	return part
end

return KeyVisual
