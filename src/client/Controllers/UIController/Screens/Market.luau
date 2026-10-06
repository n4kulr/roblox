--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CharmConfig = require(ReplicatedStorage.Config.Charms)
local Eggs = require(ReplicatedStorage.Config.Eggs)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Market = require(ReplicatedStorage.Rules.Market)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local TimeFormat = require(ReplicatedStorage.Utils.TimeFormat)
local Economy = require(script.Parent.Parent.Economy)
local EggArt = require(script.Parent.Parent.EggArt)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)

type TroveInstance = typeof(Trove.new())
type Card = {
	Offer: Market.Offer,
	Price: number,
	Panel: Frame,
	PriceText: TextLabel,
	Drops: Frame,
	StockChip: Frame,
	StockText: TextLabel,
	Action: Kit.Button,
}
type Stored = { Slot: number?, Bought: { [string]: number }? }

local theme = Kit.Theme
local config = GameConfig.Market
local accent = Color3.fromRGB(255, 96, 48)
local cardSize = Vector2.new(205, 304)
local refreshSeconds = 0.25
local reachSlack = 6
local stalls = { "Market", "MarketPlaceholder" }
local fullMessage = "Your egg bag is full!"

local MarketScreen = {}

local function counterPosition(): Vector3?
	for _, name in stalls do
		local stall = workspace:FindFirstChild(name)
		local counter = if stall then stall:FindFirstChild("Counter", true) else nil
		if counter and counter:IsA("BasePart") then
			return counter.Position
		end
	end
	return nil
end

local function isNearCounter(): boolean
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local position = counterPosition()
	if not root or not root:IsA("BasePart") or not position then
		return false
	end
	return (root.Position - position).Magnitude <= config.PromptRange + reachSlack
end

local function percentText(chance: number): string
	local percent = chance * 100
	return if percent >= 10 or percent % 1 == 0
		then string.format("%d%%", math.floor(percent + 0.5))
		else string.format("%.1f%%", percent)
end

function MarketScreen.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local cardsTrove = Trove.new()
	trove:Add(cardsTrove)
	local playUi = Kit.UiSound(context.Controllers)
	local dataController = context.Controllers.DataController
	local tracker = Economy.Track(dataController, trove)
	local cards: { Card } = {}
	local stored: Stored = {}
	local currentSlot = Market.Slot(workspace:GetServerTimeNow())
	local builtSlot = -1
	local isOpen = false
	local isBusy = false

	local modal = Kit.Modal(trove, {
		Parent = context.PlayerGui,
		Name = "Market",
		Title = "EGG MARKET",
		Glyph = "Shop",
		MaxSize = Vector2.new(900, 680),
		HeaderColor = accent,
		OnClose = function()
			context.Close("Market")
		end,
		Sound = playUi,
	})
	local timerPill = Kit.Pill({
		Parent = modal.HeaderRight,
		Name = "Timer",
		Glyph = "Clock",
		Text = "New stock in 0:00",
		Size = UDim2.fromOffset(260, 40),
		TextSize = 20,
	})
	local timer = timerPill.Label
	local grid = Kit.GridScroll({
		Parent = modal.Body,
		Name = "Offers",
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -52),
		CellSize = UDim2.fromOffset(cardSize.X, cardSize.Y),
	})
	local gridPadding = grid:FindFirstChildOfClass("UIPadding")
	if gridPadding then
		gridPadding.PaddingLeft = UDim.new(0, Kit.Space.M)
	end
	local bagLabel = Kit.Label({
		Parent = modal.Body,
		Name = "Bag",
		Text = `Egg bag: 0/{Eggs.BagCap}`,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.new(1, -24, 0, 30),
		TextSize = 24,
		Title = true,
		Scaled = true,
	})

	local function boughtOf(index: number): number
		if stored.Slot ~= currentSlot or type(stored.Bought) ~= "table" then
			return 0
		end
		local count = stored.Bought[tostring(index)]
		return if type(count) == "number" then count else 0
	end

	local function leftOf(offer: Market.Offer): number
		return math.max(0, offer.Stock - boughtOf(offer.Index))
	end

	local function bagCount(): number
		local bag = dataController:Get({ "EggInventory" })
		local total = 0
		if type(bag) == "table" then
			for _, count in bag do
				if type(count) == "number" then
					total += count
				end
			end
		end
		return total
	end

	local function currentRate(): number
		local upgrades = dataController:Get({ "Upgrades" })
		return Market.BaseRate(tracker.GetBoard(), if type(upgrades) == "table" then upgrades else {})
	end

	local function refreshCards()
		local balance = tracker.Balance() or 0
		local rate = currentRate()
		local held = bagCount()
		local isFull = held >= Eggs.BagCap
		bagLabel.Text = `Egg bag: {held}/{Eggs.BagCap}`
		bagLabel.TextColor3 = if isFull then theme.Bad else theme.Text
		for _, card in cards do
			local offer = card.Offer
			local left = leftOf(offer)
			card.Price = Market.Price(offer, rate)
			card.PriceText.Text = NumberFormat.Commas(card.Price)
			card.StockText.Text = if left > 0 then `x{left} left` else "NO STOCK"
			Kit.Paint(card.StockChip, if left > 0 then theme.Blue else theme.Grey)
			if left <= 0 then
				card.Action.SetDisabled(true)
				card.Action.SetText("NO STOCK")
			elseif isFull then
				card.Action.SetDisabled(false)
				card.Action.SetColor(theme.Grey)
				card.Action.SetText("BAG FULL")
			elseif balance < card.Price then
				card.Action.SetDisabled(false)
				card.Action.SetColor(theme.Red)
				card.Action.SetText(`Need {NumberFormat.Compact(card.Price - balance)} more!`)
			else
				card.Action.SetDisabled(false)
				card.Action.SetColor(theme.Green)
				card.Action.SetText("BUY")
			end
		end
	end

	local function buy(card: Card)
		if isBusy then
			return
		end
		local offer = card.Offer
		local balance = tracker.Balance() or 0
		if leftOf(offer) <= 0 then
			playUi("Error")
			context.Toast("No stock! Wait for the restock timer.", "Bad")
			return
		end
		if bagCount() >= Eggs.BagCap then
			playUi("Error")
			Kit.Shake(card.Panel)
			context.Toast(fullMessage, "Bad")
			return
		end
		if balance < card.Price then
			playUi("Error")
			Kit.Shake(card.Panel)
			context.Toast(`Need {NumberFormat.Compact(card.Price - balance)} more!`, "Bad")
			return
		end
		if not isNearCounter() then
			playUi("Error")
			context.Toast("Get closer to the market!", "Bad")
			return
		end
		isBusy = true
		task.spawn(function()
			local bought = Packets.MarketBuy:Fire(offer.Index)
			isBusy = false
			if bought == true then
				playUi("Confirm")
				context.Toast("Egg added to your backpack! Place it on your base.", "Good")
			else
				playUi("Error")
				context.Toast(
					if bagCount() >= Eggs.BagCap
						then fullMessage
						elseif isNearCounter() then "Couldn't buy that one!"
						else "Get closer to the market!",
					"Bad"
				)
			end
			refreshCards()
		end)
	end

	local function buildDrops(panel: Frame, egg: Eggs.Egg): Frame
		local overlay = Kit.Panel({
			Parent = panel,
			Name = "Drops",
			Size = UDim2.new(1, -12, 0, 170),
			Position = UDim2.fromOffset(6, 6),
			Color = theme.PanelDeep,
			Radius = Kit.Radius.M,
		})
		overlay.ZIndex = 5
		overlay.Visible = false
		Kit.Label({
			Parent = overlay,
			Name = "Heading",
			Text = "DROP CHANCES",
			Position = UDim2.fromOffset(8, 6),
			Size = UDim2.new(1, -16, 0, 26),
			TextSize = 20,
			Title = true,
			Scaled = true,
		}).ZIndex =
			6
		local total = 0
		for _, weight in egg.Drops do
			total += weight
		end
		local row = 0
		for _, rarity in CharmConfig.Rarities do
			local weight = egg.Drops[rarity.Name]
			if weight then
				local line = Kit.Chip({
					Parent = overlay,
					Name = rarity.Name,
					Text = `{rarity.Name}  {percentText(weight / total)}`,
					Size = UDim2.new(1, -20, 0, 28),
					Position = UDim2.fromOffset(10, 34 + row * 32),
					Color = rarity.Color,
					TextSize = 20,
				})
				line.ZIndex = 7
				(line.Parent :: Frame).ZIndex = 6
				row += 1
			end
		end
		return overlay
	end

	local function buildCard(offer: Market.Offer, animate: boolean)
		local egg = Eggs.ById[offer.EggId]
		local panel = Kit.Panel({
			Parent = grid,
			Name = `Offer{offer.Index}`,
			Size = UDim2.fromOffset(cardSize.X, cardSize.Y),
			Color = theme.Panel,
			StrokeColor = if offer.IsDeal then theme.Gold else nil,
			StrokeThickness = if offer.IsDeal then 5 else nil,
			LayoutOrder = offer.Index,
			Radius = Kit.Radius.L,
			Shards = true,
		})
		cardsTrove:Add(panel)
		local art = EggArt.Build(panel, egg, 118, "Art")
		art.Root.AnchorPoint = Vector2.new(0.5, 0)
		art.Root.Position = UDim2.new(0.5, 0, 0, 8)
		Kit.Label({
			Parent = panel,
			Name = "EggName",
			Text = egg.Name,
			Position = UDim2.fromOffset(8, 128),
			Size = UDim2.new(1, -16, 0, 28),
			TextSize = 24,
			Title = true,
			Scaled = true,
		})
		Kit.Label({
			Parent = panel,
			Name = "HatchTime",
			Text = `Hatches in {TimeFormat.Clock(egg.HatchSeconds)}`,
			Position = UDim2.fromOffset(8, 156),
			Size = UDim2.new(1, -16, 0, 20),
			TextSize = 17,
			Subtle = true,
			Scaled = true,
		})
		local stockText = Kit.Chip({
			Parent = panel,
			Name = "Stock",
			Text = "",
			Size = UDim2.fromOffset(92, 26),
			Position = UDim2.fromOffset(12, 182),
			Color = theme.Blue,
			TextSize = 16,
		})
		local drops = buildDrops(panel, egg)
		Kit.Button(cardsTrove, {
			Parent = panel,
			Name = "DropsButton",
			Text = "DROPS",
			Position = UDim2.new(1, -12, 0, 180),
			AnchorPoint = Vector2.new(1, 0),
			Size = UDim2.fromOffset(84, 30),
			Color = theme.Purple,
			TextSize = 16,
			Callback = function()
				drops.Visible = not drops.Visible
			end,
			Sound = playUi,
		})
		local priceText = Kit.Chip({
			Parent = panel,
			Name = "Price",
			Text = "",
			Size = UDim2.fromOffset(cardSize.X - 30, 30),
			Position = UDim2.fromOffset(15, 214),
			Color = theme.Track,
			TextSize = 22,
		})
		Kit.Icon({
			Parent = priceText.Parent :: Frame,
			Name = "PriceIcon",
			Glyph = "Clicks",
			Size = UDim2.fromOffset(28, 28),
			Position = UDim2.fromOffset(4, 1),
		})
		if offer.IsDeal then
			local ribbonText = Kit.Chip({
				Parent = panel,
				Name = "Deal",
				Text = "DEAL!",
				Size = UDim2.fromOffset(64, 24),
				Position = UDim2.new(1, -2, 0, 4),
				AnchorPoint = Vector2.new(1, 0),
				Color = theme.Red,
				TextSize = 18,
			})
			local ribbon = ribbonText.Parent :: Frame
			ribbon.Rotation = 10
		end
		local card: Card
		local action = Kit.Button(cardsTrove, {
			Parent = panel,
			Name = "Buy",
			Text = "BUY",
			Position = UDim2.new(0.5, 0, 1, -8),
			AnchorPoint = Vector2.new(0.5, 1),
			Size = UDim2.new(0.88, 0, 0, 44),
			Color = theme.Green,
			TextSize = 22,
			Callback = function()
				buy(card)
			end,
			Sound = playUi,
		})
		card = {
			Offer = offer,
			Price = 0,
			Panel = panel,
			PriceText = priceText,
			Drops = drops,
			StockChip = stockText.Parent :: Frame,
			StockText = stockText,
			Action = action,
		}
		table.insert(cards, card)
		if animate then
			local scale = Instance.new("UIScale")
			scale.Name = "Intro"
			scale.Scale = 0.7
			scale.Parent = panel
			Kit.Tween(
				scale,
				TweenInfo.new(
					0.2,
					Enum.EasingStyle.Back,
					Enum.EasingDirection.Out,
					0,
					false,
					(offer.Index - 1) * 0.04
				),
				{ Scale = 1 }
			)
		end
	end

	local function rebuild(animate: boolean)
		cardsTrove:Clean()
		table.clear(cards)
		builtSlot = currentSlot
		for _, offer in Market.Offers(currentSlot) do
			buildCard(offer, animate)
		end
		refreshCards()
	end

	local function tick()
		local now = workspace:GetServerTimeNow()
		local slot = Market.Slot(now)
		if slot ~= currentSlot then
			currentSlot = slot
			rebuild(true)
			context.Toast("New stock!", "Info")
		end
		timer.Text = `New stock in {TimeFormat.Clock(Market.SecondsLeft(now))}`
		refreshCards()
	end

	trove:Add(dataController:Observe({ "Market" }, function(value: any)
		stored = if type(value) == "table" then value else {}
		if isOpen then
			refreshCards()
		end
	end))
	trove:Add(dataController:Observe({ "EggInventory" }, function()
		if isOpen then
			refreshCards()
		end
	end))

	local elapsed = 0
	trove:Connect(RunService.Heartbeat, function(dt: number)
		if not isOpen then
			return
		end
		elapsed += dt
		if elapsed >= refreshSeconds then
			elapsed = 0
			tick()
		end
	end)

	local player = Players.LocalPlayer
	trove:Connect(player:GetAttributeChangedSignal("OpenMarket"), function()
		if player:GetAttribute("OpenMarket") ~= nil then
			context.Open("Market")
		end
	end)

	return {
		Modal = true,
		StartsOpen = false,
		Open = function(_self: Types.Screen)
			isOpen = true
			currentSlot = Market.Slot(workspace:GetServerTimeNow())
			if builtSlot ~= currentSlot then
				rebuild(false)
			end
			tick()
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

return MarketScreen
