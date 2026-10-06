local H = require("../harness/Harness")
local roblox = require("@lune/roblox")
local Enum = roblox.Enum

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

local screens = "StarterPlayer.StarterPlayerScripts.Controllers.UIController"

local function press(button: any)
	button.Activated:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
end

describe("UpgradeCost", function()
	local world, Upgrades, UpgradeCost

	beforeEach(function()
		world = H.newWorld()
		Upgrades = world:require("ReplicatedStorage.Config.Upgrades")
		UpgradeCost = world:require("ReplicatedStorage.Rules.UpgradeCost")
	end)

	it("sums per-level costs for Total", function()
		local luck = Upgrades.ById.Luck
		expect(UpgradeCost.Total(luck, 0, 0)):toBe(0)
		expect(UpgradeCost.Total(luck, 0, 1)):toBe(Upgrades.Cost(luck, 0))
		local expected = 0
		for level = 3, 12 do
			expected += Upgrades.Cost(luck, level)
		end
		expect(UpgradeCost.Total(luck, 3, 10)):toBe(expected)
	end)

	it("caps Total at the max level", function()
		local speed = Upgrades.ById.Speed
		local expected = 0
		for level = 8, speed.MaxLevel - 1 do
			expected += Upgrades.Cost(speed, level)
		end
		expect(UpgradeCost.Total(speed, 8, 10)):toBe(expected)
		expect(UpgradeCost.Total(speed, speed.MaxLevel, 5)):toBe(0)
	end)

	it("counts x1 and x10 purchases when cash is plentiful", function()
		local luck = Upgrades.ById.Luck
		expect(UpgradeCost.Affordable(luck, 0, 1e15, 1)):toBe(1)
		expect(UpgradeCost.Affordable(luck, 0, 1e15, 10)):toBe(10)
	end)

	it("treats want 0 as unlimited but capped at the max level", function()
		local luck = Upgrades.ById.Luck
		expect(UpgradeCost.Affordable(luck, 0, 1e15, 0)):toBe(luck.MaxLevel)
		expect(UpgradeCost.Affordable(luck, 70, 1e15, 0)):toBe(luck.MaxLevel - 70)
		expect(UpgradeCost.Affordable(luck, 70, 1e15, 10)):toBe(luck.MaxLevel - 70)
		expect(UpgradeCost.Affordable(luck, luck.MaxLevel, 1e15, 0)):toBe(0)
	end)

	it("buys only what the cash covers", function()
		local luck = Upgrades.ById.Luck
		local three = UpgradeCost.Total(luck, 0, 3)
		expect(UpgradeCost.Affordable(luck, 0, three, 10)):toBe(3)
		expect(UpgradeCost.Affordable(luck, 0, three - 1, 10)):toBe(2)
		expect(UpgradeCost.Affordable(luck, 0, three, 0)):toBe(3)
		expect(UpgradeCost.Affordable(luck, 0, 99, 0)):toBe(0)
		expect(UpgradeCost.Affordable(luck, 0, 0, 1)):toBe(0)
	end)
end)

describe("UpgradeService bulk buy", function()
	local world, Upgrades, UpgradeCost

	beforeEach(function()
		world = H.newWorld()
		world:boot({ "KeyboardService", "UpgradeService" })
		Upgrades = world:require("ReplicatedStorage.Config.Upgrades")
		UpgradeCost = world:require("ReplicatedStorage.Rules.UpgradeCost")
	end)

	local function buy(player: any, id: any, amount: any)
		return world:invoke("BuyUpgrade", player, id, amount)
	end

	it("buys exactly ten levels and charges the exact total for x10", function()
		local luck = Upgrades.ById.Luck
		local player, data = world:join(nil, { Cash = 1e9, Upgrades = { Luck = 2 } })
		expect(buy(player, "Luck", 10)):toBe(true)
		expect(data.Upgrades.Luck):toBe(12)
		expect(data.Cash):toBe(1e9 - UpgradeCost.Total(luck, 2, 10))
	end)

	it("buys as many as affordable for MAX and leaves the remainder", function()
		local luck = Upgrades.ById.Luck
		local cash = UpgradeCost.Total(luck, 0, 7) + 5
		local player, data = world:join(nil, { Cash = cash })
		expect(buy(player, "Luck", 0)):toBe(true)
		expect(data.Upgrades.Luck):toBe(7)
		expect(data.Cash):toBe(5)
	end)

	it("stops MAX at the max level", function()
		local speed = Upgrades.ById.Speed
		local player, data = world:join(nil, { Cash = 1e15, Upgrades = { Speed = 4 } })
		expect(buy(player, "Speed", 0)):toBe(true)
		expect(data.Upgrades.Speed):toBe(speed.MaxLevel)
		expect(data.Cash):toBe(1e15 - UpgradeCost.Total(speed, 4, 100))
		expect(buy(player, "Speed", 0)):toBe(false)
	end)

	it("buys the affordable part of an x10 request", function()
		local luck = Upgrades.ById.Luck
		local cash = UpgradeCost.Total(luck, 0, 4)
		local player, data = world:join(nil, { Cash = cash })
		expect(buy(player, "Luck", 10)):toBe(true)
		expect(data.Upgrades.Luck):toBe(4)
		expect(data.Cash):toBe(0)
	end)

	it("rejects a request that affords no level and changes nothing", function()
		local player, data = world:join(nil, { Cash = 99, Tutorial = 2 })
		for _, amount in { 0, 1, 10 } do
			expect(buy(player, "Luck", amount)):toBe(false)
		end
		expect(data.Cash):toBe(99)
		expect(data.Upgrades.Luck):toBe(0)
		expect(data.Tutorial):toBe(2)
	end)

	it("rejects malformed amounts", function()
		local player, data = world:join(nil, { Cash = 1e9 })
		for _, amount in { -1, 1.5, "10", true, {}, 0 / 0 } do
			expect(buy(player, "Luck", amount)):toBe(false)
		end
		expect(buy(player, "Luck", nil)):toBe(false)
		expect(data.Upgrades.Luck):toBe(0)
		expect(data.Cash):toBe(1e9)
	end)

	it("announces one board change and advances the tutorial for a bulk Slots buy", function()
		local player, data = world:join(nil, { Cash = 1e9, Tutorial = 1 })
		local changed = 0
		world.registry.KeyboardService.BoardChanged:Connect(function()
			changed += 1
		end)
		expect(buy(player, "Slots", 10)):toBe(true)
		expect(changed):toBe(1)
		expect(data.Tutorial):toBe(3)
		expect(data.Upgrades.Slots):toBe(10)
	end)

	it("settles income before pricing a bulk buy", function()
		local luck = Upgrades.ById.Luck
		local player, data = world:join(nil, {
			Cash = 0,
			Board = { "PlainClack", "PlainClack", "PlainClack", "PlainClack", "PlainClack" },
			IncomeAt = world.now - 10,
		}, false)
		expect(UpgradeCost.Total(luck, 0, 1)):toBe(100)
		expect(buy(player, "Luck", 10)):toBe(false)
		expect(data.Cash):toBe(50)
	end)

	it("declares the amount and the raised rate limit on the packet", function()
		expect(world:packets().BuyUpgrade.OnServerInvoke).never:toBeNil()
	end)
end)

describe("Upgrades screen", function()
	local world, playerGui, context, player, data, gui, notify, Upgrades, UpgradeCost, NumberFormat
	local sent, serverLimit, hang, replyDelay

	local function compact(value: number): string
		return NumberFormat.Compact(value)
	end

	local function buyText(id: string): string
		local row = gui:FindFirstChild(id, true)
		return row:FindFirstChild("Buy", true):FindFirstChild("Text", true).Text
	end

	local function buyButton(id: string): any
		return gui:FindFirstChild(id, true):FindFirstChild("Buy", true)
	end

	local function isLocked(id: string): boolean
		return buyButton(id):FindFirstChild("LockBadge", true) ~= nil
	end

	local function openScreen(overrides: any)
		local Signal = world:require("ReplicatedStorage.Packages.Signal")
		player, data = world:join(nil, overrides)
		player.GetAttributeChangedSignal = function()
			return Signal.new()
		end
		world.Players.LocalPlayer = player
		world.tree.ReplicatedStorage.GetAttributeChangedSignal = function()
			return Signal.new()
		end
		local listeners: { { Path: { any }, Callback: any } } = {}
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
		notify = function()
			for _, listener in listeners do
				listener.Callback(lookup(listener.Path))
			end
		end
		local controllers = {
			DataController = {
				Get = function(_self: any, path: { any }?)
					return lookup(path or {})
				end,
				Observe = function(_self: any, path: { any }, callback: any)
					table.insert(listeners, { Path = path, Callback = callback })
					callback(lookup(path))
					return function() end
				end,
			},
		}
		playerGui = world:newInstance("Folder")
		context = {
			Controllers = controllers,
			PlayerGui = playerGui,
			Open = function() end,
			Close = function() end,
			IsOpen = function()
				return false
			end,
			Toast = function() end,
		}
		local screen = world:require(`{screens}.Screens.Upgrades`).new(context)
		screen:Open()
		world:flush()
		gui = playerGui:FindFirstChild("ThockUpgrades")
		return screen
	end

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
		world:boot({ "KeyboardService", "UpgradeService" })
		Upgrades = world:require("ReplicatedStorage.Config.Upgrades")
		UpgradeCost = world:require("ReplicatedStorage.Rules.UpgradeCost")
		NumberFormat = world:require("ReplicatedStorage.Utils.NumberFormat")
		local RateLimit = world:require("ReplicatedStorage.Utils.RateLimit")
		sent = {}
		serverLimit = RateLimit.new(10, 1)
		hang = false
		replyDelay = 0
		world:packets().BuyUpgrade.Fire = function(_packet: any, id: string, amount: number)
			table.insert(sent, { Id = id, Amount = amount, At = world.clock })
			if hang then
				coroutine.yield()
			end
			if not serverLimit:Allow(player) then
				world.task.wait(1.5)
				return false
			end
			if replyDelay > 0 then
				world.task.wait(replyDelay)
			end
			local ok = world:invoke("BuyUpgrade", player, id, amount)
			notify()
			return ok
		end
	end)

	local function click(id: string)
		press(buyButton(id))
	end

	it("shows the x1 price by default and the selected total per mode", function()
		openScreen({ Cash = 1e7, Upgrades = { Luck = 1 }, Board = {}, IncomeAt = world.now })
		local luck = Upgrades.ById.Luck
		expect(buyText("Luck")):toBe(`x1  {compact(UpgradeCost.Total(luck, 1, 1))}`)
		press(gui:FindFirstChild("x10", true))
		expect(buyText("Luck")):toBe(`x10  {compact(UpgradeCost.Total(luck, 1, 10))}`)
		press(gui:FindFirstChild("MAX", true))
		local count = UpgradeCost.Affordable(luck, 1, 1e7, 0)
		expect(buyText("Luck")):toBe(`x{count}  {compact(UpgradeCost.Total(luck, 1, count))}`)
		press(gui:FindFirstChild("x1", true))
		expect(buyText("Luck")):toBe(`x1  {compact(UpgradeCost.Total(luck, 1, 1))}`)
	end)

	it("shows a partial count and a gray lock when nothing is affordable", function()
		local luck = Upgrades.ById.Luck
		openScreen({ Cash = UpgradeCost.Total(luck, 0, 3), Board = {}, IncomeAt = world.now })
		press(gui:FindFirstChild("x10", true))
		expect(buyText("Luck")):toBe(`x3  {compact(UpgradeCost.Total(luck, 0, 3))}`)
		expect(isLocked("Luck")):toBe(false)
		expect(isLocked("Slots")):toBe(true)
		expect(buyText("Slots")):toBe(`x10  {compact(UpgradeCost.Total(Upgrades.ById.Slots, 0, 10))}`)
		press(gui:FindFirstChild("MAX", true))
		expect(buyText("Slots")):toBe(`x1  {compact(UpgradeCost.Total(Upgrades.ById.Slots, 0, 1))}`)
	end)

	it("caps the shown amount at the remaining levels and shows MAX at the cap", function()
		local walls = Upgrades.ById.Walls
		openScreen({
			Cash = 1e15,
			Upgrades = { Walls = 3, Speed = Upgrades.ById.Speed.MaxLevel },
			Board = {},
			IncomeAt = world.now,
		})
		press(gui:FindFirstChild("x10", true))
		expect(buyText("Walls")):toBe(`x2  {compact(UpgradeCost.Total(walls, 3, 2))}`)
		expect(buyText("Speed")):toBe("MAX")
		expect(isLocked("Speed")):toBe(false)
	end)

	it("applies the selected amount to the Defense rows too", function()
		openScreen({ Cash = 1e15, Board = {}, IncomeAt = world.now })
		press(gui:FindFirstChild("x10", true))
		local lockTime = Upgrades.ById.LockTime
		expect(buyText("LockTime")):toBe(`x10  {compact(UpgradeCost.Total(lockTime, 0, 10))}`)
		click("LockTime")
		world:flush()
		expect(data.Upgrades.LockTime):toBe(10)
		expect(data.Cash):toBe(1e15 - UpgradeCost.Total(lockTime, 0, 10))
	end)

	it("sends the selected amount and buys through the server", function()
		openScreen({ Cash = 1e9, Board = {}, IncomeAt = world.now })
		press(gui:FindFirstChild("x10", true))
		click("Luck")
		world:flush()
		expect(sent[1].Amount):toBe(10)
		expect(data.Upgrades.Luck):toBe(10)
		press(gui:FindFirstChild("MAX", true))
		click("Speed")
		world:flush()
		expect(sent[2].Amount):toBe(0)
		expect(data.Upgrades.Speed):toBe(Upgrades.ById.Speed.MaxLevel)
	end)

	it("keeps one request per row in flight and never sticks", function()
		openScreen({ Cash = 1e9, Board = {}, IncomeAt = world.now })
		replyDelay = 0.3
		for _ = 1, 5 do
			click("Luck")
		end
		world:advance(0.1)
		expect(#sent):toBe(1)
		world:advance(0.5)
		click("Luck")
		world:flush()
		expect(#sent):toBe(2)
	end)

	it("survives 30 clicks in one second with consistent server state", function()
		openScreen({ Cash = 1e12, Board = {}, IncomeAt = world.now })
		local ids = { "Luck", "Speed", "Slots", "Income", "Golden", "Walls", "LockTime" }
		for index = 1, 30 do
			click(ids[(index - 1) % #ids + 1])
			world:advance(1 / 30)
		end
		world:advance(0.1)
		expect(#sent <= 16):toBe(true)
		local expectedCash = 1e12
		local totalLevels = 0
		for _, upgrade in Upgrades.List do
			local level = data.Upgrades[upgrade.Id]
			expect(level <= upgrade.MaxLevel):toBe(true)
			expectedCash -= UpgradeCost.Total(upgrade, 0, level)
			totalLevels += level
		end
		expect(data.Cash):toBe(expectedCash)
		expect(totalLevels):toBe(#sent)
		for _, id in ids do
			expect(isLocked(id)):toBe(false)
		end
		local before = #sent
		click("Luck")
		world:flush()
		expect(#sent):toBe(before + 1)
	end)

	it("never lets rapid clicks hit the server rate limit", function()
		openScreen({ Cash = 1e15, Board = {}, IncomeAt = world.now })
		local drops = 0
		local RateLimit = world:require("ReplicatedStorage.Utils.RateLimit")
		local strict = RateLimit.new(10, 1)
		serverLimit = {
			Allow = function(_self: any, key: any)
				local allowed = strict:Allow(key)
				if not allowed then
					drops += 1
				end
				return allowed
			end,
		}
		for index = 1, 90 do
			click(index % 2 == 0 and "Luck" or "Income")
			world:advance(1 / 30)
		end
		world:advance(2)
		expect(drops):toBe(0)
		expect(#sent > 0):toBe(true)
	end)

	it("recovers immediately when the server drops a rate-limited request", function()
		openScreen({ Cash = 1e9, Board = {}, IncomeAt = world.now })
		serverLimit = {
			Allow = function()
				return false
			end,
		}
		click("Luck")
		world:advance(0.1)
		expect(#sent):toBe(1)
		click("Luck")
		expect(#sent):toBe(1)
		world:advance(1.5)
		serverLimit = {
			Allow = function()
				return true
			end,
		}
		click("Luck")
		world:flush()
		expect(#sent):toBe(2)
		expect(data.Upgrades.Luck):toBe(1)
		expect(data.Cash):toBe(1e9 - Upgrades.Cost(Upgrades.ById.Luck, 0))
	end)

	it("releases a button after the safety timeout even if the reply never comes", function()
		openScreen({ Cash = 1e9, Board = {}, IncomeAt = world.now })
		hang = true
		click("Luck")
		expect(#sent):toBe(1)
		world:advance(1.9)
		click("Luck")
		expect(#sent):toBe(1)
		world:advance(0.2)
		hang = false
		click("Luck")
		world:flush()
		expect(#sent):toBe(2)
		expect(data.Upgrades.Luck):toBe(1)
	end)

	it("ignores clicks on unaffordable and maxed rows without sending", function()
		openScreen({ Cash = 0, Upgrades = { Speed = Upgrades.ById.Speed.MaxLevel }, Board = {}, IncomeAt = world.now })
		click("Luck")
		click("Speed")
		world:flush()
		expect(#sent):toBe(0)
		expect(#world.errors):toBe(0)
	end)
end)
