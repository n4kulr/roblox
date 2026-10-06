--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lifecycle = require(ReplicatedStorage.Lifecycle)

local services: { Lifecycle.System } = {
	require(script.Parent.Services.MeshService),
	require(script.Parent.Services.DataService),
	require(script.Parent.Services.PassService),
	require(script.Parent.Services.KeyboardService),
	require(script.Parent.Services.PlotService),
	require(script.Parent.Services.CosmeticService),
	require(script.Parent.Services.PlaytimeService),
	require(script.Parent.Services.StealService),
	require(script.Parent.Services.KeyfallService),
	require(script.Parent.Services.UpgradeService),
	require(script.Parent.Services.SeasonService),
	require(script.Parent.Services.RollService),
	require(script.Parent.Services.SettingsService),
	require(script.Parent.Services.PurchaseService),
	require(script.Parent.Services.EggService),
	require(script.Parent.Services.AdminService),
	require(script.Parent.Services.MarketService),
	require(script.Parent.Services.TradeService),
	require(script.Parent.Services.RebirthService),
	require(script.Parent.Services.CodeService),
	require(script.Parent.Services.LeaderboardService),
	require(script.Parent.Services.GameService),
}

return services
