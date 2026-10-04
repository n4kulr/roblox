--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)

export type Platform = {
	Stage: number,
	Index: number,
	Shape: string,
	X: number,
	D0: number,
	D1: number,
	Width: number,
}

export type Area = {
	Index: number,
	Kind: string,
	D0: number,
	D1: number,
}

export type Span = {
	Index: number,
	D0: number,
	D1: number,
}

export type Spawn = {
	Stage: number,
	Platform: number,
	X: number,
	D: number,
}

export type Layout = {
	Areas: { Area },
	Stages: { Span },
	Platforms: { Platform },
	Spawns: { Spawn },
	Length: number,
	Width: number,
	Top: number,
	LavaTop: number,
}

local config = GameConfig.Obby

local Obby = {}

function Obby.SpeedFor(rolls: number): number
	local count = if rolls == rolls then math.max(0, rolls) else 0
	local raw = config.BaseSpeed + config.SpeedPerDecade * math.log10(count + 1)
	return math.min(config.MaxSpeed, math.floor(raw))
end

function Obby.RarityFor(stage: number, roll: number): string
	local entry = config.Stages[stage]
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

function Obby.Gap(a: Platform, b: Platform): number
	local sideways = math.max(0, math.abs(a.X - b.X) - (a.Width + b.Width) / 2)
	local forward = math.max(0, b.D0 - a.D1)
	return math.sqrt(sideways * sideways + forward * forward)
end

function Obby.Layout(): Layout
	local areas: { Area } = {}
	local spans: { Span } = {}
	local platforms: { Platform } = {}
	local spawns: { Spawn } = {}
	local distance = config.RampLength
	table.insert(areas, { Index = 0, Kind = "Start", D0 = distance, D1 = distance + config.SafeLength })
	distance += config.SafeLength
	local stageCount = #config.Stages
	for stageIndex, stage in config.Stages do
		local spanStart = distance
		distance += stage.Gap
		for index = 1, stage.Count do
			local shape = stage.Shapes[(index - 1) % #stage.Shapes + 1]
			local isBeam = shape == "Beam"
			local length = if isBeam then stage.BeamLength else stage.Size
			local width = if isBeam then stage.BeamWidth else stage.Size
			local side = if index % 2 == 1 then -1 else 1
			table.insert(platforms, {
				Stage = stageIndex,
				Index = index,
				Shape = shape,
				X = side * stage.Stagger,
				D0 = distance,
				D1 = distance + length,
				Width = width,
			})
			distance += length + stage.Gap
		end
		table.insert(spans, { Index = stageIndex, D0 = spanStart, D1 = distance })
		table.insert(areas, {
			Index = stageIndex,
			Kind = if stageIndex < stageCount then "Safe" else "Finish",
			D0 = distance,
			D1 = distance + config.SafeLength,
		})
		distance += config.SafeLength
	end
	for _, platform in platforms do
		local stage = config.Stages[platform.Stage]
		if table.find(stage.Spawns, platform.Index) then
			table.insert(spawns, {
				Stage = platform.Stage,
				Platform = platform.Index,
				X = platform.X,
				D = (platform.D0 + platform.D1) / 2,
			})
		end
	end
	return {
		Areas = areas,
		Stages = spans,
		Platforms = platforms,
		Spawns = spawns,
		Length = distance,
		Width = config.CourseWidth,
		Top = config.LavaTop + config.Rise,
		LavaTop = config.LavaTop,
	}
end

return Obby
