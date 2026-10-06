local H = require("../harness/Harness")
local roblox = require("@lune/roblox")
local Layout = require("../../tools/ui_preview/Layout")

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

local screens = "StarterPlayer.StarterPlayerScripts.Controllers.UIController"
local barHeight = 84

describe("Market egg bars", function()
	local observers, world, Eggs, Market, NumberFormat, screen, playerGui, data, fired, toasts, closed, context

	local function press(button: any)
		button.Activated:Fire({ UserInputType = roblox.Enum.UserInputType.MouseButton1 })
	end

	local function lookup(path: { any }): any
		local node: any = data
		for _, part in path do
			if type(node) ~= "table" then
				return nil
			end
			node = node[part]
		end
		return node
	end

	local function open(cash: number, held: string?, bought: { [string]: number }?, placed: number?)
		data.Cash = cash
		data.HeldEgg = held or ""
		data.PlacedEggs = {}
		for index = 1, placed or 0 do
			table.insert(data.PlacedEggs, { Id = "Linear", ReadyAt = 1, X = index * 8, Z = 10 })
		end
		data.Market = { Slot = Market.Slot(world.now), Bought = bought or {} }
		screen = world:require(`{screens}.Screens.Market`).new(context)
		screen:Open()
		world.task.wait(0.4)
	end

	local function find(index: number, name: string): any
		return playerGui:FindFirstChild(`Offer{index}`, true):FindFirstChild(name, true)
	end

	local function buyText(index: number): string
		return find(index, "Buy").Face:FindFirstChild("Text", true).Text
	end

	local function isLocked(index: number): boolean
		return find(index, "LockBadge") ~= nil
	end

	local function height(index: number): number
		return playerGui:FindFirstChild(`Offer{index}`, true).Size.Y.Offset
	end

	local function offers(): any
		return Market.Offers(Market.Slot(world.now))
	end

	local function firstInStock(skip: number?): number
		for _, offer in offers() do
			if offer.Stock > 0 and offer.Index ~= skip then
				return offer.Index
			end
		end
		return 1
	end

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
		local Signal = world:require("ReplicatedStorage.Packages.Signal")
		Eggs = world:require("ReplicatedStorage.Config.Eggs")
		Market = world:require("ReplicatedStorage.Rules.Market")
		NumberFormat = world:require("ReplicatedStorage.Utils.NumberFormat")
		local player = world:newPlayer({ Name = "Tester", DisplayName = "Tester" })
		player.GetAttributeChangedSignal = function()
			return Signal.new()
		end
		world.Players.LocalPlayer = player
		data = {
			Cash = 0,
			IncomeAt = world.now,
			Board = { "PlainClack" },
			Upgrades = { Luck = 0, Speed = 0, Slots = 0, Income = 0, Walls = 0, LockTime = 0, Golden = 0 },
			HeldEgg = "",
			PlacedEggs = {},
			Market = { Slot = 0, Bought = {} },
		}
		fired = {}
		toasts = {}
		closed = {}
		observers = {}
		world:packets().MarketBuy.Fire = function(_packet: any, index: number)
			table.insert(fired, index)
			return true
		end
		local stall = world:newInstance("Model")
		stall.Name = "Market"
		stall.Parent = world.workspace
		local counter = world:newPart("Counter", 0, 3, 0)
		counter.Position = roblox.Vector3.new(0, 3, 0)
		counter.Parent = stall
		local character = world:spawnCharacter(player, 0, 3, 2)
		character.HumanoidRootPart.Position = roblox.Vector3.new(0, 3, 2)
		playerGui = world:newInstance("Folder")
		context = {
			Controllers = {
				DataController = {
					Get = function(_self: any, path: { any }?)
						return lookup(path or {})
					end,
					Observe = function(_self: any, path: { any }, callback: any)
						table.insert(observers, { Path = path, Callback = callback })
						callback(lookup(path))
						return function() end
					end,
				},
			},
			PlayerGui = playerGui,
			Open = function() end,
			Close = function(name: string)
				table.insert(closed, name)
			end,
			IsOpen = function()
				return false
			end,
			Toast = function(text: string, kind: string)
				table.insert(toasts, { Text = text, Kind = kind })
			end,
		}
	end)

	afterEach(function()
		if screen then
			screen:Destroy()
			screen = nil
		end
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	it("lists one bar per egg in catalog order", function()
		open(1e9)
		local bars = {}
		for _, item in playerGui:GetDescendants() do
			if string.match(item.Name, "^Offer%d+$") then
				table.insert(bars, item)
			end
		end
		table.sort(bars, function(a: any, b: any)
			return a.LayoutOrder < b.LayoutOrder
		end)
		expect(#bars):toBe(#Eggs.Catalog)
		for position, egg in Eggs.Catalog do
			expect(bars[position].Name):toBe(`Offer{egg.Index}`)
			expect(find(egg.Index, "EggName").Text):toBe(egg.Name)
		end
	end)

	it("shows stock chips with the remaining count", function()
		open(1e9)
		for _, offer in offers() do
			local text = find(offer.Index, "Stock").Text.Text
			if offer.Stock > 0 then
				expect(text):toBe(`x{offer.Stock} Stock`)
			else
				expect(text):toBe("NO STOCK")
			end
		end
	end)

	it("shows NO STOCK once an egg is sold out", function()
		local index = firstInStock()
		open(1e9, nil, { [tostring(index)] = offers()[index].Stock })
		expect(find(index, "Stock").Text.Text):toBe("NO STOCK")
	end)

	it("counts the stock chip down after a purchase is recorded", function()
		open(1e9)
		local index = firstInStock()
		local stock = offers()[index].Stock
		data.Market = { Slot = Market.Slot(world.now), Bought = { [tostring(index)] = 1 } }
		for _, observer in observers do
			if observer.Path[1] == "Market" then
				observer.Callback(data.Market)
			end
		end
		world.task.wait(0.4)
		expect(find(index, "Stock").Text.Text):toBe(`x{stock - 1} Stock`)
	end)

	it("shows an unlocked price button when affordable", function()
		local index = firstInStock()
		local price = Market.Price(offers()[index], 0)
		open(price)
		expect(buyText(index)):toBe(NumberFormat.Compact(price))
		expect(isLocked(index)):toBe(false)
	end)

	it("locks the price button when unaffordable", function()
		local index = firstInStock()
		local price = Market.Price(offers()[index], 0)
		open(price - 1)
		expect(buyText(index)):toBe(NumberFormat.Compact(price))
		expect(isLocked(index)):toBe(true)
	end)

	it("locks the price button when the egg has no stock", function()
		local index = firstInStock()
		open(1e9, nil, { [tostring(index)] = offers()[index].Stock })
		expect(isLocked(index)):toBe(true)
	end)

	it("shows PLACE YOUR EGG FIRST on every in-stock bar while holding an egg", function()
		open(1e9, "Linear")
		for _, offer in offers() do
			if offer.Stock > 0 then
				expect(buyText(offer.Index)):toBe("PLACE YOUR EGG FIRST")
				expect(isLocked(offer.Index)):toBe(false)
			end
		end
	end)

	it("shows BASE FULL on every in-stock bar when the base holds the maximum eggs", function()
		local index = firstInStock()
		open(1e9, nil, nil, Eggs.PlacedCap)
		expect(buyText(index)):toBe("BASE FULL")
		expect(isLocked(index)):toBe(false)
	end)

	it("prefers the holding message over the full message", function()
		local index = firstInStock()
		open(1e9, "Linear", nil, Eggs.PlacedCap)
		expect(buyText(index)):toBe("PLACE YOUR EGG FIRST")
	end)

	it("returns to the price once the egg is placed", function()
		local index = firstInStock()
		local price = Market.Price(offers()[index], 0)
		open(1e9, "Linear")
		expect(buyText(index)):toBe("PLACE YOUR EGG FIRST")
		data.HeldEgg = ""
		for _, observer in observers do
			if observer.Path[1] == "HeldEgg" then
				observer.Callback(data.HeldEgg)
			end
		end
		expect(buyText(index)):toBe(NumberFormat.Compact(price))
	end)

	it("has no egg bag label or inventory text", function()
		open(1e9)
		for _, item in playerGui:GetDescendants() do
			if item.ClassName == "TextLabel" then
				expect(string.find(string.lower(item.Text), "bag", 1, true)):toBeNil()
			end
		end
	end)

	it("expands one bar at a time and collapses on a second tap", function()
		open(1e9)
		expect(height(1)):toBe(barHeight)
		press(find(1, "Tap"))
		world.task.wait(0.3)
		expect(height(1) > barHeight):toBe(true)
		press(find(2, "Tap"))
		world.task.wait(0.3)
		expect(height(1)):toBe(barHeight)
		expect(height(2) > barHeight):toBe(true)
		press(find(2, "Tap"))
		world.task.wait(0.3)
		expect(height(2)):toBe(barHeight)
	end)

	it("sends the offer index when the price button is pressed", function()
		open(1e9)
		local target = firstInStock(1)
		press(find(target, "Buy"))
		world.task.wait(0.2)
		expect(toasts[1].Kind):toBe("Good")
		expect(fired):toEqual({ target })
		expect(height(target)):toBe(barHeight)
	end)

	it("closes the shop right after a successful purchase", function()
		open(1e9)
		press(find(firstInStock(), "Buy"))
		world.task.wait(0.2)
		expect(closed):toEqual({ "Market" })
	end)

	it("keeps the shop open when the purchase fails", function()
		open(1e9)
		world:packets().MarketBuy.Fire = function()
			return false
		end
		press(find(firstInStock(), "Buy"))
		world.task.wait(0.2)
		expect(closed):toEqual({})
		expect(toasts[1].Kind):toBe("Bad")
	end)

	it("does not send a purchase while holding an egg", function()
		open(1e9, "Linear")
		press(find(firstInStock(), "Buy"))
		world.task.wait(0.2)
		expect(fired):toEqual({})
		expect(closed):toEqual({})
		expect(toasts[1].Kind):toBe("Bad")
	end)

	it("does not send a purchase when the base is full", function()
		open(1e9, nil, nil, Eggs.PlacedCap)
		press(find(firstInStock(), "Buy"))
		world.task.wait(0.2)
		expect(fired):toEqual({})
		expect(toasts[1].Kind):toBe("Bad")
	end)

	local function recordsNamed(record: any, name: string, out: { any }): { any }
		if record.name == name then
			table.insert(out, record)
		end
		for _, child in record.children do
			recordsNamed(child, name, out)
		end
		return out
	end

	local function childNamed(record: any, name: string): any
		for _, child in record.children do
			if child.name == name then
				return child
			end
		end
		error(`no record {name}`)
	end

	it("keeps the coin icon left of the price text without overlap for every price size", function()
		open(1e9)
		local prices = { "250", "2.5K", "25K", "250K", "2.5M", "25M", "999.9M" }
		local gui = playerGui:FindFirstChild("Offer1", true)
		while gui and gui.ClassName ~= "ScreenGui" do
			gui = gui.Parent
		end
		local checked = 0
		for _, price in prices do
			for index = 1, 5 do
				find(index, "Buy").Face:FindFirstChild("Text", true).Text = price
			end
			local laidOut = Layout.Gui(gui, roblox.Vector2.new(1280, 720))
			for _, top in laidOut.children do
				for _, buy in recordsNamed(top, "Buy", {}) do
					local face = childNamed(buy, "Face")
					local holder = childNamed(face, "Price")
					local icon = childNamed(holder, "Icon")
					local text = childNamed(holder, "Text")
					expect(icon.w):toBeGreaterThan(0)
					expect(text.w):toBeGreaterThan(0)
					expect(icon.x + icon.w <= text.x):toBe(true)
					expect(text.x - (icon.x + icon.w) < 12):toBe(true)
					expect(math.abs((icon.y + icon.h / 2) - (text.y + text.h / 2)) < 1.5):toBe(true)
					local pairCenter = (icon.x + text.x + text.w) / 2
					expect(math.abs(pairCenter - holder.w / 2) < 1.5):toBe(true)
					expect(icon.x >= 0):toBe(true)
					expect(text.x + text.w <= holder.w):toBe(true)
					expect(holder.w <= face.w):toBe(true)
					checked += 1
				end
			end
		end
		expect(checked):toBe(#prices * 5)
	end)

	it("does not treat the empty-text price button as an icon-only button", function()
		open(1e9)
		local icon = find(1, "Buy").Face:FindFirstChild("Icon", true)
		expect(icon.Size.X.Offset):toBeGreaterThan(0)
		expect(icon.Size.X.Offset):toBe(icon.Size.Y.Offset)
		expect(icon.Parent.Name):toBe("Price")
	end)
end)
