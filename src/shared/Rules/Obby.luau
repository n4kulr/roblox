--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)

export type Area = {
	Kind: string,
	D0: number,
	D1: number,
	Title: string?,
	Subtitle: string?,
	SpeedNeeded: number?,
	HasHome: boolean,
}

export type TapKey = {
	Index: number,
	Letter: string,
	Row: number,
	Column: number,
	X: number,
	D: number,
	Size: number,
	Missing: boolean,
	Popup: boolean,
	PopupPhase: number,
	Section: number,
}

export type Spawn = {
	Section: number,
	X: number,
	D: number,
}

export type Layout = {
	Areas: { Area },
	Keys: { TapKey },
	Spawns: { Spawn },
	Length: number,
	Width: number,
	Top: number,
	LavaTop: number,
	HazardD0: number,
	HazardD1: number,
}

local config = GameConfig.Obby

local rows = table.freeze({
	table.freeze({ Letters = "QWERTYUIOP", Stagger = 0 }),
	table.freeze({ Letters = "ASDFGHJKL", Stagger = 0.5 }),
	table.freeze({ Letters = "ZXCVBNM", Stagger = 1 }),
	table.freeze({ Letters = " ", Stagger = 0 }),
})

local missingPattern = table.freeze({
	[2] = table.freeze({ [3] = true, [7] = true }),
	[3] = table.freeze({ [2] = true, [5] = true, [8] = true }),
	[4] = table.freeze({ [4] = true, [6] = true }),
})

local popupPattern = table.freeze({
	[2] = table.freeze({ [5] = true }),
	[3] = table.freeze({ [4] = true }),
	[4] = table.freeze({ [3] = true, [7] = true }),
})

local Obby = {}

function Obby.SpeedFor(taps: number): number
	local count = if taps == taps then math.max(0, taps) else 0
	return math.min(config.MaxSpeed, config.BaseSpeed + count * config.SpeedPerTap)
end

function Obby.RarityFor(section: number, roll: number): string
	local entry = config.Sections[section]
	if not entry then
		return "Rare"
	end
	local total = 0
	for _, option in entry.Rarities do
		total += option.Weight
	end
	local target = math.clamp(roll, 0, 0.999999) * total
	local running = 0
	for _, option in entry.Rarities do
		running += option.Weight
		if target < running then
			return option.Name
		end
	end
	return entry.Rarities[#entry.Rarities].Name
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

local function pitch(rowCount: number): number
	return rowCount * config.KeySize + math.max(0, rowCount - 1) * config.RowGap
end

local function addRowKeys(
	keys: { TapKey },
	startD: number,
	rowOffset: number,
	rowCount: number,
	section: number,
	hazard: boolean
)
	local step = config.KeySize + config.KeyGap
	local index = #keys
	for rowIndex = 1, rowCount do
		local template = rows[(rowOffset + rowIndex - 1) % #rows + 1]
		local letters = template.Letters
		local count = #letters
		local width = count * config.KeySize + (count - 1) * config.KeyGap
		local left = -width / 2 + config.KeySize / 2 + template.Stagger * (config.KeySize * 0.5)
		local d = startD + (rowIndex - 0.5) * (config.KeySize + config.RowGap)
		for column = 1, count do
			local letter = string.sub(letters, column, column)
			local missing = false
			local popup = false
			if hazard then
				local missRow = missingPattern[rowIndex]
				local popRow = popupPattern[rowIndex]
				missing = missRow ~= nil and missRow[column] == true
				popup = not missing and popRow ~= nil and popRow[column] == true
			end
			local size = if letter == " " then config.KeySize * 5 else config.KeySize
			local x = if letter == " " then 0 else left + (column - 1) * step
			index += 1
			table.insert(keys, {
				Index = index,
				Letter = letter,
				Row = rowIndex,
				Column = column,
				X = x,
				D = d,
				Size = size,
				Missing = missing,
				Popup = popup,
				PopupPhase = (rowIndex + column) * 0.35,
				Section = section,
			})
		end
	end
end

function Obby.Layout(): Layout
	local areas: { Area } = {}
	local keys: { TapKey } = {}
	local spawns: { Spawn } = {}
	local distance = 0

	table.insert(areas, {
		Kind = "Start",
		D0 = distance,
		D1 = distance + config.StartLength,
		Title = "KEYBOARD ESCAPE",
		Subtitle = "LEVEL 1",
		SpeedNeeded = nil,
		HasHome = false,
	})
	distance += config.StartLength

	local flatD0 = distance
	local flatLength = pitch(config.FlatRows)
	addRowKeys(keys, flatD0, 0, config.FlatRows, 1, false)
	distance = flatD0 + flatLength
	table.insert(spawns, { Section = 1, X = 0, D = flatD0 + flatLength * 0.55 })

	table.insert(areas, {
		Kind = "Safe",
		D0 = distance,
		D1 = distance + config.SafeLength,
		Title = "SAFE ZONE",
		Subtitle = "HOME PAD",
		SpeedNeeded = nil,
		HasHome = true,
	})
	distance += config.SafeLength

	local hazardD0 = distance
	local hazardLength = pitch(config.HazardRows)
	addRowKeys(keys, hazardD0, 1, config.HazardRows, 2, true)
	distance = hazardD0 + hazardLength
	table.insert(spawns, { Section = 2, X = -config.KeySize * 1.5, D = hazardD0 + hazardLength * 0.45 })

	table.insert(areas, {
		Kind = "Gate",
		D0 = distance,
		D1 = distance + config.GateLength,
		Title = `NEED {config.GateSpeed} SPEED`,
		Subtitle = "KEEP TAPPING",
		SpeedNeeded = config.GateSpeed,
		HasHome = false,
	})
	distance += config.GateLength

	table.insert(areas, {
		Kind = "Finish",
		D0 = distance,
		D1 = distance + config.FinishLength,
		Title = "LEVEL 1 COMPLETE",
		Subtitle = "LEVEL 2 COMING",
		SpeedNeeded = nil,
		HasHome = true,
	})
	table.insert(spawns, {
		Section = 3,
		X = config.KeySize,
		D = distance + config.FinishLength * 0.45,
	})
	distance += config.FinishLength

	return {
		Areas = areas,
		Keys = keys,
		Spawns = spawns,
		Length = distance,
		Width = config.CourseWidth,
		Top = config.KeyTop,
		LavaTop = config.LavaTop,
		HazardD0 = hazardD0,
		HazardD1 = hazardD0 + hazardLength,
	}
end

return Obby
