--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Keys = require(ReplicatedStorage.Config.Keys)
local Boosts = require(ReplicatedStorage.Rules.Boosts)

local Rewards = {}

function Rewards.ExtendPotion(
	player: Player,
	services: { [string]: any },
	field: string,
	seconds: number
): boolean
	local data = services.DataService:GetData(player)
	local replica = services.DataService:GetReplica(player)
	if not data or not replica then
		return false
	end
	if field == "ClicksUntil" then
		services.KeyboardService:Settle(player)
	end
	replica:SetValues({ "Boosts" }, { [field] = Boosts.Extend(data.Boosts[field], os.time(), seconds) })
	return true
end

function Rewards.GrantRandomKey(player: Player, services: { [string]: any }, rarity: string): boolean
	local group = Keys.ByRarity[rarity]
	local data = services.DataService:GetData(player)
	if not group or not data then
		return false
	end
	local key = group[Random.new():NextInteger(1, #group)]
	if not services.KeyboardService:AddKey(player, key.Id) then
		return false
	end
	services.DataService:Set(player, { "Discovered", key.Id }, (data.Discovered[key.Id] or 0) + 1)
	return true
end

return Rewards
