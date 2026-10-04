--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)

local config = GameConfig.Steal

local WalkSpeed = {}

WalkSpeed.StolenAttribute = "StolenFromUserId"

function WalkSpeed.Resolve(character: Model): number
	if character:GetAttribute(WalkSpeed.StolenAttribute) ~= nil then
		return config.CarryWalkSpeed
	end
	return config.NormalWalkSpeed
end

function WalkSpeed.Refresh(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = WalkSpeed.Resolve(character)
	end
end

return WalkSpeed
