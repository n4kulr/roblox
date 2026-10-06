--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharmConfig = require(ReplicatedStorage.Config.Charms)
local Keys = require(ReplicatedStorage.Config.Keys)

export type TierName = "Basic" | "Big" | "Hype"

export type Swing = {
	At: number,
	Side: number,
	Pitch: number,
	Volume: number,
}

export type CrackStage = {
	At: number,
	Count: number,
}

export type Plan = {
	Name: TierName,
	ShakeStart: number,
	BurstAt: number,
	Swings: { Swing },
	Cracks: { CrackStage },
	SwellAt: number?,
	NameAt: number,
	RarityAt: number,
	ChanceAt: number,
	ReadyAt: number,
	AutoAt: number,
	HoldSeconds: number,
	Shards: number,
	Sparks: number,
	Confetti: number,
	Stars: number,
	Shake: number,
	Spin: number,
	Rainbow: boolean,
	RayDiameter: number,
	IsLow: boolean,
}

export type Event = {
	At: number,
	Kind: string,
	Index: number,
}

local bigRank = 3
local hypeRank = 5
local popSeconds = 0.25
local popPeakAt = 0.15
local popPeak = 1.15
local shakeSeconds = 2.2
local periodStart = 0.35
local periodEnd = 0.12
local tiltStart = 12
local tiltEnd = 25
local growth = 0.12
local squashAmount = 0.05
local springSeconds = 0.45
local readyDelay = 0.6
local exitSeconds = 0.4
local flashHold = 0.08
local flashFade = 0.25
local minTapSeconds = 0.15
local crackFractions = { 0.3, 0.6, 0.85 }
local crackCounts = { 4, 8, 12 }
local periodRate = (periodEnd - periodStart) / shakeSeconds

local function clamp01(value: number): number
	return math.clamp(value, 0, 1)
end

local function lerp(from: number, to: number, alpha: number): number
	return from + (to - from) * alpha
end

local function timeAtPhase(phase: number): number
	return periodStart / periodRate * (math.exp(phase * periodRate) - 1)
end

local function buildSwings(shakeStart: number): { Swing }
	local swings: { Swing } = {}
	local index = 0
	while true do
		local offset = timeAtPhase(index * 0.5 + 0.25)
		if offset >= shakeSeconds - 0.04 then
			break
		end
		local alpha = offset / shakeSeconds
		table.insert(swings, {
			At = shakeStart + offset,
			Side = if index % 2 == 0 then 1 else -1,
			Pitch = lerp(0.8, 1.6, alpha),
			Volume = lerp(0.3, 0.6, alpha),
		})
		index += 1
	end
	return swings
end

local function newPlan(name: TierName, hold: number): Plan
	local burstAt = popSeconds + shakeSeconds
	local stages: { CrackStage } = {}
	for index, fraction in crackFractions do
		table.insert(stages, { At = popSeconds + shakeSeconds * fraction, Count = crackCounts[index] })
	end
	local plan: any = {
		Name = name,
		ShakeStart = popSeconds,
		BurstAt = burstAt,
		Swings = buildSwings(popSeconds),
		Cracks = stages,
		SwellAt = nil,
		NameAt = burstAt + 0.2,
		RarityAt = burstAt + 0.35,
		ChanceAt = burstAt + 0.5,
		ReadyAt = burstAt + readyDelay,
		HoldSeconds = hold,
		AutoAt = burstAt + readyDelay + hold,
		IsLow = false,
	}
	return plan :: Plan
end

local function basic(): Plan
	local plan = newPlan("Basic", 1.2)
	plan.Shards = 12
	plan.Sparks = 8
	plan.Confetti = 0
	plan.Stars = 0
	plan.Shake = 0
	plan.Spin = 60
	plan.Rainbow = false
	plan.RayDiameter = 820
	return plan
end

local function big(): Plan
	local plan = newPlan("Big", 2)
	plan.Shards = 18
	plan.Sparks = 12
	plan.Confetti = 0
	plan.Stars = 8
	plan.Shake = 4
	plan.Spin = 70
	plan.Rainbow = false
	plan.RayDiameter = 980
	return plan
end

local function hype(): Plan
	local plan = newPlan("Hype", 3)
	plan.SwellAt = plan.ShakeStart
	plan.Shards = 24
	plan.Sparks = 14
	plan.Confetti = 36
	plan.Stars = 14
	plan.Shake = 9
	plan.Spin = 80
	plan.Rainbow = true
	plan.RayDiameter = 1150
	return plan
end

local HatchPlan = {
	CrackLines = 12,
	ShakeSeconds = shakeSeconds,
	PopSeconds = popSeconds,
	SpringSeconds = springSeconds,
	ExitSeconds = exitSeconds,
	FlashHold = flashHold,
	FlashFade = flashFade,
	MinTapSeconds = minTapSeconds,
	PeriodStart = periodStart,
	PeriodEnd = periodEnd,
	TiltStart = tiltStart,
	TiltEnd = tiltEnd,
	Growth = growth,
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
		plan.Sparks = math.min(plan.Sparks, 4)
		plan.Confetti = 0
		plan.Stars = 0
		plan.Shake = 0
		plan.Spin = 0
		plan.Rainbow = false
	end
	return plan
end

function HatchPlan.Events(plan: Plan): { Event }
	local events: { Event } = { { At = 0, Kind = "Appear", Index = 0 } }
	local swell = plan.SwellAt
	if swell then
		table.insert(events, { At = swell, Kind = "Swell", Index = 0 })
	end
	for index, swing in plan.Swings do
		table.insert(events, { At = swing.At, Kind = "Swing", Index = index })
	end
	for index, stage in plan.Cracks do
		table.insert(events, { At = stage.At, Kind = "Crack", Index = index })
	end
	table.insert(events, { At = plan.BurstAt, Kind = "Burst", Index = 0 })
	table.insert(events, { At = plan.NameAt, Kind = "Name", Index = 0 })
	table.insert(events, { At = plan.RarityAt, Kind = "Rarity", Index = 0 })
	table.insert(events, { At = plan.ChanceAt, Kind = "Chance", Index = 0 })
	table.insert(events, { At = plan.ReadyAt, Kind = "Ready", Index = 0 })
	table.insert(events, { At = plan.AutoAt, Kind = "Auto", Index = 0 })
	table.sort(events, function(a: Event, b: Event)
		return if a.At == b.At then a.Index < b.Index else a.At < b.At
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
	elseif time >= plan.ShakeStart then
		return "Shake"
	end
	return "Appear"
end

function HatchPlan.PopScale(time: number): number
	if time <= 0 then
		return 0
	elseif time < popPeakAt then
		local alpha = time / popPeakAt
		return popPeak * (1 - (1 - alpha) * (1 - alpha))
	elseif time < popSeconds then
		local alpha = (time - popPeakAt) / (popSeconds - popPeakAt)
		return popPeak + (1 - popPeak) * (0.5 - 0.5 * math.cos(alpha * math.pi))
	end
	return 1
end

function HatchPlan.ShakeProgress(plan: Plan, time: number): number
	return clamp01((time - plan.ShakeStart) / shakeSeconds)
end

function HatchPlan.Period(plan: Plan, time: number): number
	return lerp(periodStart, periodEnd, HatchPlan.ShakeProgress(plan, time))
end

function HatchPlan.Amplitude(plan: Plan, time: number): number
	local progress = HatchPlan.ShakeProgress(plan, time)
	return lerp(tiltStart, tiltEnd, progress * progress)
end

function HatchPlan.Wave(plan: Plan, time: number): number
	local offset = time - plan.ShakeStart
	if offset <= 0 or time >= plan.BurstAt then
		return 0
	end
	local phase = math.log(1 + periodRate * offset / periodStart) / periodRate
	return math.sin(phase * math.pi * 2)
end

function HatchPlan.Tilt(plan: Plan, time: number): number
	return HatchPlan.Wave(plan, time) * HatchPlan.Amplitude(plan, time)
end

function HatchPlan.Squash(plan: Plan, time: number): (number, number)
	local wave = math.abs(HatchPlan.Wave(plan, time))
	return 1 + squashAmount * wave, 1 - squashAmount * wave
end

function HatchPlan.Grow(plan: Plan, time: number): number
	local progress = HatchPlan.ShakeProgress(plan, time)
	return 1 + growth * progress * progress
end

function HatchPlan.Flash(plan: Plan, time: number): number
	local after = time - plan.BurstAt
	if after < 0 then
		return 0
	elseif after < flashHold then
		return 1
	elseif after < flashHold + flashFade then
		local alpha = (after - flashHold) / flashFade
		return 1 - alpha * alpha * (3 - 2 * alpha)
	end
	return 0
end

function HatchPlan.CracksShown(plan: Plan, time: number): number
	local shown = 0
	for _, stage in plan.Cracks do
		if time >= stage.At then
			shown = stage.Count
		end
	end
	return shown
end

function HatchPlan.RevealRarity(rarityName: string, tier: TierName): Keys.Rarity
	local own = Keys.RarityByName[rarityName]
	if own and own.Reveal then
		return own
	end
	return Keys.RarityByName[if tier == "Hype" then "Legendary" else "Epic"]
end

return table.freeze(HatchPlan)
