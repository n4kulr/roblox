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
local cardHeight = 104
local buyWidth = 160
local iconSize = 80
local refreshSeconds = 0.25

local glyphs: { [string]: { Glyph: string, Color: Color3? } } = {
	DoubleLuck = { Glyph = "Luck" },
	DoubleClicks = { Glyph = "Income" },
	Vip = { Glyph = "Crown" },
	SeasonPremium = { Glyph = "Pass" },
	StarterPack = { Glyph = "Gift" },
	LuckPotion = { Glyph = "Flask" },
	ClicksPotion = { Glyph = "Flask", Color = Color3.fromRGB(255, 190, 40) },
	ServerLuck = { Glyph = "Globe" },
	ClicksSmall = { Glyph = "Coin" },
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
	local order = 0

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
		Padding = 12,
	})

	local function section(title: string, glyph: string)
		order += 1
		Kit.Section({
			Parent = scroll,
			Name = `{title}Header`,
			Text = title,
			Glyph = glyph,
			Color = theme.Gold,
			LayoutOrder = order,
		})
	end

	local function card(
		id: string,
		name: string,
		description: string,
		color: Color3,
		callback: () -> ()
	): Kit.Button
		order += 1
		local art = glyphs[id] or { Glyph = "Gift" }
		local frame = Kit.Panel({
			Parent = scroll,
			Name = id,
			Size = UDim2.new(1, 0, 0, cardHeight),
			Color = Kit.Shade(color, -0.12),
			LayoutOrder = order,
			Shards = true,
			Radius = Kit.Radius.L,
		})
		local iconTile = Kit.Plate({
			Parent = frame,
			Name = "IconTile",
			Position = UDim2.fromOffset(Kit.Space.M, (cardHeight - iconSize) / 2),
			Size = UDim2.fromOffset(iconSize, iconSize),
			Radius = Kit.Radius.L,
		})
		Kit.Burst({ Parent = iconTile, Diameter = iconSize - 8, Color = color })
		Kit.Icon({
			Parent = iconTile,
			Name = "Icon",
			Glyph = art.Glyph,
			Color = art.Color,
			Size = UDim2.fromScale(0.8, 0.8),
			Position = UDim2.fromScale(0.1, 0.1),
		})
		local textLeft = iconSize + Kit.Space.M * 2
		local textRight = buyWidth + Kit.Space.M * 2
		Kit.Label({
			Parent = frame,
			Name = "Name",
			Text = name,
			Position = UDim2.fromOffset(textLeft, 10),
			Size = UDim2.new(1, -(textLeft + textRight), 0, 32),
			TextSize = 30,
			Scaled = true,
			Title = true,
		})
		Kit.Label({
			Parent = frame,
			Name = "Description",
			Text = description,
			Position = UDim2.fromOffset(textLeft, 46),
			Size = UDim2.new(1, -(textLeft + textRight), 0, 48),
			TextSize = 18,
			Color = theme.Cream,
			Wrapped = true,
			VerticalAlign = Enum.TextYAlignment.Top,
		})
		return Kit.Button(trove, {
			Parent = frame,
			Name = "Buy",
			Text = "BUY",
			Position = UDim2.new(1, -Kit.Space.M, 0.5, 0),
			AnchorPoint = Vector2.new(1, 0.5),
			Size = UDim2.new(0, buyWidth, 1, -2 * Kit.Space.M - 4),
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
		local button = card(pass.Id, pass.Name, pass.Description, theme.Blue, function()
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

	section("PASSES", "Pass")
	for _, pass in Monetization.Passes do
		addPass(pass)
	end
	section("PRODUCTS", "Gift")
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
