--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Market = require(ReplicatedStorage.Rules.Market)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local TimeFormat = require(ReplicatedStorage.Utils.TimeFormat)
local Cells = require(script.Parent.Parent.Cells)
local Economy = require(script.Parent.Parent.Economy)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)

type TroveInstance = typeof(Trove.new())
type Card = {
	Offer: Market.Offer,
	Panel: Frame,
	StockChip: Frame,
	StockText: TextLabel,
	PriceChip: Frame,
	Action: Kit.Button,
}
type Stored = { Slot: number?, Bought: { [string]: number }? }

local theme = Kit.Theme
local config = GameConfig.Market
local accent = Color3.fromRGB(255, 96, 48)
local cardSize = Vector2.new(200, 266)
local refreshSeconds = 0.25
local reachSlack = 6
local stalls = { "Market", "MarketPlaceholder" }

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
		Title = "KEY MARKET",
		Glyph = "Shop",
		MaxSize = Vector2.new(700, 640),
		HeaderColor = accent,
		OnClose = function()
			context.Close("Market")
		end,
		Sound = playUi,
	})
	local timer = Kit.Chip({
		Parent = modal.HeaderRight,
		Name = "Timer",
		Text = "New stock in 0:00",
		Size = UDim2.fromOffset(240, 38),
		Color = theme.Slate,
		TextSize = 24,
	})
	local grid = Kit.GridScroll({
		Parent = modal.Body,
		Name = "Offers",
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12),
		CellSize = UDim2.fromOffset(cardSize.X, cardSize.Y),
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

	local function refreshCards()
		local balance = tracker.Balance() or 0
		for _, card in cards do
			local offer = card.Offer
			local left = leftOf(offer)
			card.StockText.Text = if left > 0 then `x{left} left` else "SOLD OUT"
			Kit.Paint(card.StockChip, if left > 0 then theme.Blue else theme.Grey)
			if left <= 0 then
				card.Action.SetDisabled(true)
				card.Action.SetText("SOLD OUT")
			elseif balance < offer.Price then
				card.Action.SetDisabled(false)
				card.Action.SetColor(theme.Red)
				card.Action.SetText(`Need {NumberFormat.Compact(offer.Price - balance)} more!`)
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
		local key = Keys.ById[offer.KeyId]
		local balance = tracker.Balance() or 0
		if leftOf(offer) <= 0 then
			playUi("Error")
			context.Toast("Sold out! Check back for new stock!", "Bad")
			return
		end
		if balance < offer.Price then
			playUi("Error")
			Kit.Shake(card.Panel)
			context.Toast(`Need {NumberFormat.Compact(offer.Price - balance)} more!`, "Bad")
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
				local sounds = context.Controllers.SoundController
				if sounds then
					sounds:PlaySwitch(key.Switch, "Press", 1, 1, nil, "Other")
				end
				context.Toast(`Bought {key.Name}!`, "Good")
			else
				playUi("Error")
				context.Toast(
					if isNearCounter() then "Couldn't buy that one!" else "Get closer to the market!",
					"Bad"
				)
			end
			refreshCards()
		end)
	end

	local function buildCard(offer: Market.Offer, animate: boolean)
		local key = Keys.ById[offer.KeyId]
		local rarity = Keys.GetRarity(key)
		local panel = Kit.Panel({
			Parent = grid,
			Name = `Offer{offer.Index}`,
			Size = UDim2.fromOffset(cardSize.X, cardSize.Y),
			Color = theme.Slate,
			StrokeColor = if offer.IsDeal then theme.Gold else nil,
			LayoutOrder = offer.Index,
			Shards = true,
		})
		cardsTrove:Add(panel)
		local cell = Cells.New(cardsTrove, { Parent = panel, Key = key })
		cell.Instance.AnchorPoint = Vector2.new(0.5, 0)
		cell.Instance.Position = UDim2.new(0.5, 0, 0, 6)
		cell.Name.TextColor3 = rarity.Color
		cell.Info.Text = `{rarity.Name} · 1 in {NumberFormat.Commas(rarity.Chance)}`
		cell.Info.TextColor3 = theme.TextDim
		Kit.Label({
			Parent = panel,
			Name = "Income",
			Text = `+{NumberFormat.Compact(Keys.GetIncome(key.Id))}/s`,
			Position = UDim2.fromOffset(10, 150),
			Size = UDim2.fromOffset(92, 22),
			TextSize = 20,
			Color = theme.Good,
			Scaled = true,
		})
		local stockText = Kit.Chip({
			Parent = panel,
			Name = "Stock",
			Text = "",
			Size = UDim2.fromOffset(84, 22),
			Position = UDim2.new(1, -10, 0, 150),
			AnchorPoint = Vector2.new(1, 0),
			Color = theme.Blue,
			TextSize = 16,
		})
		local priceText = Kit.Chip({
			Parent = panel,
			Name = "Price",
			Text = NumberFormat.Commas(offer.Price),
			Size = UDim2.fromOffset(170, 28),
			Position = UDim2.fromOffset(15, 176),
			Color = theme.Yellow,
			TextSize = 22,
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
			Size = UDim2.new(0.86, 0, 0, 46),
			Color = theme.Green,
			TextSize = 24,
			Callback = function()
				buy(card)
			end,
			Sound = playUi,
		})
		card = {
			Offer = offer,
			Panel = panel,
			StockChip = stockText.Parent :: Frame,
			StockText = stockText,
			PriceChip = priceText.Parent :: Frame,
			Action = action,
		}
		table.insert(cards, card)
		if animate then
			local scale = Instance.new("UIScale")
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
