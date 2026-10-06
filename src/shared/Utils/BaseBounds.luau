--!strict

local BaseBounds = {
	HeightAbove = 40,
	DepthBelow = 6,
}

function BaseBounds.Contains(
	baseCFrame: CFrame,
	baseSize: Vector3,
	position: Vector3,
	margin: number
): boolean
	local offset = baseCFrame:PointToObjectSpace(position)
	return math.abs(offset.X) <= baseSize.X / 2 + margin
		and math.abs(offset.Z) <= baseSize.Z / 2 + margin
		and offset.Y <= baseSize.Y / 2 + BaseBounds.HeightAbove
		and offset.Y >= -baseSize.Y / 2 - BaseBounds.DepthBelow
end

return BaseBounds
