--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Packets = require(ReplicatedStorage.Packets)
local Upgrades = require(ReplicatedStorage.Config.Upgrades)
local Trove = require(ReplicatedStorage.Packages.Trove)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Economy = require(script.Parent.Parent.Economy)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)

type Row = {
	Frame: Frame,
	Level: TextLabel,
	Cost: TextLabel,
	Buy: Kit.Button,
	Upgrade: Upgrades.Upgrade,
	IsBusy: boolean,
}

local theme = Kit.Theme
local rowHeight = 96

local Shop = {}

function Shop.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local playUi = Kit.UiSound(context.Controllers)
	local rows: { Row } = {}
	local isOpen = false
	local tracker: Economy.Tracker

	local function close()
		context.Close("Shop")
	end
	local modal = Kit.Modal(trove, {
		Parent = context.PlayerGui,
		Name = "Shop",
		Title = "Upgrades",
		MaxSize = Vector2.new(720, 560),
		OnClose = close,
		Sound = playUi,
	})
	local scroll = Kit.Scroll({
		Parent = modal.Panel,
		Name = "List",
		Position = UDim2.fromOffset(12, Kit.HeaderHeight + 4),
		Size = UDim2.new(1, -24, 1, -(Kit.HeaderHeight + 16)),
		Padding = 10,
	})

	local function refreshRow(row: Row)
		local level = tracker.GetLevel(row.Upgrade.Id)
		local cost = Upgrades.Cost(row.Upgrade, level)
		row.Level.Text = `Lv {level}/{row.Upgrade.MaxLevel}`
		if not cost then
			row.Cost.Text = "MAX"
			row.Buy.SetText("MAX")
			row.Buy.SetDisabled(true)
			return
		end
		local balance = tracker.Balance()
		local canAfford = balance ~= nil and balance >= cost
		row.Cost.Text = `${NumberFormat.Compact(cost)}`
		row.Cost.TextColor3 = if canAfford then theme.Good else theme.Bad
		row.Buy.SetText("Buy")
		row.Buy.SetDisabled(row.IsBusy or not canAfford)
	end

	local function refreshAll()
		for _, row in rows do
			refreshRow(row)
		end
	end

	tracker = Economy.Track(context.Controllers.DataController, trove, refreshAll)

	local function buy(row: Row)
		if row.IsBusy then
			return
		end
		row.IsBusy = true
		refreshRow(row)
		task.spawn(function()
			local success = Packets.BuyUpgrade:Fire(row.Upgrade.Id)
			row.IsBusy = false
			if success == true then
				playUi("Confirm")
				Kit.Pulse(row.Frame, theme.Good)
			else
				playUi("Error")
				Kit.Shake(row.Frame)
			end
			refreshRow(row)
		end)
	end

	for index, upgrade in Upgrades.List do
		local frame = Kit.Panel({
			Parent = scroll,
			Name = upgrade.Id,
			Size = UDim2.new(1, 0, 0, rowHeight),
			Color = theme.Raised,
			LayoutOrder = index,
		})
		Kit.Label({
			Parent = frame,
			Name = "Name",
			Text = upgrade.Name,
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(1, -170, 0, 28),
			TextSize = 24,
		})
		Kit.Label({
			Parent = frame,
			Name = "Description",
			Text = upgrade.Description,
			Position = UDim2.fromOffset(14, 38),
			Size = UDim2.new(1, -170, 0, 22),
			TextSize = 16,
			Color = theme.TextDim,
			Bold = false,
		})
		local level = Kit.Label({
			Parent = frame,
			Name = "Level",
			Text = "",
			Position = UDim2.fromOffset(14, 64),
			Size = UDim2.new(1, -170, 0, 22),
			TextSize = 18,
			Color = theme.Accent,
		})
		local cost = Kit.Label({
			Parent = frame,
			Name = "Cost",
			Text = "",
			Position = UDim2.new(1, -12, 0, 6),
			AnchorPoint = Vector2.new(1, 0),
			Size = UDim2.fromOffset(140, 26),
			TextSize = 22,
			Align = Enum.TextXAlignment.Right,
		})
		local row: Row = {
			Frame = frame,
			Level = level,
			Cost = cost,
			Upgrade = upgrade,
			IsBusy = false,
			Buy = nil :: any,
		}
		row.Buy = Kit.Button(trove, {
			Parent = frame,
			Name = "Buy",
			Text = "Buy",
			Position = UDim2.new(1, -12, 1, -10),
			AnchorPoint = Vector2.new(1, 1),
			Size = UDim2.fromOffset(140, 52),
			Color = theme.Accent,
			Callback = function()
				buy(row)
			end,
		})
		table.insert(rows, row)
	end
	refreshAll()

	local sinceRefresh = 0
	trove:Connect(RunService.Heartbeat, function(dt: number)
		if not isOpen then
			return
		end
		sinceRefresh += dt
		if sinceRefresh >= 0.25 then
			sinceRefresh = 0
			refreshAll()
		end
	end)

	return {
		Modal = true,
		StartsOpen = false,
		Open = function(_self: Types.Screen)
			isOpen = true
			refreshAll()
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

return Shop
