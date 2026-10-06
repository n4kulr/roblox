--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Keys = require(ReplicatedStorage.Config.Keys)
local Economy = require(script.Parent.Parent.Parent.Economy)

local Inventory = {}

function Inventory.ReadCounts(value: any): { [string]: number }
	local copy: { [string]: number } = {}
	if type(value) == "table" then
		for keyId, count in value do
			if type(keyId) == "string" and type(count) == "number" then
				copy[keyId] = count
			end
		end
	end
	return copy
end

function Inventory.ReadTags(value: any): { [number]: string }
	local copy: { [number]: string } = {}
	if type(value) == "table" then
		for index, tag in value do
			if type(index) == "number" and type(tag) == "string" then
				copy[index] = tag
			end
		end
	end
	return copy
end

function Inventory.BoardCounts(tracker: Economy.Tracker): { [string]: number }
	local counts: { [string]: number } = {}
	local slots = tracker.GetStats().Slots
	local board = tracker.GetBoard()
	for index = 1, slots do
		local keyId = board[index]
		if type(keyId) == "string" and Keys.Resolve(keyId) then
			counts[keyId] = (counts[keyId] or 0) + 1
		end
	end
	return counts
end

function Inventory.StolenTags(tracker: Economy.Tracker, boardTags: { [number]: string }): { [string]: string }
	local tags: { [string]: string } = {}
	local board = tracker.GetBoard()
	for index = 1, tracker.GetStats().Slots do
		local keyId = board[index]
		local tag = boardTags[index]
		if type(keyId) == "string" and tag and tag ~= "" and not tags[keyId] then
			tags[keyId] = tag
		end
	end
	return tags
end

return Inventory
