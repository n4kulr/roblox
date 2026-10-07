--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Upgrades = require(ReplicatedStorage.Config.Upgrades)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Rebirth = require(ReplicatedStorage.Rules.Rebirth)
local Season = require(ReplicatedStorage.Rules.Season)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local TimeFormat = require(ReplicatedStorage.Utils.TimeFormat)
local Economy = require(script.Parent.Parent.Economy)
local Kit = require(script.Parent.Parent.Kit)
local Playtime = require(script.Parent.Parent.Playtime)
local Types = require(script.Parent.Parent.Types)
local Badges = require(script.Badges)
local Currency = require(script.Currency)
local Golden = require(script.Golden)
local Hint = require(script.Hint)
local HudTypes = require(script.Types)
local RollBar = require(script.RollBar)
local SideMenu = require(script.SideMenu)
local StatChips = require(script.StatChips)
local TopBar = require(script.TopBar)

local hintStep = 2
local balanceSeconds = 0.1
local slowSeconds = 1

local function multiplierText(value: number): string
	local text = string.format("%.2f", value)
	text = string.gsub(text, "0+$", "")
	text = string.gsub(text, "%.$", "")
	return `x{text}`
end

local Hud = {}

function Hud.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local dataController = context.Controllers.DataController
	local rollController = context.Controllers.RollController
	local gui, root = Kit.ScreenGui("ThockHud", Kit.Layer.Hud, context.PlayerGui, trove)
	local isDirty = true
	local tracker = Economy.For(context, trove, function()
		isDirty = true
	end)
	local tutorialStep = 0
	local lastIncome = ""
	local lastStats = ""

	local function toggleScreen(target: string)
		if context.IsOpen(target) then
			context.Close(target)
		else
			context.Open(target)
		end
	end

	local env: HudTypes.Env = {
		Trove = trove,
		Root = root,
		Context = context,
		DataController = dataController,
		RollController = rollController,
		Toggle = toggleScreen,
	}
	local buttons = SideMenu.Build(env)
	local setAnchor = context.SetAnchor
	if setAnchor then
		setAnchor("Pets", buttons.Pets.Instance)
		trove:Add(function()
			setAnchor("Pets", nil)
		end)
	end
	local badges = Badges.Build(env, buttons)
	local setHinting = Hint.Build(env, buttons.Upgrades)
	local myBaseButton = TopBar.Build(env)
	local currency = Currency.Build(env)
	local statText = StatChips.Build(env)
	local bottom = RollBar.Build(env, myBaseButton)
	Golden.Build(env, bottom)

	local cashCount = currency.Cash
	local incomeLabel = currency.Income
	local upgradesBadge = badges.Upgrades
	local rebirthBadge = badges.Rebirth
	local passBadge = badges.Pass
	local dailyBadge = badges.Daily
	local dailyBadgeText = badges.DailyText
	local dailyTimer = badges.DailyTimer
	local dailyTimerText = badges.DailyTimerText

	local function cheapestCost(): number?
		local cheapest: number? = nil
		for _, upgrade in Upgrades.List do
			local cost = Upgrades.Cost(upgrade, tracker.GetLevel(upgrade.Id))
			if cost and (not cheapest or cost < cheapest) then
				cheapest = cost
			end
		end
		return cheapest
	end

	local function currentSeason(): Season.Progress
		local value = dataController:Get({ "Season" })
		return if type(value) == "table" then value else {}
	end

	local stats = tracker.GetStats()
	local upgradeCost: number? = nil
	local rebirthCost = 0
	local hasBalance = false

	local function writeStats(balance: number?)
		local incomeText = if balance then `+{NumberFormat.Compact(stats.Rate)}/s` else ""
		if incomeText ~= lastIncome then
			lastIncome = incomeText
			incomeLabel.Text = incomeText
		end
		local luckText = if balance then multiplierText(stats.Luck) else ""
		local speedText = if balance then string.format("%.1f/s", stats.RollsPerSecond) else ""
		local incomeMultiplierText = if balance then multiplierText(stats.IncomeMultiplier) else ""
		local statsText = `{luckText}|{speedText}|{incomeMultiplierText}`
		if statsText ~= lastStats then
			lastStats = statsText
			statText.Luck.Text = luckText
			statText.Speed.Text = speedText
			statText.Income.Text = incomeMultiplierText
		end
	end

	local function refreshBalance()
		local balance = tracker.Balance()
		cashCount.SetTarget(balance)
		if (balance ~= nil) ~= hasBalance then
			hasBalance = balance ~= nil
			writeStats(balance)
		end
		local canAfford = balance ~= nil and upgradeCost ~= nil and balance >= upgradeCost
		upgradesBadge.Visible = canAfford
		rebirthBadge.Visible = balance ~= nil and balance >= rebirthCost
		setHinting(tutorialStep == hintStep and canAfford)
	end

	local function refreshSlow()
		stats = tracker.GetStats()
		upgradeCost = cheapestCost()
		rebirthCost = Rebirth.Cost(tracker.GetRebirths())
		writeStats(tracker.Balance())
		passBadge.Visible = #Season.Claimable(
			currentSeason(),
			tracker.Boosts.Owns(GameConfig.Season.PremiumPassId)
		) > 0
		local gifts = Playtime.Read(Players.LocalPlayer, workspace:GetServerTimeNow())
		dailyBadge.Visible = gifts.ReadyCount > 0
		if gifts.ReadyCount > 0 then
			dailyBadgeText.Text = tostring(gifts.ReadyCount)
		end
		local nextLeft = gifts.NextLeft
		dailyTimer.Visible = gifts.ReadyCount == 0 and nextLeft ~= nil
		if nextLeft then
			dailyTimerText.Text = TimeFormat.Clock(nextLeft)
		end
	end

	local function refresh()
		isDirty = false
		refreshSlow()
		refreshBalance()
	end

	trove:Add(dataController:Observe({ "Tutorial" }, function(value: any)
		tutorialStep = if type(value) == "number" then value else 0
	end))
	trove:Add(dataController:Observe({ "Season" }, function()
		isDirty = true
	end))

	local slowElapsed = 0
	Kit.Poll(trove, 0, nil, function(dt: number)
		slowElapsed += dt
		if isDirty or slowElapsed >= slowSeconds then
			slowElapsed = 0
			isDirty = false
			refreshSlow()
		end
	end)
	Kit.Poll(trove, balanceSeconds, nil, refreshBalance)
	Kit.Poll(trove, 0, nil, cashCount.Step)
	refresh()
	cashCount.Step(1)

	return {
		Modal = false,
		StartsOpen = true,
		Open = function(_self: Types.Screen)
			gui.Enabled = true
		end,
		Close = function(_self: Types.Screen)
			gui.Enabled = false
		end,
		Destroy = function(_self: Types.Screen)
			trove:Destroy()
		end,
	}
end

return Hud
