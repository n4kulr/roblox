--!strict

local Config = script.Parent.Parent.Config
local KeyTiers = require(Config.KeyTiers)
local Keys = require(Config.Keys)

local Variants = {
	MaxTier = KeyTiers.MaxTier,
	FuseCost = KeyTiers.FuseCost,
	Tiers = KeyTiers.List,
}

function Variants.Parse(id: string): (string, number)
	return KeyTiers.Parse(id)
end

function Variants.Make(baseId: string, tier: number): string
	return KeyTiers.Make(baseId, tier)
end

function Variants.Multiplier(tier: number): number
	return KeyTiers.Multiplier(tier)
end

function Variants.Tier(tier: number): KeyTiers.Tier
	return KeyTiers.Get(tier)
end

function Variants.IsValid(id: string): boolean
	return Keys.Resolve(id) ~= nil
end

function Variants.Name(id: string): string
	local baseId, tier = KeyTiers.Parse(id)
	local key = Keys.ById[baseId]
	local name = if key then key.Name else baseId
	if tier == 0 then
		return name
	end
	return `{KeyTiers.Get(tier).Name} {name}`
end

function Variants.Next(id: string): string?
	local baseId, tier = KeyTiers.Parse(id)
	if tier >= KeyTiers.MaxTier or Keys.ById[baseId] == nil then
		return nil
	end
	return KeyTiers.Make(baseId, tier + 1)
end

return table.freeze(Variants)
