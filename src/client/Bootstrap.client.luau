--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:WaitForChild("Packages")
packages:WaitForChild("Trove")
ReplicatedStorage:WaitForChild("ReplicaShared")
ReplicatedStorage:WaitForChild("ReplicaClient")

local Lifecycle = require(ReplicatedStorage:WaitForChild("Lifecycle"))
local controllers = require(script.Parent.Registry)
local WorldNames = require(ReplicatedStorage.Config.WorldNames)
local Attributes = WorldNames.Attributes
local runtime = Lifecycle.new(controllers)

script.Destroying:Connect(function()
	runtime:Destroy()
end)

runtime:Start()
script:SetAttribute(Attributes.Ready, true)
Players.LocalPlayer:SetAttribute(Attributes.ClientReady, true)
