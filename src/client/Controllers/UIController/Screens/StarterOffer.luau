--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local Monetization = require(ReplicatedStorage.Config.Monetization)
local Trove = require(ReplicatedStorage.Packages.Trove)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local TimeFormat = require(ReplicatedStorage.Utils.TimeFormat)
local Kit = require(script.Parent.Parent.Kit)
local Purchases = require(script.Parent.Parent.Purchases)
local Types = require(script.Parent.Parent.Types)

type Tile = {
	Glyph: string,
	Amount: string,
	Caption: string,
	Color: Color3,
}

local theme = Kit.Theme
local offerSeconds = 900
local worthRobux = 99
local starterKeyRarity = "Epic"
local panelWidth = 560
local panelHeight = 540
local tileWidth = 150
local tileHeight = 176
local tileGap = 14
local tileTop = 166
local burstDiameter = 720
local burstSeconds = 40
local popStagger = 0.07
local tileDelay = 0.12
local flashInfo = Kit.Motion.Fade
local ribbonColor = theme.Orange

local function tilesFor(product: Monetization.Product): { Tile }
	local potionMinutes = GameConfig.Boosts.PotionSeconds // 60
	local keyColor = Keys.RarityByName[starterKeyRarity].Color
	return {
		{
			Glyph = "Clicks",
			Amount = NumberFormat.Commas(product.Amount),
			Caption = "Clicks",
			Color = theme.Gold,
		},
		{
			Glyph = "Potion",
			Amount = `{GameConfig.Boosts.PotionMultiplier}x Luck`,
			Caption = `{potionMinutes} min potion`,
			Color = theme.Green,
		},
		{ Glyph = "Keys", Amount = starterKeyRarity, Caption = "Key", Color = keyColor },
	}
end

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
		Glyph = "Gift",
		MaxSize = Vector2.new(panelWidth, panelHeight),
		HeaderColor = theme.Orange,
		OnClose = function()
			context.Close("StarterOffer")
		end,
	})
	local panel = modal.Panel
	local header = panel:FindFirstChild("Header")
	if header then
		(header :: Frame).Visible = false
	end
	local body = panel:FindFirstChild("Body")
	if body then
		(body :: Frame).Visible = false
	end
	local paint = panel:FindFirstChild("Paint")
	if paint then
		(paint :: UIGradient).Color = ColorSequence.new(theme.PromoTop, theme.PromoBottom)
	end

	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.BackgroundTransparency = 1
	stage.BorderSizePixel = 0
	stage.ClipsDescendants = true
	stage.Size = UDim2.fromScale(1, 1)
	Kit.Corner(stage, Kit.Radius.Panel)
	stage.Parent = panel

	local burst = Kit.Burst({
		Parent = stage,
		Diameter = burstDiameter,
		Position = UDim2.new(0.5, 0, 0, 250),
		Color = theme.Gold,
	})
	burst.Name = "Sparkles"
	local spin = TweenService:Create(burst, Kit.Retime(Kit.Motion.Spin, burstSeconds), { Rotation = 360 })
	spin:Play()
	trove:Add(function()
		spin:Cancel()
	end)

	local flash = Kit.Flash({ Parent = stage, Radius = Kit.Radius.Panel, ZIndex = Kit.ZIndex.Tooltip })

	local ribbonHolder = Instance.new("Frame")
	ribbonHolder.Name = "RibbonHolder"
	ribbonHolder.BackgroundTransparency = 1
	ribbonHolder.BorderSizePixel = 0
	ribbonHolder.AnchorPoint = Vector2.new(0.5, 0)
	ribbonHolder.Position = UDim2.new(0.5, 0, 0, 26)
	ribbonHolder.Size = UDim2.fromOffset(500, 84)
	ribbonHolder.Parent = panel
	local ribbonPop = Instance.new("UIScale")
	ribbonPop.Parent = ribbonHolder
	for side = 0, 1 do
		local tail = Kit.Panel({
			Parent = ribbonHolder,
			Name = if side == 0 then "TailLeft" else "TailRight",
			Position = UDim2.new(side, 0, 0.5, 8),
			AnchorPoint = Vector2.new(side, 0.5),
			Size = UDim2.fromOffset(86, 58),
			Color = Kit.Shade(ribbonColor, -0.3),
			Radius = Kit.Radius.S,
		})
		tail.Rotation = if side == 0 then -4 else 4
	end
	local ribbon = Kit.Panel({
		Parent = ribbonHolder,
		Name = "Ribbon",
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(420, 76),
		Color = ribbonColor,
		Radius = Kit.Radius.L,
		StrokeThickness = Kit.StrokeSize.Heavy,
		Gloss = true,
	})
	ribbon.ZIndex = Kit.ZIndex.Fill
	local ribbonLabel = Kit.Label({
		Parent = ribbon,
		Name = "Title",
		Text = "STARTER PACK",
		Size = UDim2.new(1, -40, 1, -8),
		Position = UDim2.fromOffset(20, 4),
		TextSize = Kit.Text.Giant,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
		Title = true,
		StrokeSize = Kit.StrokeSize.Heavy,
	})
	ribbonLabel.ZIndex = Kit.ZIndex.Badge

	local badge = Kit.Chip({
		Parent = panel,
		Name = "Badge",
		Text = "ONE TIME!",
		Size = UDim2.fromOffset(132, 40),
		Position = UDim2.new(1, -18, 0, 104),
		AnchorPoint = Vector2.new(1, 0),
		Color = theme.Red,
		TextSize = Kit.Text.Title,
	})
	local badgeFrame = badge.Parent :: Frame
	badgeFrame.Rotation = 7
	badgeFrame.ZIndex = Kit.ZIndex.Hover

	local timerPill = Kit.Pill({
		Parent = panel,
		Name = "Timer",
		Glyph = "Clock",
		Text = "15:00",
		Size = UDim2.fromOffset(150, 36),
		Position = UDim2.new(0, 22, 0, 108),
		TextSize = Kit.Text.Strong,
	})
	local timerChip = timerPill.Label

	local tiles = tilesFor(starterPack)
	local tilePops: { UIScale } = {}
	local rowWidth = #tiles * tileWidth + (#tiles - 1) * tileGap
	local row = Instance.new("Frame")
	row.Name = "Contents"
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.new(0.5, 0, 0, tileTop)
	row.Size = UDim2.fromOffset(rowWidth, tileHeight)
	row.Parent = panel
	for index, tile in tiles do
		local holder = Instance.new("Frame")
		holder.Name = `Tile{index}`
		holder.BackgroundTransparency = 1
		holder.BorderSizePixel = 0
		holder.Position = UDim2.fromOffset((index - 1) * (tileWidth + tileGap), 0)
		holder.Size = UDim2.fromOffset(tileWidth, tileHeight)
		holder.Parent = row
		local pop = Instance.new("UIScale")
		pop.Parent = holder
		table.insert(tilePops, pop)
		local card = Kit.Card({
			Parent = holder,
			Name = "Card",
			Size = UDim2.fromScale(1, 1),
			Tint = Kit.Shade(tile.Color, 0.8),
		})
		Kit.IconPlate({
			Parent = card,
			Name = "IconTile",
			Position = UDim2.new(0.5, 0, 0, 12),
			AnchorPoint = Vector2.new(0.5, 0),
			Size = UDim2.fromOffset(96, 96),
			Color = tile.Color,
			Glyph = tile.Glyph,
			Burst = true,
		})
		Kit.Label({
			Parent = card,
			Name = "Amount",
			Text = tile.Amount,
			Position = UDim2.fromOffset(6, 114),
			Size = UDim2.new(1, -12, 0, 30),
			TextSize = Kit.Text.Heading,
			Align = Enum.TextXAlignment.Center,
			Scaled = true,
			Title = true,
		})
		Kit.Label({
			Parent = card,
			Name = "Caption",
			Text = tile.Caption,
			Position = UDim2.fromOffset(6, 146),
			Size = UDim2.new(1, -12, 0, 22),
			TextSize = Kit.Text.Lead,
			Color = theme.Subtext,
			Align = Enum.TextXAlignment.Center,
			Subtle = true,
			Scaled = true,
		})
	end

	Kit.Label({
		Parent = panel,
		Name = "Worth",
		Text = `Worth <s>R$ {worthRobux}</s>`,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, tileTop + tileHeight + 14),
		Size = UDim2.fromOffset(300, 30),
		TextSize = Kit.Text.Banner,
		Color = theme.Cream,
		Align = Enum.TextXAlignment.Center,
		RichText = true,
		Scaled = true,
	})

	local buyHolder = Instance.new("Frame")
	buyHolder.Name = "BuyHolder"
	buyHolder.BackgroundTransparency = 1
	buyHolder.BorderSizePixel = 0
	buyHolder.AnchorPoint = Vector2.new(0.5, 0)
	buyHolder.Position = UDim2.new(0.5, 0, 0, tileTop + tileHeight + 52)
	buyHolder.Size = UDim2.fromOffset(360, 88)
	buyHolder.Parent = panel
	local buyPulse = Instance.new("UIScale")
	buyPulse.Name = "Pulse"
	buyPulse.Parent = buyHolder
	local buy = Kit.Button(trove, {
		Parent = buyHolder,
		Name = "Buy",
		Text = `BUY  R$ {starterPack.PriceLabel}`,
		Title = true,
		Lip = 9,
		Size = UDim2.fromScale(1, 1),
		Color = theme.Green,
		TextSize = Kit.Text.Jumbo,
		Callback = function()
			if not Purchases.PromptProduct(starterPack) then
				playUi("Error")
				context.Toast("Coming soon!", "Info")
			end
		end,
	})
	buy.SetGlow(true)
	Kit.Breathe(trove, buyPulse, 0.06, 0.6)

	local decline = Instance.new("TextButton")
	decline.Name = "NoThanks"
	decline.AutoButtonColor = false
	decline.BackgroundTransparency = 1
	decline.BorderSizePixel = 0
	decline.Font = Kit.Font
	decline.Text = "No thanks"
	decline.TextSize = Kit.Text.Label
	decline.TextColor3 = theme.TextDim
	decline.TextTransparency = 0.25
	decline.Size = UDim2.fromOffset(160, 32)
	decline.Position = UDim2.new(0.5, 0, 1, -16)
	decline.AnchorPoint = Vector2.new(0.5, 1)
	decline.Parent = panel
	trove:Connect(decline.Activated, function()
		playUi("Click")
		context.Close("StarterOffer")
	end)

	local function refreshTimer()
		local target = deadline
		if not target then
			return
		end
		timerChip.Text = TimeFormat.Clock(math.max(0, target - os.clock()))
	end

	Kit.Poll(trove, 0, function()
		return isOpen
	end, refreshTimer)

	trove:Add(dataController:Observe({ "StarterPackBought" }, function(value: any)
		isBought = value == true
		if isBought then
			context.Close("StarterOffer")
			return
		end
	end))

	local function playEntrance()
		ribbonPop.Scale = 0.4
		Kit.Tween(ribbonPop, Kit.Motion.Spring, { Scale = 1 })
		for _, pop in tilePops do
			pop.Scale = 0.01
		end
		for index, pop in tilePops do
			local delay = tileDelay + (index - 1) * popStagger
			local info = Kit.Retime(Kit.Motion.Pop, 0.3, delay)
			Kit.Tween(pop, info, { Scale = 1 })
		end
		flash.Fire(0.35, flashInfo)
	end

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
			playEntrance()
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
