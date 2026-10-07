--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldNames = require(ReplicatedStorage.Config.WorldNames)
local EditorOnly = require(script.Parent.Utils.EditorOnly)

EditorOnly.Strip()

local Lifecycle = require(ReplicatedStorage:WaitForChild("Lifecycle"))
local services = require(script.Parent.Registry)
local runtime = Lifecycle.new(services)

game:BindToClose(function()
	runtime:Destroy()
end)

runtime:Start()
script:SetAttribute(WorldNames.Attributes.Ready, true)
