--!strict

local GameConfig = require(script.Parent.Parent.Config.GameConfig)

export type Rect = {
	X: number,
	Z: number,
	HalfX: number,
	HalfZ: number,
}

export type Cell = {
	X: number,
	Z: number,
	Column: number,
	Row: number,
	Index: number,
	Slot: number?,
}

export type Layout = {
	Cells: { Cell },
	Slots: { Cell },
	Columns: number,
	Rows: number,
	MinX: number,
	MinZ: number,
	Lookup: { [number]: Cell },
}

local FloorGrid = {
	CellSize = 4.0,
	CellGap = 0.2,
	EdgeMargin = 1.0,
	RollKeyMargin = 1.0,
}

local epsilon = 1e-6

local function overlapsRect(cx: number, cz: number, half: number, rect: Rect, margin: number): boolean
	return math.abs(cx - rect.X) < half + rect.HalfX + margin - epsilon
		and math.abs(cz - rect.Z) < half + rect.HalfZ + margin - epsilon
end

function FloorGrid.CapSize(): number
	return FloorGrid.CellSize - FloorGrid.CellGap
end

function FloorGrid.Build(baseX: number, baseZ: number, rollKey: Rect?, boardX: number, boardZ: number): Layout
	local size = FloorGrid.CellSize
	local half = size / 2
	local columns = math.max(0, math.floor((baseX - FloorGrid.EdgeMargin * 2) / size + epsilon))
	local rows = math.max(0, math.floor((baseZ - FloorGrid.EdgeMargin * 2) / size + epsilon))
	local minX = -columns * size / 2
	local minZ = -rows * size / 2
	local lookup: { [number]: Cell } = {}
	local cells: { Cell } = {}
	local blocked: { [number]: boolean } = {}
	for row = 0, rows - 1 do
		for column = 0, columns - 1 do
			local index = row * columns + column + 1
			local cx = minX + (column + 0.5) * size
			local cz = minZ + (row + 0.5) * size
			if rollKey and overlapsRect(cx, cz, half, rollKey, FloorGrid.RollKeyMargin) then
				blocked[index] = true
			else
				local cell: Cell = { X = cx, Z = cz, Column = column, Row = row, Index = index, Slot = nil }
				lookup[index] = cell
				table.insert(cells, cell)
			end
		end
	end
	local slotColumns = GameConfig.BoardColumns
	local slotRows = math.ceil(GameConfig.BoardSlots / slotColumns)
	local slots: { Cell } = {}
	local bestRow = -1
	local bestColumn = -1
	local bestDistance = math.huge
	for startRow = 0, rows - slotRows do
		for startColumn = 0, columns - slotColumns do
			local isFree = true
			for row = startRow, startRow + slotRows - 1 do
				for column = startColumn, startColumn + slotColumns - 1 do
					if blocked[row * columns + column + 1] then
						isFree = false
					end
				end
			end
			if isFree then
				local centerX = minX + (startColumn + slotColumns / 2) * size
				local centerZ = minZ + (startRow + slotRows / 2) * size
				local distance = (centerX - boardX) ^ 2 + (centerZ - boardZ) ^ 2
				if distance < bestDistance - epsilon then
					bestDistance = distance
					bestRow = startRow
					bestColumn = startColumn
				end
			end
		end
	end
	if bestRow >= 0 then
		for row = 0, slotRows - 1 do
			for column = 0, slotColumns - 1 do
				local slot = row * slotColumns + column + 1
				if slot <= GameConfig.BoardSlots then
					local cell = lookup[(bestRow + row) * columns + bestColumn + column + 1]
					cell.Slot = slot
					slots[slot] = cell
				end
			end
		end
	end
	return {
		Cells = cells,
		Slots = slots,
		Columns = columns,
		Rows = rows,
		MinX = minX,
		MinZ = minZ,
		Lookup = lookup,
	}
end

function FloorGrid.IndexAt(columns: number, rows: number, x: number, z: number): number?
	local size = FloorGrid.CellSize
	local column = math.floor((x + columns * size / 2) / size)
	local row = math.floor((z + rows * size / 2) / size)
	if column < 0 or row < 0 or column >= columns or row >= rows then
		return nil
	end
	return row * columns + column + 1
end

function FloorGrid.Locate(layout: Layout, x: number, z: number): Cell?
	local index = FloorGrid.IndexAt(layout.Columns, layout.Rows, x, z)
	return if index then layout.Lookup[index] else nil
end

local function localRect(base: CFrame, part: BasePart): Rect
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

function FloorGrid.ForPlot(base: BasePart, rollKey: BasePart, board: BasePart): Layout
	local boardCenter = base.CFrame:ToObjectSpace(board.CFrame).Position
	return FloorGrid.Build(
		base.Size.X,
		base.Size.Z,
		localRect(base.CFrame, rollKey),
		boardCenter.X,
		boardCenter.Z
	)
end

return FloorGrid
