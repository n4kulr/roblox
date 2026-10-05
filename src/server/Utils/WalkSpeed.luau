--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)

local config = GameConfig.Steal

local WalkSpeed = {}

WalkSpeed.TapAttribute = "TapSpeed"
WalkSpeed.StolenAttribute = "StolenFromUserId"

function WalkSpeed.Resolve(character: Model): number
	if character:GetAttribute(WalkSpeed.StolenAttribute) ~= nil then
		return config.CarryWalkSpeed
	end
	local tap = character:GetAttribute(WalkSpeed.TapAttribute)
	if type(tap) == "number" then
		return tap
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
