--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Boosts = require(ReplicatedStorage.Rules.Boosts)
local Charms = require(ReplicatedStorage.Rules.Charms)
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
local bucketCapacity = 3
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

local function handleRoll(player: Player): (number, boolean)
	local data = services.DataService:GetData(player) :: PlayerData.Data?
	if not data or not services.PlotService:GetPlot(player) then
		return 0, false
	end
	local passService = services.PassService
	local serverLuckUntil = ReplicatedStorage:GetAttribute("ServerLuckUntil")
	local modifiers = Boosts.Modifiers(
		data.Boosts,
		if passService then passService:GetPasses(player) else {},
		os.time(),
		if type(serverLuckUntil) == "number" then serverLuckUntil else 0
	)
	local charmEffects = Charms.Effects(data.EquippedCharms)
	local stats = Stats.Compute(data.Board, data.Upgrades, {
		Luck = modifiers.Luck * charmEffects.Luck,
		Income = modifiers.Income * charmEffects.Income,
		Speed = charmEffects.Speed,
	})
	if not takeToken(player, stats.RollsPerSecond) then
		return 0, false
	end
	local isGuaranteed = data.Rolls + 1 == GameConfig.GuaranteedRareRoll
	local goldenProgress = (data.GoldenProgress or 0) + 1
	local isGolden = not isGuaranteed
		and goldenProgress >= Stats.GoldenEvery(data.Upgrades, charmEffects.GoldenReduction)
	local key = if isGuaranteed
		then Roll.PickInRarity(rng, "Rare")
		else Roll.Pick(rng, if isGolden then stats.Luck * GameConfig.GoldenRollLuck else stats.Luck)
	services.DataService:Set(player, { "Rolls" }, data.Rolls + 1)
	services.DataService:Set(player, { "GoldenProgress" }, if isGolden then 0 else goldenProgress)
	if not services.KeyboardService:AddKey(player, key.Id) then
		return 0, false
	end
	services.DataService:Set(player, { "Discovered", key.Id }, (data.Discovered[key.Id] or 0) + 1)
	if data.Tutorial == 0 then
		services.DataService:Set(player, { "Tutorial" }, 1)
	end
	if data.Tutorial == 1 and data.Rolls >= GameConfig.GuaranteedRareRoll then
		services.DataService:Set(player, { "Tutorial" }, 2)
	end
	if services.SeasonService then
		services.SeasonService:AddRoll(player, isGolden)
	end
	if Keys.GetRarity(key).Announce then
		Packets.RareRoll:FireAllClients(player.DisplayName, key.Index)
	end
	return key.Index, isGolden
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
