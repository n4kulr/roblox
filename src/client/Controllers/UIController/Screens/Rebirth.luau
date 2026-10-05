--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Rebirth = require(ReplicatedStorage.Rules.Rebirth)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Economy = require(script.Parent.Parent.Economy)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)

local theme = Kit.Theme
local refreshSeconds = 0.2

local function multiplierText(value: number): string
	return `x{string.format("%.1f", value)} Clicks`
end

local RebirthScreen = {}

function RebirthScreen.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local playUi = Kit.UiSound(context.Controllers)
	local tracker = Economy.Track(context.Controllers.DataController, trove)
	local isOpen = false
	local isBusy = false

	local modal = Kit.Modal(trove, {
		Parent = context.PlayerGui,
		Name = "Rebirth",
		Title = "REBIRTH",
		Glyph = "Rebirth",
		MaxSize = Vector2.new(760, 560),
		HeaderColor = theme.Purple,
		OnClose = function()
			context.Close("Rebirth")
		end,
		Sound = playUi,
	})

	local heading = Kit.Label({
		Parent = modal.Body,
		Name = "Heading",
		Text = "Rebirth 0 > 1",
		Position = UDim2.fromOffset(10, 12),
		Size = UDim2.new(1, -20, 0, 44),
		TextSize = 36,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})

	local tiles = Instance.new("Frame")
	tiles.Name = "Tiles"
	tiles.BackgroundTransparency = 1
	tiles.Position = UDim2.fromOffset(10, 66)
	tiles.Size = UDim2.new(1, -20, 0, 120)
	tiles.Parent = modal.Body

	local function tile(name: string, anchorX: number, color: Color3, caption: string): TextLabel
		local panel = Kit.Panel({
			Parent = tiles,
			Name = name,
			Size = UDim2.new(0.4, 0, 1, 0),
			Position = UDim2.fromScale(anchorX, 0),
			AnchorPoint = Vector2.new(anchorX, 0),
			Color = color,
			Shards = true,
		})
		Kit.Label({
			Parent = panel,
			Name = "Caption",
			Text = caption,
			Position = UDim2.fromOffset(0, 8),
			Size = UDim2.new(1, 0, 0, 26),
			TextSize = 20,
			Color = theme.TextDim,
			Align = Enum.TextXAlignment.Center,
			Scaled = true,
		})
		return Kit.Label({
			Parent = panel,
			Name = "Value",
			Text = "",
			Position = UDim2.fromOffset(6, 40),
			Size = UDim2.new(1, -12, 0, 60),
			TextSize = 32,
			Align = Enum.TextXAlignment.Center,
			Scaled = true,
		})
	end
	local currentValue = tile("Current", 0, theme.Grey, "NOW")
	local nextValue = tile("Next", 1, theme.Green, "AFTER")
	Kit.Icon({
		Parent = tiles,
		Name = "Arrow",
		Glyph = "Arrow",
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(64, 64),
	})

	Kit.Label({
		Parent = modal.Body,
		Name = "RequirementTitle",
		Text = "Requires",
		Position = UDim2.fromOffset(10, 200),
		Size = UDim2.new(1, -20, 0, 26),
		TextSize = 22,
		Subtle = true,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local bar = Kit.Bar({
		Parent = modal.Body,
		Name = "Requirement",
		Position = UDim2.fromOffset(40, 230),
		Size = UDim2.new(1, -80, 0, 40),
		Color = theme.Green,
		TextSize = 26,
	})

	local action = Kit.Button(trove, {
		Parent = modal.Body,
		Name = "Rebirth",
		Text = "REBIRTH",
		Glyph = "Rebirth",
		IconLeft = true,
		Title = true,
		Position = UDim2.new(0.5, 0, 0, 290),
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(300, 70),
		Color = theme.Green,
		TextSize = 40,
		Callback = function()
			if isBusy then
				return
			end
			local balance = tracker.Balance()
			if not balance or balance < Rebirth.Cost(tracker.GetRebirths()) then
				playUi("Error")
				context.Toast("Not enough Clicks yet!", "Bad")
				return
			end
			isBusy = true
			local reached = tracker.GetRebirths() + 1
			task.spawn(function()
				local done = Packets.Rebirth:Fire()
				isBusy = false
				if done == true then
					playUi("Confirm")
					context.Toast(`Rebirth {reached}! Clicks are now stronger!`, "Good")
				else
					playUi("Error")
					context.Toast("Couldn't rebirth right now!", "Bad")
				end
			end)
		end,
		Sound = playUi,
	})

	Kit.Label({
		Parent = modal.Body,
		Name = "Note",
		Text = "Resets your Clicks and upgrades. Keeps your keys!",
		Position = UDim2.new(0, 10, 1, -8),
		AnchorPoint = Vector2.new(0, 1),
		Size = UDim2.new(1, -20, 0, 32),
		TextSize = 22,
		Subtle = true,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})

	local function refresh()
		local rebirths = tracker.GetRebirths()
		local cost = Rebirth.Cost(rebirths)
		local balance = tracker.Balance() or 0
		heading.Text = `Rebirth {rebirths} > {rebirths + 1}`
		currentValue.Text = multiplierText(Rebirth.IncomeMultiplier(rebirths))
		nextValue.Text = multiplierText(Rebirth.IncomeMultiplier(rebirths + 1))
		bar.SetValue(balance / cost)
		bar.SetText(`{NumberFormat.Compact(math.min(balance, cost))} / {NumberFormat.Compact(cost)} Clicks`)
		local canRebirth = balance >= cost
		bar.SetColor(if canRebirth then theme.Green else theme.Blue)
		action.SetDisabled(not canRebirth)
		action.SetGlow(canRebirth)
	end

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

return RebirthScreen
