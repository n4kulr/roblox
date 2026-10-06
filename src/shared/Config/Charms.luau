--!strict

export type Kind = "Income" | "Luck" | "Speed" | "Golden" | "Steal" | "Laser"

export type Rarity = {
	Name: string,
	Order: number,
	Color: Color3,
}

export type KindInfo = {
	Label: string,
	Glyph: string,
	Color: Color3,
}

export type Charm = {
	Id: string,
	Name: string,
	Rarity: string,
	Kind: Kind,
	Amount: number,
	Color: Color3,
}

local rarities: { Rarity } = {
	{ Name = "Common", Order = 1, Color = Color3.fromRGB(200, 200, 205) },
	{ Name = "Uncommon", Order = 2, Color = Color3.fromRGB(110, 220, 120) },
	{ Name = "Rare", Order = 3, Color = Color3.fromRGB(70, 140, 255) },
	{ Name = "Epic", Order = 4, Color = Color3.fromRGB(180, 80, 255) },
	{ Name = "Legendary", Order = 5, Color = Color3.fromRGB(255, 190, 40) },
	{ Name = "Mythic", Order = 6, Color = Color3.fromRGB(255, 60, 90) },
}

local kinds: { [string]: KindInfo } = {
	Income = { Label = "Income", Glyph = "Income", Color = Color3.fromRGB(255, 200, 40) },
	Luck = { Label = "Luck", Glyph = "Luck", Color = Color3.fromRGB(96, 214, 90) },
	Speed = { Label = "Roll Speed", Glyph = "Speed", Color = Color3.fromRGB(255, 226, 70) },
	Golden = { Label = "Golden Roll", Glyph = "Golden", Color = Color3.fromRGB(255, 170, 40) },
	Steal = { Label = "Steal Speed", Glyph = "Thief", Color = Color3.fromRGB(170, 120, 255) },
	Laser = { Label = "Laser Time", Glyph = "LockTime", Color = Color3.fromRGB(255, 90, 100) },
}

local definitions: { { Id: string, Name: string, Rarity: string, Kind: Kind, Amount: number } } = {
	{ Id = "KeycapPin", Name = "Keycap Pin", Rarity = "Common", Kind = "Income", Amount = 1.25 },
	{ Id = "CloverFob", Name = "Clover Fob", Rarity = "Common", Kind = "Luck", Amount = 1.2 },
	{ Id = "TinySwitch", Name = "Tiny Switch", Rarity = "Common", Kind = "Speed", Amount = 0.1 },
	{ Id = "BrassStab", Name = "Brass Stabilizer", Rarity = "Uncommon", Kind = "Income", Amount = 1.5 },
	{ Id = "LuckyLube", Name = "Lucky Lube", Rarity = "Uncommon", Kind = "Luck", Amount = 1.4 },
	{ Id = "QuickSpring", Name = "Quick Spring", Rarity = "Uncommon", Kind = "Speed", Amount = 0.2 },
	{ Id = "GoldenTick", Name = "Golden Tick", Rarity = "Uncommon", Kind = "Golden", Amount = 5 },
	{ Id = "ThockPad", Name = "Thock Pad", Rarity = "Rare", Kind = "Income", Amount = 2 },
	{ Id = "LuckyCable", Name = "Lucky Cable", Rarity = "Rare", Kind = "Luck", Amount = 1.8 },
	{ Id = "TurboSpring", Name = "Turbo Spring", Rarity = "Rare", Kind = "Speed", Amount = 0.3 },
	{ Id = "GoldTab", Name = "Gold Tab", Rarity = "Rare", Kind = "Golden", Amount = 10 },
	{ Id = "StickyFingers", Name = "Sticky Fingers", Rarity = "Rare", Kind = "Steal", Amount = 0.25 },
	{ Id = "LaserLens", Name = "Laser Lens", Rarity = "Rare", Kind = "Laser", Amount = 10 },
	{ Id = "RainbowCoil", Name = "Rainbow Coil", Rarity = "Epic", Kind = "Income", Amount = 3 },
	{ Id = "FourLeafCap", Name = "Four-Leaf Cap", Rarity = "Epic", Kind = "Luck", Amount = 2.2 },
	{ Id = "HyperSwitch", Name = "Hyper Switch", Rarity = "Epic", Kind = "Speed", Amount = 0.4 },
	{ Id = "GoldenGear", Name = "Golden Gear", Rarity = "Epic", Kind = "Golden", Amount = 15 },
	{ Id = "GhostHand", Name = "Ghost Hand", Rarity = "Epic", Kind = "Steal", Amount = 0.5 },
	{ Id = "LaserCore", Name = "Laser Core", Rarity = "Epic", Kind = "Laser", Amount = 20 },
	{ Id = "GoldSpacebar", Name = "Gold Spacebar", Rarity = "Legendary", Kind = "Income", Amount = 5 },
	{ Id = "CloverCrown", Name = "Clover Crown", Rarity = "Legendary", Kind = "Luck", Amount = 3 },
	{ Id = "LightningSwitch", Name = "Lightning Switch", Rarity = "Legendary", Kind = "Speed", Amount = 0.5 },
	{ Id = "MidasKey", Name = "Midas Key", Rarity = "Legendary", Kind = "Golden", Amount = 25 },
	{ Id = "PhantomPaw", Name = "Phantom Paw", Rarity = "Legendary", Kind = "Steal", Amount = 1 },
	{ Id = "MegaLaser", Name = "Mega Laser", Rarity = "Legendary", Kind = "Laser", Amount = 30 },
	{ Id = "DiamondSpacebar", Name = "Diamond Spacebar", Rarity = "Mythic", Kind = "Income", Amount = 10 },
}

local rarityByName: { [string]: Rarity } = {}
for _, rarity in rarities do
	table.freeze(rarity)
	rarityByName[rarity.Name] = rarity
end

local catalog: { Charm } = {}
local byId: { [string]: Charm } = {}
local byRarity: { [string]: { Charm } } = {}
for _, rarity in rarities do
	byRarity[rarity.Name] = {}
end
for _, definition in definitions do
	assert(rarityByName[definition.Rarity] ~= nil, `Unknown charm rarity {definition.Rarity}`)
	assert(kinds[definition.Kind] ~= nil, `Unknown charm kind {definition.Kind}`)
	local charm: Charm = {
		Id = definition.Id,
		Name = definition.Name,
		Rarity = definition.Rarity,
		Kind = definition.Kind,
		Amount = definition.Amount,
		Color = rarityByName[definition.Rarity].Color,
	}
	table.freeze(charm)
	table.insert(catalog, charm)
	byId[charm.Id] = charm
	table.insert(byRarity[charm.Rarity], charm)
end
for _, group in byRarity do
	table.freeze(group)
end
for _, kind in kinds do
	table.freeze(kind)
end

local Charms = {
	EquipLimit = 3,
	Rarities = table.freeze(rarities),
	RarityByName = table.freeze(rarityByName),
	Kinds = table.freeze(kinds),
	Catalog = table.freeze(catalog),
	ById = table.freeze(byId),
	ByRarity = table.freeze(byRarity),
}

return table.freeze(Charms)
