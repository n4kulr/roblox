--!strict

local Players = game:GetService("Players")

local Loader = require(script.Loader)

local player = Players.LocalPlayer
while not player do
	Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
	player = Players.LocalPlayer
end

Loader.Start(player)
