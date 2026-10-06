--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Eggs = require(ReplicatedStorage.Config.Eggs)
local EggModel = require(ReplicatedStorage.Utils.EggModel)

local heldScale = 0.7

local Tools = {}

Tools.EggAttribute = "EggId"

function Tools.NameOf(egg: Eggs.Egg): string
	return egg.Name
end

local function build(egg: Eggs.Egg): Tool
	local tool = Instance.new("Tool")
	tool.Name = Tools.NameOf(egg)
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = egg.Tagline
	tool.Grip = CFrame.new(0, -0.3, 0)
	tool:SetAttribute(Tools.EggAttribute, egg.Id)
	EggModel.Build(tool, egg, { Scale = heldScale, BodyName = "Handle", Anchored = false })
	return tool
end

local function collect(player: Player): { Tool }
	local found: { Tool } = {}
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
			if child:IsA("Tool") and type(child:GetAttribute(Tools.EggAttribute)) == "string" then
				table.insert(found, child)
			end
		end
	end
	return found
end

function Tools.Sync(player: Player, heldEgg: string)
	local keep: Tool? = nil
	for _, tool in collect(player) do
		if keep == nil and tool:GetAttribute(Tools.EggAttribute) == heldEgg and Eggs.ById[heldEgg] ~= nil then
			keep = tool
		else
			tool:Destroy()
		end
	end
	local egg = Eggs.ById[heldEgg]
	local backpack = player:FindFirstChild("Backpack")
	if keep == nil and egg ~= nil and backpack then
		build(egg).Parent = backpack
	end
end

function Tools.Equip(player: Player)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid then
		return
	end
	for _, tool in collect(player) do
		if tool.Parent ~= character then
			humanoid:EquipTool(tool)
		end
		return
	end
end

function Tools.Clear(player: Player)
	Tools.Sync(player, "")
end

return Tools
