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
local refreshSeconds = 0.25
local bannerHeight = 120
local passHeight = 172
local productHeight = 142
local gridGap = 10

local glyphs: { [string]: { Glyph: string, Color: Color3? } } = {
	DoubleLuck = { Glyph = "Luck" },
	DoubleClicks = { Glyph = "Income" },
	Vip = { Glyph = "Crown" },
	SeasonPremium = { Glyph = "Pass" },
	StarterPack = { Glyph = "Gift" },
	LuckPotion = { Glyph = "Potion" },
	ClicksPotion = { Glyph = "Potion", Color = Color3.fromRGB(255, 190, 40) },
	ServerLuck = { Glyph = "Globe" },
	ClicksSmall = { Glyph = "Clicks" },
	ClicksLarge = { Glyph = "Income" },
}

local productColors: { [string]: Color3 } = {
	StarterPack = theme.Orange,
	LuckPotion = theme.Green,
	ClicksPotion = theme.Yellow,
	ServerLuck = theme.Purple,
	Clicks = theme.Blue,
}

local ShopScreen = {}

function ShopScreen.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local playUi = Kit.UiSound(context.Controllers)
	local dataController = context.Controllers.DataController
	local boostState = BoostState.Track(dataController, trove)
	local rows: { Row } = {}
	local isOpen = false

	local modal = Kit.Modal(trove, {
		Parent = context.PlayerGui,
		Name = "Shop",
		Title = "STORE",
		Glyph = "Store",
		MaxSize = Vector2.new(860, 620),
		HeaderColor = theme.Red,
		OnClose = function()
			context.Close("Shop")
		end,
		Sound = playUi,
	})
	local scroll = Kit.Scroll({
		Parent = modal.Body,
		Name = "List",
		Position = UDim2.fromOffset(6, 4),
		Size = UDim2.new(1, -12, 1, -8),
		Padding = gridGap,
	})

	local function comingSoon()
		playUi("Error")
		context.Toast("Coming soon!", "Info")
	end

	local function buyButton(parent: Instance, size: UDim2, textSize: number, callback: () -> ()): Kit.Button
		return Kit.Button(trove, {
			Parent = parent,
			Name = "Buy",
			Text = "BUY",
			Glyph = "Robux",
			IconLeft = true,
			Position = UDim2.new(0.5, 0, 1, -8),
			AnchorPoint = Vector2.new(0.5, 1),
			Size = size,
			Color = theme.Green,
			TextSize = textSize,
			Callback = callback,
			Sound = playUi,
		})
	end

	local function grid(name: string, order: number, count: number, columns: number, cellHeight: number)
		local rowsCount = math.ceil(count / columns)
		local holder = Instance.new("Frame")
		holder.Name = name
		holder.BackgroundTransparency = 1
		holder.BorderSizePixel = 0
		holder.LayoutOrder = order
		holder.Size = UDim2.new(1, 0, 0, rowsCount * cellHeight + (rowsCount - 1) * gridGap)
		local layout = Instance.new("UIGridLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.CellPadding = UDim2.fromOffset(gridGap, gridGap)
		layout.CellSize = UDim2.new(1 / columns, -gridGap * (columns - 1) / columns, 0, cellHeight)
		layout.Parent = holder
		holder.Parent = scroll
		return holder
	end

	local function card(
		parent: Instance,
		order: number,
		id: string,
		name: string,
		description: string?,
		color: Color3,
		iconSize: number,
		nameSize: number,
		callback: () -> ()
	): Kit.Button
		local art: { Glyph: string, Color: Color3? } = glyphs[id] or { Glyph = "Gift" }
		local frame = Kit.Panel({
			Parent = parent,
			Name = id,
			LayoutOrder = order,
			Color = color,
			Shards = true,
			Radius = Kit.Radius.L,
			Gloss = true,
		})
		Kit.Icon({
			Parent = frame,
			Name = "Icon",
			Glyph = art.Glyph,
			Color = art.Color,
			Position = UDim2.new(0.5, -iconSize / 2, 0, 8),
			Size = UDim2.fromOffset(iconSize, iconSize),
		})
		Kit.Label({
			Parent = frame,
			Name = "Name",
			Text = name,
			Position = UDim2.fromOffset(8, iconSize + 10),
			Size = UDim2.new(1, -16, 0, nameSize + 6),
			TextSize = nameSize,
			Align = Enum.TextXAlignment.Center,
			Scaled = true,
		})
		if description then
			Kit.Label({
				Parent = frame,
				Name = "Description",
				Text = description,
				Position = UDim2.fromOffset(10, iconSize + nameSize + 18),
				Size = UDim2.new(1, -20, 0, 20),
				TextSize = 16,
				Align = Enum.TextXAlignment.Center,
				Scaled = true,
			})
		end
		return buyButton(frame, UDim2.new(1, -24, 0, 40), 22, callback)
	end

	local function passCallback(pass: Monetization.Pass): () -> ()
		return function()
			if boostState.Owns(pass.Id) then
				context.Toast("You already own this!", "Good")
			elseif not Purchases.PromptPass(pass) then
				comingSoon()
			end
		end
	end

	local function productCallback(product: Monetization.Product): () -> ()
		return function()
			if product.OneTime and dataController:Get({ "StarterPackBought" }) == true then
				context.Toast("You already bought this!", "Good")
			elseif not Purchases.PromptProduct(product) then
				comingSoon()
			end
		end
	end

	local starter = Monetization.ProductById.StarterPack
	local banner = Kit.Panel({
		Parent = scroll,
		Name = "StarterBanner",
		Size = UDim2.new(1, 0, 0, bannerHeight),
		LayoutOrder = 1,
		Color = theme.Orange,
		Shards = true,
		Radius = Kit.Radius.L,
		Gloss = true,
		StrokeThickness = 4,
	})
	Kit.Icon({
		Parent = banner,
		Name = "Icon",
		Glyph = "Gift",
		Position = UDim2.fromOffset(18, 16),
		Size = UDim2.fromOffset(88, 88),
	})
	Kit.Label({
		Parent = banner,
		Name = "Name",
		Text = "STARTER PACK",
		Position = UDim2.fromOffset(130, 18),
		Size = UDim2.new(0.5, -130, 0, 48),
		TextSize = 40,
		Title = true,
		Scaled = true,
	})
	Kit.Label({
		Parent = banner,
		Name = "Description",
		Text = "Clicks, a potion and an Epic key!",
		Position = UDim2.fromOffset(130, 70),
		Size = UDim2.new(0.5, -130, 0, 30),
		TextSize = 22,
		Scaled = true,
	})
	local bannerButton = Kit.Button(trove, {
		Parent = banner,
		Name = "Buy",
		Text = "BUY",
		Glyph = "Robux",
		IconLeft = true,
		Position = UDim2.new(1, -20, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.fromOffset(190, 64),
		Color = theme.Green,
		TextSize = 30,
		Callback = if starter then productCallback(starter) else comingSoon,
		Sound = playUi,
	})
	if starter then
		table.insert(rows, { Button = bannerButton, Product = starter })
	end

	local passGrid = grid("Passes", 2, #Monetization.Passes, 2, passHeight)
	for index, pass in Monetization.Passes do
		local button = card(
			passGrid,
			index,
			pass.Id,
			pass.Name,
			pass.Description,
			theme.Blue,
			54,
			26,
			passCallback(pass)
		)
		table.insert(rows, { Button = button, Pass = pass })
	end

	local boosts: { Monetization.Product } = {}
	for _, product in Monetization.Products do
		if product.Id ~= "StarterPack" then
			table.insert(boosts, product)
		end
	end
	local productGrid = grid("Products", 3, #boosts, math.max(#boosts, 1), productHeight)
	for index, product in boosts do
		local button = card(
			productGrid,
			index,
			product.Id,
			product.Name,
			nil,
			productColors[product.Kind] or theme.Green,
			44,
			18,
			productCallback(product)
		)
		table.insert(rows, { Button = button, Product = product })
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
			button.SetText(item.PriceLabel)
		end
	end

	local function refreshAll()
		banner.Visible = dataController:Get({ "StarterPackBought" }) ~= true
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
