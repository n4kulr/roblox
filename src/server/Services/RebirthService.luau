--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local Packets = require(ReplicatedStorage.Packets)
local Rebirth = require(ReplicatedStorage.Rules.Rebirth)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local ServerTypes = require(script.Parent.Parent.Types)

local RebirthService = { Name = "RebirthService" }
local services: ServerTypes.Registry = nil :: any

local function clearBoard(player: Player, data: PlayerData.Data)
	local inventory: { [string]: number } = {}
	for keyId, count in data.Inventory do
		inventory[keyId] = count
	end
	local board: { string } = {}
	local tags: { string } = {}
	for index = 1, GameConfig.BoardSlots do
		local keyId = data.Board[index]
		if type(keyId) == "string" and Keys.Resolve(keyId) then
			inventory[keyId] = (inventory[keyId] or 0) + 1
		end
		board[index] = ""
		tags[index] = ""
	end
	services.DataService:Set(player, { "Inventory" }, inventory)
	services.DataService:Set(player, { "Board" }, board)
	services.DataService:Set(player, { "BoardTags" }, tags)
end

local function rebirth(player: Player, force: boolean): boolean
	local data = services.DataService:GetData(player)
	local replica = services.DataService:GetReplica(player)
	if not data or not replica then
		return false
	end
	services.KeyboardService:Settle(player)
	if not force and data.Cash < Rebirth.Cost(data.Rebirths) then
		return false
	end
	replica:SetValues({}, { Cash = 0, IncomeAt = os.time(), Rebirths = data.Rebirths + 1 })
	replica:SetValues(
		{ "Upgrades" },
		{ Luck = 0, Speed = 0, Slots = 0, Income = 0, Walls = 0, LockTime = 0, Golden = 0 }
	)
	clearBoard(player, data)
	services.KeyboardService:Normalize(player)
	services.KeyboardService:NotifyBoardChanged(player)
	services.DataService:RequestSave(player)
	return true
end

function RebirthService.Init(_self: any, registry: { [string]: any })
	services = registry :: any
end

function RebirthService.Force(_self: any, player: Player): boolean
	return rebirth(player, true)
end

function RebirthService.Start(_self: any)
	Packets.Rebirth.OnServerInvoke = function(player: Player)
		return rebirth(player, false)
	end
end

function RebirthService.Destroy(_self: any)
	Packets.Rebirth.OnServerInvoke = nil
end

return RebirthService
