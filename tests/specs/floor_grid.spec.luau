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
		local count = math.floor((44 - FloorGrid.EdgeMargin * 2) / FloorGrid.CellSize)
		expect(layout.Columns):toBe(count)
		expect(layout.Rows):toBe(count)
		local free = 0
		for row = 0, count - 1 do
			for column = 0, count - 1 do
				local cell = {
					X = -count * FloorGrid.CellSize / 2 + (column + 0.5) * FloorGrid.CellSize,
					Z = -count * FloorGrid.CellSize / 2 + (row + 0.5) * FloorGrid.CellSize,
				}
				if not overlaps(cell, rollKey) then
					free += 1
				end
			end
		end
		expect(#layout.Cells):toBe(free)
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
		local count = math.floor((44 - FloorGrid.EdgeMargin * 2) / FloorGrid.CellSize)
		expect(#layout.Cells):toBe(count * count)
	end)

	it("places exactly BoardSlots slot cells clear of the roll key", function()
		local layout = FloorGrid.Build(44, 44, rollKey, 0, 12)
		expect(#layout.Slots):toBe(GameConfig.BoardSlots)
		for slot = 1, GameConfig.BoardSlots do
			local cell = layout.Slots[slot]
			expect(cell.Slot):toBe(slot)
			expect(layout.Lookup[cell.Index] == cell):toBe(true)
			expect(overlaps(cell, rollKey)):toBe(false)
		end
		local marked = 0
		for _, cell in layout.Cells do
			if cell.Slot then
				marked += 1
			end
		end
		expect(marked):toBe(GameConfig.BoardSlots)
	end)

	it("puts the slots on the configured rows and columns counted from the back left", function()
		local layout = FloorGrid.Build(44, 44, rollKey, 0, 12)
		expect(layout.Columns):toBe(12)
		expect(layout.Rows):toBe(12)
		expect(#GameConfig.SlotCells):toBe(GameConfig.BoardSlots)
		local expected = {
			{ 2, 2 },
			{ 2, 5 },
			{ 2, 8 },
			{ 2, 11 },
			{ 4, 2 },
			{ 4, 5 },
			{ 4, 8 },
			{ 4, 11 },
		}
		for slot, spec in GameConfig.SlotCells do
			expect({ spec.Row, spec.Col }):toEqual(expected[slot])
			local cell = layout.Slots[slot]
			expect(layout.Rows - cell.Row):toBe(spec.Row)
			expect(layout.Columns - cell.Column):toBe(spec.Col)
		end
	end)

	it("orders slots from the back left to the back right then the next row forward", function()
		local layout = FloorGrid.Build(44, 44, rollKey, 0, 12)
		for slot = 1, 3 do
			expect(layout.Slots[slot + 1].X < layout.Slots[slot].X):toBe(true)
			expect(layout.Slots[slot + 1].Z):toBe(layout.Slots[slot].Z)
		end
		expect(layout.Slots[1].Z > rollKey.Z):toBe(true)
		expect(layout.Slots[5].Z < layout.Slots[1].Z):toBe(true)
		expect(layout.Slots[1].Z > 0):toBe(true)
		expect(layout.Slots[1].X > 0):toBe(true)
	end)

	it("ignores the board center", function()
		local a = FloorGrid.Build(44, 44, rollKey, 0, 12)
		local b = FloorGrid.Build(44, 44, rollKey, 60, -60)
		for slot = 1, GameConfig.BoardSlots do
			expect(a.Slots[slot].Index):toBe(b.Slots[slot].Index)
		end
	end)

	it("fits every slot on a 44x44 base without a roll key", function()
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

	it("keeps slots off the roll key and inside the base on other base sizes", function()
		local half = FloorGrid.CellSize / 2
		for _, size in { 30, 36, 44, 60 } do
			local key = { X = 0, Z = -size / 2 + 6, HalfX = 4, HalfZ = 4 }
			local layout = FloorGrid.Build(size, size, key, 0, 0)
			expect(#layout.Slots):toBe(GameConfig.BoardSlots)
			local seen = {}
			for slot, cell in layout.Slots do
				expect(cell.Slot):toBe(slot)
				expect(seen[cell]):toBeNil()
				seen[cell] = true
				expect(overlaps(cell, key)):toBe(false)
				expect(math.abs(cell.X) + half <= size / 2 - FloorGrid.EdgeMargin + 1e-6):toBe(true)
				expect(math.abs(cell.Z) + half <= size / 2 - FloorGrid.EdgeMargin + 1e-6):toBe(true)
			end
		end
	end)

	it("moves a slot off the roll key when the key covers its target cell", function()
		local key = { X = 0, Z = 12, HalfX = 6, HalfZ = 4 }
		local layout = FloorGrid.Build(44, 44, key, 0, 0)
		expect(#layout.Slots):toBe(GameConfig.BoardSlots)
		for _, cell in layout.Slots do
			expect(overlaps(cell, key)):toBe(false)
		end
	end)

	it("places as many slots as there are free cells on a tiny base", function()
		local layout = FloorGrid.Build(10, 10, nil, 0, 0)
		local count = math.floor((10 - FloorGrid.EdgeMargin * 2) / FloorGrid.CellSize)
		expect(#layout.Cells):toBe(count * count)
		expect(#layout.Slots):toBe(math.min(GameConfig.BoardSlots, count * count))
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
