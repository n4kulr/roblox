--!strict

export type SoundSettings = {
	SoundId: string,
	PlaybackSpeed: number,
	Volume: number,
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

local clickSound = "rbxasset://sounds/clickfast.wav"
local chimeSound = "rbxasset://sounds/electronicpingshort.wav"

local rarities: { Rarity } = {
	{
		Name = "Common",
		Chance = 1,
		Color = Color3.fromRGB(200, 200, 205),
		Income = 1,
		IsNeon = false,
		BuildUpSeconds = 0,
		Announce = false,
		Sound = { SoundId = clickSound, PlaybackSpeed = 1.0, Volume = 0.5 },
	},
	{
		Name = "Uncommon",
		Chance = 8,
		Color = Color3.fromRGB(110, 220, 120),
		Income = 4,
		IsNeon = false,
		BuildUpSeconds = 0,
		Announce = false,
		Sound = { SoundId = clickSound, PlaybackSpeed = 1.15, Volume = 0.55 },
	},
	{
		Name = "Rare",
		Chance = 50,
		Color = Color3.fromRGB(70, 140, 255),
		Income = 20,
		IsNeon = false,
		BuildUpSeconds = 0,
		Announce = false,
		Sound = { SoundId = clickSound, PlaybackSpeed = 0.75, Volume = 0.7 },
	},
	{
		Name = "Epic",
		Chance = 500,
		Color = Color3.fromRGB(180, 80, 255),
		Income = 150,
		IsNeon = true,
		BuildUpSeconds = 0.6,
		Announce = false,
		Sound = { SoundId = chimeSound, PlaybackSpeed = 1.0, Volume = 0.8 },
	},
	{
		Name = "Legendary",
		Chance = 5000,
		Color = Color3.fromRGB(255, 190, 40),
		Income = 1500,
		IsNeon = true,
		BuildUpSeconds = 1.0,
		Announce = true,
		Sound = { SoundId = chimeSound, PlaybackSpeed = 1.2, Volume = 0.9 },
	},
	{
		Name = "Mythic",
		Chance = 100000,
		Color = Color3.fromRGB(255, 60, 90),
		Income = 40000,
		IsNeon = true,
		BuildUpSeconds = 1.5,
		Announce = true,
		Sound = { SoundId = chimeSound, PlaybackSpeed = 1.45, Volume = 1 },
	},
	{
		Name = "Secret",
		Chance = 1000000,
		Color = Color3.fromRGB(40, 240, 235),
		Income = 500000,
		IsNeon = true,
		BuildUpSeconds = 1.5,
		Announce = true,
		Sound = { SoundId = chimeSound, PlaybackSpeed = 1.75, Volume = 1 },
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
	table.freeze(rarity.Sound)
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
