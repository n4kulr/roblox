--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local RateLimit = require(ReplicatedStorage.Utils.RateLimit)
local Roll = require(script.Roll)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	_trove: TroveInstance?,
}

local RollService = {
	Name = "RollService",
	_trove = nil :: TroveInstance?,
}
local services: { [string]: any } = {}
local rng = Random.new()
local limiter = RateLimit.new(2, 0.5)

local function handleRoll(player: Player): number
	local data = services.DataService:GetData(player) :: PlayerData.Data?
	if not data or not services.PlotService:GetPlot(player) then
		return 0
	end
	if not limiter:Allow(player) then
		return 0
	end
	local key = Roll.Pick(rng, GameConfig.Luck)
	services.DataService:Set(player, { "Rolls" }, data.Rolls + 1)
	if not services.KeyboardService:AddKey(player, key.Id) then
		return 0
	end
	if Keys.GetRarity(key).Announce then
		Packets.RareRoll:FireAllClients(player.DisplayName, key.Index)
	end
	return key.Index
end

function RollService.Init(self: State, registry: { [string]: any })
	services = registry
	self._trove = Trove.new()
end

function RollService.Start(self: State)
	local trove = self._trove :: TroveInstance
	Packets.Roll.OnServerInvoke = handleRoll
	trove:Add(Players.PlayerRemoving:Connect(function(player: Player)
		limiter:Remove(player)
	end))
end

function RollService.Destroy(self: State)
	Packets.Roll.OnServerInvoke = nil
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return RollService
