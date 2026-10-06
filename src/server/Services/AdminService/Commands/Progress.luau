--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Upgrades = require(ReplicatedStorage.Config.Upgrades)
local Boosts = require(ReplicatedStorage.Rules.Boosts)
local Charms = require(ReplicatedStorage.Rules.Charms)
local Stats = require(ReplicatedStorage.Rules.Stats)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Config = require(script.Parent.Parent.Parent.Parent.Config.Admin)
local Rewards = require(script.Parent.Parent.Parent.Parent.Utils.Rewards)
local Amount = require(script.Parent.Parent.Amount)
local Types = require(script.Parent.Parent.Types)
local Support = require(script.Parent.Support)

local dataOf = Support.DataOf
local normalize = Support.Normalize
local maxRolls = Config.MaxRolls

local function setAllUpgrades(context: Types.Context, target: Player, toMax: boolean): boolean
	local replica = context.Services.DataService:GetReplica(target)
	if not replica then
		return false
	end
	context.Services.KeyboardService:Settle(target)
	local levels: { [string]: number } = {}
	for _, upgrade in Upgrades.List do
		levels[upgrade.Id] = if toMax then upgrade.MaxLevel else 0
	end
	replica:SetValues({ "Upgrades" }, levels)
	normalize(context, target)
	context.Services.DataService:RequestSave(target)
	return true
end

local Progress = {}

function Progress.Register(builder: Types.Builder)
	local simple, withArgument = builder.Simple, builder.WithArgument

	withArgument(
		"rolls",
		"rolls <n> [player|all]",
		"Add to the roll counter",
		function(context, _admin, target, args)
			local amount = Amount.Parse(args[1])
			if not amount or amount < 1 then
				return false, "Bad amount"
			end
			local data = dataOf(context, target)
			if not data then
				return false, "Data not loaded"
			end
			local total = math.min(data.Rolls + amount, maxRolls)
			context.Services.DataService:Set(target, { "Rolls" }, total)
			context.Services.DataService:RequestSave(target)
			return true, `Rolls now {NumberFormat.Compact(total)}`
		end
	)

	simple("golden", "golden [player|all]", "Make the next roll golden", function(context, _admin, target)
		local data = dataOf(context, target)
		if not data then
			return false, "Data not loaded"
		end
		local every = Stats.GoldenEvery(data.Upgrades, Charms.Effects(data.EquippedCharms).GoldenReduction)
		context.Services.DataService:Set(target, { "GoldenProgress" }, math.max(0, every - 1))
		return true, "Next roll will be golden"
	end)

	simple("maxupgrades", "maxupgrades [player|all]", "Max every upgrade", function(context, _admin, target)
		if not setAllUpgrades(context, target, true) then
			return false, "Data not loaded"
		end
		return true, "All upgrades maxed"
	end)

	simple(
		"resetupgrades",
		"resetupgrades [player|all]",
		"Reset every upgrade",
		function(context, _admin, target)
			if not setAllUpgrades(context, target, false) then
				return false, "Data not loaded"
			end
			return true, "All upgrades reset"
		end
	)

	simple(
		"rebirth",
		"rebirth [player|all]",
		"Force a rebirth, ignoring the cost",
		function(context, _admin, target)
			if not context.Services.RebirthService:Force(target) then
				return false, "Rebirth failed"
			end
			local data = dataOf(context, target)
			return true, `Rebirthed (now {if data then data.Rebirths else 0})`
		end
	)

	local function potion(name: string, label: string, field: string)
		withArgument(
			name,
			`{name} <minutes> [player|all]`,
			`Extend the {label} potion`,
			function(context, _admin, target, args)
				local minutes = Amount.Parse(args[1])
				if not minutes or minutes < 1 then
					return false, "Bad minutes"
				end
				if not Rewards.ExtendPotion(target, context.Services, field, minutes * 60) then
					return false, "Data not loaded"
				end
				local data = dataOf(context, target)
				local boosts: { [string]: number } = if data then data.Boosts :: any else {}
				local left = Boosts.Remaining(boosts[field] or 0, os.time())
				return true, `{label} potion: {math.floor(left / 60)}m left`
			end
		)
	end

	potion("luckpotion", "Luck", "LuckUntil")
	potion("clickspotion", "Clicks", "ClicksUntil")
end

return Progress
