--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local DailyRewards = require(ReplicatedStorage.Config.DailyRewards)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Daily = require(ReplicatedStorage.Rules.Daily)
local TimeFormat = require(ReplicatedStorage.Utils.TimeFormat)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)

type Tile = {
	Panel: Frame,
	Action: Kit.Button,
	Reward: DailyRewards.Reward,
	IsGlowing: boolean,
}

local theme = Kit.Theme
local refreshSeconds = 0.5
local claimedColor = theme.Grey
local lockedColor = Color3.fromRGB(70, 78, 96)

local rewardEmoji: { [string]: string } = {
	Clicks = "💵",
	LuckPotion = "🍀",
	ClicksPotion = "💰",
	Key = "🔑",
}

local DailyScreen = {}

function DailyScreen.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local playUi = Kit.UiSound(context.Controllers)
	local dataController = context.Controllers.DataController
	local tiles: { Tile } = {}
	local isOpen = false
	local isBusy = false

	local modal = Kit.Modal(trove, {
		Parent = context.PlayerGui,
		Name = "Daily",
		Title = "DAILY REWARDS",
		Icon = "📅",
		MaxSize = Vector2.new(780, 470),
		HeaderColor = theme.Blue,
		OnClose = function()
			context.Close("Daily")
		end,
		Sound = playUi,
	})

	local small = Instance.new("Frame")
	small.Name = "Days"
	small.BackgroundTransparency = 1
	small.Position = UDim2.fromOffset(10, 10)
	small.Size = UDim2.new(0.68, -15, 1, -66)
	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.CellSize = UDim2.new(1 / 3, -8, 0.5, -6)
	grid.CellPadding = UDim2.fromOffset(8, 8)
	grid.Parent = small
	small.Parent = modal.Body

	local big = Instance.new("Frame")
	big.Name = "Bonus"
	big.BackgroundTransparency = 1
	big.Position = UDim2.new(0.68, 5, 0, 10)
	big.Size = UDim2.new(0.32, -15, 1, -66)
	big.Parent = modal.Body

	local status = Kit.Label({
		Parent = modal.Body,
		Name = "Status",
		Text = "",
		Position = UDim2.new(0, 10, 1, -8),
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.new(1, -20, 0, 40),
		TextSize = 28,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})

	local function now(): number
		return workspace:GetServerTimeNow()
	end

	local function currentDaily(): Daily.Stored
		local value = dataController:Get({ "Daily" })
		return if type(value) == "table" then value else {}
	end

	local function claimedDays(state: Daily.Status, stored: Daily.Stored): number
		if state.CanClaim then
			return state.Day - 1
		end
		return math.min(#DailyRewards.Rewards, stored.Streak or 0)
	end

	local function refresh()
		local stored = currentDaily()
		local state = Daily.Status(stored, now())
		local claimed = claimedDays(state, stored)
		for _, tile in tiles do
			local day = tile.Reward.Day
			if day <= claimed then
				Kit.Paint(tile.Panel, claimedColor)
				tile.Action.SetDisabled(true)
				tile.Action.SetText("CLAIMED")
			elseif state.CanClaim and day == state.Day then
				Kit.Paint(tile.Panel, if day == #DailyRewards.Rewards then theme.Gold else theme.Green)
				tile.Action.SetDisabled(false)
				tile.Action.SetColor(theme.Green)
				tile.Action.SetText("CLAIM")
				if not tile.IsGlowing then
					tile.IsGlowing = true
					tile.Action.SetGlow(true)
				end
			else
				Kit.Paint(
					tile.Panel,
					if day == #DailyRewards.Rewards then Kit.Shade(theme.Gold, -0.35) else lockedColor
				)
				tile.Action.SetDisabled(false)
				tile.Action.SetColor(theme.Red)
				tile.Action.SetText("LOCKED")
			end
			if tile.IsGlowing and not (state.CanClaim and day == state.Day) then
				tile.IsGlowing = false
				tile.Action.SetGlow(false)
			end
		end
		if state.CanClaim then
			if state.StreakBroken and (stored.LastClaim or 0) > 0 then
				status.Text = "Streak reset! Back to Day 1!"
			else
				status.Text = "Your reward is ready! 🎉"
			end
		else
			status.Text = `Next reward in {TimeFormat.Hours(state.SecondsLeft)}`
		end
	end

	local function claim(reward: DailyRewards.Reward)
		if isBusy then
			return
		end
		local state = Daily.Status(currentDaily(), now())
		if not state.CanClaim or state.Day ~= reward.Day then
			playUi("Error")
			context.Toast("Come back later for this one!", "Bad")
			return
		end
		isBusy = true
		task.spawn(function()
			local day = Packets.ClaimDaily:Fire()
			isBusy = false
			if type(day) == "number" and day > 0 then
				playUi("Confirm")
				context.Toast(`📅 Day {day}: {reward.Label}!`, "Good")
			else
				playUi("Error")
				context.Toast("Oops, couldn't claim that!", "Bad")
			end
			refresh()
		end)
	end

	for _, reward in DailyRewards.Rewards do
		local isBig = reward.Day == #DailyRewards.Rewards
		local panel = Kit.Panel({
			Parent = if isBig then big else small,
			Name = `Day{reward.Day}`,
			Size = UDim2.fromScale(1, 1),
			Color = lockedColor,
			LayoutOrder = reward.Day,
			Shards = true,
		})
		Kit.Label({
			Parent = panel,
			Name = "Day",
			Text = `DAY {reward.Day}`,
			Position = UDim2.fromOffset(0, 6),
			Size = UDim2.new(1, 0, 0, if isBig then 34 else 24),
			TextSize = if isBig then 30 else 22,
			Align = Enum.TextXAlignment.Center,
			Scaled = true,
		})
		Kit.Icon({
			Parent = panel,
			Name = "Icon",
			Emoji = rewardEmoji[reward.Kind] or "🎁",
			Position = UDim2.fromScale(if isBig then 0.2 else 0.25, if isBig then 0.2 else 0.18),
			Size = UDim2.fromScale(if isBig then 0.6 else 0.5, if isBig then 0.36 else 0.3),
		})
		Kit.Label({
			Parent = panel,
			Name = "Reward",
			Text = reward.Label,
			Position = UDim2.new(0, 4, 0.5, if isBig then 20 else 6),
			Size = UDim2.new(1, -8, 0, if isBig then 30 else 22),
			TextSize = if isBig then 26 else 18,
			Align = Enum.TextXAlignment.Center,
			Scaled = true,
		})
		local action = Kit.Button(trove, {
			Parent = panel,
			Name = "Action",
			Text = "LOCKED",
			Position = UDim2.new(0.5, 0, 1, -8),
			AnchorPoint = Vector2.new(0.5, 1),
			Size = UDim2.new(0.86, 0, 0, if isBig then 46 else 36),
			Color = theme.Red,
			TextSize = if isBig then 26 else 20,
			Callback = function()
				claim(reward)
			end,
			Sound = playUi,
		})
		table.insert(tiles, { Panel = panel, Action = action, Reward = reward, IsGlowing = false })
	end

	trove:Add(dataController:Observe({ "Daily" }, function(_value: any)
		if isOpen then
			refresh()
		end
	end))

	local elapsed = 0
	trove:Connect(RunService.Heartbeat, function(dt: number)
		if not isOpen then
			return
		end
		elapsed += dt
		if elapsed >= refreshSeconds then
			elapsed = 0
			refresh()
		end
	end)

	return {
		Modal = true,
		StartsOpen = false,
		Open = function(_self: Types.Screen)
			isOpen = true
			refresh()
			modal.Show()
		end,
		Close = function(_self: Types.Screen)
			isOpen = false
			modal.Hide()
		end,
		Destroy = function(_self: Types.Screen)
			trove:Destroy()
		end,
	}
end

return DailyScreen
