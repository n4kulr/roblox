--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Packets = require(ReplicatedStorage.Packets)
local Season = require(ReplicatedStorage.Rules.Season)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local Rewards = require(script.Parent.Parent.Utils.Rewards)

local SeasonService = { Name = "SeasonService" }
local services: { [string]: any } = {}

local function ensureCurrent(player: Player, data: PlayerData.Data)
	if data.Season.Id == GameConfig.Season.Id then
		return
	end
	local replica = services.DataService:GetReplica(player)
	if replica then
		replica:SetValues(
			{ "Season" },
			{ Id = GameConfig.Season.Id, Xp = 0, ClaimedFree = 0, ClaimedPremium = 0 }
		)
	end
end

local function claim(player: Player, level: number, premium: boolean): boolean
	if type(level) ~= "number" or type(premium) ~= "boolean" then
		return false
	end
	local data = services.DataService:GetData(player) :: PlayerData.Data?
	local replica = services.DataService:GetReplica(player)
	if not data or not replica then
		return false
	end
	local ownsPremium = services.PassService:Owns(player, GameConfig.Season.PremiumPassId)
	if not Season.CanClaim(data.Season, level, premium, ownsPremium) then
		return false
	end
	local reward = Season.Reward(level, premium)
	if not reward or not Rewards.Grant(player, services, reward) then
		return false
	end
	replica:SetValues({ "Season" }, { [if premium then "ClaimedPremium" else "ClaimedFree"] = level })
	services.DataService:RequestSave(player)
	return true
end

function SeasonService.Init(_self: any, registry: { [string]: any })
	services = registry
end

function SeasonService.Start(_self: any)
	services.DataService.PlayerLoaded:Connect(ensureCurrent)
	Packets.ClaimSeason.OnServerInvoke = claim
end

function SeasonService.AddRoll(_self: any, player: Player, isGolden: boolean)
	local data = services.DataService:GetData(player) :: PlayerData.Data?
	if not data or data.Season.Id ~= GameConfig.Season.Id then
		return
	end
	local xp = if isGolden then GameConfig.Season.XpPerGoldenRoll else GameConfig.Season.XpPerRoll
	services.DataService:Set(player, { "Season", "Xp" }, data.Season.Xp + xp)
end

function SeasonService.Destroy(_self: any)
	Packets.ClaimSeason.OnServerInvoke = nil
end

return SeasonService
