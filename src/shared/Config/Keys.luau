--!strict

local KeyTiers = require(script.Parent.KeyTiers)
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
	IsShiny: boolean,
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
	Exclusive: boolean,
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
		IsShiny = false,
		BuildUpSeconds = 0,
		Announce = false,
		Reveal = nil,
	},
	{
		Name = "Uncommon",
		Chance = 10,
		Color = Color3.fromRGB(110, 220, 120),
		Income = 6,
		IsShiny = false,
		BuildUpSeconds = 0,
		Announce = false,
		Reveal = nil,
	},
	{
		Name = "Rare",
		Chance = 120,
		Color = Color3.fromRGB(70, 140, 255),
		Income = 40,
		IsShiny = false,
		BuildUpSeconds = 0,
		Announce = false,
		Reveal = nil,
	},
	{
		Name = "Epic",
		Chance = 2400,
		Color = Color3.fromRGB(180, 80, 255),
		Income = 400,
		IsShiny = true,
		BuildUpSeconds = 0.6,
		Announce = false,
		Reveal = sound({
			layer(soundAssets.Chime, 1.0, 0.3, 0.015),
		}, 4, 0, -3),
	},
	{
		Name = "Legendary",
		Chance = 50000,
		Color = Color3.fromRGB(255, 190, 40),
		Income = 4000,
		IsShiny = true,
		BuildUpSeconds = 1.0,
		Announce = true,
		Reveal = sound({
			layer(soundAssets.Chime, 1.08, 0.4, 0.015),
			layer(soundAssets.Sparkle, 1.0, 0.25, 0.07),
		}, 3, 0, -1),
	},
	{
		Name = "Mythic",
		Chance = 2000000,
		Color = Color3.fromRGB(255, 60, 90),
		Income = 40000,
		IsShiny = true,
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
		Chance = 15000000,
		Color = Color3.fromRGB(40, 240, 235),
		Income = 400000,
		IsShiny = true,
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
	Exclusive: boolean?,
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
	{
		Id = "GoldenSpacebar",
		Name = "Golden Spacebar",
		Rarity = "Mythic",
		Switch = "ToprePurple",
		Perk = perk("Income", 0.5),
		Exclusive = true,
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
		Exclusive = definition.Exclusive == true,
	}
	assert(SwitchSounds.Switches[key.Switch] ~= nil, `Unknown switch {key.Switch}`)
	assert(rarityByName[key.Rarity] ~= nil, `Unknown rarity {key.Rarity}`)
	table.freeze(key)
	catalog[index] = key
	byId[key.Id] = key
	if not key.Exclusive then
		table.insert(byRarity[key.Rarity], key)
	end
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

function Keys.ApplyFinish(part: BasePart, rarity: Rarity)
	part.Material = Enum.Material.SmoothPlastic
	part.Reflectance = if rarity.IsShiny then 0.22 else 0
end

function Keys.VariantStyle(keyId: string): (Color3, number, Enum.Material)
	local baseId, tier = KeyTiers.Parse(keyId)
	local key = byId[baseId]
	local rarity = if key then rarityByName[key.Rarity] else rarities[1]
	local base = rarity.Color
	if tier == 1 then
		return base:Lerp(KeyTiers.Get(1).Color, 0.7), 0.3, Enum.Material.Metal
	elseif tier == 2 then
		return base:Lerp(KeyTiers.Get(2).Color, 0.6), 0.4, Enum.Material.SmoothPlastic
	elseif tier == 3 then
		return base:Lerp(Color3.fromRGB(40, 16, 82), 0.75), 0.5, Enum.Material.Metal
	end
	return base, if rarity.IsShiny then 0.22 else 0, Enum.Material.SmoothPlastic
end

function Keys.ApplyVariantFinish(part: BasePart, keyId: string)
	local color, reflectance, material = Keys.VariantStyle(keyId)
	part.Color = color
	part.Material = material
	part.Reflectance = reflectance
end

function Keys.Resolve(id: any): Key?
	if type(id) ~= "string" then
		return nil
	end
	local baseId = KeyTiers.Parse(id)
	return byId[baseId]
end

function Keys.GetIncome(keyId: string): number
	local baseId, tier = KeyTiers.Parse(keyId)
	local key = byId[baseId]
	return if key then rarityByName[key.Rarity].Income * KeyTiers.Multiplier(tier) else 0
end

function Keys.GetSellValue(keyId: string): number
	return math.max(10, Keys.GetIncome(keyId) * 30)
end

return table.freeze(Keys)
