--!strict

export type RewardKind = "Clicks" | "LuckPotion" | "ClicksPotion" | "Key"

export type Reward = {
	Kind: RewardKind,
	Amount: number,
	Rarity: string?,
	Label: string,
}

export type Level = {
	Level: number,
	Free: Reward,
	Premium: Reward,
}

local function clicks(amount: number, label: string): Reward
	return table.freeze({ Kind = "Clicks" :: RewardKind, Amount = amount, Label = label })
end

local function potion(kind: RewardKind, seconds: number, label: string): Reward
	return table.freeze({ Kind = kind, Amount = seconds, Label = label })
end

local function key(rarity: string, label: string): Reward
	return table.freeze({ Kind = "Key" :: RewardKind, Amount = 1, Rarity = rarity, Label = label })
end

local levels: { Level } = {}
for level = 1, 30 do
	local free: Reward
	local premium: Reward
	if level % 10 == 0 then
		free = key(
			if level == 30 then "Legendary" else "Epic",
			if level == 30 then "Legendary Key" else "Epic Key"
		)
		premium = key(
			if level == 30 then "Mythic" else "Legendary",
			if level == 30 then "Mythic Key!" else "Legendary Key"
		)
	elseif level % 5 == 0 then
		free = key("Rare", "Rare Key")
		premium = key("Epic", "Epic Key")
	elseif level % 3 == 0 then
		free = potion("LuckPotion", 300, "2x Luck (5 min)")
		premium = potion("LuckPotion", 900, "2x Luck (15 min)")
	elseif level % 2 == 0 then
		free = potion("ClicksPotion", 300, "2x Clicks (5 min)")
		premium = potion("ClicksPotion", 900, "2x Clicks (15 min)")
	else
		free = clicks(1000 * level, `{level}K Clicks`)
		premium = clicks(5000 * level, `{level * 5}K Clicks`)
	end
	levels[level] = table.freeze({ Level = level, Free = free, Premium = premium })
end

return table.freeze({
	Levels = table.freeze(levels),
})
