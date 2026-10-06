--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharmConfig = require(ReplicatedStorage.Config.Charms)
local Keys = require(ReplicatedStorage.Config.Keys)

export type TierName = "Basic" | "Big" | "Hype"

export type Beat = {
	Start: number,
	End: number,
	Tilt: number,
	Pitch: number,
	Volume: number,
	Cracks: number,
}

export type Plan = {
	Name: TierName,
	Land: number,
	Beats: { Beat },
	SwellAt: number?,
	BurstAt: number,
	NameAt: number,
	ChipAt: number,
	ReadyAt: number,
	AutoAt: number,
	Shards: number,
	Confetti: number,
	Stars: number,
	Shake: number,
	Spin: number,
	Rainbow: boolean,
	RayDiameter: number,
	EggScale: number,
	IsLow: boolean,
}

export type Event = {
	At: number,
	Kind: string,
	Index: number,
}

local bigRank = 3
local hypeRank = 5
local autoSeconds = 2.5
local releaseDelay = 0.12

local function beat(
	start: number,
	length: number,
	tilt: number,
	pitch: number,
	volume: number,
	cracks: number
): Beat
	return {
		Start = start,
		End = start + length,
		Tilt = tilt,
		Pitch = pitch,
		Volume = volume,
		Cracks = cracks,
	}
end

local function finish(plan: Plan): Plan
	plan.NameAt = plan.BurstAt + 0.35
	plan.ChipAt = plan.BurstAt + 0.55
	plan.ReadyAt = plan.BurstAt + 1
	plan.AutoAt = plan.ReadyAt + autoSeconds
	return plan
end

local function basic(): Plan
	return finish({
		Name = "Basic",
		Land = 0.45,
		Beats = {
			beat(0.8, 0.5, 8, 0.85, 0.7, 3),
			beat(1.45, 0.5, 14, 1, 0.85, 7),
			beat(2.1, 0.5, 20, 1.2, 1, 11),
		},
		SwellAt = nil,
		BurstAt = 2.8,
		Shards = 10,
		Confetti = 0,
		Stars = 0,
		Shake = 0,
		Spin = 80,
		Rainbow = false,
		RayDiameter = 760,
		EggScale = 1,
		IsLow = false,
	} :: any)
end

local function big(): Plan
	return finish({
		Name = "Big",
		Land = 0.5,
		Beats = {
			beat(0.85, 0.7, 10, 0.85, 0.75, 3),
			beat(1.7, 0.7, 17, 1, 0.9, 7),
			beat(2.55, 0.7, 24, 1.2, 1, 11),
		},
		SwellAt = nil,
		BurstAt = 3.5,
		Shards = 16,
		Confetti = 24,
		Stars = 8,
		Shake = 4,
		Spin = 100,
		Rainbow = false,
		RayDiameter = 900,
		EggScale = 1.1,
		IsLow = false,
	} :: any)
end

local function hype(): Plan
	return finish({
		Name = "Hype",
		Land = 0.55,
		Beats = {
			beat(1, 0.9, 12, 0.8, 0.8, 3),
			beat(2.1, 0.9, 20, 1, 0.95, 7),
			beat(3.2, 0.9, 30, 1.25, 1.1, 11),
		},
		SwellAt = 0.8,
		BurstAt = 4.6,
		Shards = 24,
		Confetti = 40,
		Stars = 14,
		Shake = 10,
		Spin = 130,
		Rainbow = true,
		RayDiameter = 1100,
		EggScale = 1.2,
		IsLow = false,
	} :: any)
end

local HatchPlan = {
	CrackLines = 12,
	AutoSeconds = autoSeconds,
}

function HatchPlan.RankOf(rarityName: string): number
	local info = CharmConfig.RarityByName[rarityName]
	return if info then info.Order else 1
end

function HatchPlan.TierName(rarityName: string, minRank: number): TierName
	if minRank > #Keys.Rarities then
		return "Basic"
	end
	local rank = HatchPlan.RankOf(rarityName)
	if rank >= hypeRank and rank >= minRank then
		return "Hype"
	end
	if rank >= bigRank then
		return "Big"
	end
	return "Basic"
end

function HatchPlan.For(rarityName: string, minRank: number, isLow: boolean): Plan
	local name = HatchPlan.TierName(rarityName, minRank)
	local plan = if name == "Hype" then hype() elseif name == "Big" then big() else basic()
	plan.IsLow = isLow
	if isLow then
		plan.Shards = math.min(plan.Shards, 6)
		plan.Confetti = 0
		plan.Stars = 0
		plan.Shake = 0
		plan.Spin = 0
		plan.Rainbow = false
	end
	return plan
end

function HatchPlan.Events(plan: Plan): { Event }
	local events: { Event } = { { At = plan.Land, Kind = "Land", Index = 0 } }
	local swell = plan.SwellAt
	if swell then
		table.insert(events, { At = swell, Kind = "Swell", Index = 0 })
	end
	for index, item in plan.Beats do
		table.insert(events, { At = item.Start, Kind = "Crack", Index = index })
		table.insert(events, { At = item.Start + releaseDelay, Kind = "CrackRelease", Index = index })
	end
	table.insert(events, { At = plan.BurstAt, Kind = "Burst", Index = 0 })
	table.insert(events, { At = plan.NameAt, Kind = "Name", Index = 0 })
	table.insert(events, { At = plan.ChipAt, Kind = "Chip", Index = 0 })
	table.insert(events, { At = plan.ReadyAt, Kind = "Ready", Index = 0 })
	table.insert(events, { At = plan.AutoAt, Kind = "Auto", Index = 0 })
	table.sort(events, function(a: Event, b: Event)
		return a.At < b.At
	end)
	return events
end

function HatchPlan.PhaseAt(plan: Plan, time: number): string
	if time >= plan.AutoAt then
		return "Done"
	elseif time >= plan.ReadyAt then
		return "Ready"
	elseif time >= plan.BurstAt then
		return "Reveal"
	elseif time >= plan.Beats[1].Start then
		return "Shake"
	end
	return "Drop"
end

function HatchPlan.RevealRarity(rarityName: string, tier: TierName): Keys.Rarity
	local own = Keys.RarityByName[rarityName]
	if own and own.Reveal then
		return own
	end
	return Keys.RarityByName[if tier == "Hype" then "Legendary" else "Epic"]
end

return table.freeze(HatchPlan)
