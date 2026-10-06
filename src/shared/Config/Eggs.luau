--!strict

export type Egg = {
	Id: string,
	Name: string,
	Index: number,
	HatchSeconds: number,
	PriceMinutes: number,
	MinPrice: number,
	StockMin: number,
	StockMax: number,
	AppearChance: number,
	Color: Color3,
	SpotColor: Color3,
	Drops: { [string]: number },
	Tagline: string,
}

local definitions: { Egg } = {
	{
		Id = "Linear",
		Name = "Linear Egg",
		Index = 1,
		HatchSeconds = 120,
		PriceMinutes = 3,
		MinPrice = 250,
		StockMin = 3,
		StockMax = 6,
		AppearChance = 1,
		Color = Color3.fromRGB(235, 90, 80),
		SpotColor = Color3.fromRGB(255, 220, 210),
		Drops = { Common = 70, Uncommon = 26, Rare = 4 },
		Tagline = "Smooth and simple",
	},
	{
		Id = "Tactile",
		Name = "Tactile Egg",
		Index = 2,
		HatchSeconds = 480,
		PriceMinutes = 12,
		MinPrice = 2500,
		StockMin = 2,
		StockMax = 4,
		AppearChance = 1,
		Color = Color3.fromRGB(170, 120, 255),
		SpotColor = Color3.fromRGB(235, 220, 255),
		Drops = { Common = 35, Uncommon = 40, Rare = 20, Epic = 5 },
		Tagline = "Bumpy and bouncy",
	},
	{
		Id = "Clicky",
		Name = "Clicky Egg",
		Index = 3,
		HatchSeconds = 1200,
		PriceMinutes = 30,
		MinPrice = 25000,
		StockMin = 1,
		StockMax = 3,
		AppearChance = 0.85,
		Color = Color3.fromRGB(70, 170, 255),
		SpotColor = Color3.fromRGB(215, 240, 255),
		Drops = { Uncommon = 30, Rare = 45, Epic = 22, Legendary = 3 },
		Tagline = "Loud and proud",
	},
	{
		Id = "Golden",
		Name = "Golden Egg",
		Index = 4,
		HatchSeconds = 2700,
		PriceMinutes = 90,
		MinPrice = 250000,
		StockMin = 1,
		StockMax = 2,
		AppearChance = 0.6,
		Color = Color3.fromRGB(255, 200, 50),
		SpotColor = Color3.fromRGB(255, 245, 190),
		Drops = { Rare = 45, Epic = 40, Legendary = 15 },
		Tagline = "Shiny and rich",
	},
	{
		Id = "Rainbow",
		Name = "Rainbow Egg",
		Index = 5,
		HatchSeconds = 7200,
		PriceMinutes = 240,
		MinPrice = 2500000,
		StockMin = 1,
		StockMax = 1,
		AppearChance = 0.35,
		Color = Color3.fromRGB(255, 110, 190),
		SpotColor = Color3.fromRGB(120, 235, 255),
		Drops = { Epic = 50, Legendary = 49, Mythic = 1 },
		Tagline = "Insane power inside",
	},
}

local catalog: { Egg } = {}
local byId: { [string]: Egg } = {}
for _, egg in definitions do
	table.freeze(egg.Drops)
	table.freeze(egg)
	table.insert(catalog, egg)
	byId[egg.Id] = egg
end

return table.freeze({
	BagCap = 10,
	PlacedCap = 3,
	PlaceSpacing = 4,
	PlaceInset = 2,
	RollKeyClear = 1.5,
	PriceSpreadMin = 0.8,
	PriceSpreadMax = 1.3,
	DealBelow = 0.92,
	Catalog = table.freeze(catalog),
	ById = table.freeze(byId),
})
