--!strict

export type Tier = {
	Index: number,
	Name: string,
	Suffix: string,
	Multiplier: number,
	Color: Color3,
	Chip: string,
}

local tiers: { Tier } = {
	table.freeze({
		Index = 0,
		Name = "Normal",
		Suffix = "",
		Multiplier = 1,
		Color = Color3.fromRGB(255, 255, 255),
		Chip = "",
	}),
	table.freeze({
		Index = 1,
		Name = "Gold",
		Suffix = "@Gold",
		Multiplier = 3,
		Color = Color3.fromRGB(255, 205, 70),
		Chip = "GOLD",
	}),
	table.freeze({
		Index = 2,
		Name = "Rainbow",
		Suffix = "@Rainbow",
		Multiplier = 10,
		Color = Color3.fromRGB(255, 120, 200),
		Chip = "RAINBOW",
	}),
	table.freeze({
		Index = 3,
		Name = "Mythical",
		Suffix = "@Mythical",
		Multiplier = 40,
		Color = Color3.fromRGB(120, 60, 200),
		Chip = "MYTHICAL",
	}),
}

local bySuffix: { [string]: number } = {}
for _, tier in tiers do
	if tier.Suffix ~= "" then
		bySuffix[tier.Suffix] = tier.Index
	end
end

local KeyTiers = {
	List = table.freeze(tiers),
	MaxTier = #tiers - 1,
	FuseCost = 5,
}

function KeyTiers.Parse(id: string): (string, number)
	local at = string.find(id, "@", 1, true)
	if not at then
		return id, 0
	end
	local tier = bySuffix[string.sub(id, at)]
	if not tier then
		return id, 0
	end
	return string.sub(id, 1, at - 1), tier
end

function KeyTiers.Make(baseId: string, tier: number): string
	local entry = tiers[math.clamp(math.floor(tier), 0, #tiers - 1) + 1]
	return baseId .. entry.Suffix
end

function KeyTiers.Multiplier(tier: number): number
	local entry = tiers[math.floor(tier) + 1]
	return if entry then entry.Multiplier else 1
end

function KeyTiers.Get(tier: number): Tier
	return tiers[math.clamp(math.floor(tier), 0, #tiers - 1) + 1]
end

return table.freeze(KeyTiers)
