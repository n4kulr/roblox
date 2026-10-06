--!strict

local Character = require(script.Parent.Parent.Parent.Utils.Character)

local Intruders = {}

local cellSize = 32
local keyStride = 4096

export type Entry = { Player: Player, Root: BasePart }
export type Index = { [number]: { Entry } }

local function cellKey(cellX: number, cellZ: number): number
	return cellX * keyStride + cellZ
end

function Intruders.Build(players: { Player }): Index
	local index: Index = {}
	for _, player in players do
		local root = Character.RootOf(player)
		if root then
			local position = root.CFrame.Position
			local key = cellKey(math.floor(position.X / cellSize), math.floor(position.Z / cellSize))
			local bucket = index[key]
			if not bucket then
				bucket = {}
				index[key] = bucket
			end
			table.insert(bucket, { Player = player, Root = root })
		end
	end
	return index
end

function Intruders.Near(index: Index, center: Vector3, reach: number): { Entry }
	local found: { Entry } = {}
	for cellX = math.floor((center.X - reach) / cellSize), math.floor((center.X + reach) / cellSize) do
		for cellZ = math.floor((center.Z - reach) / cellSize), math.floor((center.Z + reach) / cellSize) do
			local bucket = index[cellKey(cellX, cellZ)]
			if bucket then
				table.move(bucket, 1, #bucket, #found + 1, found)
			end
		end
	end
	return found
end

return Intruders
