--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lifecycle = require(ReplicatedStorage.Lifecycle)

local services: { Lifecycle.System } = {
	require(script.Parent.Services.DataService),
	require(script.Parent.Services.KeyboardService),
	require(script.Parent.Services.PlotService),
	require(script.Parent.Services.RollService),
	require(script.Parent.Services.PurchaseService),
	require(script.Parent.Services.GameService),
	require(script.Parent.Services.ComponentService),
}

return services
