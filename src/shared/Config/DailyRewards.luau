--!strict

export type RewardKind = "Clicks" | "LuckPotion" | "ClicksPotion" | "Key"

export type Reward = {
	Day: number,
	Kind: RewardKind,
	Amount: number,
	Rarity: string?,
	Label: string,
}

local rewards: { Reward } = {
	{ Day = 1, Kind = "Clicks", Amount = 500, Label = "500 Clicks" },
	{ Day = 2, Kind = "LuckPotion", Amount = 600, Label = "2x Luck (10 min)" },
	{ Day = 3, Kind = "Clicks", Amount = 2500, Label = "2.5K Clicks" },
	{ Day = 4, Kind = "Key", Amount = 1, Rarity = "Rare", Label = "Rare Key" },
	{ Day = 5, Kind = "ClicksPotion", Amount = 1800, Label = "2x Clicks (30 min)" },
	{ Day = 6, Kind = "Clicks", Amount = 15000, Label = "15K Clicks" },
	{ Day = 7, Kind = "Key", Amount = 1, Rarity = "Epic", Label = "Epic Key!" },
}

for _, reward in rewards do
	table.freeze(reward)
end

return table.freeze({
	Rewards = table.freeze(rewards),
})
