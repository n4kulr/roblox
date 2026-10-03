--!strict

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
	Sound: SoundSettings,
}

export type Key = {
	Id: string,
	Name: string,
	Rarity: string,
	Index: number,
}

local soundAssets = {
	Thock = "rbxasset://sounds/clickfast.wav",
	Thud = "rbxasset://sounds/clickfast.wav",
	Chime = "rbxasset://sounds/electronicpingshort.wav",
	Sparkle = "rbxasset://sounds/electronicpingshort.wav",
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
		Sound = sound({ layer(soundAssets.Thock, 0.6, 0.65) }, 6, -3, -26),
	},
	{
		Name = "Uncommon",
		Chance = 8,
		Color = Color3.fromRGB(110, 220, 120),
		Income = 4,
		IsNeon = false,
		BuildUpSeconds = 0,
		Announce = false,
		Sound = sound({
			layer(soundAssets.Thock, 0.58, 0.65),
			layer(soundAssets.Thud, 0.4, 0.3),
		}, 7, -2, -24),
	},
	{
		Name = "Rare",
		Chance = 50,
		Color = Color3.fromRGB(70, 140, 255),
		Income = 20,
		IsNeon = false,
		BuildUpSeconds = 0,
		Announce = false,
		Sound = sound({
			layer(soundAssets.Thock, 0.52, 0.7),
			layer(soundAssets.Thud, 0.36, 0.45, 0.005),
		}, 8, -2, -18),
	},
	{
		Name = "Epic",
		Chance = 500,
		Color = Color3.fromRGB(180, 80, 255),
		Income = 150,
		IsNeon = true,
		BuildUpSeconds = 0.6,
		Announce = false,
		Sound = sound({
			layer(soundAssets.Thock, 0.52, 0.7),
			layer(soundAssets.Thud, 0.36, 0.45, 0.005),
			layer(soundAssets.Chime, 1.3, 0.3, 0.015),
		}, 7, 0, -8),
	},
	{
		Name = "Legendary",
		Chance = 5000,
		Color = Color3.fromRGB(255, 190, 40),
		Income = 1500,
		IsNeon = true,
		BuildUpSeconds = 1.0,
		Announce = true,
		Sound = sound({
			layer(soundAssets.Thock, 0.5, 0.75),
			layer(soundAssets.Thud, 0.34, 0.5, 0.005),
			layer(soundAssets.Chime, 1.4, 0.4, 0.015),
			layer(soundAssets.Sparkle, 1.9, 0.25, 0.07),
		}, 6, 0, -3),
	},
	{
		Name = "Mythic",
		Chance = 100000,
		Color = Color3.fromRGB(255, 60, 90),
		Income = 40000,
		IsNeon = true,
		BuildUpSeconds = 1.5,
		Announce = true,
		Sound = sound({
			layer(soundAssets.Thock, 0.48, 0.8),
			layer(soundAssets.Thud, 0.32, 0.55, 0.005),
			layer(soundAssets.Chime, 1.5, 0.45, 0.015),
			layer(soundAssets.Sparkle, 2.0, 0.3, 0.07),
			layer(soundAssets.Chime, 2.1, 0.25, 0.14),
		}, 6, 1, 0),
	},
	{
		Name = "Secret",
		Chance = 1000000,
		Color = Color3.fromRGB(40, 240, 235),
		Income = 500000,
		IsNeon = true,
		BuildUpSeconds = 1.5,
		Announce = true,
		Sound = sound({
			layer(soundAssets.Thock, 0.45, 0.85),
			layer(soundAssets.Thud, 0.3, 0.6, 0.005),
			layer(soundAssets.Chime, 1.6, 0.5, 0.015),
			layer(soundAssets.Sparkle, 2.2, 0.35, 0.07),
			layer(soundAssets.Chime, 2.4, 0.3, 0.14),
			layer(soundAssets.Sparkle, 2.8, 0.25, 0.22),
		}, 6, 2, 2),
	},
}

local definitions: { { string } } = {
	{ "PlainClack", "Plain Clack", "Common" },
	{ "BeigeBlock", "Beige Block", "Common" },
	{ "OfficeTap", "Office Tap", "Common" },
	{ "CreamyThock", "Creamy Thock", "Uncommon" },
	{ "MintLinear", "Mint Linear", "Uncommon" },
	{ "GlassTink", "Glass Tink", "Rare" },
	{ "TopazTap", "Topaz Tap", "Rare" },
	{ "CrystalChime", "Crystal Chime", "Epic" },
	{ "AmethystPop", "Amethyst Pop", "Epic" },
	{ "ThunderKey", "Thunder Key", "Legendary" },
	{ "SunburstKey", "Sunburst Key", "Legendary" },
	{ "LavaKey", "Lava Key", "Mythic" },
	{ "MeowKey", "Meow Key", "Secret" },
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
		Id = definition[1],
		Name = definition[2],
		Rarity = definition[3],
		Index = index,
	}
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

return table.freeze(Keys)
