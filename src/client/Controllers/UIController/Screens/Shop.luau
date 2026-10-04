--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Monetization = require(ReplicatedStorage.Config.Monetization)
local Trove = require(ReplicatedStorage.Packages.Trove)
local BoostState = require(script.Parent.Parent.BoostState)
local Kit = require(script.Parent.Parent.Kit)
local Purchases = require(script.Parent.Parent.Purchases)
local Types = require(script.Parent.Parent.Types)

type Row = {
	Button: Kit.Button,
	Pass: Monetization.Pass?,
	Product: Monetization.Product?,
}

local theme = Kit.Theme
local cardHeight = 96
local buyWidth = 140
local iconSize = 72
local refreshSeconds = 0.25

local productColors: { [string]: Color3 } = {
	StarterPack = theme.Orange,
	LuckPotion = theme.Green,
	ClicksPotion = theme.Yellow,
	ServerLuck = theme.Purple,
	Clicks = theme.Blue,
}

local productGlyphs: { [string]: string } = {
	StarterPack = "Gift",
	LuckPotion = "Luck",
	ClicksPotion = "Clicks",
	ServerLuck = "Star",
	Clicks = "Coin",
}

local ShopScreen = {}

function ShopScreen.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local playUi = Kit.UiSound(context.Controllers)
	local dataController = context.Controllers.DataController
	local boostState = BoostState.Track(dataController, trove)
	local rows: { Row } = {}
	local isOpen = false
	local order = 0

	local modal = Kit.Modal(trove, {
		Parent = context.PlayerGui,
		Name = "Shop",
		Title = "STORE",
		Glyph = "Shop",
		MaxSize = Vector2.new(720, 580),
		HeaderColor = theme.Red,
		OnClose = function()
			context.Close("Shop")
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

	local function section(title: string)
		order += 1
		local strip = Kit.Panel({
			Parent = scroll,
			Name = `{title}Header`,
			Size = UDim2.new(1, 0, 0, 34),
			Color = theme.Track,
			LayoutOrder = order,
			Radius = 6,
			StrokeThickness = 2,
			Bevel = false,
		})
		Kit.Label({
			Parent = strip,
			Name = "Text",
			Text = title,
			Position = UDim2.fromOffset(12, 0),
			Size = UDim2.new(1, -24, 1, 0),
			TextSize = 26,
			Color = theme.Gold,
			Scaled = true,
		})
	end

	local function card(
		id: string,
		name: string,
		description: string,
		color: Color3,
		glyph: string,
		callback: () -> ()
	): Kit.Button
		order += 1
		local frame = Kit.Panel({
			Parent = scroll,
			Name = id,
			Size = UDim2.new(1, 0, 0, cardHeight),
			Color = color,
			LayoutOrder = order,
			Shards = true,
			Radius = Kit.CardRadius,
		})
		local iconTile = Kit.Panel({
			Parent = frame,
			Name = "IconTile",
			Position = UDim2.fromOffset(10, (cardHeight - iconSize) / 2),
			Size = UDim2.fromOffset(iconSize, iconSize),
			Color = theme.Cell,
			Transparency = 0.08,
			Radius = 10,
			StrokeThickness = 2.5,
			Bevel = false,
		})
		Kit.Burst({ Parent = iconTile, Diameter = iconSize - 8 })
		Kit.Icon({
			Parent = iconTile,
			Name = "Icon",
			Glyph = glyph,
			Size = UDim2.fromScale(0.72, 0.72),
			Position = UDim2.fromScale(0.14, 0.14),
		})
		local textLeft = iconSize + 22
		local textWidth = UDim2.new(1, -(textLeft + buyWidth + 22), 0, 30)
		Kit.Label({
			Parent = frame,
			Name = "Name",
			Text = Kit.PlainTitle(name),
			Position = UDim2.fromOffset(textLeft, 8),
			Size = textWidth,
			TextSize = 28,
			Scaled = true,
		})
		Kit.Label({
			Parent = frame,
			Name = "Description",
			Text = description,
			Position = UDim2.fromOffset(textLeft, 42),
			Size = UDim2.new(1, -(textLeft + buyWidth + 22), 0, 46),
			TextSize = 18,
			Color = Color3.fromRGB(255, 244, 170),
			Wrapped = true,
			VerticalAlign = Enum.TextYAlignment.Top,
		})
		return Kit.Button(trove, {
			Parent = frame,
			Name = "Buy",
			Text = "BUY",
			Position = UDim2.new(1, -10, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Size = UDim2.new(0, buyWidth, 1, -20),
			Color = theme.Green,
			TextSize = 26,
			Callback = callback,
			Sound = playUi,
		})
	end

	local function comingSoon()
		playUi("Error")
		context.Toast("Coming soon!", "Info")
	end

	local function addPass(pass: Monetization.Pass)
		local button = card(pass.Id, pass.Name, pass.Description, theme.Blue, "Pass", function()
			if boostState.Owns(pass.Id) then
				context.Toast("You already own this!", "Good")
			elseif not Purchases.PromptPass(pass) then
				comingSoon()
			end
		end)
		table.insert(rows, { Button = button, Pass = pass })
	end

	local function addProduct(product: Monetization.Product)
		local button = card(
			product.Id,
			product.Name,
			product.Description,
			productColors[product.Kind] or theme.Green,
			productGlyphs[product.Kind] or "Shop",
			function()
				if product.OneTime and dataController:Get({ "StarterPackBought" }) == true then
					context.Toast("You already bought this!", "Good")
				elseif not Purchases.PromptProduct(product) then
					comingSoon()
				end
			end
		)
		table.insert(rows, { Button = button, Product = product })
	end

	section("PASSES")
	for _, pass in Monetization.Passes do
		addPass(pass)
	end
	section("PRODUCTS")
	for _, product in Monetization.Products do
		addProduct(product)
	end

	local function refreshRow(row: Row)
		local button = row.Button
		local item: { AssetId: number, PriceLabel: string } = (row.Pass or row.Product) :: any
		local isOwned = false
		if row.Pass then
			isOwned = boostState.Owns(row.Pass.Id)
		elseif row.Product and row.Product.OneTime then
			isOwned = dataController:Get({ "StarterPackBought" }) == true
		end
		button.SetDisabled(isOwned)
		if isOwned then
			button.SetText(if row.Pass then "OWNED" else "BOUGHT")
		elseif item.AssetId == 0 then
			button.SetColor(theme.Grey)
			button.SetText("SOON")
		else
			button.SetColor(theme.Green)
			button.SetText(`BUY\nR$ {item.PriceLabel}`)
		end
	end

	local function refreshAll()
		for _, row in rows do
			refreshRow(row)
		end
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

return ShopScreen
