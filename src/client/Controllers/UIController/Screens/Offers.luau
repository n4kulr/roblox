--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Monetization = require(ReplicatedStorage.Config.Monetization)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Boosts = require(ReplicatedStorage.Rules.Boosts)
local Daily = require(ReplicatedStorage.Rules.Daily)
local TimeFormat = require(ReplicatedStorage.Utils.TimeFormat)
local BoostState = require(script.Parent.Parent.BoostState)
local Kit = require(script.Parent.Parent.Kit)
local Purchases = require(script.Parent.Parent.Purchases)
local Types = require(script.Parent.Parent.Types)

type BoostPill = {
	Frame: Frame,
	Label: TextLabel,
}

local theme = Kit.Theme
local menuHalfHeight = 88
local dailyWidth = 176
local dailyHeight = 50
local menuGap = 8
local stackWidth = 168
local pillWidth = 176
local pillHeight = 30
local multipliersHeight = 64
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
		Text = "📅 DAILY REWARDS",
		Size = UDim2.fromOffset(dailyWidth, dailyHeight),
		Position = UDim2.new(0, 12, 0.5, -(menuHalfHeight + menuGap)),
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

	local stack = Instance.new("Frame")
	stack.Name = "Offers"
	stack.BackgroundTransparency = 1
	stack.AnchorPoint = Vector2.new(1, 0.5)
	stack.Position = UDim2.new(1, -12, 0.5, 0)
	stack.AutomaticSize = Enum.AutomaticSize.Y
	stack.Size = UDim2.fromOffset(stackWidth, 0)
	local stackList = Instance.new("UIListLayout")
	stackList.SortOrder = Enum.SortOrder.LayoutOrder
	stackList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	stackList.Padding = UDim.new(0, 8)
	stackList.Parent = stack
	stack.Parent = root

	local function comingSoon()
		playUi("Error")
		context.Toast("Coming soon! 🚧", "Info")
	end

	Kit.Button(trove, {
		Parent = stack,
		Name = "Shop",
		Text = "🛒 SHOP",
		Size = UDim2.fromOffset(stackWidth, 52),
		Color = theme.Red,
		TextSize = 26,
		LayoutOrder = 1,
		Callback = function()
			toggleScreen("Shop")
		end,
		Sound = playUi,
	})

	local starterPack = Monetization.ProductById.StarterPack
	local giftButton = Kit.Button(trove, {
		Parent = stack,
		Name = "StarterPack",
		Text = "🎁 STARTER PACK",
		Size = UDim2.fromOffset(stackWidth, 56),
		Color = theme.Orange,
		TextSize = 22,
		LayoutOrder = 2,
		Callback = function()
			if not Purchases.PromptProduct(starterPack) then
				comingSoon()
			end
		end,
		Sound = playUi,
	})
	giftButton.SetGlow(true)
	trove:Add(dataController:Observe({ "StarterPackBought" }, function(value: any)
		giftButton.Instance.Visible = value ~= true
	end))

	local passButtons: { [string]: Kit.Button } = {}
	local function passPill(passId: string, color: Color3, order: number)
		local pass = Monetization.PassById[passId]
		passButtons[passId] = Kit.Button(trove, {
			Parent = stack,
			Name = passId,
			Text = pass.Name,
			Size = UDim2.fromOffset(stackWidth, 44),
			Color = color,
			TextSize = 24,
			LayoutOrder = order,
			Callback = function()
				if boostState.Owns(passId) then
					context.Toast("You already own this! ✅", "Good")
				elseif not Purchases.PromptPass(pass) then
					comingSoon()
				end
			end,
			Sound = playUi,
		})
	end
	passPill("DoubleLuck", theme.Green, 3)
	passPill("DoubleClicks", theme.Yellow, 4)

	local badges = Instance.new("Frame")
	badges.Name = "BoostBadges"
	badges.BackgroundTransparency = 1
	badges.AnchorPoint = Vector2.new(1, 1)
	badges.Position = UDim2.new(1, -12, 1, -(12 + multipliersHeight + 8))
	badges.AutomaticSize = Enum.AutomaticSize.Y
	badges.Size = UDim2.fromOffset(pillWidth, 0)
	local badgeList = Instance.new("UIListLayout")
	badgeList.SortOrder = Enum.SortOrder.LayoutOrder
	badgeList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	badgeList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	badgeList.Padding = UDim.new(0, 6)
	badgeList.Parent = badges
	badges.Parent = root

	local function boostPill(name: string, color: Color3, order: number): BoostPill
		local frame = Kit.Panel({
			Parent = badges,
			Name = name,
			Size = UDim2.fromOffset(pillWidth, pillHeight),
			Color = color,
			LayoutOrder = order,
			Radius = 4,
			StrokeThickness = 2.5,
			Bevel = false,
		})
		frame.Visible = false
		local label = Kit.Label({
			Parent = frame,
			Name = "Text",
			Text = "",
			Position = UDim2.fromOffset(4, 0),
			Size = UDim2.new(1, -8, 1, 0),
			TextSize = 20,
			Align = Enum.TextXAlignment.Center,
			Scaled = true,
		})
		return { Frame = frame, Label = label }
	end
	local luckPill = boostPill("LuckPotion", theme.Green, 1)
	local clicksPill = boostPill("ClicksPotion", theme.Yellow, 2)
	local serverPill = boostPill("ServerLuck", theme.Purple, 3)

	local function showPill(pill: BoostPill, emoji: string, multiplier: number, secondsLeft: number)
		local isActive = secondsLeft > 0
		pill.Frame.Visible = isActive
		if isActive then
			pill.Label.Text = `{emoji} {multiplierLabel(multiplier)}x {TimeFormat.Clock(secondsLeft)}`
		end
	end

	local function showServerPill(secondsLeft: number)
		local isActive = secondsLeft > 0
		serverPill.Frame.Visible = isActive
		if isActive then
			serverPill.Label.Text =
				`🌟 Server {multiplierLabel(GameConfig.Boosts.ServerLuckMultiplier)}x {TimeFormat.Clock(
					secondsLeft
				)}`
		end
	end

	local function refresh()
		local now = workspace:GetServerTimeNow()
		local stored = boostState.Stored()
		showPill(
			luckPill,
			"🍀",
			GameConfig.Boosts.PotionMultiplier,
			Boosts.Remaining(stored.LuckUntil or 0, now)
		)
		showPill(
			clicksPill,
			"💰",
			GameConfig.Boosts.PotionMultiplier,
			Boosts.Remaining(stored.ClicksUntil or 0, now)
		)
		local serverUntil = boostState.ServerLuck()
		showServerPill(Boosts.Remaining(serverUntil, now))
		for passId, button in passButtons do
			local isOwned = boostState.Owns(passId)
			button.SetDisabled(isOwned)
			button.SetText(if isOwned then "OWNED ✓" else Monetization.PassById[passId].Name)
		end
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
				`🌟 {name} activated Server Luck! {multiplierLabel(GameConfig.Boosts.ServerLuckMultiplier)}x Luck for everyone!`,
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
