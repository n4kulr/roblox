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

function Rewards.AddClicks(player: Player, services: { [string]: any }, amount: number): boolean
	local data = services.DataService:GetData(player)
	if not data or not services.DataService:AdjustCash(player, amount) then
		return false
	end
	if amount > 0 then
		services.DataService:Set(player, { "TotalEarned" }, data.TotalEarned + amount)
	end
	return true
end

function Rewards.Grant(player: Player, services: { [string]: any }, reward: any): boolean
	local kind = reward.Kind
	if kind == "Clicks" then
		return Rewards.AddClicks(player, services, reward.Amount)
	elseif kind == "LuckPotion" then
		return Rewards.ExtendPotion(player, services, "LuckUntil", reward.Amount)
	elseif kind == "ClicksPotion" then
		return Rewards.ExtendPotion(player, services, "ClicksUntil", reward.Amount)
	elseif kind == "Key" then
		return Rewards.GrantRandomKey(player, services, reward.Rarity or "Common")
	end
	return false
end

return Rewards
