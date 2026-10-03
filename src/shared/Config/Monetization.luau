--!strict

export type Pass = {
	Id: string,
	AssetId: number,
	Name: string,
	Description: string,
	PriceLabel: string,
}

export type ProductKind = "LuckPotion" | "ClicksPotion" | "ServerLuck" | "StarterPack" | "Clicks"

export type Product = {
	Id: string,
	AssetId: number,
	Name: string,
	Description: string,
	PriceLabel: string,
	Kind: ProductKind,
	Amount: number,
	OneTime: boolean,
}

local passes: { Pass } = {
	{
		Id = "DoubleLuck",
		AssetId = 0,
		Name = "🍀 x2 Luck",
		Description = "Double luck forever!",
		PriceLabel = "199",
	},
	{
		Id = "DoubleClicks",
		AssetId = 0,
		Name = "💰 x2 Clicks",
		Description = "Double Clicks forever!",
		PriceLabel = "249",
	},
	{
		Id = "Vip",
		AssetId = 0,
		Name = "👑 VIP",
		Description = "+10% Clicks and a VIP tag!",
		PriceLabel = "299",
	},
}

local products: { Product } = {
	{
		Id = "StarterPack",
		AssetId = 0,
		Name = "🎁 Starter Pack",
		Description = "10K Clicks, 2x Luck potion and an Epic key!",
		PriceLabel = "49",
		Kind = "StarterPack",
		Amount = 10000,
		OneTime = true,
	},
	{
		Id = "LuckPotion",
		AssetId = 0,
		Name = "🍀 Luck Potion",
		Description = "2x Luck for 15 minutes!",
		PriceLabel = "29",
		Kind = "LuckPotion",
		Amount = 900,
		OneTime = false,
	},
	{
		Id = "ClicksPotion",
		AssetId = 0,
		Name = "💰 Clicks Potion",
		Description = "2x Clicks for 15 minutes!",
		PriceLabel = "29",
		Kind = "ClicksPotion",
		Amount = 900,
		OneTime = false,
	},
	{
		Id = "ServerLuck",
		AssetId = 0,
		Name = "🌟 Server Luck",
		Description = "2x Luck for EVERYONE for 10 minutes!",
		PriceLabel = "99",
		Kind = "ServerLuck",
		Amount = 600,
		OneTime = false,
	},
	{
		Id = "ClicksSmall",
		AssetId = 0,
		Name = "💵 Pile of Clicks",
		Description = "+25K Clicks",
		PriceLabel = "25",
		Kind = "Clicks",
		Amount = 25000,
		OneTime = false,
	},
	{
		Id = "ClicksLarge",
		AssetId = 0,
		Name = "💰 Mountain of Clicks",
		Description = "+300K Clicks",
		PriceLabel = "199",
		Kind = "Clicks",
		Amount = 300000,
		OneTime = false,
	},
}

local passById: { [string]: Pass } = {}
for _, pass in passes do
	table.freeze(pass)
	passById[pass.Id] = pass
end
local productById: { [string]: Product } = {}
for _, product in products do
	table.freeze(product)
	productById[product.Id] = product
end

return table.freeze({
	Passes = table.freeze(passes),
	PassById = table.freeze(passById),
	Products = table.freeze(products),
	ProductById = table.freeze(productById),
})
