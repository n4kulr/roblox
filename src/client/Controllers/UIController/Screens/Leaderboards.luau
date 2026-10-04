--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)

type Row = { Name: string, Value: number }

local theme = Kit.Theme
local rowHeight = 56
local silverColor = Color3.fromRGB(190, 198, 212)
local bronzeColor = Color3.fromRGB(205, 127, 70)

local tabs: { { Title: string, Compact: boolean, Glyph: string } } = {
	{ Title = "Clicks", Compact = true, Glyph = "Coin" },
	{ Title = "Rolls", Compact = false, Glyph = "Speed" },
	{ Title = "Rebirths", Compact = false, Glyph = "Rebirth" },
}

local function rankColor(rank: number): Color3
	if rank == 1 then
		return theme.Gold
	elseif rank == 2 then
		return silverColor
	elseif rank == 3 then
		return bronzeColor
	end
	return theme.Cell
end

local LeaderboardsScreen = {}

function LeaderboardsScreen.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local playUi = Kit.UiSound(context.Controllers)
	local selected = 1
	local requestToken = 0
	local tabButtons: { Kit.Button } = {}

	local modal = Kit.Modal(trove, {
		Parent = context.PlayerGui,
		Name = "Leaderboards",
		Title = "LEADERBOARDS",
		Glyph = "Leaderboard",
		MaxSize = Vector2.new(700, 540),
		HeaderColor = theme.Gold,
		OnClose = function()
			context.Close("Leaderboards")
		end,
		Sound = playUi,
	})

	local tabBar = Instance.new("Frame")
	tabBar.Name = "Tabs"
	tabBar.BackgroundTransparency = 1
	tabBar.Position = UDim2.fromOffset(10, 10)
	tabBar.Size = UDim2.new(1, -20, 0, 52)
	local tabList = Instance.new("UIListLayout")
	tabList.FillDirection = Enum.FillDirection.Horizontal
	tabList.SortOrder = Enum.SortOrder.LayoutOrder
	tabList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	tabList.Padding = UDim.new(0, 8)
	tabList.Parent = tabBar
	tabBar.Parent = modal.Body

	local list = Kit.Scroll({
		Parent = modal.Body,
		Name = "List",
		Position = UDim2.fromOffset(10, 70),
		Size = UDim2.new(1, -20, 1, -80),
		Padding = 8,
	})
	local status = Kit.Label({
		Parent = modal.Body,
		Name = "Status",
		Text = "",
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.new(1, -40, 0, 40),
		TextSize = 28,
		Color = theme.TextDim,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})

	local function clearRows()
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
	end

	local function show(rows: { Row }, tab: number)
		clearRows()
		status.Text = if #rows == 0 then "No one on the board yet!" else ""
		local me = Players.LocalPlayer.Name
		for rank, row in rows do
			local isMe = row.Name == me
			local panel = Kit.Panel({
				Parent = list,
				Name = `Rank{rank}`,
				Size = UDim2.new(1, 0, 0, rowHeight),
				Color = if isMe and rank > 3 then theme.Blue else rankColor(rank),
				LayoutOrder = rank,
				StrokeColor = if isMe then theme.Text else nil,
				StrokeThickness = if isMe then 4 else nil,
				Shards = rank <= 3,
			})
			local textColor = if rank <= 3 then theme.TextInk else theme.Text
			Kit.Label({
				Parent = panel,
				Name = "Rank",
				Text = `#{rank}`,
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.fromOffset(70, rowHeight),
				TextSize = 30,
				Color = textColor,
				Scaled = true,
				Outline = rank > 3,
			})
			Kit.Label({
				Parent = panel,
				Name = "Name",
				Text = if isMe then `{row.Name} (you)` else row.Name,
				Position = UDim2.fromOffset(90, 0),
				Size = UDim2.new(1, -260, 0, rowHeight),
				TextSize = 26,
				Color = textColor,
				Scaled = true,
				Outline = rank > 3,
			})
			Kit.Label({
				Parent = panel,
				Name = "Value",
				Text = if tabs[tab].Compact
					then NumberFormat.Compact(row.Value)
					else NumberFormat.Commas(row.Value),
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -14, 0, 0),
				Size = UDim2.fromOffset(150, rowHeight),
				TextSize = 28,
				Color = textColor,
				Align = Enum.TextXAlignment.Right,
				Scaled = true,
				Outline = rank > 3,
			})
		end
	end

	local function load(tab: number)
		selected = tab
		for index, button in tabButtons do
			button.SetSelected(index == tab)
		end
		requestToken += 1
		local token = requestToken
		clearRows()
		status.Text = "Loading..."
		task.spawn(function()
			local rows = Packets.GetLeaderboard:Fire(tab)
			if token ~= requestToken then
				return
			end
			if type(rows) == "table" then
				show(rows, tab)
			else
				status.Text = "Couldn't load the board!"
			end
		end)
	end

	for index, tab in tabs do
		tabButtons[index] = Kit.Button(trove, {
			Parent = tabBar,
			Name = `Tab{index}`,
			Glyph = tab.Glyph,
			IconLeft = true,
			Text = tab.Title,
			Size = UDim2.new(0.32, 0, 1, 0),
			Color = theme.Blue,
			TextSize = 20,
			LayoutOrder = index,
			Callback = function()
				load(index)
			end,
			Sound = playUi,
		})
	end

	return {
		Modal = true,
		StartsOpen = false,
		Open = function(_self: Types.Screen)
			modal.Show()
			load(selected)
		end,
		Close = function(_self: Types.Screen)
			requestToken += 1
			modal.Hide()
		end,
		Destroy = function(_self: Types.Screen)
			requestToken += 1
			trove:Destroy()
		end,
	}
end

return LeaderboardsScreen
