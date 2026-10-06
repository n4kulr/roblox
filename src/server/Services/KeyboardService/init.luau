--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local Packets = require(ReplicatedStorage.Packets)
local Board = require(ReplicatedStorage.Rules.Board)
local Boosts = require(ReplicatedStorage.Rules.Boosts)
local Stats = require(ReplicatedStorage.Rules.Stats)
local Variants = require(ReplicatedStorage.Rules.Variants)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local Income = require(script.Income)
local Inventory = require(script.Inventory)
local StatsCache = require(script.StatsCache)
local Types = require(script.Types)

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	BoardChanged: Signal.Signal<Player>,
	_trove: TroveInstance?,
}

local KeyboardService = {
	Name = "KeyboardService",
	BoardChanged = Signal.new() :: Signal.Signal<Player>,
	_trove = nil :: TroveInstance?,
}
local context: Types.Context = { Services = {} }
local cache = StatsCache.new()
local offlinePassWaitSeconds = 20
local pendingOffline: { [Player]: boolean } = {}

local function getData(player: Player): PlayerData.Data?
	return context.Services.DataService:GetData(player) :: PlayerData.Data?
end

local function boardRate(player: Player, data: PlayerData.Data): number
	local passService = context.Services.PassService
	local passes = if passService then passService:GetPasses(player) else {}
	return cache:Rate(player, data, Boosts.PassIncome(passes))
end

local function isInteger(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge and value % 1 == 0
end

local function settle(player: Player)
	if pendingOffline[player] then
		return
	end
	local data = getData(player)
	local replica = context.Services.DataService:GetReplica(player)
	if not data or not replica then
		return
	end
	local cash, incomeAt = Income.Settled(data, os.time(), boardRate(player, data))
	if cash ~= data.Cash or incomeAt ~= data.IncomeAt then
		replica:SetValues(
			{},
			{ Cash = cash, IncomeAt = incomeAt, TotalEarned = Income.TotalEarnedAfter(data, cash) }
		)
	end
end

local function announceBoardChanged(player: Player)
	cache:Invalidate(player)
	KeyboardService.BoardChanged:Fire(player)
end

local function normalize(player: Player, data: PlayerData.Data)
	local unlocked = math.min(Stats.Slots(data.Upgrades), GameConfig.BoardSlots)
	local result = Board.Normalize(data.Board, data.BoardTags, unlocked)
	if result.TagsChanged then
		context.Services.DataService:Set(player, { "BoardTags" }, result.Tags)
	end
	if not result.BoardChanged then
		return
	end
	cache:Invalidate(player)
	context.Services.DataService:Set(player, { "Board" }, result.Board)
	for _, keyId in result.Overflow do
		Inventory.Add(context, player, keyId, 1)
	end
end

local function grantOffline(player: Player, data: PlayerData.Data)
	local now = os.time()
	local cash = Income.Offline(data, now, boardRate(player, data))
	local replica = context.Services.DataService:GetReplica(player)
	if replica then
		replica:SetValues(
			{},
			{ Cash = cash, IncomeAt = now, TotalEarned = Income.TotalEarnedAfter(data, cash) }
		)
	end
end

local function finishOffline(player: Player)
	if not pendingOffline[player] then
		return
	end
	pendingOffline[player] = nil
	local data = getData(player)
	if data then
		grantOffline(player, data)
	end
end

local function slotInRange(data: PlayerData.Data, slot: any): boolean
	return isInteger(slot) and slot >= 1 and slot <= Stats.Slots(data.Upgrades)
end

local function placeKey(player: Player, slot: number, keyId: string): boolean
	if type(slot) ~= "number" or type(keyId) ~= "string" or not isInteger(slot) then
		return false
	end
	local data = getData(player)
	if not data or not slotInRange(data, slot) then
		return false
	end
	if Keys.Resolve(keyId) == nil or (data.Inventory[keyId] or 0) < 1 then
		return false
	end
	settle(player)
	local previous = data.Board[slot]
	Inventory.Remove(context, player, data, keyId, 1)
	if not Board.IsEmptySlot(previous) then
		Inventory.Add(context, player, previous, 1)
	end
	Inventory.SetSlot(context, player, slot, keyId)
	announceBoardChanged(player)
	return true
end

local function clearSlot(player: Player, slot: number): boolean
	if type(slot) ~= "number" or not isInteger(slot) then
		return false
	end
	local data = getData(player)
	if not data or not slotInRange(data, slot) then
		return false
	end
	local previous = data.Board[slot]
	if Board.IsEmptySlot(previous) then
		return false
	end
	settle(player)
	Inventory.Add(context, player, previous, 1)
	Inventory.SetSlot(context, player, slot, "")
	announceBoardChanged(player)
	return true
end

local function sellKey(player: Player, keyId: string, count: number): boolean
	if type(keyId) ~= "string" or type(count) ~= "number" or not isInteger(count) or count < 1 then
		return false
	end
	local data = getData(player)
	if not data or Keys.Resolve(keyId) == nil or (data.Inventory[keyId] or 0) < count then
		return false
	end
	settle(player)
	Inventory.Remove(context, player, data, keyId, count)
	local cash = math.min(GameConfig.MaxCash, data.Cash + Keys.GetSellValue(keyId) * count)
	context.Services.DataService:Set(player, { "Cash" }, cash)
	return true
end

local function fuseKey(player: Player, keyId: string): string
	if type(keyId) ~= "string" then
		return ""
	end
	local nextId = Variants.Next(keyId)
	local data = getData(player)
	if not data or not nextId or (data.Inventory[keyId] or 0) < Variants.FuseCost then
		return ""
	end
	settle(player)
	Inventory.Remove(context, player, data, keyId, Variants.FuseCost)
	KeyboardService.AddKey(KeyboardService, player, nextId)
	context.Services.DataService:RequestSave(player)
	return nextId
end

local function equipBest(player: Player): boolean
	local data = getData(player)
	if not data then
		return false
	end
	settle(player)
	local result = Board.EquipBest(data.Board, data.Inventory, Stats.Slots(data.Upgrades))
	context.Services.DataService:Set(player, { "Board" }, result.Board)
	context.Services.DataService:Set(player, { "Inventory" }, result.Inventory)
	for index = 1, GameConfig.BoardSlots do
		Inventory.SetTag(context, player, index, "")
	end
	announceBoardChanged(player)
	return true
end

function KeyboardService.Init(self: State, registry: { [string]: any })
	context.Services = registry
	self._trove = Trove.new()
end

function KeyboardService.Start(self: State)
	local trove = self._trove :: TroveInstance
	local services = context.Services
	trove:Add(KeyboardService.BoardChanged:Connect(function(player: Player)
		cache:Invalidate(player)
	end))
	services.DataService.PlayerLoaded:Connect(function(player: Player, data: PlayerData.Data)
		normalize(player, data)
		local passService = services.PassService
		if data.IncomeAt <= 0 or not passService or passService:IsResolved(player) then
			grantOffline(player, data)
		else
			pendingOffline[player] = true
			task.delay(offlinePassWaitSeconds, finishOffline, player)
		end
		announceBoardChanged(player)
	end)
	if services.PassService then
		trove:Add(services.PassService.Resolved:Connect(finishOffline))
	end
	services.DataService.PlayerReleasing:Connect(function(player: Player, data: PlayerData.Data)
		if pendingOffline[player] then
			pendingOffline[player] = nil
			grantOffline(player, data)
		end
		local cash, incomeAt = Income.Settled(data, os.time(), boardRate(player, data))
		data.TotalEarned = Income.TotalEarnedAfter(data, cash)
		data.Cash = cash
		data.IncomeAt = incomeAt
		cache:Invalidate(player)
	end)
	trove:Add(task.spawn(function()
		while true do
			task.wait(GameConfig.SettleIntervalSeconds)
			for _, player in Players:GetPlayers() do
				settle(player)
			end
		end
	end))
	Packets.PlaceKey.OnServerInvoke = placeKey
	Packets.ClearSlot.OnServerInvoke = clearSlot
	Packets.SellKey.OnServerInvoke = sellKey
	Packets.FuseKey.OnServerInvoke = fuseKey
	Packets.EquipBest.OnServerInvoke = equipBest
end

function KeyboardService.Settle(_self: State, player: Player)
	settle(player)
end

function KeyboardService.Normalize(_self: State, player: Player)
	local data = getData(player)
	if data then
		normalize(player, data)
	end
end

function KeyboardService.NotifyBoardChanged(_self: State, player: Player)
	announceBoardChanged(player)
end

function KeyboardService.InvalidateStats(_self: State, player: Player)
	cache:Invalidate(player)
end

function KeyboardService.GetRate(_self: State, player: Player): number
	local data = getData(player)
	return if data then boardRate(player, data) else 0
end

function KeyboardService.GetRollStats(
	_self: State,
	player: Player,
	luckMultiplier: number
): StatsCache.RollStats?
	local data = getData(player)
	return if data then cache:Roll(player, data, luckMultiplier) else nil
end

function KeyboardService.AddKey(_self: State, player: Player, keyId: string, tag: string?): boolean
	local key = Keys.Resolve(keyId)
	if not key then
		return false
	end
	settle(player)
	local data = getData(player)
	if not data then
		return false
	end
	local placed = false
	if data.Settings.AutoPlace then
		local slot, displaces = Board.PickSlot(data.Board, Stats.Slots(data.Upgrades), keyId)
		if slot then
			local displaced = data.Board[slot]
			Inventory.SetSlot(context, player, slot, keyId)
			Inventory.SetTag(context, player, slot, tag or "")
			if displaces then
				Inventory.Add(context, player, displaced, 1)
			end
			placed = true
		end
	end
	if placed then
		announceBoardChanged(player)
	else
		Inventory.Add(context, player, keyId, 1)
	end
	if Keys.GetRarity(key).Announce then
		context.Services.DataService:RequestSave(player)
	end
	return true
end

function KeyboardService.TakeFromSlot(_self: State, player: Player, slot: number, keyId: string): boolean
	local data = getData(player)
	if not data or not slotInRange(data, slot) then
		return false
	end
	if data.Board[slot] ~= keyId or Keys.Resolve(keyId) == nil then
		return false
	end
	settle(player)
	Inventory.SetSlot(context, player, slot, "")
	announceBoardChanged(player)
	return true
end

function KeyboardService.RestoreKey(_self: State, player: Player, slot: number, keyId: string): boolean
	local data = getData(player)
	if not data or Keys.Resolve(keyId) == nil then
		return false
	end
	if slotInRange(data, slot) and Board.IsEmptySlot(data.Board[slot]) then
		settle(player)
		Inventory.SetSlot(context, player, slot, keyId)
		announceBoardChanged(player)
		return true
	end
	return KeyboardService.AddKey(KeyboardService, player, keyId)
end

function KeyboardService.Destroy(self: State)
	Packets.PlaceKey.OnServerInvoke = nil
	Packets.ClearSlot.OnServerInvoke = nil
	Packets.SellKey.OnServerInvoke = nil
	Packets.FuseKey.OnServerInvoke = nil
	Packets.EquipBest.OnServerInvoke = nil
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return KeyboardService
