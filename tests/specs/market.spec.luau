local roblox = require("@lune/roblox")
local H = require("../harness/Harness")

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

local startTime = 1700000250
local slotEnd = 1700000400
local bootList = { "KeyboardService", "EggService", "MarketService" }

local function countParts(instance: any): number
	local total = 0
	for _, item in instance:GetDescendants() do
		if item:IsA("BasePart") then
			total += 1
		end
	end
	return total
end

describe("MarketService", function()
	local world, Market, Eggs, GameConfig, player, data

	beforeEach(function()
		world = H.newWorld({ Time = startTime })
		world:boot(bootList)
		Market = world:require("ReplicatedStorage.Rules.Market")
		Eggs = world:require("ReplicatedStorage.Config.Eggs")
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		player, data = world:join(nil, { Cash = 100000000, Settings = { AutoPlace = false } })
		world:spawnCharacter(player, 0, 3, -6)
	end)

	afterEach(function()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	local function offers(): any
		return Market.Offers(Market.Slot(world.now))
	end

	local function priceOf(index: number): number
		return Market.Price(offers()[index], 0)
	end

	local function buy(index: any): any
		return world:invoke("MarketBuy", player, index)
	end

	it("buys an egg: cash and stock update, the egg is held and nothing is placed", function()
		local price = priceOf(1)
		data.Cash = price + 100
		expect(buy(1)):toBe(true)
		expect(data.Cash):toBe(100)
		expect(data.HeldEgg):toBe("Linear")
		expect(data.EggInventory):toEqual({})
		expect(data.PlacedEggs):toEqual({})
		expect(data.Market.Slot):toBe(Market.Slot(world.now))
		expect(data.Market.Bought["1"]):toBe(1)
		expect((world.saves[player] or 0) > 0):toBe(true)
	end)

	it("deducts the price once and equips the egg tool", function()
		local price = priceOf(2)
		data.Cash = price * 2
		expect(buy(2)):toBe(true)
		expect(data.Cash):toBe(price)
		expect(data.Market.Bought["2"]):toBe(1)
		local character = player.Character
		local tool = character:FindFirstChildOfClass("Tool")
		expect(tool ~= nil):toBe(true)
		expect(tool.Name):toBe("Tactile Egg")
		expect(tool:GetAttribute("EggId")):toBe("Tactile")
		expect(#player:FindFirstChild("Backpack"):GetChildren()):toBe(0)
	end)

	it("rejects buying while an egg is still held and changes nothing", function()
		expect(buy(2)):toBe(true)
		local cash = data.Cash
		expect(buy(1)):toBe(false)
		expect(buy(2)):toBe(false)
		expect(data.Cash):toBe(cash)
		expect(data.HeldEgg):toBe("Tactile")
		expect(data.Market.Bought["1"]):toBeNil()
		expect(data.Market.Bought["2"]):toBe(1)
	end)

	it("allows another purchase once the held egg is placed", function()
		expect(buy(1)):toBe(true)
		expect(world:invoke("PlaceEgg", player, "Linear", 10, 10)):toBe(true)
		expect(data.HeldEgg):toBe("")
		expect(buy(2)):toBe(true)
		expect(data.HeldEgg):toBe("Tactile")
		expect(#data.PlacedEggs):toBe(1)
	end)

	it("rejects buying when three eggs are already placed and changes nothing", function()
		for index = 1, Eggs.PlacedCap do
			table.insert(data.PlacedEggs, { Id = "Linear", ReadyAt = 1, X = index * 8, Z = 10 })
		end
		local cash = data.Cash
		expect(buy(1)):toBe(false)
		expect(data.Cash):toBe(cash)
		expect(data.HeldEgg):toBe("")
		expect(data.Market.Bought["1"]):toBeNil()
	end)

	it("rejects a purchase without enough cash and changes nothing", function()
		data.Cash = priceOf(1) - 1
		expect(buy(1)):toBe(false)
		expect(data.Cash):toBe(priceOf(1) - 1)
		expect(data.EggInventory):toEqual({})
		expect(data.Market.Bought["1"]):toBeNil()
	end)

	it("accepts an exact-cost purchase", function()
		data.Cash = priceOf(2)
		expect(buy(2)):toBe(true)
		expect(data.Cash):toBe(0)
	end)

	it("keeps egg prices fixed when the board earns more", function()
		local basePrice = Market.Price(offers()[1], 0)
		for index = 1, GameConfig.BaseSlots do
			data.Board[index] = "PlainClack"
		end
		local rate = Market.BaseRate(data.Board, data.Upgrades)
		local price = Market.Price(offers()[1], rate)
		expect(price):toBe(basePrice)
		expect(price):toBe(Eggs.ById.Linear.MinPrice)
		data.Cash = price + 5
		data.IncomeAt = world.now
		expect(buy(1)):toBe(true)
		expect(data.Cash):toBe(5)
	end)

	it("sells out after the stock is bought", function()
		local offer = offers()[1]
		for count = 1, offer.Stock do
			expect(buy(1)):toBe(true)
			expect(data.Market.Bought["1"]):toBe(count)
			data.HeldEgg = ""
		end
		local cash = data.Cash
		expect(buy(1)):toBe(false)
		expect(data.Cash):toBe(cash)
		expect(data.Market.Bought["1"]):toBe(offer.Stock)
	end)

	it("keeps stock per offer", function()
		local first = offers()[1]
		data.Market = { Slot = Market.Slot(world.now), Bought = { ["1"] = first.Stock } }
		expect(buy(1)):toBe(false)
		expect(buy(2)):toBe(true)
		expect(data.Market.Bought["2"]):toBe(1)
	end)

	it("rejects invalid offer indexes", function()
		local cash = data.Cash
		for _, index in { 0, -1, 7, 1.5, 100, "1", true, 0 / 0, math.huge } do
			expect(buy(index)):toBe(false)
		end
		expect(buy(nil)):toBe(false)
		expect(data.Cash):toBe(cash)
		expect(data.EggInventory):toEqual({})
	end)

	it("rejects an index with no stock this restock", function()
		local empty: number? = nil
		for _, offer in offers() do
			if offer.Stock == 0 then
				empty = offer.Index
				break
			end
		end
		if empty then
			expect(buy(empty)):toBe(false)
			expect(data.EggInventory):toEqual({})
		end
		expect(buy(#Eggs.Catalog + 1)):toBe(false)
	end)

	it("fails for players without data", function()
		local stranger = world:newPlayer()
		world:spawnCharacter(stranger, 0, 3, -6)
		expect(world:invoke("MarketBuy", stranger, 1)):toBe(false)
	end)

	it("resets bought counts when the slot rolls over", function()
		local offer = offers()[1]
		data.Market = { Slot = Market.Slot(world.now), Bought = { ["1"] = offer.Stock } }
		expect(buy(1)):toBe(false)
		world:advance(300)
		expect(buy(1)):toBe(true)
		expect(data.Market.Slot):toBe(Market.Slot(world.now))
		expect(data.Market.Bought):toEqual({ ["1"] = 1 })
	end)

	it("refuses purchases right at the slot boundary", function()
		world:setTime(slotEnd - 0.5)
		expect(buy(1)):toBe(false)
		world:setTime(slotEnd + 0.5)
		expect(buy(1)):toBe(false)
		expect(data.EggInventory):toEqual({})
		world:setTime(slotEnd + 5)
		expect(buy(1)):toBe(true)
	end)

	it("rejects players who are too far from the counter", function()
		local range = GameConfig.Market.PromptRange + 6
		local counter = world.workspace:FindFirstChild("Market").Counter
		local position = counter.CFrame.Position
		world:moveCharacter(player, position.X, 3, position.Z + range + 5)
		expect(buy(1)):toBe(false)
		expect(data.EggInventory):toEqual({})
		world:moveCharacter(player, position.X, position.Y, position.Z + range - 1)
		expect(buy(1)):toBe(true)
	end)

	it("rejects players without a character", function()
		local stranger, strangerData = world:join(nil, { Cash = 100000000 })
		expect(world:invoke("MarketBuy", stranger, 1)):toBe(false)
		expect(strangerData.EggInventory):toEqual({})
	end)

	it("settles earned income before checking the price", function()
		data.Cash = 0
		data.Board = {}
		for index = 1, GameConfig.BaseSlots do
			data.Board[index] = "PlainClack"
		end
		local rate = Market.BaseRate(data.Board, data.Upgrades)
		local price = Market.Price(offers()[1], rate)
		local seconds = math.ceil(price / rate) + 10
		data.IncomeAt = world.now - seconds
		expect(buy(1)):toBe(true)
		expect(data.Cash):toBe(seconds * rate - price)
		expect(data.IncomeAt):toBe(world.now)
	end)

	it("clears its packet handler on Destroy", function()
		local packet = world:packets().MarketBuy
		expect(packet.OnServerInvoke ~= nil):toBe(true)
		world:destroy()
		expect(packet.OnServerInvoke):toBeNil()
		expect(world.workspace:FindFirstChild("Market")):toBeNil()
	end)
end)

describe("Market stall", function()
	local world, Market, Eggs, GameConfig

	beforeEach(function()
		world = H.newWorld({ Time = startTime })
		Market = world:require("ReplicatedStorage.Rules.Market")
		Eggs = world:require("ReplicatedStorage.Config.Eggs")
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
	end)

	afterEach(function()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	it("builds a placeholder stall at the map center with a counter and prompt", function()
		world:boot({ "KeyboardService", "EggService", "MarketService" })
		local stall = world.workspace:FindFirstChild("Market")
		expect(stall ~= nil):toBe(true)
		expect(stall.ClassName):toBe("Model")
		local counter = stall:FindFirstChild("Counter")
		expect(counter:IsA("BasePart")):toBe(true)
		expect(stall.PrimaryPart == counter):toBe(true)
		local position = counter.CFrame.Position
		expect(math.abs(position.X) < 2):toBe(true)
		expect(position.Z < -8 and position.Z > -20):toBe(true)
		expect(position.Y - counter.Size.Y / 2):toBeCloseTo(0, 1e-6)
		local prompt = counter:FindFirstChild("MarketPrompt")
		expect(prompt.ClassName):toBe("ProximityPrompt")
		expect(prompt.ActionText):toBe("Open Egg Market")
		expect(prompt.ObjectText):toBe("Shop")
		expect(prompt.HoldDuration):toBe(0)
		expect(prompt.MaxActivationDistance):toBe(GameConfig.Market.PromptRange)
		expect(prompt.RequiresLineOfSight):toBe(false)
	end)

	it("keeps the stall small, anchored and clear of the spawn", function()
		world:boot({ "KeyboardService", "EggService", "MarketService" })
		local stall = world.workspace:FindFirstChild("Market")
		expect(countParts(stall) < 140):toBe(true)
		for _, item in stall:GetDescendants() do
			if item:IsA("BasePart") then
				expect(item.Anchored):toBe(true)
				expect(item.CFrame.Position.Z + item.Size.Z / 2 < -4):toBe(true)
				expect(item.CFrame.Position.Y - item.Size.Y / 2 > -0.01):toBe(true)
			end
		end
	end)

	it("has striped awning, an EGG MARKET sign and a display egg per tier", function()
		world:boot({ "KeyboardService", "EggService", "MarketService" })
		local stall = world.workspace:FindFirstChild("Market")
		local colors: { [any]: boolean } = {}
		local stripes = 0
		for _, item in stall:GetChildren() do
			if string.sub(item.Name, 1, 6) == "Awning" then
				stripes += 1
				colors[item.Color] = true
			end
		end
		expect(stripes >= 6):toBe(true)
		local distinct = 0
		for _ in colors do
			distinct += 1
		end
		expect(distinct):toBe(2)
		local gui = stall.SignBoard.SignGui
		expect(gui.Text.Text):toBe("EGG MARKET")
		expect(gui.Text.Font == roblox.Enum.Font.FredokaOne):toBe(true)
		for index = 1, #Eggs.Catalog do
			expect(stall:FindFirstChild(`Egg{index}`) ~= nil):toBe(true)
		end
	end)

	it("colors the display eggs by the current offers and repaints on a new slot", function()
		world:boot({ "KeyboardService", "EggService", "MarketService" })
		local stall = world.workspace:FindFirstChild("Market")
		local function check()
			local offers = Market.Offers(Market.Slot(world.now))
			for index = 1, #Eggs.Catalog do
				local display = stall:FindFirstChild(`Egg{index}`)
				local offer = offers[index]
				local inStock = offer ~= nil and offer.Stock > 0
				expect(display.Transparency):toBe(if inStock then 0 else 1)
				if inStock then
					expect(display.Color):toBe(Eggs.ById[offer.EggId].Color)
				end
			end
		end
		check()
		world:advance(300)
		check()
		world:advance(300 * 40)
		check()
	end)

	it("pings the player to open the market when the prompt is triggered", function()
		world:boot({ "KeyboardService", "EggService", "MarketService" })
		local player = world:join()
		local prompt = world.workspace:FindFirstChild("Market").Counter:FindFirstChild("MarketPrompt")
		expect(player:GetAttribute("OpenMarket")):toBeNil()
		prompt.Triggered:Fire(player)
		expect(player:GetAttribute("OpenMarket")):toBe(world.clock)
		world:advance(5)
		prompt.Triggered:Fire(player)
		expect(player:GetAttribute("OpenMarket")):toBe(world.clock)
	end)

	it("uses an authored workspace.Market and adds the prompt to its Counter", function()
		local authored = world:newInstance("Model")
		authored.Name = "Market"
		local counter = world:newPart("Counter", 50, 1, 50)
		counter.Size = roblox.Vector3.new(6, 2, 2)
		counter.Parent = authored
		local cap = world:newPart("Egg1", 50, 2.5, 50)
		cap.Parent = authored
		authored.Parent = world.workspace
		world:boot({ "KeyboardService", "EggService", "MarketService" })
		local count = 0
		for _, child in world.workspace:GetChildren() do
			if string.sub(child.Name, 1, 6) == "Market" then
				count += 1
			end
		end
		expect(count):toBe(1)
		expect(world.workspace:FindFirstChild("Market") == authored):toBe(true)
		expect(counter:FindFirstChild("MarketPrompt") ~= nil):toBe(true)
		expect(authored:FindFirstChild("Floor")):toBeNil()
		local first = Market.Offers(Market.Slot(world.now))[1]
		expect(cap.Color):toBe(Eggs.ById[first.EggId].Color)
	end)

	it("measures distance from an authored counter", function()
		local authored = world:newInstance("Model")
		authored.Name = "Market"
		local counter = world:newPart("Counter", 50, 1, 50)
		counter.Parent = authored
		authored.Parent = world.workspace
		world:boot({ "KeyboardService", "EggService", "MarketService" })
		local player, data = world:join(nil, { Cash = 100000000, Settings = { AutoPlace = false } })
		world:spawnCharacter(player, 0, 3, -6)
		expect(world:invoke("MarketBuy", player, 1)):toBe(false)
		world:moveCharacter(player, 52, 3, 50)
		expect(world:invoke("MarketBuy", player, 1)):toBe(true)
		expect(data.HeldEgg):toBe("Linear")
	end)

	it("builds a differently named placeholder when workspace.Market is unusable", function()
		local broken = world:newInstance("Model")
		broken.Name = "Market"
		broken.Parent = world.workspace
		world:boot({ "KeyboardService", "EggService", "MarketService" })
		expect(#world.warnings > 0):toBe(true)
		local fallback = world.workspace:FindFirstChild("MarketPlaceholder")
		expect(fallback ~= nil):toBe(true)
		expect(fallback.Counter:FindFirstChild("MarketPrompt") ~= nil):toBe(true)
	end)
end)
