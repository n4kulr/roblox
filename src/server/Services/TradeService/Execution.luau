--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeyTiers = require(ReplicatedStorage.Config.KeyTiers)
local Keys = require(ReplicatedStorage.Config.Keys)
local Trade = require(ReplicatedStorage.Rules.Trade)
local PlayerData = require(script.Parent.Parent.Parent.Data.PlayerData)
local Types = require(script.Parent.Types)

local Execution = {}

local function describe(offer: Types.Offer): string
	local ids: { string } = {}
	for keyId, count in offer do
		if count > 0 then
			table.insert(ids, keyId)
		end
	end
	table.sort(ids)
	local parts: { string } = {}
	for _, keyId in ids do
		local flag = if Trade.IsAtLeast(keyId, "Mythic") then " [MYTHIC+]" else ""
		table.insert(parts, `{offer[keyId]}x {keyId}{flag}`)
	end
	return if #parts > 0 then table.concat(parts, ", ") else "nothing"
end

function Execution.CanRun(context: Types.Context, session: Types.Session): boolean
	local first, second = session.Players[1], session.Players[2]
	local dataFirst = context.Services.DataService:GetData(first)
	local dataSecond = context.Services.DataService:GetData(second)
	if not dataFirst or not dataSecond then
		return false
	end
	return Trade.CanExecute(
		dataFirst.Inventory,
		session.Offers[first],
		dataSecond.Inventory,
		session.Offers[second]
	)
end

function Execution.Run(context: Types.Context, session: Types.Session): boolean
	if not Execution.CanRun(context, session) then
		return false
	end
	local dataService = context.Services.DataService
	local first, second = session.Players[1], session.Players[2]
	local dataFirst = dataService:GetData(first) :: PlayerData.Data
	local dataSecond = dataService:GetData(second) :: PlayerData.Data
	local offerFirst, offerSecond = session.Offers[first], session.Offers[second]
	local inventoryFirst, inventorySecond =
		Trade.Apply(dataFirst.Inventory, offerFirst, dataSecond.Inventory, offerSecond)
	local function discovered(data: PlayerData.Data, received: Types.Offer): { [string]: number }
		local out: { [string]: number } = {}
		for keyId, count in received do
			if count > 0 and Keys.Resolve(keyId) then
				local baseId = KeyTiers.Parse(keyId)
				out[baseId] = (out[baseId] or data.Discovered[baseId] or 0) + count
			end
		end
		return out
	end
	local foundFirst = discovered(dataFirst, offerSecond)
	local foundSecond = discovered(dataSecond, offerFirst)
	dataService:Set(first, { "Inventory" }, inventoryFirst)
	dataService:Set(second, { "Inventory" }, inventorySecond)
	for keyId, total in foundFirst do
		dataService:Set(first, { "Discovered", keyId }, total)
	end
	for keyId, total in foundSecond do
		dataService:Set(second, { "Discovered", keyId }, total)
	end
	dataService:RequestSave(first)
	dataService:RequestSave(second)
	print(
		`[Trade] {first.Name} <-> {second.Name}: {first.Name} gave {describe(offerFirst)}; {second.Name} gave {describe(
			offerSecond
		)}`
	)
	return true
end

return Execution
