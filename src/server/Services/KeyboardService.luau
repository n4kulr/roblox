--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local Packets = require(ReplicatedStorage.Packets)
local Boosts = require(ReplicatedStorage.Rules.Boosts)
local Income = require(ReplicatedStorage.Rules.Income)
local Rebirth = require(ReplicatedStorage.Rules.Rebirth)
local Stats = require(ReplicatedStorage.Rules.Stats)
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

local function boardRate(player: Player, data: PlayerData.Data): number
	local passService = services.PassService
	local passes = if passService then passService:GetPasses(player) else {}
	local income = Boosts.PassIncome(passes) * Rebirth.IncomeMultiplier(data.Rebirths)
	return Stats.Compute(data.Board, data.Upgrades, { Income = income }).Rate
end

local function totalEarnedAfter(data: PlayerData.Data, cash: number): number
	return data.TotalEarned + math.max(0, cash - data.Cash)
end

local function isInteger(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) < math.huge and value % 1 == 0
end

local function isEmptySlot(keyId: any): boolean
	return type(keyId) ~= "string" or Keys.ById[keyId] == nil
end

local function settledValues(player: Player, data: PlayerData.Data, now: number): (number, number)
	if data.IncomeAt <= 0 or now <= data.IncomeAt then
		return data.Cash, if data.IncomeAt <= 0 then now else data.IncomeAt
	end
	local earned = Income.Earned(
		boardRate(player, data),
		data.IncomeAt,
		now,
		data.Boosts.ClicksUntil,
		GameConfig.Boosts.PotionMultiplier
	)
	return math.min(maxCash, data.Cash + earned), now
end

local function settle(player: Player)
	local data = services.DataService:GetData(player) :: PlayerData.Data?
	local replica = services.DataService:GetReplica(player)
	if not data or not replica then
		return
	end
	local cash, incomeAt = settledValues(player, data, os.time())
	if cash ~= data.Cash or incomeAt ~= data.IncomeAt then
		replica:SetValues(
			{},
			{ Cash = cash, IncomeAt = incomeAt, TotalEarned = totalEarnedAfter(data, cash) }
		)
	end
end

local function addToInventory(player: Player, keyId: string, amount: number)
	local data = services.DataService:GetData(player) :: PlayerData.Data?
	if data then
		services.DataService:Set(player, { "Inventory", keyId }, (data.Inventory[keyId] or 0) + amount)
	end
end

local function removeFromInventory(player: Player, data: PlayerData.Data, keyId: string, amount: number)
	local remaining = (data.Inventory[keyId] or 0) - amount
	services.DataService:Set(player, { "Inventory", keyId }, if remaining > 0 then remaining else nil)
end

local function setTag(player: Player, slot: number, tag: string)
	local data = services.DataService:GetData(player) :: PlayerData.Data?
	if not data or type(data.BoardTags) ~= "table" then
		return
	end
	if (data.BoardTags[slot] or "") ~= tag then
		local path: { string | number } = { "BoardTags", slot }
		services.DataService:Set(player, path, tag)
	end
end

local function setSlot(player: Player, slot: number, keyId: string)
	local path: { string | number } = { "Board", slot }
	services.DataService:Set(player, path, keyId)
	setTag(player, slot, "")
end

local function normalize(player: Player, data: PlayerData.Data)
	local unlocked = Stats.Slots(data.Upgrades)
	local board: { string } = {}
	local moved: { string } = {}
	local tags: { string } = {}
	local changed = false
	local tagsChanged = false
	local oldTags: any = data.BoardTags
	for index = 1, GameConfig.BoardSlots do
		local tag = if type(oldTags) == "table" then oldTags[index] else nil
		if type(tag) ~= "string" then
			tag = ""
			tagsChanged = true
		end
		tags[index] = tag
		local keyId = data.Board[index]
		if type(keyId) ~= "string" then
			keyId = ""
			changed = true
		end
		if index > unlocked and keyId ~= "" then
			if Keys.ById[keyId] then
				table.insert(moved, keyId)
			end
			keyId = ""
			tags[index] = ""
			changed = true
			tagsChanged = true
		end
		board[index] = keyId
	end
	for index in data.Board do
		if type(index) ~= "number" or index < 1 or index > GameConfig.BoardSlots or index % 1 ~= 0 then
			changed = true
		end
	end
	if type(oldTags) == "table" then
		for index in oldTags do
			if type(index) ~= "number" or index < 1 or index > GameConfig.BoardSlots or index % 1 ~= 0 then
				tagsChanged = true
			end
		end
	end
	if tagsChanged then
		services.DataService:Set(player, { "BoardTags" }, tags)
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
	for _, keyId in moved do
		addToInventory(player, keyId, 1)
	end
	for _, keyId in overflow do
		addToInventory(player, keyId, 1)
	end
end

local function grantOffline(player: Player, data: PlayerData.Data)
	local now = os.time()
	local cash = data.Cash
	if data.IncomeAt > 0 then
		local elapsed = math.clamp(now - data.IncomeAt, 0, GameConfig.OfflineCapSeconds)
		local earned = math.floor(
			Income.Earned(
				boardRate(player, data),
				data.IncomeAt,
				data.IncomeAt + elapsed,
				data.Boosts.ClicksUntil,
				GameConfig.Boosts.PotionMultiplier
			) * GameConfig.OfflineRate
		)
		cash = math.min(maxCash, cash + earned)
	end
	local replica = services.DataService:GetReplica(player)
	if replica then
		replica:SetValues({}, { Cash = cash, IncomeAt = now, TotalEarned = totalEarnedAfter(data, cash) })
	end
end

local function placeKey(player: Player, slot: number, keyId: string): boolean
	if type(slot) ~= "number" or type(keyId) ~= "string" or not isInteger(slot) then
		return false
	end
	local data = services.DataService:GetData(player) :: PlayerData.Data?
	if not data or slot < 1 or slot > Stats.Slots(data.Upgrades) then
		return false
	end
	if Keys.ById[keyId] == nil or (data.Inventory[keyId] or 0) < 1 then
		return false
	end
	settle(player)
	local previous = data.Board[slot]
	removeFromInventory(player, data, keyId, 1)
	if not isEmptySlot(previous) then
		addToInventory(player, previous, 1)
	end
	setSlot(player, slot, keyId)
	KeyboardService.BoardChanged:Fire(player)
	return true
end

local function clearSlot(player: Player, slot: number): boolean
	if type(slot) ~= "number" or not isInteger(slot) then
		return false
	end
	local data = services.DataService:GetData(player) :: PlayerData.Data?
	if not data or slot < 1 or slot > Stats.Slots(data.Upgrades) then
		return false
	end
	local previous = data.Board[slot]
	if isEmptySlot(previous) then
		return false
	end
	settle(player)
	addToInventory(player, previous, 1)
	setSlot(player, slot, "")
	KeyboardService.BoardChanged:Fire(player)
	return true
end

local function sellKey(player: Player, keyId: string, count: number): boolean
	if type(keyId) ~= "string" or type(count) ~= "number" or not isInteger(count) or count < 1 then
		return false
	end
	local data = services.DataService:GetData(player) :: PlayerData.Data?
	if not data or Keys.ById[keyId] == nil or (data.Inventory[keyId] or 0) < count then
		return false
	end
	settle(player)
	removeFromInventory(player, data, keyId, count)
	local cash = math.min(maxCash, data.Cash + Keys.GetSellValue(keyId) * count)
	services.DataService:Set(player, { "Cash" }, cash)
	return true
end

local function equipBest(player: Player): boolean
	local data = services.DataService:GetData(player) :: PlayerData.Data?
	if not data then
		return false
	end
	settle(player)
	local unlocked = Stats.Slots(data.Upgrades)
	local counts: { [string]: number } = {}
	for index = 1, unlocked do
		local keyId = data.Board[index]
		if type(keyId) == "string" and Keys.ById[keyId] then
			counts[keyId] = (counts[keyId] or 0) + 1
		end
	end
	for keyId, count in data.Inventory do
		if Keys.ById[keyId] and type(count) == "number" and count > 0 then
			counts[keyId] = (counts[keyId] or 0) + count
		end
	end
	local ranked: { string } = {}
	for keyId in counts do
		table.insert(ranked, keyId)
	end
	table.sort(ranked, function(a: string, b: string): boolean
		local incomeA, incomeB = Keys.GetIncome(a), Keys.GetIncome(b)
		if incomeA ~= incomeB then
			return incomeA > incomeB
		end
		local hasPerkA, hasPerkB = Keys.ById[a].Perk ~= nil, Keys.ById[b].Perk ~= nil
		if hasPerkA ~= hasPerkB then
			return hasPerkA
		end
		return Keys.ById[a].Index < Keys.ById[b].Index
	end)
	local board: { string } = {}
	for index = 1, GameConfig.BoardSlots do
		board[index] = ""
	end
	local slot = 1
	for _, keyId in ranked do
		while counts[keyId] > 0 and slot <= unlocked do
			board[slot] = keyId
			counts[keyId] -= 1
			slot += 1
		end
	end
	local inventory: { [string]: number } = {}
	for keyId, count in counts do
		if count > 0 then
			inventory[keyId] = count
		end
	end
	services.DataService:Set(player, { "Board" }, board)
	services.DataService:Set(player, { "Inventory" }, inventory)
	for index = 1, GameConfig.BoardSlots do
		setTag(player, index, "")
	end
	KeyboardService.BoardChanged:Fire(player)
	return true
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
	services.DataService.PlayerReleasing:Connect(function(player: Player, data: PlayerData.Data)
		local cash, incomeAt = settledValues(player, data, os.time())
		data.TotalEarned = totalEarnedAfter(data, cash)
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
	Packets.PlaceKey.OnServerInvoke = placeKey
	Packets.ClearSlot.OnServerInvoke = clearSlot
	Packets.SellKey.OnServerInvoke = sellKey
	Packets.EquipBest.OnServerInvoke = equipBest
end

function KeyboardService.Settle(_self: State, player: Player)
	settle(player)
end

function KeyboardService.Normalize(_self: State, player: Player)
	local data = services.DataService:GetData(player) :: PlayerData.Data?
	if data then
		normalize(player, data)
	end
end

function KeyboardService.GetRate(_self: State, player: Player): number
	local data = services.DataService:GetData(player) :: PlayerData.Data?
	return if data then boardRate(player, data) else 0
end

function KeyboardService.AddKey(_self: State, player: Player, keyId: string, tag: string?): boolean
	local key = Keys.ById[keyId]
	if not key then
		return false
	end
	settle(player)
	local data = services.DataService:GetData(player) :: PlayerData.Data?
	if not data then
		return false
	end
	local placed = false
	if data.Settings.AutoPlace then
		local income = Keys.GetIncome(keyId)
		local emptyIndex: number? = nil
		local lowestIndex: number? = nil
		local lowestIncome = math.huge
		for index = 1, Stats.Slots(data.Upgrades) do
			local slotId = data.Board[index]
			if isEmptySlot(slotId) then
				emptyIndex = index
				break
			end
			local slotKey = Keys.ById[slotId]
			if slotKey and slotKey.Perk == nil then
				local slotIncome = Keys.GetIncome(slotId)
				if slotIncome < lowestIncome then
					lowestIncome = slotIncome
					lowestIndex = index
				end
			end
		end
		if emptyIndex then
			setSlot(player, emptyIndex, keyId)
			setTag(player, emptyIndex, tag or "")
			placed = true
		elseif key.Perk == nil and lowestIndex and income > lowestIncome then
			local displaced = data.Board[lowestIndex]
			setSlot(player, lowestIndex, keyId)
			setTag(player, lowestIndex, tag or "")
			addToInventory(player, displaced, 1)
			placed = true
		end
	end
	if placed then
		KeyboardService.BoardChanged:Fire(player)
	else
		addToInventory(player, keyId, 1)
	end
	if Keys.GetRarity(key).Announce then
		services.DataService:RequestSave(player)
	end
	return true
end

function KeyboardService.TakeFromSlot(_self: State, player: Player, slot: number, keyId: string): boolean
	local data = services.DataService:GetData(player) :: PlayerData.Data?
	if not data or not isInteger(slot) or slot < 1 or slot > Stats.Slots(data.Upgrades) then
		return false
	end
	if data.Board[slot] ~= keyId or Keys.ById[keyId] == nil then
		return false
	end
	settle(player)
	setSlot(player, slot, "")
	KeyboardService.BoardChanged:Fire(player)
	return true
end

function KeyboardService.RestoreKey(_self: State, player: Player, slot: number, keyId: string): boolean
	local data = services.DataService:GetData(player) :: PlayerData.Data?
	if not data or Keys.ById[keyId] == nil then
		return false
	end
	if
		isInteger(slot)
		and slot >= 1
		and slot <= Stats.Slots(data.Upgrades)
		and isEmptySlot(data.Board[slot])
	then
		settle(player)
		setSlot(player, slot, keyId)
		KeyboardService.BoardChanged:Fire(player)
		return true
	end
	return KeyboardService.AddKey(KeyboardService, player, keyId)
end

function KeyboardService.Destroy(self: State)
	Packets.PlaceKey.OnServerInvoke = nil
	Packets.ClearSlot.OnServerInvoke = nil
	Packets.SellKey.OnServerInvoke = nil
	Packets.EquipBest.OnServerInvoke = nil
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return KeyboardService
