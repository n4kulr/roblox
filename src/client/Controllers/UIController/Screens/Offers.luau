--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Boosts = require(ReplicatedStorage.Rules.Boosts)
local Daily = require(ReplicatedStorage.Rules.Daily)
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
local screenMargin = 24
local menuHalfHeight = 92
local offerWidth = 184
local offerHeight = 52
local menuGap = 8
local effectWidth = 72
local effectHeight = 56
local multipliersHeight = 148
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
		Glyph = "Daily",
		IconLeft = true,
		Text = "DAILY",
		Size = UDim2.fromOffset(offerWidth, offerHeight),
		Position = UDim2.new(0, screenMargin, 0.5, -(menuHalfHeight + menuGap)),
		AnchorPoint = Vector2.new(0, 1),
		Color = theme.Green,
		TextSize = 22,
		Callback = function()
			toggleScreen("Daily")
		end,
		Sound = playUi,
	})
	local dailyBadge = Kit.Badge(dailyButton.Instance, "!")
	dailyBadge.Visible = false

	local giftButton = Kit.Button(trove, {
		Parent = root,
		Name = "StarterPack",
		Glyph = "Gift",
		IconLeft = true,
		Text = "STARTER PACK",
		Size = UDim2.fromOffset(offerWidth, offerHeight),
		Position = UDim2.new(0, screenMargin, 0.5, menuHalfHeight + menuGap),
		Color = theme.Orange,
		TextSize = 22,
		Callback = function()
			context.Open("StarterOffer")
		end,
		Sound = playUi,
	})
	giftButton.SetGlow(true)
	trove:Add(dataController:Observe({ "StarterPackBought" }, function(value: any)
		giftButton.Instance.Visible = value ~= true
	end))

	local badges = Instance.new("Frame")
	badges.Name = "BoostBadges"
	badges.BackgroundTransparency = 1
	badges.AnchorPoint = Vector2.new(1, 1)
	badges.Position = UDim2.new(1, -screenMargin, 1, -(screenMargin + multipliersHeight + menuGap))
	badges.AutomaticSize = Enum.AutomaticSize.X
	badges.Size = UDim2.fromOffset(0, effectHeight)
	local badgeList = Instance.new("UIListLayout")
	badgeList.SortOrder = Enum.SortOrder.LayoutOrder
	badgeList.FillDirection = Enum.FillDirection.Horizontal
	badgeList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	badgeList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	badgeList.Padding = UDim.new(0, menuGap)
	badgeList.Parent = badges
	badges.Parent = root

	local function boostPill(name: string, glyph: string, order: number): BoostPill
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Size = UDim2.fromOffset(effectWidth, effectHeight)
		frame.LayoutOrder = order
		frame.Visible = false
		frame.Parent = badges
		Kit.Icon({
			Parent = frame,
			Name = "Icon",
			Glyph = glyph,
			Size = UDim2.fromOffset(32, 32),
			Position = UDim2.fromOffset(0, 0),
		})
		local multiplierText = Kit.Label({
			Parent = frame,
			Name = "Multiplier",
			Text = "",
			Size = UDim2.fromOffset(effectWidth - 36, 32),
			Position = UDim2.fromOffset(36, 0),
			TextSize = 24,
		})
		local timer = Kit.Label({
			Parent = frame,
			Name = "Timer",
			Text = "",
			Size = UDim2.fromOffset(effectWidth, 20),
			Position = UDim2.fromOffset(0, 36),
			TextSize = 16,
			Color = theme.TextDim,
			Align = Enum.TextXAlignment.Center,
		})
		return { Frame = frame, Multiplier = multiplierText, Timer = timer }
	end
	local luckPill = boostPill("LuckPotion", "Flask", 1)
	local clicksPill = boostPill("ClicksPotion", "Coin", 2)
	local serverPill = boostPill("ServerLuck", "Globe", 3)

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
				"Good"
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
