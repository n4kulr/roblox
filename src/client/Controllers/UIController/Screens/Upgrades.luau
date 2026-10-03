--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Packets = require(ReplicatedStorage.Packets)
local UiAssets = require(ReplicatedStorage.Config.UiAssets)
local Upgrades = require(ReplicatedStorage.Config.Upgrades)
local Stats = require(ReplicatedStorage.Rules.Stats)
local Trove = require(ReplicatedStorage.Packages.Trove)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Economy = require(script.Parent.Parent.Economy)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)

type Row = {
	Frame: Frame,
	Bar: Kit.Bar,
	Preview: TextLabel,
	Buy: Kit.Button,
	Upgrade: Upgrades.Upgrade,
	IsBusy: boolean,
}

local theme = Kit.Theme
local cardHeight = 104
local refreshSeconds = 0.2
local buyWidth = 150
local iconSize = 84

local cardColors: { [string]: Color3 } = {
	Luck = theme.Green,
	Speed = theme.Yellow,
	Slots = theme.Blue,
}

local UpgradesScreen = {}

function UpgradesScreen.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local playUi = Kit.UiSound(context.Controllers)
	local rows: { Row } = {}
	local isOpen = false
	local tracker: Economy.Tracker

	local modal = Kit.Modal(trove, {
		Parent = context.PlayerGui,
		Name = "Upgrades",
		Title = "UPGRADES",
		Icon = "🛒",
		IconAsset = UiAssets.Icons.Upgrades,
		MaxSize = Vector2.new(700, 520),
		HeaderColor = theme.Green,
		OnClose = function()
			context.Close("Upgrades")
		end,
		Sound = playUi,
	})
	local scroll = Kit.Scroll({
		Parent = modal.Body,
		Name = "List",
		Position = UDim2.fromOffset(10, 8),
		Size = UDim2.new(1, -20, 1, -16),
		Padding = 10,
	})

	local function previewText(upgrade: Upgrades.Upgrade, level: number): string
		local board = tracker.GetBoard()
		local levels = {
			Luck = tracker.GetLevel("Luck"),
			Speed = tracker.GetLevel("Speed"),
			Slots = tracker.GetLevel("Slots"),
		}
		local nextLevels = table.clone(levels)
		nextLevels[upgrade.Id] = level + 1
		local now = Stats.Compute(board, levels)
		local isMaxed = level >= upgrade.MaxLevel
		local after = if isMaxed then now else Stats.Compute(board, nextLevels)
		if upgrade.Id == "Luck" then
			if isMaxed then
				return string.format("Now: x%.1f Luck", now.Luck)
			end
			return string.format("x%.1f → x%.1f Luck", now.Luck, after.Luck)
		elseif upgrade.Id == "Speed" then
			if isMaxed then
				return string.format("Now: %.1f rolls/s", now.RollsPerSecond)
			end
			return string.format("%.1f/s → %.1f/s", now.RollsPerSecond, after.RollsPerSecond)
		end
		if isMaxed then
			return string.format("Now: %d slots", now.Slots)
		end
		return string.format("%d → %d slots", now.Slots, after.Slots)
	end

	local function refreshRow(row: Row)
		local level = tracker.GetLevel(row.Upgrade.Id)
		row.Preview.Text = previewText(row.Upgrade, level)
		local maxLevel = row.Upgrade.MaxLevel
		row.Bar.SetText(`Lv {level}/{maxLevel}`)
		row.Bar.SetValue(level / maxLevel)
		local cost = Upgrades.Cost(row.Upgrade, level)
		if not cost then
			row.Buy.SetText("MAXED!")
			row.Buy.SetColor(theme.Yellow)
			return
		end
		local balance = tracker.Balance()
		if balance ~= nil and balance >= cost then
			row.Buy.SetText(`BUY\n⌨️ {NumberFormat.Compact(cost)}`)
			row.Buy.SetColor(theme.Green)
		else
			local missing = cost - (balance or 0)
			row.Buy.SetText(`Need {NumberFormat.Compact(missing)} more!`)
			row.Buy.SetColor(theme.Red)
		end
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
		local level = tracker.GetLevel(row.Upgrade.Id)
		local cost = Upgrades.Cost(row.Upgrade, level)
		if not cost then
			playUi("Confirm")
			context.Toast("Already MAXED! 🎉", "Good")
			Kit.Pulse(row.Frame, theme.Gold)
			return
		end
		local balance = tracker.Balance() or 0
		if balance < cost then
			playUi("Error")
			Kit.Shake(row.Frame)
			context.Toast(`Need {NumberFormat.Compact(cost - balance)} more Clicks!`, "Bad")
			return
		end
		row.IsBusy = true
		task.spawn(function()
			local success = Packets.BuyUpgrade:Fire(row.Upgrade.Id)
			row.IsBusy = false
			if success == true then
				playUi("Confirm")
				Kit.Pulse(row.Frame, theme.Good)
				context.Toast(`Bought {row.Upgrade.Name}!`, "Good")
			else
				playUi("Error")
				Kit.Shake(row.Frame)
				context.Toast("Oops, couldn't buy that!", "Bad")
			end
			refreshRow(row)
		end)
	end

	for index, upgrade in Upgrades.List do
		local emoji, title = string.match(upgrade.Name, "^(%S+)%s+(.+)$")
		local card = Kit.Panel({
			Parent = scroll,
			Name = upgrade.Id,
			Size = UDim2.new(1, 0, 0, cardHeight),
			Color = cardColors[upgrade.Id] or theme.Green,
			LayoutOrder = index,
			Shards = true,
		})
		local iconTile = Kit.Panel({
			Parent = card,
			Name = "IconTile",
			Position = UDim2.fromOffset(10, 10),
			Size = UDim2.fromOffset(iconSize, iconSize),
			Color = theme.Cell,
			Transparency = 0.15,
		})
		Kit.Burst({
			Parent = iconTile,
			Diameter = iconSize - 8,
		})
		Kit.Icon({
			Parent = iconTile,
			Name = "Icon",
			Emoji = emoji or "⌨️",
			Size = UDim2.fromScale(0.8, 0.8),
			Position = UDim2.fromScale(0.1, 0.1),
		})
		local textLeft = iconSize + 22
		local textWidth = UDim2.new(1, -(textLeft + buyWidth + 22), 0, 26)
		Kit.Label({
			Parent = card,
			Name = "Name",
			Text = title or upgrade.Name,
			Position = UDim2.fromOffset(textLeft, 5),
			Size = textWidth,
			TextSize = 26,
			Scaled = true,
		})
		Kit.Label({
			Parent = card,
			Name = "Effect",
			Text = upgrade.Effect,
			Position = UDim2.fromOffset(textLeft, 32),
			Size = UDim2.new(1, -(textLeft + buyWidth + 22), 0, 20),
			TextSize = 17,
			Color = Color3.fromRGB(255, 244, 170),
			Scaled = true,
		})
		local previewLabel = Kit.Label({
			Parent = card,
			Name = "Preview",
			Text = "",
			Position = UDim2.fromOffset(textLeft, 53),
			Size = UDim2.new(1, -(textLeft + buyWidth + 22), 0, 22),
			TextSize = 20,
			Scaled = true,
		})
		local bar = Kit.Bar({
			Parent = card,
			Name = "Level",
			Position = UDim2.fromOffset(textLeft, 77),
			Size = UDim2.new(1, -(textLeft + buyWidth + 22), 0, 22),
			Color = theme.Good,
			Text = "Lv 0",
			TextSize = 16,
		})
		local row: Row = {
			Frame = card,
			Bar = bar,
			Preview = previewLabel,
			Buy = nil :: any,
			Upgrade = upgrade,
			IsBusy = false,
		}
		row.Buy = Kit.Button(trove, {
			Parent = card,
			Name = "Buy",
			Text = "BUY",
			Position = UDim2.new(1, -10, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Size = UDim2.new(0, buyWidth, 1, -20),
			Color = theme.Green,
			TextSize = 26,
			Callback = function()
				buy(row)
			end,
			Sound = playUi,
		})
		table.insert(rows, row)
	end

	local elapsed = 0
	trove:Connect(RunService.Heartbeat, function(dt: number)
		if not isOpen then
			return
		end
		elapsed += dt
		if elapsed >= refreshSeconds then
			elapsed = 0
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

return UpgradesScreen
