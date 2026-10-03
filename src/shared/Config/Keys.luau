--!strict

local SwitchSounds = require(script.Parent.SwitchSounds)

export type SoundLayer = {
	SoundId: string,
	PlaybackSpeed: number,
	Volume: number,
	Delay: number?,
}

export type Tone = {
	LowGain: number,
	MidGain: number,
	HighGain: number,
}

export type SoundSettings = {
	Layers: { SoundLayer },
	Tone: Tone,
}

export type Rarity = {
	Name: string,
	Chance: number,
	Color: Color3,
	Income: number,
	IsNeon: boolean,
	BuildUpSeconds: number,
	Announce: boolean,
	Reveal: SoundSettings?,
}

export type PerkKind = "Luck" | "Speed" | "Income"

export type Perk = {
	Kind: PerkKind,
	Amount: number,
}

export type Key = {
	Id: string,
	Name: string,
	Rarity: string,
	Index: number,
	Perk: Perk?,
	Switch: string,
	Flair: { SoundLayer }?,
}

local soundAssets = {
	Thock = "rbxassetid://99381679014350",
	Thud = "rbxassetid://88055159429775",
	Chime = "rbxassetid://9103417189",
	Sparkle = "rbxassetid://107978604605265",
}

local function layer(soundId: string, speed: number, volume: number, delay: number?): SoundLayer
	return table.freeze({ SoundId = soundId, PlaybackSpeed = speed, Volume = volume, Delay = delay })
end

local function sound(layers: { SoundLayer }, low: number, mid: number, high: number): SoundSettings
	return table.freeze({
		Layers = table.freeze(layers),
		Tone = table.freeze({ LowGain = low, MidGain = mid, HighGain = high }),
	})
end

local rarities: { Rarity } = {
	{
		Name = "Common",
		Chance = 1,
		Color = Color3.fromRGB(200, 200, 205),
		Income = 1,
		IsNeon = false,
		BuildUpSeconds = 0,
		Announce = false,
		Reveal = nil,
	},
	{
		Name = "Uncommon",
		Chance = 8,
		Color = Color3.fromRGB(110, 220, 120),
		Income = 4,
		IsNeon = false,
		BuildUpSeconds = 0,
		Announce = false,
		Reveal = nil,
	},
	{
		Name = "Rare",
		Chance = 50,
		Color = Color3.fromRGB(70, 140, 255),
		Income = 20,
		IsNeon = false,
		BuildUpSeconds = 0,
		Announce = false,
		Reveal = nil,
	},
	{
		Name = "Epic",
		Chance = 500,
		Color = Color3.fromRGB(180, 80, 255),
		Income = 150,
		IsNeon = true,
		BuildUpSeconds = 0.6,
		Announce = false,
		Reveal = sound({
			layer(soundAssets.Chime, 1.0, 0.3, 0.015),
		}, 4, 0, -3),
	},
	{
		Name = "Legendary",
		Chance = 5000,
		Color = Color3.fromRGB(255, 190, 40),
		Income = 1500,
		IsNeon = true,
		BuildUpSeconds = 1.0,
		Announce = true,
		Reveal = sound({
			layer(soundAssets.Chime, 1.08, 0.4, 0.015),
			layer(soundAssets.Sparkle, 1.0, 0.25, 0.07),
		}, 3, 0, -1),
	},
	{
		Name = "Mythic",
		Chance = 100000,
		Color = Color3.fromRGB(255, 60, 90),
		Income = 40000,
		IsNeon = true,
		BuildUpSeconds = 1.5,
		Announce = true,
		Reveal = sound({
			layer(soundAssets.Chime, 1.15, 0.45, 0.015),
			layer(soundAssets.Sparkle, 1.05, 0.3, 0.07),
			layer(soundAssets.Chime, 1.62, 0.25, 0.14),
		}, 3, 1, 0),
	},
	{
		Name = "Secret",
		Chance = 1000000,
		Color = Color3.fromRGB(40, 240, 235),
		Income = 500000,
		IsNeon = true,
		BuildUpSeconds = 1.5,
		Announce = true,
		Reveal = sound({
			layer(soundAssets.Chime, 1.23, 0.5, 0.015),
			layer(soundAssets.Sparkle, 1.16, 0.35, 0.07),
			layer(soundAssets.Chime, 1.85, 0.3, 0.14),
			layer(soundAssets.Sparkle, 1.47, 0.25, 0.22),
		}, 3, 2, 1),
	},
}

type Definition = {
	Id: string,
	Name: string,
	Rarity: string,
	Switch: string,
	Perk: Perk?,
	Flair: { SoundLayer }?,
}

local function perk(kind: PerkKind, amount: number): Perk
	return table.freeze({ Kind = kind, Amount = amount })
end

local lavaFlair: { SoundLayer } = table.freeze({ layer(soundAssets.Thud, 0.5, 0.4) })
local meowFlair: { SoundLayer } = table.freeze({ layer(soundAssets.Chime, 1.6, 0.35, 0.03) })

local definitions: { Definition } = {
	{ Id = "PlainClack", Name = "Plain Clack", Rarity = "Common", Switch = "MxBlack" },
	{ Id = "BeigeBlock", Name = "Beige Block", Rarity = "Common", Switch = "MxRed" },
	{ Id = "OfficeTap", Name = "Office Tap", Rarity = "Common", Switch = "MxBrown" },
	{ Id = "CreamyThock", Name = "Creamy Thock", Rarity = "Uncommon", Switch = "NkCream" },
	{ Id = "MintLinear", Name = "Mint Linear", Rarity = "Uncommon", Switch = "Turquoise" },
	{ Id = "GlassTink", Name = "Glass Tink", Rarity = "Rare", Switch = "MxBlue" },
	{ Id = "TopazTap", Name = "Topaz Tap", Rarity = "Rare", Switch = "EgOreo" },
	{ Id = "CrystalChime", Name = "Crystal Chime", Rarity = "Epic", Switch = "EgCrystalPurple" },
	{ Id = "AmethystPop", Name = "Amethyst Pop", Rarity = "Epic", Switch = "HolyPanda" },
	{ Id = "ThunderKey", Name = "Thunder Key", Rarity = "Legendary", Switch = "ToprePurple" },
	{ Id = "SunburstKey", Name = "Sunburst Key", Rarity = "Legendary", Switch = "HolyPanda" },
	{ Id = "LavaKey", Name = "Lava Key", Rarity = "Mythic", Switch = "ToprePurple", Flair = lavaFlair },
	{ Id = "MeowKey", Name = "Meow Key", Rarity = "Secret", Switch = "CreamTravel", Flair = meowFlair },
	{
		Id = "CloverCap",
		Name = "Clover Cap",
		Rarity = "Uncommon",
		Switch = "CreamTravel",
		Perk = perk("Luck", 0.1),
	},
	{
		Id = "TurboSwitch",
		Name = "Turbo Switch",
		Rarity = "Rare",
		Switch = "MxBrownPbt",
		Perk = perk("Speed", 0.15),
	},
	{
		Id = "GoldPlate",
		Name = "Gold Plate",
		Rarity = "Epic",
		Switch = "MxBrown",
		Perk = perk("Income", 0.25),
	},
	{
		Id = "FourLeafArtisan",
		Name = "Four-Leaf Artisan",
		Rarity = "Legendary",
		Switch = "NkCream",
		Perk = perk("Luck", 0.5),
	},
}

local rarityByName: { [string]: Rarity } = {}
for _, rarity in rarities do
	table.freeze(rarity)
	rarityByName[rarity.Name] = rarity
end

local catalog: { Key } = {}
local byId: { [string]: Key } = {}
local byRarity: { [string]: { Key } } = {}
for _, rarity in rarities do
	byRarity[rarity.Name] = {}
end
for index, definition in definitions do
	local key: Key = {
		Id = definition.Id,
		Name = definition.Name,
		Rarity = definition.Rarity,
		Index = index,
		Perk = definition.Perk,
		Switch = definition.Switch,
		Flair = definition.Flair,
	}
	assert(SwitchSounds.Switches[key.Switch] ~= nil, `Unknown switch {key.Switch}`)
	assert(rarityByName[key.Rarity] ~= nil, `Unknown rarity {key.Rarity}`)
	table.freeze(key)
	catalog[index] = key
	byId[key.Id] = key
	table.insert(byRarity[key.Rarity], key)
end
for _, group in byRarity do
	table.freeze(group)
end

local Keys = {
	SoundAssets = table.freeze(soundAssets),
	RollKeySwitch = "CreamTravel",
	Rarities = table.freeze(rarities),
	RarityByName = table.freeze(rarityByName),
	Catalog = table.freeze(catalog),
	ById = table.freeze(byId),
	ByRarity = table.freeze(byRarity),
}

function Keys.GetRarity(key: Key): Rarity
	return rarityByName[key.Rarity]
end

function Keys.GetIncome(keyId: string): number
	local key = byId[keyId]
	return if key then rarityByName[key.Rarity].Income else 0
end

function Keys.GetSellValue(keyId: string): number
	return math.max(10, Keys.GetIncome(keyId) * 30)
end

return table.freeze(Keys)
