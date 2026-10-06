--!strict

local Config = script.Parent.Parent.Config
local GameConfig = require(Config.GameConfig)
local Keys = require(Config.Keys)

export type Placed = { Index: number, KeyId: string, Tag: string, Income: number }

export type Normalized = {
	Board: { string },
	Tags: { string },
	Overflow: { string },
	BoardChanged: boolean,
	TagsChanged: boolean,
}

export type Equipped = {
	Board: { string },
	Inventory: { [string]: number },
}

local Board = {}

function Board.IsSlotIndex(index: any): boolean
	return type(index) == "number" and index >= 1 and index % 1 == 0 and index == index
end

function Board.IsEmptySlot(keyId: any): boolean
	return type(keyId) ~= "string" or Keys.Resolve(keyId) == nil
end

function Board.Empty(): { string }
	local board: { string } = {}
	for index = 1, GameConfig.BoardSlots do
		board[index] = ""
	end
	return board
end

local function byIndex(a: Placed, b: Placed): boolean
	return a.Index < b.Index
end

local function outranks(a: Placed, b: Placed): boolean
	if a.Income ~= b.Income then
		return a.Income > b.Income
	end
	return a.Index < b.Index
end

function Board.Normalize(board: any, oldTags: any, unlocked: number): Normalized
	local current: { [any]: any } = if type(board) == "table" then board else {}
	local placed: { Placed } = {}
	local changed = false
	for index, keyId in current do
		local isIndex = Board.IsSlotIndex(index)
		if not isIndex or index > GameConfig.BoardSlots then
			changed = true
		end
		if isIndex and type(keyId) == "string" and Keys.Resolve(keyId) then
			local tag = if type(oldTags) == "table" then oldTags[index] else nil
			table.insert(placed, {
				Index = index,
				KeyId = keyId,
				Tag = if type(tag) == "string" then tag else "",
				Income = Keys.GetIncome(keyId),
			})
		end
	end
	table.sort(placed, byIndex)
	local ranked = table.clone(placed)
	table.sort(ranked, outranks)
	local kept: { [Placed]: boolean } = {}
	for position = 1, math.min(unlocked, #ranked) do
		kept[ranked[position]] = true
	end
	local nextBoard = Board.Empty()
	local nextTags = Board.Empty()
	local relocate: { Placed } = {}
	local overflow: { string } = {}
	for _, entry in placed do
		if not kept[entry] then
			table.insert(overflow, entry.KeyId)
		elseif entry.Index <= unlocked then
			nextBoard[entry.Index] = entry.KeyId
			nextTags[entry.Index] = entry.Tag
		else
			table.insert(relocate, entry)
		end
	end
	local nextSlot = 1
	for _, entry in relocate do
		while nextBoard[nextSlot] ~= "" do
			nextSlot += 1
		end
		nextBoard[nextSlot] = entry.KeyId
	end
	local tagsChanged = type(oldTags) ~= "table"
	local oldTagMap: { [any]: any } = if type(oldTags) == "table" then oldTags else {}
	for index = 1, GameConfig.BoardSlots do
		if current[index] ~= nextBoard[index] then
			changed = true
		end
		if not tagsChanged and oldTagMap[index] ~= nextTags[index] then
			tagsChanged = true
		end
	end
	if not tagsChanged then
		for index in oldTagMap do
			if not Board.IsSlotIndex(index) or index > GameConfig.BoardSlots then
				tagsChanged = true
				break
			end
		end
	end
	return {
		Board = nextBoard,
		Tags = nextTags,
		Overflow = overflow,
		BoardChanged = changed,
		TagsChanged = tagsChanged,
	}
end

function Board.EquipBest(board: { string }, inventory: { [string]: number }, unlocked: number): Equipped
	local counts: { [string]: number } = {}
	for index = 1, unlocked do
		local keyId = board[index]
		if type(keyId) == "string" and Keys.Resolve(keyId) then
			counts[keyId] = (counts[keyId] or 0) + 1
		end
	end
	for keyId, count in inventory do
		if Keys.Resolve(keyId) and type(count) == "number" and count > 0 then
			counts[keyId] = (counts[keyId] or 0) + count
		end
	end
	local ranked: { string } = {}
	local incomes: { [string]: number } = {}
	for keyId in counts do
		table.insert(ranked, keyId)
		incomes[keyId] = Keys.GetIncome(keyId)
	end
	table.sort(ranked, function(a: string, b: string): boolean
		if incomes[a] ~= incomes[b] then
			return incomes[a] > incomes[b]
		end
		local keyA, keyB = Keys.Resolve(a) :: Keys.Key, Keys.Resolve(b) :: Keys.Key
		local hasPerkA, hasPerkB = keyA.Perk ~= nil, keyB.Perk ~= nil
		if hasPerkA ~= hasPerkB then
			return hasPerkA
		end
		if keyA.Index ~= keyB.Index then
			return keyA.Index < keyB.Index
		end
		return a < b
	end)
	local nextBoard = Board.Empty()
	local slot = 1
	for _, keyId in ranked do
		while counts[keyId] > 0 and slot <= unlocked do
			nextBoard[slot] = keyId
			counts[keyId] -= 1
			slot += 1
		end
	end
	local nextInventory: { [string]: number } = {}
	for keyId, count in counts do
		if count > 0 then
			nextInventory[keyId] = count
		end
	end
	return { Board = nextBoard, Inventory = nextInventory }
end

function Board.PickSlot(board: { string }, unlocked: number, keyId: string): (number?, boolean)
	local key = Keys.Resolve(keyId)
	if not key then
		return nil, false
	end
	local lowestIndex: number? = nil
	local lowestIncome = math.huge
	for index = 1, unlocked do
		local slotId = board[index]
		if Board.IsEmptySlot(slotId) then
			return index, false
		end
		local slotKey = Keys.Resolve(slotId)
		if slotKey and slotKey.Perk == nil then
			local slotIncome = Keys.GetIncome(slotId)
			if slotIncome < lowestIncome then
				lowestIncome = slotIncome
				lowestIndex = index
			end
		end
	end
	if key.Perk == nil and lowestIndex and Keys.GetIncome(keyId) > lowestIncome then
		return lowestIndex, true
	end
	return nil, false
end

return table.freeze(Board)
