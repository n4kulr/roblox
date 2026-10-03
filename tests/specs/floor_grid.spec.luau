local H = require("../harness/Harness")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

describe("FloorGrid", function()
	local FloorGrid, GameConfig

	beforeEach(function()
		local world = H.newWorld()
		FloorGrid = world:require("ReplicatedStorage.Rules.FloorGrid")
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
	end)

	local rollKey = { X = 0, Z = -10, HalfX = 4, HalfZ = 4 }

	local function overlaps(cell: any, rect: any): boolean
		local half = FloorGrid.CellSize / 2
		return math.abs(cell.X - rect.X) < half + rect.HalfX + FloorGrid.RollKeyMargin - 1e-6
			and math.abs(cell.Z - rect.Z) < half + rect.HalfZ + FloorGrid.RollKeyMargin - 1e-6
	end

	it("tiles a 44x44 base around the roll key", function()
		local layout = FloorGrid.Build(44, 44, rollKey, 0, 12)
		expect(layout.Columns):toBe(10)
		expect(layout.Rows):toBe(10)
		expect(#layout.Cells):toBe(88)
	end)

	it("keeps every cell inside the base and clear of the roll key", function()
		local layout = FloorGrid.Build(44, 44, rollKey, 0, 12)
		local half = FloorGrid.CellSize / 2
		for _, cell in layout.Cells do
			expect(math.abs(cell.X) + half <= 22 - FloorGrid.EdgeMargin + 1e-6):toBe(true)
			expect(math.abs(cell.Z) + half <= 22 - FloorGrid.EdgeMargin + 1e-6):toBe(true)
			expect(overlaps(cell, rollKey)):toBe(false)
		end
	end)

	it("fills the whole base when there is no roll key", function()
		local layout = FloorGrid.Build(44, 44, nil, 0, 0)
		expect(#layout.Cells):toBe(100)
	end)

	it("places exactly BoardSlots slot cells in row-major order clear of the roll key", function()
		local layout = FloorGrid.Build(44, 44, rollKey, 0, 12)
		expect(GameConfig.BoardSlots):toBe(60)
		expect(#layout.Slots):toBe(GameConfig.BoardSlots)
		local previous = nil
		for slot = 1, GameConfig.BoardSlots do
			local cell = layout.Slots[slot]
			expect(cell.Slot):toBe(slot)
			expect(layout.Lookup[cell.Index] == cell):toBe(true)
			expect(overlaps(cell, rollKey)):toBe(false)
			if previous then
				expect(cell.Index > previous.Index):toBe(true)
			end
			previous = cell
		end
		local marked = 0
		for _, cell in layout.Cells do
			if cell.Slot then
				marked += 1
			end
		end
		expect(marked):toBe(GameConfig.BoardSlots)
	end)

	it("picks the cells nearest the board center", function()
		local layout = FloorGrid.Build(44, 44, rollKey, 0, 12)
		local function distance(cell: any): number
			return (cell.X - 0) ^ 2 + (cell.Z - 12) ^ 2
		end
		local farthestSlot = 0
		for _, cell in layout.Slots do
			farthestSlot = math.max(farthestSlot, distance(cell))
		end
		for _, cell in layout.Cells do
			if not cell.Slot then
				expect(distance(cell) >= farthestSlot - 1e-6):toBe(true)
			end
		end
	end)

	it("fits 60 slots on a 44x44 base without a roll key", function()
		local layout = FloorGrid.Build(44, 44, nil, 0, 0)
		expect(#layout.Slots):toBe(GameConfig.BoardSlots)
	end)

	it("is deterministic", function()
		local a = FloorGrid.Build(44, 44, rollKey, 0, 12)
		local b = FloorGrid.Build(44, 44, rollKey, 0, 12)
		expect(#a.Cells):toBe(#b.Cells)
		for index, cell in a.Cells do
			expect(cell.X):toBe(b.Cells[index].X)
			expect(cell.Z):toBe(b.Cells[index].Z)
			expect(cell.Slot):toBe(b.Cells[index].Slot)
		end
	end)

	it("keeps slots off the roll key when the board center is near it", function()
		local layout = FloorGrid.Build(44, 44, rollKey, 0, -10)
		expect(#layout.Slots):toBe(GameConfig.BoardSlots)
		for _, cell in layout.Slots do
			expect(overlaps(cell, rollKey)):toBe(false)
		end
	end)

	it("keeps slots inside the base when the board center is past the edge", function()
		local layout = FloorGrid.Build(44, 44, rollKey, 60, 60)
		expect(#layout.Slots):toBe(GameConfig.BoardSlots)
		local half = FloorGrid.CellSize / 2
		for _, cell in layout.Slots do
			expect(math.abs(cell.X) + half <= 22 - FloorGrid.EdgeMargin + 1e-6):toBe(true)
			expect(math.abs(cell.Z) + half <= 22 - FloorGrid.EdgeMargin + 1e-6):toBe(true)
		end
		local last = layout.Slots[GameConfig.BoardSlots]
		expect(last.Column):toBe(layout.Columns - 1)
	end)

	it("uses every free cell when the base has fewer cells than BoardSlots", function()
		local layout = FloorGrid.Build(20, 20, nil, 0, 0)
		expect(#layout.Cells):toBe(16)
		expect(#layout.Slots):toBe(16)
		expect(#layout.Slots < GameConfig.BoardSlots):toBe(true)
	end)

	it("locates the cell under a point", function()
		local layout = FloorGrid.Build(44, 44, rollKey, 0, 12)
		for _, cell in layout.Cells do
			expect(FloorGrid.Locate(layout, cell.X + 1.5, cell.Z - 1.5) == cell):toBe(true)
		end
		expect(FloorGrid.Locate(layout, 0, -10)):toBeNil()
		expect(FloorGrid.Locate(layout, 30, 0)):toBeNil()
	end)
end)
