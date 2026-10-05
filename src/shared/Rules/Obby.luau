--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)

export type Cell = {
	Section: string,
	Row: number,
	Col: number,
	X: number,
	D: number,
	Width: number,
	Length: number,
	Letter: string,
	Kind: string,
	Phase: number,
}

export type Area = {
	Name: string,
	Kind: string,
	D0: number,
	D1: number,
}

export type Run = {
	Name: string,
	D0: number,
	D1: number,
}

export type Pedestal = {
	Section: string,
	X: number,
	D: number,
	Rarities: string,
}

export type Layout = {
	Width: number,
	Top: number,
	Length: number,
	Areas: { Area },
	Runs: { Run },
	Cells: { Cell },
	Pedestals: { Pedestal },
	GateD: number,
}

local config = GameConfig.Obby

local Obby = {}

function Obby.SpeedFor(taps: number): number
	local count = if taps == taps then math.max(0, taps) else 0
	local raw = config.BaseSpeed + count * config.SpeedPerTap
	return math.min(config.MaxSpeed, math.floor(raw))
end

function Obby.ParseRarities(spec: string): { { Name: string, Weight: number } }
	local out = {}
	for token in string.gmatch(spec, "[^,]+") do
		local name, weight = string.match(token, "^%s*(%a+)%s*:?%s*([%d%.]*)%s*$")
		if name and Keys.RarityByName[name] then
			table.insert(out, { Name = name, Weight = tonumber(weight) or 1 })
		end
	end
	return out
end

function Obby.RarityFor(spec: string, roll: number): string
	local options = Obby.ParseRarities(spec)
	if #options == 0 then
		return "Rare"
	end
	local total = 0
	for _, option in options do
		total += option.Weight
	end
	local target = math.clamp(roll, 0, 0.999999) * total
	local running = 0
	for _, option in options do
		running += option.Weight
		if target < running then
			return option.Name
		end
	end
	return options[#options].Name
end

function Obby.KeyContains(cframe: CFrame, size: Vector3, point: Vector3): boolean
	local offset = cframe:PointToObjectSpace(point)
	return math.abs(offset.X) <= size.X / 2
		and math.abs(offset.Z) <= size.Z / 2
		and offset.Y >= size.Y / 2 - 1
		and offset.Y <= size.Y / 2 + config.Key.TapReach
end

function Obby.Contains(cframe: CFrame, size: Vector3, point: Vector3, reachUp: number): boolean
	local offset = cframe:PointToObjectSpace(point)
	return math.abs(offset.X) <= size.X / 2
		and math.abs(offset.Z) <= size.Z / 2
		and offset.Y >= -size.Y / 2
		and offset.Y <= size.Y / 2 + reachUp
end

function Obby.Entrance(marketPosition: Vector3?): CFrame
	local center = config.MapCenter
	local market = marketPosition or config.FallbackMarket
	local offset = Vector3.new(market.X - center.X, 0, market.Z - center.Z)
	if offset.Magnitude < 0.001 then
		offset = Vector3.new(config.FallbackMarket.X - center.X, 0, config.FallbackMarket.Z - center.Z)
	end
	local direction = -offset.Unit
	local position = Vector3.new(center.X, config.GroundY, center.Z) + direction * config.EntranceDistance
	return CFrame.new(position) * CFrame.Angles(0, math.atan2(-direction.X, -direction.Z), 0)
end

local letterRows = { "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM" }
local modifierLabels = { "TAB", "CAPS", "SHIFT", "CTRL" }

local function rowCells(section: string, row: number, depth: number): { Cell }
	local key = config.Key
	local pitch = key.Size + key.Gap
	local half = config.Width / 2
	local offset = key.Stagger[(row - 1) % #key.Stagger + 1]
	local letters = letterRows[(row - 1) % #letterRows + 1]
	local cells: { Cell } = {}
	local col = -1
	while true do
		local left = -half + (col + offset) * pitch
		if left >= half then
			break
		end
		local clippedLeft = math.max(left, -half)
		local clippedRight = math.min(left + key.Size, half)
		if clippedRight - clippedLeft >= 2 then
			local index = #cells + 1
			local isModifier = index == 1 or (row % 3 == 0 and clippedRight >= half - 0.01)
			local label = if index == 1 then modifierLabels[(row - 1) % #modifierLabels + 1] else "BKSP"
			table.insert(cells, {
				Section = section,
				Row = row,
				Col = index,
				X = (clippedLeft + clippedRight) / 2,
				D = depth,
				Width = clippedRight - clippedLeft,
				Length = key.Size,
				Letter = if isModifier
					then label
					else string.sub(letters, (index - 2) % #letters + 1, (index - 2) % #letters + 1),
				Kind = if isModifier then "Modifier" else "Key",
				Phase = 0,
			})
		end
		col += 1
	end
	return cells
end

local function removeNearest(cells: { Cell }, row: number, x: number): Cell?
	local best: Cell? = nil
	for _, cell in cells do
		if cell.Row == row and cell.Kind == "Key" then
			if not best or math.abs(cell.X - x) < math.abs(best.X - x) then
				best = cell
			end
		end
	end
	if best then
		table.remove(cells, table.find(cells, best) :: number)
	end
	return best
end

function Obby.Layout(): Layout
	local level = config.Level1
	local key = config.Key
	local pitch = key.Size + key.Gap
	local areas: { Area } = {}
	local runs: { Run } = {}
	local cells: { Cell } = {}
	local pedestals: { Pedestal } = {}
	local distance = 0

	local function addArea(name: string, kind: string, length: number): Area
		local area = { Name = name, Kind = kind, D0 = distance, D1 = distance + length }
		table.insert(areas, area)
		distance += length
		return area
	end

	local function addRun(name: string): { Cell }
		local run = { Name = name, D0 = distance, D1 = distance + level.RunRows * pitch }
		table.insert(runs, run)
		local out: { Cell } = {}
		for row = 1, level.RunRows do
			for _, cell in rowCells(name, row, run.D0 + (row - 1) * pitch + key.Size / 2) do
				table.insert(out, cell)
			end
		end
		distance = run.D1
		return out
	end

	addArea("Start", "Start", level.StartLength)
	local runA = addRun("RunA")
	addArea("Safe1", "Safe", level.SafeLength)
	local runB = addRun("RunB")
	addArea("Approach", "Approach", level.ApproachLength)
	local gateD = distance + config.Gate.Thickness / 2
	distance += config.Gate.Thickness
	local endArea = addArea("End", "End", level.EndLength)

	for _, spec in level.Pedestals do
		local section: string = spec.Section
		if spec.Section == "RunA" then
			local runStart = runs[1].D0
			table.insert(pedestals, {
				Section = section,
				X = spec.X,
				D = runStart + (spec.Row - 1) * pitch + key.Size / 2,
				Rarities = spec.Rarities,
			})
		elseif spec.Section == "RunB" then
			local removed = removeNearest(runB, spec.Row, spec.X)
			if removed then
				table.insert(pedestals, {
					Section = section,
					X = removed.X,
					D = removed.D,
					Rarities = spec.Rarities,
				})
			end
		else
			table.insert(pedestals, {
				Section = section,
				X = spec.X,
				D = (endArea.D0 + endArea.D1) / 2,
				Rarities = spec.Rarities,
			})
		end
	end

	local popupRows: { [number]: boolean } = {}
	for _, popup in level.PopUps do
		popupRows[popup.Row] = true
	end
	local keptB: { Cell } = {}
	for _, cell in runB do
		local isHole = cell.Row >= 2
			and cell.Row < level.RunRows
			and cell.Kind == "Key"
			and (cell.Row * 5 + cell.Col * 3) % level.HoleModulo == 0
		local isCovered = false
		for _, popup in level.PopUps do
			if
				cell.Row == popup.Row
				and math.abs(cell.X - popup.X) < popup.Width / 2 + cell.Width / 2 - 0.5
			then
				isCovered = true
			end
		end
		if not isHole and not isCovered then
			table.insert(keptB, cell)
		end
	end
	for _, popup in level.PopUps do
		table.insert(keptB, {
			Section = "RunB",
			Row = popup.Row,
			Col = 0,
			X = popup.X,
			D = runs[2].D0 + (popup.Row - 1) * pitch + key.Size / 2,
			Width = popup.Width,
			Length = key.Size,
			Letter = popup.Label,
			Kind = "PopUp",
			Phase = popup.Phase,
		})
	end
	for _, cell in runA do
		table.insert(cells, cell)
	end
	for _, cell in keptB do
		table.insert(cells, cell)
	end
	return {
		Width = config.Width,
		Top = config.GroundY + key.Height,
		Length = distance,
		Areas = areas,
		Runs = runs,
		Cells = cells,
		Pedestals = pedestals,
		GateD = gateD,
	}
end

return Obby
