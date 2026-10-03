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
local offerSeconds = 900
local oldPrice = "R$ 99"
local tileWidth = 240
local columnGap = 24

type Included = {
	Icon: string,
	Title: string,
	Detail: string,
}

local contents: { Included } = {
	{ Icon = "clicks", Title = "10K Clicks", Detail = "" },
	{ Icon = "flask", Title = "2x Luck potion", Detail = "15 minutes" },
	{ Icon = "keys", Title = "Epic Key", Detail = "Guaranteed" },
}

local StarterOffer = {}

function StarterOffer.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local playUi = Kit.UiSound(context.Controllers)
	local dataController = context.Controllers.DataController
	local starterPack = Monetization.ProductById.StarterPack
	local isBought = false
	local isOpen = false
	local deadline: number? = nil

	local modal = Kit.Modal(trove, {
		Parent = context.PlayerGui,
		Name = "StarterOffer",
		Title = "STARTER PACK",
		IconName = "gift",
		MaxSize = Vector2.new(740, 520),
		HeaderColor = theme.Red,
		OnClose = function()
			context.Close("StarterOffer")
		end,
		Sound = playUi,
	})

	local timerChip = Kit.Chip({
		Parent = modal.HeaderRight,
		Name = "Timer",
		Text = "LIMITED TIME 15:00",
		Size = UDim2.fromOffset(0, 32),
		Color = theme.Line,
		GlyphName = "clock",
		AutoWidth = true,
	})
	local timerPanel = timerChip.Parent
	if timerPanel and timerPanel:IsA("GuiObject") then
		timerPanel.BackgroundTransparency = 0.45
	end

	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.Size = UDim2.fromScale(1, 1)
	local rowList = Instance.new("UIListLayout")
	rowList.FillDirection = Enum.FillDirection.Horizontal
	rowList.SortOrder = Enum.SortOrder.LayoutOrder
	rowList.Padding = UDim.new(0, columnGap)
	rowList.Parent = row
	row.Parent = modal.Content

	local tile = Kit.Panel({
		Parent = row,
		Name = "GiftTile",
		Size = UDim2.new(0, tileWidth, 1, 0),
		Color = theme.Surface3:Lerp(theme.Red, 0.25),
		LayoutOrder = 1,
	})
	tile.ClipsDescendants = true
	local burst = Kit.Burst({ Parent = tile, Diameter = 340 })
	local burstImage = burst:FindFirstChild("Image")
	if burstImage and burstImage:IsA("ImageLabel") then
		burstImage.ImageTransparency = 0.55
	end
	local gift = Kit.Icon(tile, "gift", 176)
	gift.AnchorPoint = Vector2.new(0.5, 0.5)
	gift.Position = UDim2.new(0.5, 0, 0.5, -16)
	local ribbon = Kit.Panel({
		Parent = tile,
		Name = "Ribbon",
		Size = UDim2.fromOffset(0, 32),
		Position = UDim2.fromOffset(-14, 20),
		Color = theme.Gold,
	})
	ribbon.AutomaticSize = Enum.AutomaticSize.X
	local ribbonPadding = Instance.new("UIPadding")
	ribbonPadding.PaddingLeft = UDim.new(0, 30)
	ribbonPadding.PaddingRight = UDim.new(0, 20)
	ribbonPadding.Parent = ribbon
	local ribbonText = Kit.Label({
		Parent = ribbon,
		Name = "Text",
		Text = "50% OFF!",
		Size = UDim2.fromOffset(0, 32),
		TextSize = 16,
		Color = theme.Line,
	})
	ribbonText.AutomaticSize = Enum.AutomaticSize.X
	ribbonText.TextTruncate = Enum.TextTruncate.None
	local onceChip = Kit.Chip({
		Parent = tile,
		Name = "OneTime",
		Text = "ONE TIME OFFER",
		Size = UDim2.fromOffset(0, 28),
		Position = UDim2.new(0.5, 0, 1, -16),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = theme.Line,
		GlyphName = "star",
		AutoWidth = true,
	})
	local oncePanel = onceChip.Parent
	if oncePanel and oncePanel:IsA("GuiObject") then
		oncePanel.BackgroundTransparency = 0.3
	end

	local right = Instance.new("Frame")
	right.Name = "Details"
	right.BackgroundTransparency = 1
	right.BorderSizePixel = 0
	right.Size = UDim2.new(1, -(tileWidth + columnGap), 1, 0)
	right.LayoutOrder = 2
	local rightList = Instance.new("UIListLayout")
	rightList.SortOrder = Enum.SortOrder.LayoutOrder
	rightList.Padding = UDim.new(0, 8)
	rightList.Parent = right
	right.Parent = row

	Kit.Caption({
		Parent = right,
		Name = "InsideCaption",
		Text = "What's inside",
		LayoutOrder = 1,
	})
	for index, item in contents do
		local line = Kit.Panel({
			Parent = right,
			Name = `Line{index}`,
			Size = UDim2.new(1, 0, 0, 52),
			Color = theme.Surface2,
			LayoutOrder = 1 + index,
		})
		local icon = Kit.Icon(line, item.Icon, 36)
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, 12, 0.5, 0)
		local hasDetail = item.Detail ~= ""
		Kit.Label({
			Parent = line,
			Name = "Title",
			Text = item.Title,
			Position = UDim2.new(0, 60, 0.5, if hasDetail then -10 else 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Size = UDim2.new(1, -72, 0, 20),
			TextSize = 16,
		})
		if hasDetail then
			Kit.Label({
				Parent = line,
				Name = "Detail",
				Text = item.Detail,
				Position = UDim2.new(0, 60, 0.5, 10),
				AnchorPoint = Vector2.new(0, 0.5),
				Size = UDim2.new(1, -72, 0, 16),
				TextSize = 13,
				Color = theme.Muted,
				Body = true,
			})
		end
	end

	local prices = Instance.new("Frame")
	prices.Name = "Prices"
	prices.BackgroundTransparency = 1
	prices.BorderSizePixel = 0
	prices.Size = UDim2.new(1, 0, 0, 56)
	prices.LayoutOrder = 10
	local priceList = Instance.new("UIListLayout")
	priceList.FillDirection = Enum.FillDirection.Horizontal
	priceList.VerticalAlignment = Enum.VerticalAlignment.Center
	priceList.SortOrder = Enum.SortOrder.LayoutOrder
	priceList.Padding = UDim.new(0, 16)
	priceList.Parent = prices
	prices.Parent = right
	local oldLabel = Kit.Label({
		Parent = prices,
		Name = "OldPrice",
		Text = `<s>{oldPrice}</s>`,
		Size = UDim2.fromOffset(0, 48),
		TextSize = 22,
		Color = theme.Muted,
		RichText = true,
		LayoutOrder = 1,
	})
	oldLabel.AutomaticSize = Enum.AutomaticSize.X
	local newLabel = Kit.Label({
		Parent = prices,
		Name = "NewPrice",
		Text = `R$ {starterPack.PriceLabel}`,
		Size = UDim2.fromOffset(0, 48),
		TextSize = 32,
		Color = Kit.TextSafe(theme.Green, theme.Surface),
		LayoutOrder = 2,
	})
	newLabel.AutomaticSize = Enum.AutomaticSize.X

	local isAvailable = Purchases.IsAvailable(starterPack)
	local buy = Kit.Button(trove, {
		Parent = right,
		Name = "Buy",
		Text = if isAvailable then "BUY" else "SOON",
		GlyphName = "gift",
		Hero = true,
		Size = UDim2.new(1, 0, 0, 64),
		Color = if isAvailable then theme.Green else theme.Grey,
		LayoutOrder = 11,
		Callback = function()
			if not Purchases.PromptProduct(starterPack) then
				playUi("Error")
				context.Toast("Coming soon!", "Info")
			end
		end,
		Sound = playUi,
	})
	buy.SetGlow(isAvailable)

	local declineHolder = Instance.new("Frame")
	declineHolder.Name = "NoThanksHolder"
	declineHolder.BackgroundTransparency = 1
	declineHolder.BorderSizePixel = 0
	declineHolder.Size = UDim2.new(1, 0, 0, 40)
	declineHolder.LayoutOrder = 12
	declineHolder.Parent = right
	Kit.Button(trove, {
		Parent = declineHolder,
		Name = "NoThanks",
		Text = "No thanks",
		Size = UDim2.fromOffset(160, 40),
		Position = UDim2.fromScale(0.5, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = theme.Grey,
		Callback = function()
			context.Close("StarterOffer")
		end,
		Sound = playUi,
	})

	local function refreshTimer()
		local target = deadline
		if not target then
			return
		end
		timerChip.Text = `LIMITED TIME {TimeFormat.Clock(target - os.clock())}`
	end

	trove:Connect(RunService.Heartbeat, function()
		if isOpen then
			refreshTimer()
		end
	end)

	trove:Add(dataController:Observe({ "StarterPackBought" }, function(value: any)
		isBought = value == true
		if isBought then
			context.Close("StarterOffer")
			return
		end
	end))

	return {
		Modal = true,
		StartsOpen = false,
		Open = function(_self: Types.Screen)
			if isBought then
				context.Toast("You already bought this!", "Good")
				context.Close("StarterOffer")
				return
			end
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
