--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Packets = require(ReplicatedStorage.Packets)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local Rewards = require(script.Parent.Parent.Utils.Rewards)

type Session = { Start: number, Mask: number }
type Tier = { Seconds: number, Kind: string, Amount: number, Min: number, Rarity: string }

local PlaytimeService = { Name = "PlaytimeService" }
local services: { [string]: any } = {}
local sessions: { [Player]: Session } = {}

local function publish(player: Player, session: Session)
	player:SetAttribute("PlaytimeStart", session.Start)
	player:SetAttribute("PlaytimeClaimed", session.Mask)
end

local function begin(player: Player, _data: PlayerData.Data)
	local session = { Start = os.time(), Mask = 0 }
	sessions[player] = session
	publish(player, session)
end

local function finish(player: Player, _data: PlayerData.Data)
	sessions[player] = nil
end

local function grant(player: Player, tier: Tier): boolean
	if tier.Kind == "Cash" then
		services.KeyboardService:Settle(player)
		local rate = services.KeyboardService:GetRate(player)
		local amount = math.max(tier.Min, math.floor(tier.Amount * rate))
		return Rewards.AddClicks(player, services, amount)
	end
	return Rewards.Grant(player, services, tier)
end

local function claim(player: Player, index: number): boolean
	if type(index) ~= "number" or index % 1 ~= 0 then
		return false
	end
	local tiers = GameConfig.Playtime :: { Tier }
	local tier = tiers[index]
	local session = sessions[player]
	if not tier or not session then
		return false
	end
	local bit = 2 ^ (index - 1)
	if math.floor(session.Mask / bit) % 2 == 1 then
		return false
	end
	if os.time() - session.Start < tier.Seconds then
		return false
	end
	if not services.DataService:GetData(player) or not grant(player, tier) then
		return false
	end
	session.Mask += bit
	publish(player, session)
	services.DataService:RequestSave(player)
	return true
end

function PlaytimeService.Init(_self: any, registry: { [string]: any })
	services = registry
end

function PlaytimeService.Start(_self: any)
	services.DataService.PlayerLoaded:Connect(begin)
	services.DataService.PlayerReleasing:Connect(finish)
	Packets.ClaimPlaytime.OnServerInvoke = claim
end

function PlaytimeService.Destroy(_self: any)
	Packets.ClaimPlaytime.OnServerInvoke = nil
end

return PlaytimeService
