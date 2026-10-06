--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Eggs = require(ReplicatedStorage.Config.Eggs)
local EggModel = require(ReplicatedStorage.Utils.EggModel)
local Inventory = require(script.Parent.Inventory)

local heldScale = 0.7

local Tools = {}

Tools.EggAttribute = "EggId"
Tools.CountAttribute = "Count"

function Tools.NameOf(egg: Eggs.Egg, count: number): string
	return `{egg.Name} x{count}`
end

local function build(egg: Eggs.Egg, count: number): Tool
	local tool = Instance.new("Tool")
	tool.Name = Tools.NameOf(egg, count)
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = egg.Tagline
	tool.Grip = CFrame.new(0, -0.3, 0)
	tool:SetAttribute(Tools.EggAttribute, egg.Id)
	tool:SetAttribute(Tools.CountAttribute, count)
	EggModel.Build(tool, egg, { Scale = heldScale, BodyName = "Handle", Anchored = false })
	return tool
end

local function collect(player: Player): { [string]: { Tool } }
	local found: { [string]: { Tool } } = {}
	local holders: { Instance } = {}
	local backpack = player:FindFirstChild("Backpack")
	if backpack then
		table.insert(holders, backpack)
	end
	local character = player.Character
	if character then
		table.insert(holders, character)
	end
	for _, holder in holders do
		for _, child in holder:GetChildren() do
			if child:IsA("Tool") then
				local eggId = child:GetAttribute(Tools.EggAttribute)
				if type(eggId) == "string" then
					found[eggId] = found[eggId] or {}
					table.insert(found[eggId], child)
				end
			end
		end
	end
	return found
end

function Tools.Sync(player: Player, bag: Inventory.Bag)
	local backpack = player:FindFirstChild("Backpack")
	local found = collect(player)
	for eggId, list in found do
		local keep = if Eggs.ById[eggId] ~= nil and Inventory.Count(bag, eggId) > 0 then 1 else 0
		for index = #list, keep + 1, -1 do
			list[index]:Destroy()
			table.remove(list, index)
		end
	end
	for _, egg in Eggs.Catalog do
		local count = Inventory.Count(bag, egg.Id)
		if count > 0 then
			local existing = if found[egg.Id] then found[egg.Id][1] else nil
			if existing then
				existing.Name = Tools.NameOf(egg, count)
				existing:SetAttribute(Tools.CountAttribute, count)
			elseif backpack then
				build(egg, count).Parent = backpack
			end
		end
	end
end

function Tools.Clear(player: Player)
	Tools.Sync(player, {})
end

return Tools
