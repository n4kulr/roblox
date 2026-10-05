--!strict

export type UpgradeId = "Luck" | "Speed" | "Slots" | "Income" | "Walls" | "LockTime" | "Golden"

export type Category = "Keys" | "Defense"

export type Upgrade = {
	Id: UpgradeId,
	Name: string,
	Description: string,
	Effect: string,
	Category: Category,
	MaxLevel: number,
	BaseCost: number,
	Growth: number,
	PerLevel: number,
}

local list: { Upgrade } = {
	{
		Id = "Luck",
		Name = "🍀 Lucky Charm",
		Description = "Find rarer keys more often!",
		Effect = "+10% Luck each level",
		Category = "Keys",
		MaxLevel = 75,
		BaseCost = 100,
		Growth = 1.22,
		PerLevel = 0.1,
	},
	{
		Id = "Speed",
		Name = "⚡ Fast Fingers",
		Description = "Roll keys even faster!",
		Effect = "+0.5 rolls per second each level",
		Category = "Keys",
		MaxLevel = 10,
		BaseCost = 250,
		Growth = 1.75,
		PerLevel = 0.5,
	},
	{
		Id = "Slots",
		Name = "⌨️ Bigger Keyboard",
		Description = "Hold more keys and earn more Clicks!",
		Effect = "+2 keyboard slots each level",
		Category = "Keys",
		MaxLevel = 25,
		BaseCost = 500,
		Growth = 1.45,
		PerLevel = 2,
	},
	{
		Id = "Income",
		Name = "💰 Money Maker",
		Description = "Every key earns more Clicks!",
		Effect = "+10% Clicks each level",
		Category = "Keys",
		MaxLevel = 50,
		BaseCost = 400,
		Growth = 1.25,
		PerLevel = 0.1,
	},
	{
		Id = "Golden",
		Name = "Golden Touch",
		Description = "Reach your Golden Roll sooner!",
		Effect = "-5 rolls to a Golden Roll each level",
		Category = "Keys",
		MaxLevel = 10,
		BaseCost = 1500,
		Growth = 1.6,
		PerLevel = 5,
	},
	{
		Id = "Walls",
		Name = "🧱 Taller Walls",
		Description = "Build your base walls higher!",
		Effect = "+3 wall height each level",
		Category = "Defense",
		MaxLevel = 5,
		BaseCost = 5000,
		Growth = 3,
		PerLevel = 3,
	},
	{
		Id = "LockTime",
		Name = "🔴 Laser Lock",
		Description = "Lasers block thieves for longer!",
		Effect = "+10 seconds of lasers each level",
		Category = "Defense",
		MaxLevel = 10,
		BaseCost = 20000,
		Growth = 1.9,
		PerLevel = 10,
	},
}

local byId: { [string]: Upgrade } = {}
for _, upgrade in list do
	table.freeze(upgrade)
	byId[upgrade.Id] = upgrade
end

local Upgrades = {
	List = table.freeze(list),
	ById = table.freeze(byId),
}

function Upgrades.Cost(upgrade: Upgrade, level: number): number?
	if level >= upgrade.MaxLevel then
		return nil
	end
	return math.floor(upgrade.BaseCost * upgrade.Growth ^ level)
end

return table.freeze(Upgrades)
