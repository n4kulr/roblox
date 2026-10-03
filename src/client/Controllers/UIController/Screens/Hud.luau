--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Upgrades = require(ReplicatedStorage.Config.Upgrades)
local Trove = require(ReplicatedStorage.Packages.Trove)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Economy = require(script.Parent.Parent.Economy)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)

local theme = Kit.Theme
local hintStep = 2

local Hud = {}

function Hud.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local dataController = context.Controllers.DataController
	local playUi = Kit.UiSound(context.Controllers)
	local gui, root = Kit.ScreenGui("ThockHud", 1, context.PlayerGui, trove)
	local tracker = Economy.Track(dataController, trove)
	local tutorialStep = 0
	local lastCash = ""
	local lastIncome = ""
	local lastStats = ""
	local isHinting = false
	local pulseTween: Tween? = nil

	local top = Kit.Panel({
		Parent = root,
		Name = "Top",
		Size = UDim2.fromOffset(300, 108),
		Position = UDim2.new(0.5, 0, 0, 8),
		AnchorPoint = Vector2.new(0.5, 0),
		Transparency = 0.2,
	})
	local cashLabel = Kit.Label({
		Parent = top,
		Name = "Cash",
		Text = "...",
		Position = UDim2.fromOffset(0, 4),
		Size = UDim2.new(1, 0, 0, 52),
		TextSize = 42,
		Color = theme.Gold,
		Align = Enum.TextXAlignment.Center,
	})
	local incomeLabel = Kit.Label({
		Parent = top,
		Name = "Income",
		Text = "",
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 0, 26),
		TextSize = 22,
		Color = theme.Good,
		Align = Enum.TextXAlignment.Center,
	})
	local statsLabel = Kit.Label({
		Parent = top,
		Name = "Stats",
		Text = "",
		Position = UDim2.fromOffset(0, 82),
		Size = UDim2.new(1, 0, 0, 20),
		TextSize = 16,
		Color = theme.TextDim,
		Align = Enum.TextXAlignment.Center,
		Bold = false,
	})

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundTransparency = 1
	bar.AnchorPoint = Vector2.new(0.5, 1)
	bar.Position = UDim2.new(0.5, 0, 1, -12)
	bar.Size = UDim2.fromOffset(0, Kit.ButtonHeight)
	bar.AutomaticSize = Enum.AutomaticSize.X
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 10)
	list.Parent = bar
	bar.Parent = root

	local function barButton(name: string, text: string, order: number, target: string): Kit.Button
		return Kit.Button(trove, {
			Parent = bar,
			Name = name,
			Text = text,
			LayoutOrder = order,
			Size = UDim2.fromOffset(150, Kit.ButtonHeight),
			Color = theme.Panel,
			Callback = function()
				context.Open(target)
			end,
			Sound = playUi,
		})
	end
	local upgradesButton = barButton("Upgrades", "Upgrades", 1, "Shop")
	barButton("Keys", "Keys", 2, "Keys")
	barButton("Settings", "Settings", 3, "Settings")

	local tooltip = Kit.Panel({
		Parent = root,
		Name = "Tooltip",
		Size = UDim2.fromOffset(250, 44),
		Position = UDim2.new(0.5, 0, 1, -84),
		AnchorPoint = Vector2.new(0.5, 1),
		StrokeColor = theme.Gold,
	})
	tooltip.Visible = false
	Kit.Label({
		Parent = tooltip,
		Name = "Text",
		Text = "Buy your first upgrade!",
		Size = UDim2.fromScale(1, 1),
		TextSize = 20,
		Color = theme.Gold,
		Align = Enum.TextXAlignment.Center,
	})
	local bounce = TweenService:Create(
		tooltip,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = UDim2.new(0.5, 0, 1, -92) }
	)
	trove:Add(function()
		bounce:Cancel()
		bounce:Destroy()
	end)

	local function setHinting(value: boolean)
		if value == isHinting then
			return
		end
		isHinting = value
		tooltip.Visible = value
		local stroke = upgradesButton.Instance:FindFirstChildOfClass("UIStroke")
		if value then
			bounce:Play()
			if stroke then
				stroke.Color = theme.Gold
				local tweenInstance = TweenService:Create(
					stroke,
					TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
					{ Thickness = 5 }
				)
				pulseTween = tweenInstance
				tweenInstance:Play()
			end
		else
			bounce:Pause()
			local active = pulseTween
			if active then
				active:Cancel()
				active:Destroy()
				pulseTween = nil
			end
			if stroke then
				stroke.Color = theme.Stroke
				stroke.Thickness = 1.5
			end
		end
	end
	trove:Add(function()
		setHinting(false)
	end)

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

	local function refresh()
		local balance = tracker.Balance()
		local stats = tracker.GetStats()
		local cashText = if balance then NumberFormat.Compact(balance) else "..."
		if cashText ~= lastCash then
			lastCash = cashText
			cashLabel.Text = cashText
		end
		local incomeText = if balance then `+{NumberFormat.Compact(stats.Rate)}/s` else ""
		if incomeText ~= lastIncome then
			lastIncome = incomeText
			incomeLabel.Text = incomeText
		end
		local statsText = if balance
			then string.format("Luck x%.2f  |  %.1f rolls/s", stats.Luck, stats.RollsPerSecond)
			else ""
		if statsText ~= lastStats then
			lastStats = statsText
			statsLabel.Text = statsText
		end
		local cost = cheapestCost()
		setHinting(tutorialStep == hintStep and balance ~= nil and cost ~= nil and balance >= cost)
	end

	trove:Add(dataController:Observe({ "Tutorial" }, function(value: any)
		tutorialStep = if type(value) == "number" then value else 0
	end))

	local elapsedSinceRefresh = 0
	trove:Connect(RunService.Heartbeat, function(dt: number)
		elapsedSinceRefresh += dt
		if elapsedSinceRefresh >= 0.1 then
			elapsedSinceRefresh = 0
			refresh()
		end
	end)
	refresh()

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
