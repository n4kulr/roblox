--!strict

local EdgeIndicator = {}

function EdgeIndicator.Place(
	point: Vector2,
	isBehind: boolean,
	viewport: Vector2,
	margin: number
): (Vector2, number)
	local center = viewport / 2
	local offset = point - center
	if isBehind then
		offset = -offset
	end
	if offset.Magnitude < 1e-6 then
		offset = Vector2.new(0, 1)
	end
	local limitX = math.max(center.X - margin, 0)
	local limitY = math.max(center.Y - margin, 0)
	local scaleX = if offset.X == 0 then math.huge else limitX / math.abs(offset.X)
	local scaleY = if offset.Y == 0 then math.huge else limitY / math.abs(offset.Y)
	local position = center + offset * math.min(scaleX, scaleY)
	return position, math.deg(math.atan2(offset.Y, offset.X))
end

return table.freeze(EdgeIndicator)
