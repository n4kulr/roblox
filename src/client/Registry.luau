--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lifecycle = require(ReplicatedStorage.Lifecycle)

local controllers: { Lifecycle.System } = {
	require(script.Parent.Controllers.DataController),
	require(script.Parent.Controllers.AppController),
	require(script.Parent.Controllers.SoundController),
	require(script.Parent.Controllers.RollController),
	require(script.Parent.Controllers.KeyboardController),
	require(script.Parent.Controllers.KeyPressController),
	require(script.Parent.Controllers.TutorialController),
	require(script.Parent.Controllers.UIController),
	require(script.Parent.Controllers.StealController),
	require(script.Parent.Controllers.TradeController),
	require(script.Parent.Controllers.KeyfallController),
	require(script.Parent.Controllers.ComponentController),
}

return controllers
