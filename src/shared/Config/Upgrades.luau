--!strict

export type UpgradeId = "Luck" | "Speed" | "Slots"

export type Upgrade = {
	Id: UpgradeId,
	Name: string,
	Description: string,
	MaxLevel: number,
	BaseCost: number,
	Growth: number,
	PerLevel: number,
}

local list: { Upgrade } = {
	{
		Id = "Luck",
		Name = "Luck",
		Description = "+10% luck per level",
		MaxLevel = 20,
		BaseCost = 100,
		Growth = 1.6,
		PerLevel = 0.1,
	},
	{
		Id = "Speed",
		Name = "Roll Speed",
		Description = "+0.3 rolls per second per level",
		MaxLevel = 10,
		BaseCost = 250,
		Growth = 1.75,
		PerLevel = 0.3,
	},
	{
		Id = "Slots",
		Name = "Keyboard Slots",
		Description = "+2 keyboard slots per level",
		MaxLevel = 10,
		BaseCost = 500,
		Growth = 2.2,
		PerLevel = 2,
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
