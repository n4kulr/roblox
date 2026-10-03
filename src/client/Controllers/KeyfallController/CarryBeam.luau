--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)

type TroveInstance = typeof(Trove.new())

local beamColor = Color3.fromRGB(255, 214, 64)

local CarryBeam = {}

function CarryBeam.Start(root: BasePart, base: BasePart): TroveInstance
	local trove = Trove.new()
	local from = Instance.new("Attachment")
	from.Name = "KeyfallBeamStart"
	from.Parent = root
	trove:Add(from)
	local to = Instance.new("Attachment")
	to.Name = "KeyfallBeamEnd"
	to.Parent = base
	trove:Add(to)
	local beam = Instance.new("Beam")
	beam.Name = "KeyfallBeam"
	beam.Attachment0 = from
	beam.Attachment1 = to
	beam.Color = ColorSequence.new(beamColor)
	beam.Width0 = 1.2
	beam.Width1 = 1.2
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Segments = 1
	beam.Parent = root
	trove:Add(beam)
	return trove
end

return CarryBeam
