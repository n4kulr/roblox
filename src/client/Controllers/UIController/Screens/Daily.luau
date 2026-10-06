--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local TimeFormat = require(ReplicatedStorage.Utils.TimeFormat)
local Economy = require(script.Parent.Parent.Economy)
local Kit = require(script.Parent.Parent.Kit)
local Playtime = require(script.Parent.Parent.Playtime)
local Types = require(script.Parent.Parent.Types)

type Tile = {
	Button: Kit.Button,
	Icon: GuiObject,
	Status: TextLabel,
	Reward: TextLabel,
	Check: GuiObject,
	State: string,
	Bounce: Tween?,
}

local theme = Kit.Theme
local claimedColor = Kit.Shade(theme.Green, 0.6)
local iconRest = UDim2.fromScale(0.2, 0.08)
local iconUp = UDim2.fromScale(0.2, -0.02)
local bounceInfo = Kit.Motion.Bounce

local rewardGlyph: { [string]: string } = {
	Cash = "Clicks",
	LuckPotion = "Potion",
	ClicksPotion = "Potion",
	Key = "Keys",
}
local rewardTint: { [string]: Color3? } = {
	ClicksPotion = theme.Amber,
}

local function minutesText(seconds: number): string
	return `{math.max(1, math.floor(seconds / 60))}m`
end

local DailyScreen = {}

function DailyScreen.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local playUi = Kit.UiSound(context.Controllers)
	local tracker = Economy.Track(context.Controllers.DataController, trove)
	local localPlayer = Players.LocalPlayer
	local tiles: { Tile } = {}
	local claimedHere: { [number]: boolean } = {}
	local isOpen = false
	local isBusy = false

	local modal = Kit.Modal(trove, {
		Parent = context.PlayerGui,
		Name = "Daily",
		Title = "GIFTS",
		Glyph = "Gift",
		MaxSize = Vector2.new(900, 560),
		HeaderColor = theme.Blue,
		OnClose = function()
			context.Close("Daily")
		end,
	})

	Kit.Label({
		Parent = modal.Body,
		Name = "Hint",
		Text = "Play to unlock gifts!",
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 0, 40),
		TextSize = Kit.Text.Banner,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})

	local grid = Instance.new("Frame")
	grid.Name = "Gifts"
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(10, 56)
	grid.Size = UDim2.new(1, -20, 1, -66)
	local layout = Instance.new("UIGridLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.CellSize = UDim2.new(0.2, -8, 0.5, -6)
	layout.CellPadding = UDim2.fromOffset(8, 10)
	layout.Parent = grid
	grid.Parent = modal.Body

	local function now(): number
		return workspace:GetServerTimeNow()
	end

	local function rewardText(index: number): string
		local tier = Playtime.Tiers[index]
		if tier.Kind == "Cash" then
			local amount = math.max(tier.Min, math.floor(tier.Amount * tracker.GetStats().Rate))
			return `+{NumberFormat.Compact(amount)}`
		elseif tier.Kind == "LuckPotion" then
			return `Luck {minutesText(tier.Amount)}`
		elseif tier.Kind == "ClicksPotion" then
			return `Clicks {minutesText(tier.Amount)}`
		end
		return `{string.sub(tier.Rarity, 1, 6)} Key`
	end

	local function stopBounce(tile: Tile)
		local running = tile.Bounce
		if running then
			running:Cancel()
			tile.Bounce = nil
		end
		tile.Icon.Position = iconRest
	end

	local function startBounce(tile: Tile)
		if tile.Bounce then
			return
		end
		local tween = TweenService:Create(tile.Icon, bounceInfo, { Position = iconUp })
		tile.Bounce = tween
		tween:Play()
	end

	local function setState(tile: Tile, state: string)
		if tile.State == state then
			return
		end
		tile.State = state
		local button = tile.Button
		tile.Check.Visible = state == "Claimed"
		button.SetLocked(state == "Locked")
		button.SetGlow(state == "Ready")
		if state == "Ready" then
			button.SetColor(theme.Green)
			button.SetText("READY!")
			startBounce(tile)
		else
			stopBounce(tile)
			if state == "Claimed" then
				button.SetColor(claimedColor)
				button.SetText("CLAIMED")
			else
				button.SetColor(theme.Grey)
			end
		end
	end

	local function refresh()
		local progress = Playtime.Read(localPlayer, now())
		for index, tile in tiles do
			local state = progress.States[index]
			if state == "Ready" and claimedHere[index] then
				state = "Claimed"
			end
			setState(tile, state)
			if state == "Locked" then
				local text = TimeFormat.Clock(progress.Left[index])
				if tile.Status.Text ~= text then
					tile.Button.SetText(text)
				end
			end
			local reward = rewardText(index)
			if tile.Reward.Text ~= reward then
				tile.Reward.Text = reward
			end
		end
	end

	local function claim(index: number)
		if isBusy then
			return
		end
		local tile = tiles[index]
		if tile.State == "Claimed" then
			playUi("Error")
			context.Toast("You already got that gift!", "Info")
			return
		elseif tile.State ~= "Ready" then
			playUi("Error")
			context.Toast("Keep playing to unlock this gift!", "Info")
			return
		end
		isBusy = true
		task.spawn(function()
			local reward = rewardText(index)
			local isClaimed = Packets.ClaimPlaytime:Fire(index)
			isBusy = false
			if isClaimed == true then
				claimedHere[index] = true
				playUi("Confirm")
				Kit.Pulse(tile.Button.Instance, theme.Gold)
				context.Toast(`Gift: {reward}!`, "Good")
			else
				playUi("Error")
				context.Toast("Oops, couldn't open that gift!", "Bad")
			end
			refresh()
		end)
	end

	for index, tier in Playtime.Tiers do
		local button = Kit.Button(trove, {
			Parent = grid,
			Name = `Gift{index}`,
			Glyph = "Gift",
			Text = "",
			Color = theme.Grey,
			LayoutOrder = index,
			TextSize = Kit.Text.Title,
			IconScale = 0.4,
			Callback = function()
				claim(index)
			end,
		})
		local face = button.Face
		local icon = face:FindFirstChild("Icon") :: GuiObject
		icon.Position = iconRest
		icon.Size = UDim2.fromScale(0.6, 0.4)
		local status = face:FindFirstChild("Text") :: TextLabel
		status.Position = UDim2.fromScale(0.04, 0.66)
		status.Size = UDim2.fromScale(0.92, 0.3)
		Kit.Label({
			Parent = face,
			Name = "Tier",
			Text = Playtime.Name(tier.Seconds),
			Position = UDim2.fromOffset(8, 4),
			Size = UDim2.new(0.5, 0, 0, 20),
			TextSize = Kit.Text.Small,
		})
		local row = Instance.new("Frame")
		row.Name = "Row"
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromScale(0, 0.46)
		row.Size = UDim2.fromScale(1, 0.2)
		local rowList = Instance.new("UIListLayout")
		rowList.FillDirection = Enum.FillDirection.Horizontal
		rowList.HorizontalAlignment = Enum.HorizontalAlignment.Center
		rowList.VerticalAlignment = Enum.VerticalAlignment.Center
		rowList.Padding = UDim.new(0, Kit.Space.Xs)
		rowList.Parent = row
		row.Parent = face
		Kit.Icon({
			Parent = row,
			Name = "RewardIcon",
			Glyph = rewardGlyph[tier.Kind],
			Color = rewardTint[tier.Kind],
			Size = UDim2.fromOffset(24, 24),
			LayoutOrder = 1,
		})
		local reward = Kit.Label({
			Parent = row,
			Name = "Reward",
			Text = "",
			Size = UDim2.new(1, -34, 1, 0),
			TextSize = Kit.Text.Label,
			Align = Enum.TextXAlignment.Left,
			Scaled = true,
			LayoutOrder = 2,
		})
		reward.TextWrapped = false
		local check = Kit.Icon({
			Parent = face,
			Name = "Check",
			Glyph = "Check",
			Size = UDim2.fromOffset(28, 28),
			Position = UDim2.new(1, -6, 0, 4),
			AnchorPoint = Vector2.new(1, 0),
		})
		check.Visible = false
		table.insert(tiles, {
			Button = button,
			Icon = icon,
			Status = status,
			Reward = reward,
			Check = check,
			State = "",
			Bounce = nil,
		})
	end

	trove:Add(function()
		for _, tile in tiles do
			stopBounce(tile)
		end
	end)

	Kit.Poll(trove, Kit.PollSeconds.Relaxed, function()
		return isOpen
	end, refresh)

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
