--!strict

local MeshTemplates = require(script.Parent.Parent.Parent.Utils.MeshTemplates)
local Types = require(script.Parent.Types)

local Skin = {}

local function skinOne(old: BasePart, template: MeshPart): BasePart
	if old:IsA("MeshPart") then
		return old
	end
	local key: MeshPart = template:Clone()
	key.Name = old.Name
	key.Anchored = old.Anchored
	key.Size = old.Size
	key.CFrame = old.CFrame
	key.Color = old.Color
	key.Material = old.Material
	key.Transparency = old.Transparency
	for name, value in old:GetAttributes() do
		key:SetAttribute(name, value)
	end
	key.Parent = old.Parent
	old:Destroy()
	return key
end

function Skin.Apply(info: Types.Info): boolean
	local template = MeshTemplates.Get("Keycap")
	if not template then
		return false
	end
	local replaced: { [BasePart]: BasePart } = {}
	local keys: { BasePart } = {}
	for _, part in info.TapKeys do
		local key = skinOne(part, template)
		replaced[part] = key
		table.insert(keys, key)
	end
	local popUps: { BasePart } = {}
	for _, part in info.PopUps do
		table.insert(popUps, replaced[part] or part)
	end
	table.clear(info.TapKeys)
	table.move(keys, 1, #keys, 1, info.TapKeys)
	table.clear(info.PopUps)
	table.move(popUps, 1, #popUps, 1, info.PopUps)
	return true
end

return Skin
