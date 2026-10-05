--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Boosts = require(ReplicatedStorage.Rules.Boosts)
local TimeFormat = require(ReplicatedStorage.Utils.TimeFormat)
local BoostState = require(script.Parent.Parent.BoostState)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)

type BoostPill = {
	Frame: Frame,
	Caption: Kit.Pill,
	Timer: TextLabel,
}

local margin = Kit.ScreenMargin
local statWidth = 150
local statHeight = 46
local statGap = 16
local chipWidth = 140
local chipGap = 14
local refreshSeconds = 0.25

local function multiplierLabel(value: number): string
	return string.format("%g", value)
end

local Offers = {}

function Offers.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local dataController = context.Controllers.DataController
	local boostState = BoostState.Track(dataController, trove)
	local gui, root = Kit.ScreenGui("ThockOffers", 1, context.PlayerGui, trove)

	local stack = Instance.new("Frame")
	stack.Name = "BoostBadges"
	stack.BackgroundTransparency = 1
	stack.AnchorPoint = Vector2.new(1, 1)
	stack.Position = UDim2.new(1, -(margin + statWidth + chipGap + 10), 1, -margin)
	stack.Size = UDim2.fromOffset(chipWidth, 3 * statHeight + 2 * statGap)
	local stackList = Instance.new("UIListLayout")
	stackList.SortOrder = Enum.SortOrder.LayoutOrder
	stackList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	stackList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	stackList.Padding = UDim.new(0, statGap)
	stackList.Parent = stack
	stack.Parent = root

	local function boostPill(
		name: string,
		caption: string,
		glyph: string,
		color: Color3,
		order: number
	): BoostPill
		local pill = Kit.Pill({
			Parent = stack,
			Name = name,
			Glyph = glyph,
			Caption = caption,
			Text = "",
			DiscColor = color,
			Size = UDim2.fromOffset(chipWidth - 10, statHeight),
			LayoutOrder = order,
			TextSize = 22,
		})
		pill.Instance.Visible = false
		return { Frame = pill.Instance, Caption = pill, Timer = pill.Label }
	end
	local luckPill = boostPill("LuckPotion", "LUCK", "Potion", Kit.Theme.Green, 1)
	local clicksPill = boostPill("ClicksPotion", "CLICKS", "Coin", Kit.Theme.Gold, 2)
	local serverPill = boostPill("ServerLuck", "SERVER", "Globe", Kit.Theme.Blue, 3)

	local function showPill(pill: BoostPill, multiplier: number, secondsLeft: number)
		local isActive = secondsLeft > 0
		pill.Frame.Visible = isActive
		if isActive then
			pill.Caption.SetCaption(`{multiplierLabel(multiplier)}x BOOST`)
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
