local roblox = require("@lune/roblox")
local H = require("../harness/Harness")
local S = require("../support")

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

local startTime = 1700000250
local slotEnd = 1700000400

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
	local world, Market, Keys, GameConfig, player, data

	beforeEach(function()
		world = H.newWorld({ Time = startTime })
		world:boot({ "KeyboardService", "MarketService" })
		Market = world:require("ReplicatedStorage.Rules.Market")
		Keys = world:require("ReplicatedStorage.Config.Keys")
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

	local function buy(index: any): any
		return world:invoke("MarketBuy", player, index)
	end

	it("buys an offer: cash, key, discovery and stock all update", function()
		local offer = offers()[1]
		data.Cash = offer.Price + 100
		expect(buy(1)):toBe(true)
		expect(data.Cash):toBe(100)
		expect(data.Inventory[offer.KeyId]):toBe(1)
		expect(data.Discovered[offer.KeyId]):toBe(1)
		expect(data.Market.Slot):toBe(Market.Slot(world.now))
		expect(data.Market.Bought["1"]):toBe(1)
		expect((world.saves[player] or 0) > 0):toBe(true)
	end)

	it("places a bought key on the board when auto place is on", function()
		data.Settings.AutoPlace = true
		local offer = offers()[2]
		expect(buy(2)):toBe(true)
		expect(S.totals(data)[offer.KeyId]):toBe(1)
		expect(data.Board[1]):toBe(offer.KeyId)
	end)

	it("rejects a purchase without enough cash and changes nothing", function()
		local offer = offers()[1]
		data.Cash = offer.Price - 1
		local before = S.snapshot(data)
		expect(buy(1)):toBe(false)
		expect(data.Cash):toBe(before.Cash)
		expect(data.Inventory):toEqual(before.Inventory)
		expect(data.Discovered):toEqual(before.Discovered)
		expect(data.Market.Bought["1"]):toBeNil()
	end)

	it("accepts an exact-cost purchase", function()
		local offer = offers()[3]
		data.Cash = offer.Price
		expect(buy(3)):toBe(true)
		expect(data.Cash):toBe(0)
	end)

	it("sells out after the stock is bought", function()
		local offer = offers()[4]
		for count = 1, offer.Stock do
			expect(buy(4)):toBe(true)
			expect(data.Market.Bought["4"]):toBe(count)
		end
		local cash = data.Cash
		expect(buy(4)):toBe(false)
		expect(data.Cash):toBe(cash)
		expect(data.Inventory[offer.KeyId]):toBe(offer.Stock)
		expect(data.Market.Bought["4"]):toBe(offer.Stock)
	end)

	it("keeps stock per offer", function()
		local first, second = offers()[1], offers()[2]
		for _ = 1, first.Stock do
			expect(buy(1)):toBe(true)
		end
		expect(buy(1)):toBe(false)
		expect(buy(2)):toBe(true)
		expect(data.Market.Bought["2"]):toBe(1)
		expect(second.Stock >= 1):toBe(true)
	end)

	it("rejects invalid offer indexes", function()
		local before = S.snapshot(data)
		for _, index in { 0, -1, 7, 1.5, 100, "1", true, S.nan(), math.huge } do
			expect(buy(index)):toBe(false)
		end
		expect(buy(nil)):toBe(false)
		expect(data.Cash):toBe(before.Cash)
		expect(data.Inventory):toEqual(before.Inventory)
		expect(data.Market):toEqual(before.Market)
	end)

	it("fails for players without data", function()
		local stranger = world:newPlayer()
		world:spawnCharacter(stranger, 0, 3, -6)
		expect(world:invoke("MarketBuy", stranger, 1)):toBe(false)
	end)

	it("resets bought counts when the slot rolls over", function()
		local offer = offers()[1]
		for _ = 1, offer.Stock do
			expect(buy(1)):toBe(true)
		end
		expect(buy(1)):toBe(false)
		world:advance(300)
		local nextOffer = offers()[1]
		expect(buy(1)):toBe(true)
		expect(data.Market.Slot):toBe(Market.Slot(world.now))
		expect(data.Market.Bought):toEqual({ ["1"] = 1 })
		expect(nextOffer.KeyId ~= nil):toBe(true)
	end)

	it("prices and grants from the offers of the current slot after a rollover", function()
		local oldSlot = Market.Slot(world.now)
		world:advance(300)
		expect(Market.Slot(world.now)):toBe(oldSlot + 1)
		local fresh = offers()[5]
		data.Cash = fresh.Price + 7
		expect(buy(5)):toBe(true)
		expect(data.Cash):toBe(7)
		expect(data.Inventory[fresh.KeyId]):toBe(1)
	end)

	it("refuses purchases right at the slot boundary", function()
		world:setTime(slotEnd - 0.5)
		expect(buy(1)):toBe(false)
		world:setTime(slotEnd + 0.5)
		expect(buy(1)):toBe(false)
		expect(data.Inventory):toEqual({})
		world:setTime(slotEnd + 5)
		expect(buy(1)):toBe(true)
	end)

	it("rejects players who are too far from the counter", function()
		local range = GameConfig.Market.PromptRange + 6
		local counter = world.workspace:FindFirstChild("Market").Counter
		local position = counter.CFrame.Position
		world:moveCharacter(player, position.X, 3, position.Z + range + 5)
		expect(buy(1)):toBe(false)
		expect(data.Inventory):toEqual({})
		world:moveCharacter(player, position.X, position.Y, position.Z + range - 1)
		expect(buy(1)):toBe(true)
	end)

	it("rejects players without a character", function()
		local stranger, strangerData = world:join(nil, { Cash = 100000000 })
		expect(world:invoke("MarketBuy", stranger, 1)):toBe(false)
		expect(strangerData.Inventory):toEqual({})
	end)

	it("settles earned income before checking the price", function()
		local offer = offers()[1]
		data.Cash = 0
		data.Board = S.fill("PlainClack", 10)
		local seconds = math.ceil(offer.Price / 10) + 10
		data.IncomeAt = world.now - seconds
		expect(buy(1)):toBe(true)
		expect(data.Cash):toBe(seconds * 10 - offer.Price)
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
	local world, Market, Keys, GameConfig

	beforeEach(function()
		world = H.newWorld({ Time = startTime })
		Market = world:require("ReplicatedStorage.Rules.Market")
		Keys = world:require("ReplicatedStorage.Config.Keys")
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
	end)

	afterEach(function()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	it("builds a placeholder stall at the map center with a counter and prompt", function()
		world:boot({ "KeyboardService", "MarketService" })
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
		expect(prompt.ActionText):toBe("Open Key Market")
		expect(prompt.ObjectText):toBe("Shop")
		expect(prompt.HoldDuration):toBe(0)
		expect(prompt.MaxActivationDistance):toBe(GameConfig.Market.PromptRange)
		expect(prompt.RequiresLineOfSight):toBe(false)
	end)

	it("keeps the stall small, anchored and clear of the spawn", function()
		world:boot({ "KeyboardService", "MarketService" })
		local stall = world.workspace:FindFirstChild("Market")
		expect(countParts(stall) < 60):toBe(true)
		for _, item in stall:GetDescendants() do
			if item:IsA("BasePart") then
				expect(item.Anchored):toBe(true)
				expect(item.CFrame.Position.Z + item.Size.Z / 2 < -4):toBe(true)
				expect(item.CFrame.Position.Y - item.Size.Y / 2 > -0.01):toBe(true)
			end
		end
	end)

	it("has striped awning, a KEY MARKET sign and a display cap per offer", function()
		world:boot({ "KeyboardService", "MarketService" })
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
		expect(gui.Text.Text):toBe("KEY MARKET")
		expect(gui.Text.Font == roblox.Enum.Font.FredokaOne):toBe(true)
		for index = 1, GameConfig.Market.OfferCount do
			expect(stall:FindFirstChild(`Cap{index}`) ~= nil):toBe(true)
		end
	end)

	it("colors the display caps by the current offers and repaints on a new slot", function()
		world:boot({ "KeyboardService", "MarketService" })
		local stall = world.workspace:FindFirstChild("Market")
		local function check()
			for index, offer in Market.Offers(Market.Slot(world.now)) do
				local rarity = Keys.GetRarity(Keys.ById[offer.KeyId])
				expect(stall:FindFirstChild(`Cap{index}`).Color):toBe(rarity.Color)
			end
		end
		check()
		world:advance(300)
		check()
		world:advance(300 * 40)
		check()
	end)

	it("pings the player to open the market when the prompt is triggered", function()
		world:boot({ "KeyboardService", "MarketService" })
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
		local cap = world:newPart("Cap1", 50, 2.5, 50)
		cap.Parent = authored
		authored.Parent = world.workspace
		world:boot({ "KeyboardService", "MarketService" })
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
		expect(cap.Color):toBe(Keys.GetRarity(Keys.ById[first.KeyId]).Color)
	end)

	it("measures distance from an authored counter", function()
		local authored = world:newInstance("Model")
		authored.Name = "Market"
		local counter = world:newPart("Counter", 50, 1, 50)
		counter.Parent = authored
		authored.Parent = world.workspace
		world:boot({ "KeyboardService", "MarketService" })
		local player, data = world:join(nil, { Cash = 100000000, Settings = { AutoPlace = false } })
		world:spawnCharacter(player, 0, 3, -6)
		expect(world:invoke("MarketBuy", player, 1)):toBe(false)
		world:moveCharacter(player, 52, 3, 50)
		expect(world:invoke("MarketBuy", player, 1)):toBe(true)
		expect(next(data.Inventory) ~= nil):toBe(true)
	end)

	it("builds a differently named placeholder when workspace.Market is unusable", function()
		local broken = world:newInstance("Model")
		broken.Name = "Market"
		broken.Parent = world.workspace
		world:boot({ "KeyboardService", "MarketService" })
		expect(#world.warnings > 0):toBe(true)
		local fallback = world.workspace:FindFirstChild("MarketPlaceholder")
		expect(fallback ~= nil):toBe(true)
		expect(fallback.Counter:FindFirstChild("MarketPrompt") ~= nil):toBe(true)
	end)
end)
