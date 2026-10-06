--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local Rewards = require(script.Parent.Parent.Utils.Rewards)
local Chest = require(script.Chest)
local Membership = require(script.Membership)

type TroveInstance = typeof(Trove.new())

local Result = table.freeze({ Claimed = 0, NotInGroup = 1, OnCooldown = 2, NotConfigured = 3 })

local GroupChestService = {
	Name = "GroupChestService",
	_trove = nil :: TroveInstance?,
}
local services: { [string]: any } = {}
local memberCache: Membership.Cache = {}
local busy: { [Player]: boolean } = {}

local function isReady(data: PlayerData.Data, now: number): boolean
	return now - data.GroupChestAt >= GameConfig.GroupChest.CooldownSeconds
end

local function payout(player: Player): boolean
	local config = GameConfig.GroupChest
	services.KeyboardService:Settle(player)
	local rate = services.KeyboardService:GetRate(player)
	local cash = math.max(config.MinCash, math.floor(config.IncomeSeconds * rate))
	if not Rewards.AddClicks(player, services, cash) then
		return false
	end
	return Rewards.ExtendPotion(player, services, "LuckUntil", config.LuckPotionSeconds)
end

local function claim(player: Player): number
	local config = GameConfig.GroupChest
	if config.GroupId <= 0 then
		return Result.NotConfigured
	end
	local data = services.DataService:GetData(player) :: PlayerData.Data?
	if not data or busy[player] or not isReady(data, os.time()) then
		return Result.OnCooldown
	end
	busy[player] = true
	local isMember = Membership.IsMember(memberCache, player, config.GroupId, os.time())
	busy[player] = nil
	if not isMember then
		return Result.NotInGroup
	end
	data = services.DataService:GetData(player) :: PlayerData.Data?
	local now = os.time()
	if not data or not isReady(data, now) or not payout(player) then
		return Result.OnCooldown
	end
	services.DataService:Set(player, { "GroupChestAt" }, now)
	services.DataService:RequestSave(player)
	return Result.Claimed
end

local function bindChest(trove: TroveInstance)
	local authored = workspace:FindFirstChild(Chest.ModelName)
	if not authored then
		local model = Chest.Build(GameConfig.Obby.MapCenter)
		model.Parent = workspace
		trove:Add(model)
		return
	end
	local anchor = Chest.AnchorOf(authored)
	if not anchor then
		warn("[GroupChestService] workspace.GroupChest has no BasePart to hold the prompt")
		return
	end
	local hadPrompt = anchor:FindFirstChild(Chest.PromptName) ~= nil
	local hadSign = anchor:FindFirstChild(Chest.SignName) ~= nil
	local prompt = Chest.AddPrompt(anchor)
	local sign = Chest.AddSign(anchor)
	if not hadPrompt then
		trove:Add(prompt)
	end
	if not hadSign then
		trove:Add(sign)
	end
end

function GroupChestService.Init(self: any, registry: { [string]: any })
	services = registry
	self._trove = Trove.new()
end

function GroupChestService.Start(self: any)
	local trove = self._trove :: TroveInstance
	bindChest(trove)
	trove:Connect(Players.PlayerRemoving, function(player: Player)
		memberCache[player] = nil
		busy[player] = nil
	end)
	Packets.ClaimGroupChest.OnServerInvoke = claim
end

function GroupChestService.Destroy(self: any)
	Packets.ClaimGroupChest.OnServerInvoke = nil
	table.clear(memberCache)
	table.clear(busy)
	if self._trove then
		(self._trove :: TroveInstance):Destroy()
		self._trove = nil
	end
end

return GroupChestService
