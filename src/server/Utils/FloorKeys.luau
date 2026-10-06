--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FloorGrid = require(ReplicatedStorage.Rules.FloorGrid)
local Parts = require(ReplicatedStorage.Utils.Parts)
local MeshTemplates = require(script.Parent.MeshTemplates)

local FloorKeys = {
	Sink = 0.35,
	Press = 0.75,
	Lighten = 0.45,
}

local capHeight = FloorGrid.CapHeight
local white = Color3.new(1, 1, 1)

function FloorKeys.Color(base: Color3): Color3
	return base:Lerp(white, FloorKeys.Lighten)
end

function FloorKeys.Top(): number
	return capHeight - FloorKeys.Sink - FloorKeys.Press
end

function FloorKeys.Blank(cframe: CFrame, color: Color3): BasePart
	local template = MeshTemplates.Get("Keycap")
	local cap: BasePart = if template then template:Clone() else Instance.new("Part")
	local capSize = FloorGrid.CapSize()
	cap.Anchored = true
	Parts.Passive(cap)
	cap.CastShadow = false
	cap.Size = Vector3.new(capSize, capHeight, capSize)
	cap.CFrame = cframe
	cap.Color = color
	cap.Material = Enum.Material.SmoothPlastic
	cap.Reflectance = 0
	cap.Transparency = 0
	return cap
end

return FloorKeys
