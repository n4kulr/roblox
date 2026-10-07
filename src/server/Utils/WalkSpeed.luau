--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local WorldNames = require(ReplicatedStorage.Config.WorldNames)
local Character = require(script.Parent.Character)

local config = GameConfig.Steal

local WalkSpeed = {}

WalkSpeed.TapAttribute = WorldNames.Attributes.TapSpeed
WalkSpeed.StolenAttribute = WorldNames.Attributes.StolenFromUserId

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
	local humanoid = Character.HumanoidOf(character)
	if humanoid then
		humanoid.WalkSpeed = WalkSpeed.Resolve(character)
	end
end

return WalkSpeed
