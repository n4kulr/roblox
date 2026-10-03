--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DailyRewards = require(ReplicatedStorage.Config.DailyRewards)
local Packets = require(ReplicatedStorage.Packets)
local Daily = require(ReplicatedStorage.Rules.Daily)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local Rewards = require(script.Parent.Parent.Utils.Rewards)

local DailyService = { Name = "DailyService" }
local services: { [string]: any } = {}

local function grant(player: Player, reward: DailyRewards.Reward): boolean
	local kind = reward.Kind
	if kind == "Clicks" then
		return services.DataService:AdjustCash(player, reward.Amount)
	elseif kind == "LuckPotion" then
		return Rewards.ExtendPotion(player, services, "LuckUntil", reward.Amount)
	elseif kind == "ClicksPotion" then
		return Rewards.ExtendPotion(player, services, "ClicksUntil", reward.Amount)
	end
	return Rewards.GrantRandomKey(player, services, reward.Rarity or "Common")
end

local function claim(player: Player): number
	local data = services.DataService:GetData(player) :: PlayerData.Data?
	local replica = services.DataService:GetReplica(player)
	if not data or not replica then
		return 0
	end
	local now = os.time()
	local status = Daily.Status(data.Daily, now)
	if not status.CanClaim then
		return 0
	end
	local reward = DailyRewards.Rewards[status.Day]
	if not reward or not grant(player, reward) then
		return 0
	end
	replica:SetValues({ "Daily" }, { Streak = status.Day, LastClaim = now })
	services.DataService:RequestSave(player)
	return status.Day
end

function DailyService.Init(_self: any, registry: { [string]: any })
	services = registry
end

function DailyService.Start(_self: any)
	Packets.ClaimDaily.OnServerInvoke = claim
end

function DailyService.Destroy(_self: any)
	Packets.ClaimDaily.OnServerInvoke = nil
end

return DailyService
