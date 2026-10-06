--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Keys = require(ReplicatedStorage.Config.Keys)

export type TierName = "Mini" | "Epic" | "Legendary" | "Mythic" | "Secret"

export type Tier = {
	Name: TierName,
	Duration: number,
	ImpactAt: number,
	Dim: number,
	Entry: "Pop" | "Drop" | "Rise" | "Spin",
	Charge: boolean,
	Rays: number,
	Rings: number,
	Particles: number,
	Rain: boolean,
	Cracks: boolean,
	Border: boolean,
	Stars: boolean,
	Chroma: boolean,
	Glitch: boolean,
	Rainbow: boolean,
	ShakeUi: number,
	ShakeCamera: number,
	ShakeSeconds: number,
	FlashStart: number,
	TitleAt: number,
	NameAt: number,
	TitleScale: number,
	Squash: number,
	Swell: boolean,
}

local rarityRank: { [string]: number } = {}
for index, rarity in Keys.Rarities do
	rarityRank[rarity.Name] = index
end

local offRank = #Keys.Rarities + 1
local epicRank = rarityRank.Epic or 4
local legendaryRank = rarityRank.Legendary or 5
local mythicRank = rarityRank.Mythic or 6
local secretRank = rarityRank.Secret or 7

local tiers: { [string]: Tier } = {
	Mini = {
		Name = "Mini",
		Duration = 0.8,
		ImpactAt = 0.12,
		Dim = 0.55,
		Entry = "Pop",
		Charge = false,
		Rays = 0,
		Rings = 1,
		Particles = 0,
		Rain = false,
		Cracks = false,
		Border = false,
		Stars = false,
		Chroma = false,
		Glitch = false,
		Rainbow = false,
		ShakeUi = 0,
		ShakeCamera = 0,
		ShakeSeconds = 0,
		FlashStart = 0.55,
		TitleAt = 0.12,
		NameAt = 0.2,
		TitleScale = 0.6,
		Squash = 0.12,
		Swell = false,
	},
	Epic = {
		Name = "Epic",
		Duration = 1.2,
		ImpactAt = 0.2,
		Dim = 0.35,
		Entry = "Pop",
		Charge = false,
		Rays = 1,
		Rings = 1,
		Particles = 10,
		Rain = false,
		Cracks = false,
		Border = false,
		Stars = false,
		Chroma = false,
		Glitch = false,
		Rainbow = false,
		ShakeUi = 5,
		ShakeCamera = 0,
		ShakeSeconds = 0.25,
		FlashStart = 0.4,
		TitleAt = 0.22,
		NameAt = 0.35,
		TitleScale = 0.85,
		Squash = 0.2,
		Swell = false,
	},
	Legendary = {
		Name = "Legendary",
		Duration = 2.2,
		ImpactAt = 0.5,
		Dim = 0.12,
		Entry = "Drop",
		Charge = false,
		Rays = 2,
		Rings = 2,
		Particles = 36,
		Rain = false,
		Cracks = false,
		Border = false,
		Stars = false,
		Chroma = false,
		Glitch = false,
		Rainbow = false,
		ShakeUi = 16,
		ShakeCamera = 0,
		ShakeSeconds = 0.4,
		FlashStart = 0.3,
		TitleAt = 0.6,
		NameAt = 0.8,
		TitleScale = 1,
		Squash = 0.38,
		Swell = false,
	},
	Mythic = {
		Name = "Mythic",
		Duration = 3.2,
		ImpactAt = 1.5,
		Dim = 0.06,
		Entry = "Rise",
		Charge = true,
		Rays = 2,
		Rings = 3,
		Particles = 48,
		Rain = false,
		Cracks = true,
		Border = true,
		Stars = false,
		Chroma = true,
		Glitch = false,
		Rainbow = false,
		ShakeUi = 28,
		ShakeCamera = 1,
		ShakeSeconds = 0.7,
		FlashStart = 0,
		TitleAt = 1.62,
		NameAt = 1.85,
		TitleScale = 1.05,
		Squash = 0.45,
		Swell = true,
	},
	Secret = {
		Name = "Secret",
		Duration = 4,
		ImpactAt = 2,
		Dim = 0,
		Entry = "Spin",
		Charge = true,
		Rays = 2,
		Rings = 3,
		Particles = 56,
		Rain = true,
		Cracks = true,
		Border = true,
		Stars = true,
		Chroma = true,
		Glitch = true,
		Rainbow = true,
		ShakeUi = 34,
		ShakeCamera = 1.3,
		ShakeSeconds = 0.8,
		FlashStart = 0,
		TitleAt = 2.12,
		NameAt = 2.35,
		TitleScale = 1.05,
		Squash = 0.5,
		Swell = true,
	},
}

local Tiers = {
	OffRank = offRank,
	SkipDelay = 0.5,
}

function Tiers.RankOf(rarity: Keys.Rarity): number
	return rarityRank[rarity.Name] or 1
end

function Tiers.ShouldPlay(rank: number, minRank: number): boolean
	return rank >= minRank and minRank < offRank
end

function Tiers.NameFor(rank: number): TierName
	if rank >= secretRank then
		return "Secret"
	elseif rank >= mythicRank then
		return "Mythic"
	elseif rank >= legendaryRank then
		return "Legendary"
	elseif rank >= epicRank then
		return "Epic"
	end
	return "Mini"
end

function Tiers.For(rank: number): Tier
	return tiers[Tiers.NameFor(rank)]
end

function Tiers.Get(name: TierName): Tier
	return tiers[name]
end

function Tiers.Clamp(value: any): number
	if type(value) ~= "number" or value ~= value then
		return legendaryRank
	end
	return math.clamp(math.floor(value), 1, offRank)
end

return Tiers
