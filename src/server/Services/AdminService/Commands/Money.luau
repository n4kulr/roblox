--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Config = require(script.Parent.Parent.Parent.Parent.Config.Admin)
local Rewards = require(script.Parent.Parent.Parent.Parent.Utils.Rewards)
local Amount = require(script.Parent.Parent.Amount)
local Types = require(script.Parent.Parent.Types)
local Support = require(script.Parent.Support)

local maxCash = GameConfig.MaxCash
local maxMoneyValue = Config.MaxMoneyValue
local dataOf = Support.DataOf
local reward = Support.Reward

local function addClicks(context: Types.Context, player: Player, requested: number): number
	local services = context.Services
	services.KeyboardService:Settle(player)
	local data = dataOf(context, player)
	if not data then
		return 0
	end
	local amount = math.min(requested, maxCash - data.Cash)
	if amount <= 0 or not Rewards.AddClicks(player, services, amount) then
		return 0
	end
	return amount
end

local function setClicks(context: Types.Context, player: Player, value: number): boolean
	local services = context.Services
	services.KeyboardService:Settle(player)
	local data = dataOf(context, player)
	if not data then
		return false
	end
	local target = math.clamp(math.floor(value), 0, maxCash)
	local gained = target - data.Cash
	services.DataService:Set(player, { "Cash" }, target)
	if gained > 0 then
		services.DataService:Set(player, { "TotalEarned" }, data.TotalEarned + gained)
	end
	services.DataService:RequestSave(player)
	return true
end

local Money = {}

function Money.Register(builder: Types.Builder)
	local simple, withArgument = builder.Simple, builder.WithArgument

	withArgument(
		"money",
		"money <amount> [player|all]",
		"Add Clicks (1k 2.5m 1b 1t)",
		function(context, _admin, target, args)
			local amount = Amount.Parse(args[1])
			if not amount or amount < 1 then
				return false, "Bad amount"
			end
			local added = addClicks(context, target, amount)
			if added <= 0 then
				return false, "Clicks are already maxed"
			end
			reward(target, "Cash", string.format("%d", added), 1)
			return true, `Added {NumberFormat.Compact(added)} Clicks`
		end
	)

	withArgument(
		"setmoney",
		"setmoney <amount> [player|all]",
		"Set Clicks to an exact amount",
		function(context, _admin, target, args)
			local amount = Amount.Parse(args[1])
			if not amount then
				return false, "Bad amount"
			end
			if not setClicks(context, target, amount) then
				return false, "Data not loaded"
			end
			return true, `Clicks set to {NumberFormat.Compact(math.min(amount, maxCash))}`
		end
	)

	simple("resetmoney", "resetmoney [player|all]", "Set Clicks to 0", function(context, _admin, target)
		if not setClicks(context, target, 0) then
			return false, "Data not loaded"
		end
		return true, "Clicks reset to 0"
	end)

	simple(
		"maxmoney",
		"maxmoney [player|all]",
		"Set Clicks to 1 quadrillion",
		function(context, _admin, target)
			local before = dataOf(context, target)
			local previous = if before then before.Cash else 0
			if not setClicks(context, target, maxMoneyValue) then
				return false, "Data not loaded"
			end
			if maxMoneyValue > previous then
				reward(target, "Cash", string.format("%d", maxMoneyValue - previous), 1)
			end
			return true, `Clicks set to {NumberFormat.Compact(maxMoneyValue)}`
		end
	)

	withArgument(
		"income",
		"income <seconds> [player|all]",
		"Grant N seconds of current income",
		function(context, _admin, target, args)
			local seconds = Amount.Parse(args[1])
			if not seconds or seconds < 1 then
				return false, "Bad seconds"
			end
			local rate = context.Services.KeyboardService:GetRate(target)
			local earned = math.floor(rate * seconds)
			if earned < 1 then
				return false, "No income to grant"
			end
			local added = addClicks(context, target, earned)
			if added <= 0 then
				return false, "Clicks are already maxed"
			end
			reward(target, "Cash", string.format("%d", added), 1)
			return true, `Granted {NumberFormat.Compact(added)} Clicks ({seconds}s of income)`
		end
	)
end

return Money
