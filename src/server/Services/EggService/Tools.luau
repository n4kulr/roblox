--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Eggs = require(ReplicatedStorage.Config.Eggs)
local WorldNames = require(ReplicatedStorage.Config.WorldNames)
local EggModel = require(ReplicatedStorage.Utils.EggModel)
local Character = require(script.Parent.Parent.Parent.Utils.Character)

local heldScale = 0.7

local Tools = {}

Tools.EggAttribute = WorldNames.Attributes.EggId

function Tools.NameOf(egg: Eggs.Egg): string
	return egg.Name
end

local function build(egg: Eggs.Egg): Tool
	local tool = Instance.new("Tool")
	tool.Name = Tools.NameOf(egg)
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ManualActivationOnly = false
	tool.ToolTip = ""
	tool.Grip = CFrame.new(0, -0.3, 0)
	tool:SetAttribute(Tools.EggAttribute, egg.Id)
	EggModel.Build(tool, egg, { Scale = heldScale, BodyName = "Handle", Anchored = false })
	return tool
end

local function keepEquipped(tool: Tool)
	tool.AncestryChanged:Connect(function()
		if tool.Parent == nil then
			return
		end
		local parent = tool.Parent
		if parent:IsA("Backpack") then
			local player = parent.Parent
			if player and player:IsA("Player") then
				Tools.Equip(player)
			end
		end
	end)
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
	local character = player.Character
	local humanoid = Character.HumanoidOf(character)
	if keep == nil and egg ~= nil then
		local tool = build(egg)
		keepEquipped(tool)
		if character and humanoid then
			tool.Parent = character
		else
			local backpack = player:FindFirstChild("Backpack")
			if backpack then
				tool.Parent = backpack
			end
		end
		keep = tool
	elseif keep ~= nil and not keep:GetAttribute("_EggBound") then
		keep:SetAttribute("_EggBound", true)
		keepEquipped(keep)
	end
	local equipped = keep
	if equipped ~= nil and character and humanoid and equipped.Parent ~= character then
		humanoid:EquipTool(equipped)
	end
end

function Tools.Equip(player: Player)
	local character = player.Character
	local humanoid = Character.HumanoidOf(character)
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
