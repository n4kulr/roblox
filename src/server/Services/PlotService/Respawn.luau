--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FloorGrid = require(ReplicatedStorage.Rules.FloorGrid)
local WalkSpeed = require(script.Parent.Parent.Parent.Utils.WalkSpeed)
local Types = require(script.Parent.Types)

local Respawn = {}

function Respawn.HomeCFrame(info: Types.PlotInfo): CFrame
	return info.Base.CFrame * CFrame.new(0, info.Base.Size.Y / 2 + FloorGrid.CapHeight + 3, 0)
end

function Respawn.Teleport(context: Types.Context, player: Player, character: Model)
	task.spawn(function()
		local root = character:WaitForChild("HumanoidRootPart", 10)
		local info = context.ByPlayer[player]
		if not root or not info or character.Parent == nil then
			return
		end
		character:PivotTo(context.RespawnPoints[player] or Respawn.HomeCFrame(info))
	end)
end

function Respawn.ApplyWalkSpeed(character: Model)
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			WalkSpeed.Refresh(character)
		end
	end)
end

return Respawn
