--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)

export type Data = {
	SchemaVersion: number,
	Cash: number,
	IncomeAt: number,
	Board: { string },
	Inventory: { [string]: number },
	Rolls: number,
	LastSeenAt: number,
	Receipts: { [string]: number },
}

local PlayerData = {}

local function emptyBoard(): { string }
	local board = {}
	for index = 1, GameConfig.BoardSlots do
		board[index] = ""
	end
	return board
end

PlayerData.Template = {
	SchemaVersion = 1,
	Cash = 0,
	IncomeAt = 0,
	Board = emptyBoard(),
	Inventory = {},
	Rolls = 0,
	LastSeenAt = 0,
	Receipts = {},
} :: Data

local function natural(value: any): boolean
	return type(value) == "number"
		and value == value
		and math.abs(value) < math.huge
		and value >= 0
		and value % 1 == 0
end

function PlayerData.Validate(data: any): boolean
	if type(data) ~= "table" or (data.SchemaVersion ~= nil and data.SchemaVersion ~= 1) then
		return false
	end
	for _, key in { "Cash", "IncomeAt", "Rolls", "LastSeenAt" } do
		if data[key] ~= nil and not natural(data[key]) then
			return false
		end
	end
	if data.Receipts ~= nil then
		if type(data.Receipts) ~= "table" then
			return false
		end
		for purchaseId, grantedAt in data.Receipts do
			if type(purchaseId) ~= "string" or #purchaseId == 0 or not natural(grantedAt) then
				return false
			end
		end
	end
	if data.Board ~= nil then
		if type(data.Board) ~= "table" then
			return false
		end
		for index, keyId in data.Board do
			if type(index) ~= "number" or type(keyId) ~= "string" then
				return false
			end
		end
	end
	if data.Inventory ~= nil then
		if type(data.Inventory) ~= "table" then
			return false
		end
		for keyId, count in data.Inventory do
			if type(keyId) ~= "string" or not natural(count) then
				return false
			end
		end
	end
	return true
end

function PlayerData.Migrate(_data: any) end

return PlayerData
