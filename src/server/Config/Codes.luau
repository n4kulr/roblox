--!strict

export type CodeReward = {
	Kind: "Clicks" | "LuckPotion" | "ClicksPotion" | "Key",
	Amount: number,
	Rarity: string?,
	Label: string,
}

export type Code = {
	Code: string,
	Reward: CodeReward,
	ExpiresAt: number?,
}

local codes: { Code } = {
	{ Code = "THOCK", Reward = { Kind = "Clicks", Amount = 1000, Label = "1K Clicks" } },
	{ Code = "RELEASE", Reward = { Kind = "LuckPotion", Amount = 900, Label = "2x Luck (15 min)" } },
	{ Code = "CLACKY", Reward = { Kind = "Key", Amount = 1, Rarity = "Rare", Label = "Rare Key" } },
}

local byCode: { [string]: Code } = {}
for _, code in codes do
	byCode[string.upper(code.Code)] = code
end

return table.freeze({
	ByCode = table.freeze(byCode),
})
