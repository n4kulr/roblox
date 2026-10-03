--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Boosts = require(ReplicatedStorage.Rules.Boosts)
local Daily = require(ReplicatedStorage.Rules.Daily)
local Market = require(ReplicatedStorage.Rules.Market)
local TimeFormat = require(ReplicatedStorage.Utils.TimeFormat)
local BoostState = require(script.Parent.Parent.BoostState)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)

type BoostPill = {
	Frame: Frame,
	Multiplier: TextLabel,
	Timer: TextLabel,
}

local theme = Kit.Theme
local margin = Kit.Margin
local columnWidth = 176
local effectWidth = 72
local effectHeight = 62
local statsHeight = 48
local refreshSeconds = 0.25

local function multiplierLabel(value: number): string
	return string.format("%g", value)
end

local Offers = {}

function Offers.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local playUi = Kit.UiSound(context.Controllers)
	local dataController = context.Controllers.DataController
	local boostState = BoostState.Track(dataController, trove)
	local gui, root = Kit.ScreenGui("ThockOffers", 1, context.PlayerGui, trove)

	local function toggleScreen(target: string)
		if context.IsOpen(target) then
			context.Close(target)
		else
			context.Open(target)
		end
	end

	local dailyButton = Kit.Button(trove, {
		Parent = root,
		Name = "DailyRewards",
		Text = "DAILY REWARDS",
		GlyphName = "daily",
		Size = UDim2.fromOffset(columnWidth, 52),
		Position = UDim2.fromOffset(margin, margin),
		Color = theme.Blue,
		TextSize = 16,
		Shards = true,
		Callback = function()
			toggleScreen("Daily")
		end,
		Sound = playUi,
	})
	local dailyBadge = Kit.Badge(dailyButton.Instance, "!")
	dailyBadge.Visible = false

	local stack = Instance.new("Frame")
	stack.Name = "Offers"
	stack.BackgroundTransparency = 1
	stack.AnchorPoint = Vector2.new(1, 0)
	stack.Position = UDim2.new(1, -margin, 0, margin)
	stack.AutomaticSize = Enum.AutomaticSize.Y
	stack.Size = UDim2.fromOffset(columnWidth, 0)
	local stackList = Instance.new("UIListLayout")
	stackList.SortOrder = Enum.SortOrder.LayoutOrder
	stackList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	stackList.Padding = UDim.new(0, 16)
	stackList.Parent = stack
	stack.Parent = root

	local giftButton = Kit.Button(trove, {
		Parent = stack,
		Name = "StarterPack",
		Text = "STARTER PACK",
		GlyphName = "gift",
		Size = UDim2.fromOffset(columnWidth, 52),
		Color = theme.Gold,
		TextSize = 16,
		Shards = true,
		LayoutOrder = 1,
		Callback = function()
			context.Open("StarterOffer")
		end,
		Sound = playUi,
	})
	giftButton.SetGlow(true)
	trove:Add(dataController:Observe({ "StarterPackBought" }, function(value: any)
		giftButton.Instance.Visible = value ~= true
	end))

	local marketPlate, marketInner = Kit.Plate({
		Parent = stack,
		Name = "MarketStock",
		Class = "TextButton",
		Size = UDim2.fromOffset(columnWidth, 56),
		LayoutOrder = 2,
		Lip = true,
	})
	local marketButton: TextButton = marketPlate :: any
	local marketIcon = Kit.Icon(marketInner, "market", 40)
	marketIcon.AnchorPoint = Vector2.new(0, 0.5)
	marketIcon.Position = UDim2.new(0, 8, 0.5, 0)
	Kit.Caption({
		Parent = marketInner,
		Name = "Caption",
		Text = "New stock in",
		Position = UDim2.fromOffset(56, 6),
		Size = UDim2.new(1, -60, 0, 18),
	})
	local marketTime = Kit.Label({
		Parent = marketInner,
		Name = "Time",
		Text = "0:00",
		Position = UDim2.fromOffset(56, 24),
		Size = UDim2.new(1, -60, 0, 22),
		TextSize = 22,
	})
	trove:Connect(marketButton.Activated, function()
		playUi("Click")
		context.Toast("Visit the Key Market in the middle of the map!", "Info")
	end)

	local badges = Instance.new("Frame")
	badges.Name = "BoostBadges"
	badges.BackgroundTransparency = 1
	badges.AnchorPoint = Vector2.new(1, 1)
	badges.Position = UDim2.new(1, -margin, 1, -(margin + statsHeight + 16))
	badges.AutomaticSize = Enum.AutomaticSize.X
	badges.Size = UDim2.fromOffset(0, effectHeight)
	local badgeList = Instance.new("UIListLayout")
	badgeList.SortOrder = Enum.SortOrder.LayoutOrder
	badgeList.FillDirection = Enum.FillDirection.Horizontal
	badgeList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	badgeList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	badgeList.Padding = UDim.new(0, 16)
	badgeList.Parent = badges
	badges.Parent = root

	local function boostPill(name: string, iconName: string, order: number): BoostPill
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Size = UDim2.fromOffset(effectWidth, effectHeight)
		frame.LayoutOrder = order
		frame.Visible = false
		frame.Parent = badges
		Kit.Icon(frame, iconName, 40).Position = UDim2.fromOffset(2, 0)
		local multiplierText = Kit.Label({
			Parent = frame,
			Name = "Multiplier",
			Text = "",
			Size = UDim2.fromOffset(effectWidth - 46, 40),
			Position = UDim2.fromOffset(46, 0),
			TextSize = 22,
			Outline = true,
		})
		local timer = Kit.Label({
			Parent = frame,
			Name = "Timer",
			Text = "",
			Size = UDim2.fromOffset(effectWidth, 18),
			Position = UDim2.fromOffset(0, 42),
			TextSize = 13,
			Align = Enum.TextXAlignment.Center,
			Outline = true,
			Body = true,
		})
		return { Frame = frame, Multiplier = multiplierText, Timer = timer }
	end
	local luckPill = boostPill("LuckPotion", "luck", 1)
	local clicksPill = boostPill("ClicksPotion", "clicks", 2)
	local serverPill = boostPill("ServerLuck", "star", 3)

	local function showPill(pill: BoostPill, multiplier: number, secondsLeft: number)
		local isActive = secondsLeft > 0
		pill.Frame.Visible = isActive
		if isActive then
			pill.Multiplier.Text = `{multiplierLabel(multiplier)}x`
			pill.Timer.Text = TimeFormat.Clock(secondsLeft)
		end
	end

	local function refresh()
		local now = workspace:GetServerTimeNow()
		local stored = boostState.Stored()
		showPill(luckPill, GameConfig.Boosts.PotionMultiplier, Boosts.Remaining(stored.LuckUntil or 0, now))
		showPill(
			clicksPill,
			GameConfig.Boosts.PotionMultiplier,
			Boosts.Remaining(stored.ClicksUntil or 0, now)
		)
		local serverUntil = boostState.ServerLuck()
		showPill(serverPill, GameConfig.Boosts.ServerLuckMultiplier, Boosts.Remaining(serverUntil, now))
		marketTime.Text = TimeFormat.Clock(Market.SecondsLeft(now))
		local dailyData = dataController:Get({ "Daily" })
		dailyBadge.Visible = type(dailyData) == "table" and Daily.Status(dailyData, now).CanClaim
	end

	local lastServerUntil = boostState.ServerLuck()
	trove:Connect(ReplicatedStorage:GetAttributeChangedSignal("ServerLuckUntil"), function()
		local serverUntil, by = boostState.ServerLuck()
		local previous = lastServerUntil
		lastServerUntil = serverUntil
		if serverUntil > previous and serverUntil > workspace:GetServerTimeNow() then
			local name = if by ~= "" then by else "Someone"
			context.Toast(
				`{name} activated Server Luck! {multiplierLabel(GameConfig.Boosts.ServerLuckMultiplier)}x Luck for everyone!`,
				"Gold"
			)
			refresh()
		end
	end)

	local elapsed = 0
	trove:Connect(RunService.Heartbeat, function(dt: number)
		elapsed += dt
		if elapsed >= refreshSeconds then
			elapsed = 0
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

return Offers
