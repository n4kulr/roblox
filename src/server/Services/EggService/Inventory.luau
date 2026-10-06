--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Eggs = require(ReplicatedStorage.Config.Eggs)

export type Bag = { [string]: number }
export type Placed = { Id: string, ReadyAt: number, X: number, Z: number }

local maxCount = 1000

local Inventory = {}

Inventory.MaxCount = maxCount

function Inventory.Count(bag: Bag, eggId: string): number
	return bag[eggId] or 0
end

local function isCount(value: any): boolean
	return type(value) == "number" and value == value and value % 1 == 0 and value >= 1 and value <= maxCount
end

local function isCoordinate(value: any): boolean
	return type(value) == "number" and value == value and math.abs(value) ~= math.huge
end

function Inventory.Next(bag: Bag): string?
	for _, egg in Eggs.Catalog do
		if (bag[egg.Id] or 0) > 0 then
			return egg.Id
		end
	end
	return nil
end

function Inventory.Added(bag: Bag, eggId: string): Bag
	local copy = table.clone(bag)
	copy[eggId] = (copy[eggId] or 0) + 1
	return copy
end

function Inventory.Removed(bag: Bag, eggId: string): Bag
	local copy = table.clone(bag)
	local left = (copy[eggId] or 0) - 1
	if left > 0 then
		copy[eggId] = left
	else
		copy[eggId] = nil
	end
	return copy
end

function Inventory.CleanBag(bag: any): Bag
	local clean: Bag = {}
	if type(bag) == "table" then
		for eggId, count in bag do
			if type(eggId) == "string" and Eggs.ById[eggId] ~= nil and isCount(count) then
				clean[eggId] = count
			end
		end
	end
	return clean
end

function Inventory.CleanPlaced(list: any): { Placed }
	local clean: { Placed } = {}
	if type(list) == "table" then
		for _, entry in list do
			if
				type(entry) == "table"
				and type(entry.Id) == "string"
				and Eggs.ById[entry.Id] ~= nil
				and isCoordinate(entry.ReadyAt)
				and isCoordinate(entry.X)
				and isCoordinate(entry.Z)
			then
				table.insert(clean, { Id = entry.Id, ReadyAt = entry.ReadyAt, X = entry.X, Z = entry.Z })
			end
		end
	end
	return clean
end

function Inventory.Same(a: { [any]: any }, b: { [any]: any }): boolean
	for key, value in a do
		if type(value) == "table" then
			if type(b[key]) ~= "table" or not Inventory.Same(value, b[key]) then
				return false
			end
		elseif b[key] ~= value then
			return false
		end
	end
	for key in b do
		if a[key] == nil then
			return false
		end
	end
	return true
end

return Inventory
