--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Eggs = require(ReplicatedStorage.Config.Eggs)

export type Rect = {
	X: number,
	Z: number,
	HalfX: number,
	HalfZ: number,
}

export type Spot = {
	X: number,
	Z: number,
}

export type Reason = "Ok" | "Invalid" | "Bounds" | "RollKey" | "Spacing"

local searchStep = 3

local EggPlacement = {}

local function isFinite(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) ~= math.huge
end

function EggPlacement.RectOf(base: CFrame, part: BasePart): Rect
	local relative = base:ToObjectSpace(part.CFrame)
	local size = part.Size
	local right, up, look = relative.RightVector, relative.UpVector, relative.LookVector
	return {
		X = relative.Position.X,
		Z = relative.Position.Z,
		HalfX = (math.abs(right.X) * size.X + math.abs(up.X) * size.Y + math.abs(look.X) * size.Z) / 2,
		HalfZ = (math.abs(right.Z) * size.X + math.abs(up.Z) * size.Y + math.abs(look.Z) * size.Z) / 2,
	}
end

function EggPlacement.Check(baseSize: Vector3, rollKey: Rect?, placed: { Spot }, x: any, z: any): Reason
	if not isFinite(x) or not isFinite(z) then
		return "Invalid"
	end
	local limitX = baseSize.X / 2 - Eggs.PlaceInset
	local limitZ = baseSize.Z / 2 - Eggs.PlaceInset
	if math.abs(x) > limitX or math.abs(z) > limitZ then
		return "Bounds"
	end
	if
		rollKey
		and math.abs(x - rollKey.X) < rollKey.HalfX + Eggs.RollKeyClear
		and math.abs(z - rollKey.Z) < rollKey.HalfZ + Eggs.RollKeyClear
	then
		return "RollKey"
	end
	for _, other in placed do
		local dx, dz = x - other.X, z - other.Z
		if dx * dx + dz * dz < Eggs.PlaceSpacing * Eggs.PlaceSpacing then
			return "Spacing"
		end
	end
	return "Ok"
end

function EggPlacement.FindSpot(baseSize: Vector3, rollKey: Rect?, placed: { Spot }): Spot?
	local limitX = baseSize.X / 2 - Eggs.PlaceInset
	local limitZ = baseSize.Z / 2 - Eggs.PlaceInset
	local candidates: { Spot } = {}
	local steps = math.floor(limitX / searchStep)
	local rows = math.floor(limitZ / searchStep)
	for column = -steps, steps do
		for row = -rows, rows do
			table.insert(candidates, { X = column * searchStep, Z = row * searchStep })
		end
	end
	table.sort(candidates, function(a: Spot, b: Spot)
		local da = a.X * a.X + a.Z * a.Z
		local db = b.X * b.X + b.Z * b.Z
		if da ~= db then
			return da < db
		end
		if a.X ~= b.X then
			return a.X < b.X
		end
		return a.Z < b.Z
	end)
	for _, spot in candidates do
		if EggPlacement.Check(baseSize, rollKey, placed, spot.X, spot.Z) == "Ok" then
			return spot
		end
	end
	return nil
end

return table.freeze(EggPlacement)
