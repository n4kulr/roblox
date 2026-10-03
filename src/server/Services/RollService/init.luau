--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Stats = require(ReplicatedStorage.Rules.Stats)
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
local bucketCapacity = 2
local buckets: { [Player]: { Tokens: number, UpdatedAt: number } } = {}

local function takeToken(player: Player, rate: number): boolean
	local now = os.clock()
	local bucket = buckets[player]
	if not bucket then
		bucket = { Tokens = bucketCapacity, UpdatedAt = now }
		buckets[player] = bucket
	end
	bucket.Tokens = math.min(bucketCapacity, bucket.Tokens + (now - bucket.UpdatedAt) * rate)
	bucket.UpdatedAt = now
	if bucket.Tokens < 1 then
		return false
	end
	bucket.Tokens -= 1
	return true
end

local function handleRoll(player: Player): number
	local data = services.DataService:GetData(player) :: PlayerData.Data?
	if not data or not services.PlotService:GetPlot(player) then
		return 0
	end
	local stats = Stats.Compute(data.Board, data.Upgrades)
	if not takeToken(player, stats.RollsPerSecond) then
		return 0
	end
	local isGuaranteed = data.Rolls + 1 == GameConfig.GuaranteedRareRoll
	local key = if isGuaranteed then Roll.PickInRarity(rng, "Rare") else Roll.Pick(rng, stats.Luck)
	services.DataService:Set(player, { "Rolls" }, data.Rolls + 1)
	if not services.KeyboardService:AddKey(player, key.Id) then
		return 0
	end
	if data.Tutorial == 0 then
		services.DataService:Set(player, { "Tutorial" }, 1)
	end
	if data.Tutorial == 1 and data.Rolls >= GameConfig.GuaranteedRareRoll then
		services.DataService:Set(player, { "Tutorial" }, 2)
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
		buckets[player] = nil
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
