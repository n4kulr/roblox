--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Eggs = require(ReplicatedStorage.Config.Eggs)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Market = require(ReplicatedStorage.Rules.Market)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local TimeFormat = require(ReplicatedStorage.Utils.TimeFormat)
local Economy = require(script.Parent.Parent.Economy)
local EggArt = require(script.Parent.Parent.EggArt)
local Kit = require(script.Parent.Parent.Kit)
local PlayerState = require(script.Parent.Parent.PlayerState)
local Types = require(script.Parent.Parent.Types)
local Counter = require(script.Counter)
local Display = require(script.Display)

type TroveInstance = typeof(Trove.new())
type Card = {
	Offer: Market.Offer,
	Price: number,
	Wrapper: Frame,
	Panel: Frame,
	Left: number,
	StockChip: Frame,
	StockText: TextLabel,
	StockScale: UIScale,
	Action: Kit.Button,
	Extra: number,
}
type Stored = { Slot: number?, Bought: { [string]: number }? }

local theme = Kit.Theme
local barHeight = Display.BarHeight
local expandedExtra = 84
local expandInfo = Kit.Motion.Base
local popInfo = Kit.Motion.Pop
local holdingText = "PLACE YOUR EGG FIRST"
local holdingMessage = "Place the egg you are holding on your base first!"
local fullText = "BASE FULL"
local fullMessage = `Your base holds {Eggs.PlacedCap} eggs! Hatch one first.`

local MarketScreen = {}

function MarketScreen.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local cardsTrove = Trove.new()
	trove:Add(cardsTrove)
	local playUi = Kit.UiSound(context.Controllers)
	local dataController = context.Controllers.DataController
	local tracker = Economy.For(context, trove)
	local cards: { Card } = {}
	local stored: Stored = {}
	local currentSlot = Market.Slot(workspace:GetServerTimeNow())
	local builtSlot = -1
	local isOpen = false
	local buyGuard = Kit.Request(trove)
	local expanded: Card? = nil

	local modal = Kit.Modal(trove, {
		Parent = context.PlayerGui,
		Name = "Market",
		Title = "EGG MARKET",
		Glyph = "Shop",
		MaxSize = Vector2.new(900, 680),
		HeaderColor = theme.Ember,
		OnClose = function()
			context.Close("Market")
		end,
	})
	local timerPill = Kit.Pill({
		Parent = modal.HeaderRight,
		Name = "Timer",
		Glyph = "Clock",
		Text = "New stock in 0:00",
		Size = UDim2.fromOffset(260, 40),
		TextSize = Kit.Text.Label,
	})
	local timer = timerPill.Label
	local list = Kit.Scroll({
		Parent = modal.Body,
		Name = "Offers",
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12),
		Padding = 10,
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

	local function isHolding(): boolean
		local held = dataController:Get({ "HeldEgg" })
		return type(held) == "string" and held ~= ""
	end

	local function isBaseFull(): boolean
		local placed = dataController:Get({ "PlacedEggs" })
		return type(placed) == "table" and #placed >= Eggs.PlacedCap
	end

	local function currentRate(): number
		local upgrades = dataController:Get({ "Upgrades" })
		return Market.BaseRate(tracker.GetBoard(), if type(upgrades) == "table" then upgrades else {})
	end

	local function refreshCards()
		local balance = tracker.Balance() or 0
		local rate = currentRate()
		local holding = isHolding()
		local isFull = isBaseFull()
		for _, card in cards do
			local offer = card.Offer
			local left = leftOf(offer)
			card.Price = Market.Price(offer, rate)
			card.StockText.Text = if left > 0 then `x{left} Stock` else "NO STOCK"
			Kit.Paint(card.StockChip, if left > 0 then theme.Blue else theme.Red)
			if left < card.Left then
				card.StockScale.Scale = 1.3
				Kit.Tween(card.StockScale, popInfo, { Scale = 1 })
			end
			card.Left = left
			local priceText = NumberFormat.Compact(card.Price)
			if left <= 0 then
				card.Action.SetDisabled(true)
				card.Action.SetColor(theme.Grey)
				card.Action.SetText(priceText)
				card.Action.SetIconVisible(true)
				card.Action.SetLocked(true)
			elseif holding or isFull then
				card.Action.SetDisabled(false)
				card.Action.SetColor(theme.Grey)
				card.Action.SetText(if holding then holdingText else fullText)
				card.Action.SetIconVisible(false)
				card.Action.SetLocked(false)
			elseif balance < card.Price then
				card.Action.SetDisabled(false)
				card.Action.SetColor(theme.Grey)
				card.Action.SetText(priceText)
				card.Action.SetIconVisible(true)
				card.Action.SetLocked(true)
			else
				card.Action.SetDisabled(false)
				card.Action.SetColor(theme.Green)
				card.Action.SetText(priceText)
				card.Action.SetIconVisible(true)
				card.Action.SetLocked(false)
			end
		end
	end

	local function setExpanded(card: Card, isOn: boolean)
		local extra = if isOn then expandedExtra else 0
		card.Extra = extra
		Kit.Tween(card.Wrapper, expandInfo, { Size = UDim2.new(1, 0, 0, barHeight + extra) })
	end

	local function toggle(card: Card)
		local previous = expanded
		if previous and previous ~= card then
			setExpanded(previous, false)
		end
		if previous == card then
			setExpanded(card, false)
			expanded = nil
		else
			setExpanded(card, true)
			expanded = card
		end
	end

	local function buy(card: Card)
		if buyGuard.IsBusy() then
			return
		end
		local offer = card.Offer
		local balance = tracker.Balance() or 0
		if leftOf(offer) <= 0 then
			playUi("Error")
			context.Toast("No stock! Wait for the restock timer.", "Bad")
			return
		end
		if isHolding() or isBaseFull() then
			playUi("Error")
			Kit.Shake(card.Wrapper)
			context.Toast(if isHolding() then holdingMessage else fullMessage, "Bad")
			return
		end
		if balance < card.Price then
			playUi("Error")
			Kit.Shake(card.Wrapper)
			context.Toast(`Need {NumberFormat.Compact(card.Price - balance)} more!`, "Bad")
			return
		end
		if not Counter.IsNear() then
			playUi("Error")
			context.Toast("Get closer to the market!", "Bad")
			return
		end
		buyGuard.Run(function()
			return Packets.MarketBuy:Fire(offer.Index)
		end, function(isOk: boolean, bought: any)
			if isOk and bought == true then
				playUi("Confirm")
				context.Toast(Eggs.Guide.BoughtToast, "Good")
				context.Close("Market")
			else
				playUi("Error")
				context.Toast(
					if isHolding()
						then holdingMessage
						elseif isBaseFull() then fullMessage
						elseif Counter.IsNear() then "Couldn't buy that one!"
						else "Get closer to the market!",
					"Bad"
				)
			end
			refreshCards()
		end)
	end

	local function buildCard(offer: Market.Offer, animate: boolean)
		local egg = Eggs.ById[offer.EggId]
		local wrapper = Instance.new("Frame")
		wrapper.Name = `Offer{offer.Index}`
		wrapper.BackgroundTransparency = 1
		wrapper.Size = UDim2.new(1, 0, 0, barHeight)
		wrapper.LayoutOrder = offer.Index
		wrapper.Parent = list
		cardsTrove:Add(wrapper)
		local panel = Kit.Panel({
			Parent = wrapper,
			Name = "Bar",
			Size = UDim2.fromScale(1, 1),
			Color = theme.Panel,
			Radius = Kit.Radius.L,
			Flat = true,
		})
		panel.ClipsDescendants = true
		local accentColor = Kit.Shade(egg.Color, 0.1)
		local accent = Kit.Panel({
			Parent = panel,
			Name = "Accent",
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.new(0, 16, 1, -8),
			Color = accentColor,
			Radius = 10,
			Flat = true,
			StrokeThickness = 0,
		})
		Kit.Panel({
			Parent = accent,
			Name = "Fill",
			Position = UDim2.new(1, -8, 0, 0),
			Size = UDim2.new(0, 8, 1, 0),
			Color = accentColor,
			Radius = 0,
			Flat = true,
			StrokeThickness = 0,
		})
		local tap = Instance.new("TextButton")
		tap.Name = "Tap"
		tap.BackgroundTransparency = 1
		tap.Text = ""
		tap.AutoButtonColor = false
		tap.Size = UDim2.new(1, 0, 0, barHeight)
		tap.Parent = panel
		local plate = Kit.Panel({
			Parent = panel,
			Name = "Plate",
			Position = UDim2.fromOffset(30, 8),
			Size = UDim2.fromOffset(68, 68),
			Color = Kit.Shade(egg.Color, 0.62),
			Radius = Kit.Radius.M,
		})
		local art = EggArt.Build(plate, egg, 58, "Art")
		art.Root.AnchorPoint = Vector2.new(0.5, 0.5)
		art.Root.Position = UDim2.fromScale(0.5, 0.5)
		Kit.Label({
			Parent = panel,
			Name = "EggName",
			Text = egg.Name,
			Position = UDim2.fromOffset(112, 8),
			Size = UDim2.new(1, -330, 0, 34),
			TextSize = Kit.Text.Banner,
			Title = true,
		})
		Kit.Label({
			Parent = panel,
			Name = "HatchTime",
			Text = `Hatches in {TimeFormat.Clock(egg.HatchSeconds)}`,
			Position = UDim2.fromOffset(112, 48),
			Size = UDim2.fromOffset(176, 26),
			TextSize = Kit.Text.Body,
			Subtle = true,
		})
		local stockText = Kit.Chip({
			Parent = panel,
			Name = "Stock",
			Text = "",
			Size = UDim2.fromOffset(104, 26),
			Position = UDim2.fromOffset(296, 48),
			Color = theme.Blue,
			TextSize = Kit.Text.Body,
		})
		local stockChip = stockText.Parent :: Frame
		local stockScale = Instance.new("UIScale")
		stockScale.Name = "Pop"
		stockScale.Parent = stockChip
		Display.BuildDrops(panel, egg)
		local card: Card
		local action = Kit.Button(cardsTrove, {
			Parent = panel,
			Name = "Buy",
			Text = "",
			Glyph = "Clicks",
			IconLeft = true,
			Position = UDim2.new(1, -16, 0, 42),
			AnchorPoint = Vector2.new(1, 0.5),
			Size = UDim2.fromOffset(190, 62),
			Color = theme.Green,
			TextSize = Kit.Text.Heading,
			Callback = function()
				buy(card)
			end,
		})
		Display.CenterPrice(action.Face)
		card = {
			Offer = offer,
			Price = 0,
			Wrapper = wrapper,
			Panel = panel,
			Left = leftOf(offer),
			StockChip = stockChip,
			StockText = stockText,
			StockScale = stockScale,
			Action = action,
			Extra = 0,
		}
		cardsTrove:Connect(tap.Activated, function()
			playUi("Click")
			toggle(card)
		end)
		table.insert(cards, card)
		if animate then
			local scale = Instance.new("UIScale")
			scale.Name = "Intro"
			scale.Scale = 0.85
			scale.Parent = wrapper
			Kit.Tween(scale, Kit.Retime(Kit.Motion.Pop, 0.2, (offer.Index - 1) * 0.04), { Scale = 1 })
		end
	end

	local function rebuild(animate: boolean)
		cardsTrove:Clean()
		table.clear(cards)
		expanded = nil
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
	for _, field in { "HeldEgg", "PlacedEggs" } do
		trove:Add(dataController:Observe({ field }, function()
			if isOpen then
				refreshCards()
			end
		end))
	end

	Kit.Poll(trove, Kit.PollSeconds.Relaxed, function()
		return isOpen
	end, tick)

	trove:Connect(PlayerState.MarketRequested(), function()
		if PlayerState.IsMarketRequested() then
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
