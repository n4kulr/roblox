--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)

local config = GameConfig.Market
local reachSlack = 6
local stalls = { "Market", "MarketPlaceholder" }

local Counter = {}

local function counterPosition(): Vector3?
	for _, name in stalls do
		local stall = workspace:FindFirstChild(name)
		local counter = if stall then stall:FindFirstChild("Counter", true) else nil
		if counter and counter:IsA("BasePart") then
			return counter.Position
		end
	end
	return nil
end

local function isNearCounter(): boolean
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local position = counterPosition()
	if not root or not root:IsA("BasePart") or not position then
		return false
	end
	return (root.Position - position).Magnitude <= config.PromptRange + reachSlack
end

Counter.IsNear = isNearCounter

return Counter
