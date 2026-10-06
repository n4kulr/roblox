--!strict

local Config = script.Parent.Parent.Config
local GameConfig = require(Config.GameConfig)
local Keys = require(Config.Keys)

export type Offer = { [string]: number }
export type Inventory = { [string]: number }

local rarityRank: { [string]: number } = {}
for index, rarity in Keys.Rarities do
	rarityRank[rarity.Name] = index
end

local Trade = {
	Reasons = table.freeze({
		UnknownKey = "That key doesn't exist!",
		BadCount = "That's not a good amount!",
		NotOwned = "You don't have that many!",
		TooMany = "That's too many different keys!",
	}),
}

local function isCount(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge and value % 1 == 0
end

local function distinctCount(offer: Offer): number
	local total = 0
	for _, count in offer do
		if count > 0 then
			total += 1
		end
	end
	return total
end

function Trade.ValidateOffer(
	inventory: Inventory,
	offer: Offer,
	keyId: string,
	count: number
): (boolean, string?)
	if type(keyId) ~= "string" or Keys.Resolve(keyId) == nil then
		return false, Trade.Reasons.UnknownKey
	end
	if not isCount(count) or count < 0 then
		return false, Trade.Reasons.BadCount
	end
	if count > (inventory[keyId] or 0) then
		return false, Trade.Reasons.NotOwned
	end
	if
		count > 0
		and (offer[keyId] or 0) == 0
		and distinctCount(offer) >= GameConfig.Trade.MaxDistinctKeys
	then
		return false, Trade.Reasons.TooMany
	end
	return true, nil
end

local function isHeld(inventory: Inventory, offer: Offer): boolean
	for keyId, count in offer do
		if
			Keys.Resolve(keyId) == nil
			or not isCount(count)
			or count < 0
			or count > (inventory[keyId] or 0)
		then
			return false
		end
	end
	return distinctCount(offer) <= GameConfig.Trade.MaxDistinctKeys
end

function Trade.IsEmpty(offer: Offer): boolean
	return distinctCount(offer) == 0
end

function Trade.CanExecute(inventoryA: Inventory, offerA: Offer, inventoryB: Inventory, offerB: Offer): boolean
	if Trade.IsEmpty(offerA) and Trade.IsEmpty(offerB) then
		return false
	end
	return isHeld(inventoryA, offerA) and isHeld(inventoryB, offerB)
end

local function swapped(inventory: Inventory, giving: Offer, receiving: Offer): Inventory
	local out: Inventory = {}
	for keyId, count in inventory do
		if count > 0 then
			out[keyId] = count
		end
	end
	for keyId, count in giving do
		if count > 0 then
			local remaining = (out[keyId] or 0) - count
			if remaining > 0 then
				out[keyId] = remaining
			else
				out[keyId] = nil
			end
		end
	end
	for keyId, count in receiving do
		if count > 0 then
			out[keyId] = (out[keyId] or 0) + count
		end
	end
	return out
end

function Trade.Apply(
	inventoryA: Inventory,
	offerA: Offer,
	inventoryB: Inventory,
	offerB: Offer
): (Inventory, Inventory)
	return swapped(inventoryA, offerA, offerB), swapped(inventoryB, offerB, offerA)
end

function Trade.IsAtLeast(keyId: string, rarityName: string): boolean
	local key = Keys.Resolve(keyId)
	local minimum = rarityRank[rarityName]
	return key ~= nil and minimum ~= nil and (rarityRank[key.Rarity] or 0) >= minimum
end

return Trade
