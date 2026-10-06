--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local BaseBounds = require(ReplicatedStorage.Utils.BaseBounds)

local BaseZone = {}

function BaseZone.IsInside(plot: Model?, character: Model?): boolean
	local base = if plot then plot:FindFirstChild("Base") else nil
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not base or not base:IsA("BasePart") or not root or not root:IsA("BasePart") then
		return false
	end
	return BaseBounds.Contains(base.CFrame, base.Size, root.CFrame.Position, GameConfig.RollInBaseMargin)
end

return BaseZone
