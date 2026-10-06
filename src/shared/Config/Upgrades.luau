--!strict

export type UpgradeId = "Luck" | "Speed" | "Slots" | "Income" | "Walls" | "LockTime" | "Golden"

export type Category = "Keys" | "Defense"

export type Upgrade = {
	Id: UpgradeId,
	Name: string,
	Glyph: string,
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
		Name = "Lucky Charm",
		Glyph = "Luck",
		Description = "Find rarer keys more often!",
		Effect = "+10% Luck each level",
		Category = "Keys",
		MaxLevel = 120,
		BaseCost = 150,
		Growth = 1.25,
		PerLevel = 0.1,
	},
	{
		Id = "Speed",
		Name = "Fast Fingers",
		Glyph = "Speed",
		Description = "Roll keys even faster!",
		Effect = "+0.5 rolls per second each level",
		Category = "Keys",
		MaxLevel = 14,
		BaseCost = 3000,
		Growth = 3,
		PerLevel = 0.5,
	},
	{
		Id = "Slots",
		Name = "Bigger Keyboard",
		Glyph = "Slots",
		Description = "Hold more keys and earn more Clicks!",
		Effect = "+1 keyboard slot each level",
		Category = "Keys",
		MaxLevel = 5,
		BaseCost = 8000,
		Growth = 5,
		PerLevel = 1,
	},
	{
		Id = "Income",
		Name = "Money Maker",
		Glyph = "Income",
		Description = "Every key earns more Clicks!",
		Effect = "+10% Clicks each level",
		Category = "Keys",
		MaxLevel = 100,
		BaseCost = 800,
		Growth = 1.27,
		PerLevel = 0.1,
	},
	{
		Id = "Golden",
		Name = "Golden Touch",
		Glyph = "Golden",
		Description = "Reach your Golden Roll sooner!",
		Effect = "-5 rolls to a Golden Roll each level",
		Category = "Keys",
		MaxLevel = 15,
		BaseCost = 4000,
		Growth = 2.6,
		PerLevel = 5,
	},
	{
		Id = "Walls",
		Name = "Taller Walls",
		Glyph = "Walls",
		Description = "Build your base walls higher!",
		Effect = "+3 wall height each level",
		Category = "Defense",
		MaxLevel = 5,
		BaseCost = 300000,
		Growth = 3.2,
		PerLevel = 3,
	},
	{
		Id = "LockTime",
		Name = "Laser Lock",
		Glyph = "LockTime",
		Description = "Lasers block thieves for longer!",
		Effect = "+10 seconds of lasers each level",
		Category = "Defense",
		MaxLevel = 10,
		BaseCost = 1000000,
		Growth = 2.0,
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
