--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	BoardChanged: Signal.Signal<Player>,
	_trove: TroveInstance?,
}

local maxCash = 9007199254740991

local KeyboardService = {
	Name = "KeyboardService",
	BoardChanged = Signal.new() :: Signal.Signal<Player>,
	_trove = nil :: TroveInstance?,
}
local services: { [string]: any } = {}

local function boardRate(board: { string }): number
	local rate = 0
	for index = 1, GameConfig.BoardSlots do
		local keyId = board[index]
		if type(keyId) == "string" then
			rate += Keys.GetIncome(keyId)
		end
	end
	return rate
end

local function isEmptySlot(keyId: any): boolean
	return type(keyId) ~= "string" or Keys.ById[keyId] == nil
end

local function settledValues(data: PlayerData.Data, now: number): (number, number)
	if data.IncomeAt <= 0 or now <= data.IncomeAt then
		return data.Cash, if data.IncomeAt <= 0 then now else data.IncomeAt
	end
	local earned = math.floor(boardRate(data.Board) * (now - data.IncomeAt))
	return math.min(maxCash, data.Cash + earned), now
end

local function settle(player: Player)
	local data = services.DataService:GetData(player) :: PlayerData.Data?
	local replica = services.DataService:GetReplica(player)
	if not data or not replica then
		return
	end
	local cash, incomeAt = settledValues(data, os.time())
	if cash ~= data.Cash or incomeAt ~= data.IncomeAt then
		replica:SetValues({}, { Cash = cash, IncomeAt = incomeAt })
	end
end

local function addToInventory(player: Player, data: PlayerData.Data, keyId: string)
	services.DataService:Set(player, { "Inventory", keyId }, (data.Inventory[keyId] or 0) + 1)
end

local function normalize(player: Player, data: PlayerData.Data)
	local board: { string } = {}
	local changed = false
	for index = 1, GameConfig.BoardSlots do
		local keyId = data.Board[index]
		if type(keyId) ~= "string" then
			keyId = ""
			changed = true
		end
		board[index] = keyId
	end
	for index in data.Board do
		if type(index) ~= "number" or index < 1 or index > GameConfig.BoardSlots or index % 1 ~= 0 then
			changed = true
		end
	end
	if not changed then
		return
	end
	local overflow: { string } = {}
	for index, keyId in data.Board do
		if type(index) == "number" and index > GameConfig.BoardSlots and type(keyId) == "string" then
			if Keys.ById[keyId] then
				table.insert(overflow, keyId)
			end
		end
	end
	services.DataService:Set(player, { "Board" }, board)
	for _, keyId in overflow do
		addToInventory(player, data, keyId)
	end
end

local function grantOffline(player: Player, data: PlayerData.Data)
	local now = os.time()
	local cash = data.Cash
	if data.IncomeAt > 0 then
		local elapsed = math.clamp(now - data.IncomeAt, 0, GameConfig.OfflineCapSeconds)
		local earned = math.floor(boardRate(data.Board) * elapsed * GameConfig.OfflineRate)
		cash = math.min(maxCash, cash + earned)
	end
	local replica = services.DataService:GetReplica(player)
	if replica then
		replica:SetValues({}, { Cash = cash, IncomeAt = now })
	end
end

function KeyboardService.Init(self: State, registry: { [string]: any })
	services = registry
	self._trove = Trove.new()
end

function KeyboardService.Start(self: State)
	local trove = self._trove :: TroveInstance
	services.DataService.PlayerLoaded:Connect(function(player: Player, data: PlayerData.Data)
		normalize(player, data)
		grantOffline(player, data)
		KeyboardService.BoardChanged:Fire(player)
	end)
	services.DataService.PlayerReleasing:Connect(function(_player: Player, data: PlayerData.Data)
		local cash, incomeAt = settledValues(data, os.time())
		data.Cash = cash
		data.IncomeAt = incomeAt
	end)
	trove:Add(task.spawn(function()
		while true do
			task.wait(GameConfig.SettleIntervalSeconds)
			for _, player in Players:GetPlayers() do
				settle(player)
			end
		end
	end))
end

function KeyboardService.Settle(_self: State, player: Player)
	settle(player)
end

function KeyboardService.GetRate(_self: State, player: Player): number
	local data = services.DataService:GetData(player) :: PlayerData.Data?
	return if data then boardRate(data.Board) else 0
end

function KeyboardService.AddKey(_self: State, player: Player, keyId: string): boolean
	local key = Keys.ById[keyId]
	if not key then
		return false
	end
	settle(player)
	local data = services.DataService:GetData(player) :: PlayerData.Data?
	if not data then
		return false
	end
	local income = Keys.GetIncome(keyId)
	local emptyIndex: number? = nil
	local lowestIndex: number? = nil
	local lowestIncome = math.huge
	for index = 1, GameConfig.BoardSlots do
		local slotId = data.Board[index]
		if isEmptySlot(slotId) then
			emptyIndex = index
			break
		end
		local slotIncome = Keys.GetIncome(slotId)
		if slotIncome < lowestIncome then
			lowestIncome = slotIncome
			lowestIndex = index
		end
	end
	if emptyIndex then
		local path: { string | number } = { "Board", emptyIndex }
		services.DataService:Set(player, path, keyId)
		KeyboardService.BoardChanged:Fire(player)
	elseif lowestIndex and income > lowestIncome then
		local displaced = data.Board[lowestIndex]
		local path: { string | number } = { "Board", lowestIndex }
		services.DataService:Set(player, path, keyId)
		addToInventory(player, data, displaced)
		KeyboardService.BoardChanged:Fire(player)
	else
		addToInventory(player, data, keyId)
	end
	if Keys.GetRarity(key).Announce then
		services.DataService:RequestSave(player)
	end
	return true
end

function KeyboardService.Destroy(self: State)
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return KeyboardService
