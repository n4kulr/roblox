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
	Bar: Frame,
	BarText: TextLabel,
	Buy: Kit.Button,
	Upgrade: Upgrades.Upgrade,
	IsBusy: boolean,
}

local theme = Kit.Theme
local cardHeight = 178
local refreshSeconds = 0.2

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
		Title = "🛒 SHOP",
		MaxSize = Vector2.new(640, 580),
		HeaderColor = theme.Green,
		OnClose = close,
		Sound = playUi,
	})
	local scroll = Kit.Scroll({
		Parent = modal.Body,
		Name = "List",
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 1, -18),
		Padding = 14,
	})

	local function refreshRow(row: Row)
		local level = tracker.GetLevel(row.Upgrade.Id)
		local maxLevel = row.Upgrade.MaxLevel
		row.BarText.Text = `Lv {level}/{maxLevel}`
		row.Bar.Size = UDim2.fromScale(math.clamp(level / maxLevel, 0, 1), 1)
		local cost = Upgrades.Cost(row.Upgrade, level)
		if not cost then
			row.Buy.SetText("MAXED!")
			row.Buy.SetColor(theme.Gold)
			return
		end
		local balance = tracker.Balance()
		if balance ~= nil and balance >= cost then
			row.Buy.SetText(`💰 {NumberFormat.Compact(cost)}`)
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
		local frame = Kit.Panel({
			Parent = scroll,
			Name = upgrade.Id,
			Size = UDim2.new(1, 0, 0, cardHeight),
			Color = theme.Raised,
			LayoutOrder = index,
		})
		Kit.Label({
			Parent = frame,
			Name = "Name",
			Text = upgrade.Name,
			Position = UDim2.fromOffset(14, 8),
			Size = UDim2.new(1, -28, 0, 38),
			TextSize = 30,
			Scaled = true,
		})
		Kit.Label({
			Parent = frame,
			Name = "Description",
			Text = upgrade.Description,
			Position = UDim2.fromOffset(14, 46),
			Size = UDim2.new(1, -28, 0, 26),
			TextSize = 20,
			Color = theme.TextDim,
			Scaled = true,
			Outline = false,
		})
		local track = Instance.new("Frame")
		track.Name = "Track"
		track.BorderSizePixel = 0
		track.Position = UDim2.fromOffset(14, 80)
		track.Size = UDim2.new(1, -28, 0, 26)
		Kit.Paint(track, theme.Deep)
		Kit.Corner(track, 13)
		Kit.Stroke(track, theme.Ink, 3)
		track.Parent = frame
		local fill = Instance.new("Frame")
		fill.Name = "Fill"
		fill.BorderSizePixel = 0
		fill.Size = UDim2.fromScale(0, 1)
		Kit.Paint(fill, theme.Good)
		Kit.Corner(fill, 13)
		fill.Parent = track
		local barText = Kit.Label({
			Parent = track,
			Name = "Level",
			Text = "Lv 0",
			Size = UDim2.fromScale(1, 1),
			TextSize = 18,
			Align = Enum.TextXAlignment.Center,
			Scaled = true,
		})
		local row: Row = {
			Frame = frame,
			Bar = fill,
			BarText = barText,
			Buy = nil :: any,
			Upgrade = upgrade,
			IsBusy = false,
		}
		row.Buy = Kit.Button(trove, {
			Parent = frame,
			Name = "Buy",
			Text = "💰",
			Position = UDim2.new(0.5, 0, 1, -10),
			AnchorPoint = Vector2.new(0.5, 1),
			Size = UDim2.new(1, -28, 0, 46),
			Color = theme.Green,
			TextSize = 28,
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

return Shop
