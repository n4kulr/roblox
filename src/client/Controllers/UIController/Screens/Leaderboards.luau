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
local rowHeight = 60
local silverColor = Color3.fromRGB(190, 198, 212)
local bronzeColor = Color3.fromRGB(205, 127, 70)

local tabs: { { Title: string, Glyph: string, Color: Color3, Compact: boolean } } = {
	{ Title = "Clicks Earned", Glyph = "Clicks", Color = theme.Green, Compact = true },
	{ Title = "Rolls", Glyph = "Roll", Color = theme.Blue, Compact = false },
	{ Title = "Rebirths", Glyph = "Rebirth", Color = theme.Pink, Compact = false },
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
	local tabBar: Kit.TabBar

	local modal = Kit.Modal(trove, {
		Parent = context.PlayerGui,
		Name = "Leaderboards",
		Title = "LEADERBOARDS",
		Glyph = "Leaderboard",
		MaxSize = Vector2.new(860, 620),
		HeaderColor = theme.Gold,
		OnClose = function()
			context.Close("Leaderboards")
		end,
		Sound = playUi,
	})

	local tabEntries: { Kit.Tab } = {}
	for index, tab in tabs do
		table.insert(
			tabEntries,
			{ Id = tostring(index), Text = tab.Title, Glyph = tab.Glyph, Color = tab.Color }
		)
	end
	local load: (tab: number) -> ()
	tabBar = Kit.TabBar(trove, {
		Parent = modal.Body,
		Name = "Tabs",
		Tabs = tabEntries,
		Selected = "1",
		Position = UDim2.fromOffset(Kit.Space.M, Kit.Space.M),
		Size = UDim2.new(1, -2 * Kit.Space.M, 0, 54),
		OnSelect = function(id: string)
			load(tonumber(id) or 1)
		end,
		Sound = playUi,
	})

	local list = Kit.Scroll({
		Parent = modal.Body,
		Name = "List",
		Position = UDim2.fromOffset(Kit.Space.S, 74),
		Size = UDim2.new(1, -2 * Kit.Space.S, 1, -82),
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
				Radius = Kit.Radius.L,
			})
			local medal = Kit.Panel({
				Parent = panel,
				Name = "Medal",
				Position = UDim2.fromOffset(Kit.Space.M, (rowHeight - 44) / 2),
				Size = UDim2.fromOffset(44, 44),
				Color = if rank <= 3 then Kit.Shade(rankColor(rank), -0.3) else theme.Track,
				Radius = 22,
				Flat = true,
			})
			Kit.Label({
				Parent = medal,
				Name = "Rank",
				Text = tostring(rank),
				Size = UDim2.fromScale(1, 1),
				TextSize = 26,
				Align = Enum.TextXAlignment.Center,
				Scaled = true,
				Title = true,
			})
			if rank == 1 then
				Kit.Icon({
					Parent = panel,
					Name = "Crown",
					Glyph = "Crown",
					Position = UDim2.fromOffset(Kit.Space.M + 10, 1),
					Size = UDim2.fromOffset(26, 22),
				})
			end
			local textColor = if rank <= 3 then theme.TextInk else theme.Text
			Kit.Label({
				Parent = panel,
				Name = "Name",
				Text = if isMe then `{row.Name} (you)` else row.Name,
				Position = UDim2.fromOffset(72, 0),
				Size = UDim2.new(1, -250, 0, rowHeight),
				TextSize = 26,
				Color = textColor,
				Scaled = true,
				Outline = rank > 3,
			})
			Kit.Icon({
				Parent = panel,
				Name = "ValueIcon",
				Glyph = tabs[tab].Glyph,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -150, 0.5, 0),
				Size = UDim2.fromOffset(30, 30),
			})
			Kit.Label({
				Parent = panel,
				Name = "Value",
				Text = if tabs[tab].Compact
					then NumberFormat.Compact(row.Value)
					else NumberFormat.Commas(row.Value),
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -14, 0, 0),
				Size = UDim2.fromOffset(130, rowHeight),
				TextSize = 28,
				Color = textColor,
				Align = Enum.TextXAlignment.Right,
				Scaled = true,
				Outline = rank > 3,
			})
		end
	end

	load = function(tab: number)
		selected = tab
		tabBar.Select(tostring(tab))
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
