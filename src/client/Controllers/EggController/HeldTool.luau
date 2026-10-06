--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldNames = require(ReplicatedStorage.Config.WorldNames)

local Attributes = WorldNames.Attributes

local HeldTool = {}

function HeldTool.Find(character: Instance?): Tool?
	if not character then
		return nil
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and type(child:GetAttribute(Attributes.EggId)) == "string" then
			return child
		end
	end
	return nil
end

function HeldTool.Watch(player: Player, trove: any, onChanged: (tool: Tool?) -> ())
	local characterTrove = trove:Extend()
	local current: Tool? = nil
	local function update(character: Instance?)
		local tool = HeldTool.Find(character)
		if tool ~= current then
			current = tool
			onChanged(tool)
		end
	end
	local function bind(character: Model)
		characterTrove:Clean()
		update(character)
		characterTrove:Connect(character.ChildAdded, function()
			update(character)
		end)
		characterTrove:Connect(character.ChildRemoved, function()
			update(character)
		end)
	end
	trove:Connect(player.CharacterAdded, bind)
	trove:Connect(player.CharacterRemoving, function()
		characterTrove:Clean()
		update(nil)
	end)
	if player.Character then
		bind(player.Character)
	end
end

return HeldTool
