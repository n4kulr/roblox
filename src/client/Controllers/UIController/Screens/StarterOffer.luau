--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Monetization = require(ReplicatedStorage.Config.Monetization)
local Trove = require(ReplicatedStorage.Packages.Trove)
local TimeFormat = require(ReplicatedStorage.Utils.TimeFormat)
local Kit = require(script.Parent.Parent.Kit)
local Purchases = require(script.Parent.Parent.Purchases)
local Types = require(script.Parent.Parent.Types)

local theme = Kit.Theme
local showDelay = 2
local offerSeconds = 900
local oldPrice = "R$ 99"
local contentHeight = 464
local margin = 16

local contents: { string } = {
	"⌨️ 10,000 Clicks",
	"🍀 2x Luck potion (15 min)",
	"🗝️ Epic Key",
}

local StarterOffer = {}

function StarterOffer.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local playUi = Kit.UiSound(context.Controllers)
	local dataController = context.Controllers.DataController
	local starterPack = Monetization.ProductById.StarterPack
	local isBought = false
	local isOpen = false
	local hasShown = false
	local isScheduled = false
	local deadline: number? = nil
	local showThread: thread? = nil

	local modal = Kit.Modal(trove, {
		Parent = context.PlayerGui,
		Name = "StarterOffer",
		Title = "STARTER PACK",
		Icon = "🎁",
		MaxSize = Vector2.new(520, 560),
		HeaderColor = theme.Orange,
		OnClose = function()
			context.Close("StarterOffer")
		end,
		Sound = playUi,
	})

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Content"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(0, 4)
	scroll.Size = UDim2.new(1, 0, 1, -8)
	scroll.CanvasSize = UDim2.fromOffset(0, contentHeight)
	scroll.ScrollBarThickness = 4
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Parent = modal.Body

	local timerChip = Kit.Chip({
		Parent = scroll,
		Name = "Timer",
		Text = "⏰ 15:00",
		Size = UDim2.fromOffset(168, 40),
		Position = UDim2.fromOffset(margin, 16),
		Color = theme.Purple,
		TextSize = 24,
	})
	local ribbon = Kit.Chip({
		Parent = scroll,
		Name = "Ribbon",
		Text = "50% OFF!",
		Size = UDim2.fromOffset(136, 40),
		Position = UDim2.new(1, -margin, 0, 16),
		AnchorPoint = Vector2.new(1, 0),
		Color = theme.Red,
		TextSize = 24,
	})
	local ribbonFrame = ribbon.Parent
	if ribbonFrame and ribbonFrame:IsA("GuiObject") then
		ribbonFrame.Rotation = 6
	end

	local list = Kit.Panel({
		Parent = scroll,
		Name = "Contents",
		Position = UDim2.fromOffset(margin, 72),
		Size = UDim2.new(1, -2 * margin, 0, 168),
		Color = theme.Cell,
	})
	for index, line in contents do
		Kit.Label({
			Parent = list,
			Name = `Line{index}`,
			Text = line,
			Position = UDim2.fromOffset(16, 8 + (index - 1) * 48),
			Size = UDim2.new(1, -32, 0, 48),
			TextSize = 26,
			Scaled = true,
		})
	end

	local prices = Instance.new("Frame")
	prices.Name = "Prices"
	prices.BackgroundTransparency = 1
	prices.BorderSizePixel = 0
	prices.Position = UDim2.fromOffset(margin, 256)
	prices.Size = UDim2.new(1, -2 * margin, 0, 56)
	prices.Parent = scroll
	Kit.Label({
		Parent = prices,
		Name = "OldPrice",
		Text = `<s>{oldPrice}</s>`,
		Size = UDim2.fromScale(0.4, 1),
		TextSize = 32,
		Color = theme.TextDim,
		Align = Enum.TextXAlignment.Right,
		RichText = true,
		Scaled = true,
	})
	Kit.Label({
		Parent = prices,
		Name = "NewPrice",
		Text = `R$ {starterPack.PriceLabel}`,
		Position = UDim2.fromScale(0.44, 0),
		Size = UDim2.fromScale(0.56, 1),
		TextSize = 48,
		Color = theme.Good,
		Scaled = true,
	})

	local buy = Kit.Button(trove, {
		Parent = scroll,
		Name = "Buy",
		Text = if Purchases.IsAvailable(starterPack) then "BUY" else "SOON",
		Size = UDim2.fromOffset(320, 72),
		Position = UDim2.new(0.5, 0, 0, 328),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = if Purchases.IsAvailable(starterPack) then theme.Green else theme.Grey,
		TextSize = 40,
		Callback = function()
			if not Purchases.PromptProduct(starterPack) then
				playUi("Error")
				context.Toast("Coming soon!", "Info")
			end
		end,
		Sound = playUi,
	})
	buy.SetGlow(Purchases.IsAvailable(starterPack))

	local decline = Instance.new("TextButton")
	decline.Name = "NoThanks"
	decline.AutoButtonColor = false
	decline.BackgroundTransparency = 1
	decline.BorderSizePixel = 0
	decline.Font = Kit.Font
	decline.Text = "No thanks"
	decline.TextSize = 22
	decline.TextColor3 = theme.TextDim
	decline.Size = UDim2.fromOffset(160, 40)
	decline.Position = UDim2.new(0.5, 0, 0, 416)
	decline.AnchorPoint = Vector2.new(0.5, 0)
	decline.Parent = scroll
	trove:Connect(decline.Activated, function()
		playUi("Click")
		context.Close("StarterOffer")
	end)

	local function refreshTimer()
		local target = deadline
		if not target then
			return
		end
		timerChip.Text = `⏰ {TimeFormat.Clock(target - os.clock())}`
	end

	trove:Connect(RunService.Heartbeat, function()
		if isOpen then
			refreshTimer()
		end
	end)

	trove:Add(function()
		local thread = showThread
		showThread = nil
		if thread then
			task.cancel(thread)
		end
	end)

	trove:Add(dataController:Observe({ "StarterPackBought" }, function(value: any)
		isBought = value == true
		if isBought then
			context.Close("StarterOffer")
			return
		end
		if isScheduled then
			return
		end
		isScheduled = true
		showThread = task.delay(showDelay, function()
			showThread = nil
			if hasShown or isBought then
				return
			end
			context.Open("StarterOffer")
		end)
	end))

	return {
		Modal = true,
		StartsOpen = false,
		Open = function(_self: Types.Screen)
			if isBought then
				context.Toast("You already bought this! ✅", "Good")
				context.Close("StarterOffer")
				return
			end
			hasShown = true
			isOpen = true
			if not deadline then
				deadline = os.clock() + offerSeconds
			end
			refreshTimer()
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

return StarterOffer
