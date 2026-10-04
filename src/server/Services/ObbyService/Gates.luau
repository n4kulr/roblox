--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)

local config = GameConfig.Obby.Gate

local Gates = {}

export type Result = {
	Gate: BasePart,
	Required: number,
	Passed: boolean,
	Destination: CFrame?,
}

function Gates.Required(gate: BasePart): number
	local required = gate:GetAttribute("RequiredSpeed")
	return if type(required) == "number" then required else config.RequiredSpeed
end

function Gates.Check(gates: { BasePart }, root: CFrame, speed: number): Result?
	for _, gate in gates do
		local size = gate.Size
		local offset = gate.CFrame:PointToObjectSpace(root.Position)
		local depth = size.Z / 2
		if
			offset.Z > 0
			and offset.Z <= depth + config.Reach
			and math.abs(offset.X) <= size.X / 2
			and math.abs(offset.Y) <= size.Y / 2
		then
			local required = Gates.Required(gate)
			local passed = speed >= required
			local destination = nil
			if passed then
				local world = gate.CFrame:PointToWorldSpace(Vector3.new(offset.X, offset.Y, -(depth + 3)))
				destination = CFrame.new(world) * (root - root.Position)
			end
			return { Gate = gate, Required = required, Passed = passed, Destination = destination }
		end
	end
	return nil
end

return Gates
