local H = require("../harness/Harness")
local roblox = require("@lune/roblox")
local Layout = require("../../tools/ui_preview/Layout")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

local screens = "StarterPlayer.StarterPlayerScripts.Controllers.UIController"
local viewports = { roblox.Vector2.new(1280, 720), roblox.Vector2.new(844, 390) }

local progressPatterns: { [string]: string } = {
	Luck = "^x[%d.]+ > x[%d.]+$",
	Speed = "^[%d.]+/s > [%d.]+/s$",
	Slots = "^%d+ > %d+ slots$",
	Income = "^%+%d+%% > %+%d+%%$",
	Golden = "^%d+ > %d+ rolls$",
	Walls = "^%d+ > %d+ studs$",
	LockTime = "^%d+s > %d+s$",
}

local maxPatterns: { [string]: string } = {
	Luck = "^x[%d.]+  MAX$",
	Speed = "^[%d.]+/s  MAX$",
	Slots = "^%d+ slots  MAX$",
	Income = "^%+%d+%%  MAX$",
	Golden = "^%d+ rolls  MAX$",
	Walls = "^%d+ studs  MAX$",
	LockTime = "^%d+s  MAX$",
}

local function plain(text: string): string
	local stripped = string.gsub(text, "<[^>]+>", "")
	return stripped
end

local function isInside(item: any, name: string): boolean
	local node = item.Parent
	while node do
		if node.Name == name then
			return true
		end
		node = node.Parent
	end
	return false
end

local function press(button: any)
	button.Activated:Fire({ UserInputType = roblox.Enum.UserInputType.MouseButton1 })
end

local function overflowing(record: any, out: { string })
	local text = record.text
	if text and text.overflow then
		table.insert(out, record.name)
	end
	for _, child in record.children do
		overflowing(child, out)
	end
end

describe("Upgrades rows and starter offer", function()
	local world, playerGui, context, data, toasts, closed, Upgrades, Monetization, NumberFormat

	local function boot(name: string): any
		return world:require(`{screens}.Screens.{name}`).new(context)
	end

	local function textsOf(card: any): { any }
		local found = {}
		for _, item in card:GetDescendants() do
			if item.ClassName == "TextLabel" and item.Text ~= "" then
				if not isInside(item, "Buy") and not isInside(item, "Level") then
					table.insert(found, item)
				end
			end
		end
		return found
	end

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
		local Signal = world:require("ReplicatedStorage.Packages.Signal")
		local player = world:newPlayer({ Name = "Tester", DisplayName = "Tester" })
		player.GetAttributeChangedSignal = function()
			return Signal.new()
		end
		world.Players.LocalPlayer = player
		world.tree.ReplicatedStorage.GetAttributeChangedSignal = function()
			return Signal.new()
		end
		data = {
			Cash = 5000,
			IncomeAt = world.now,
			Board = { "PlainClack", "CreamyThock" },
			BoardTags = {},
			Inventory = {},
			Upgrades = { Luck = 1, Speed = 2, Slots = 1, Income = 3, Walls = 1, LockTime = 2, Golden = 2 },
			Boosts = { LuckUntil = 0, ClicksUntil = 0 },
			StarterPackBought = false,
		}
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
		toasts = {}
		closed = {}
		playerGui = world:newInstance("Folder")
		context = {
			Controllers = {
				DataController = {
					Get = function(_self: any, path: { any }?)
						return lookup(path or {})
					end,
					Observe = function(_self: any, path: { any }, callback: any)
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
			Toast = function(text: string)
				table.insert(toasts, text)
			end,
		}
		Upgrades = world:require("ReplicatedStorage.Config.Upgrades")
		Monetization = world:require("ReplicatedStorage.Config.Monetization")
		NumberFormat = world:require("ReplicatedStorage.Utils.NumberFormat")
	end)

	describe("Upgrades rows", function()
		local function openUpgrades()
			local screen = boot("Upgrades")
			screen:Open()
			world:flush()
			return screen, playerGui:FindFirstChild("ThockUpgrades")
		end

		it("shows exactly two text lines per upgrade in the name [effect] and current > next format", function()
			local _, gui = openUpgrades()
			for _, upgrade in Upgrades.List do
				local card = gui:FindFirstChild(upgrade.Id, true)
				local lines = textsOf(card)
				expect(#lines):toBe(2)
				local first = plain(card:FindFirstChild("Line1").Text)
				expect(string.find(first, upgrade.Name .. "  [", 1, true) == 1):toBe(true)
				expect(string.sub(first, -11)):toBe(" per level]")
				expect(string.find(first, "\n", 1, true)):toBe(nil)
				local second = card:FindFirstChild("Line2").Text
				expect(string.match(plain(second), progressPatterns[upgrade.Id]) ~= nil):toBe(true)
				expect(string.find(second, '<font color="#1FA64A">> ', 1, true) ~= nil):toBe(true)
			end
		end)

		it("formats specific values", function()
			local _, gui = openUpgrades()
			local function line2(id: string): string
				return plain(gui:FindFirstChild(id, true):FindFirstChild("Line2").Text)
			end
			expect(line2("Income")):toBe("+30% > +40%")
			expect(line2("Golden")):toBe("90 > 85 rolls")
			expect(line2("Slots")):toBe("4 > 5 slots")
			expect(plain(gui:FindFirstChild("Luck", true):FindFirstChild("Line1").Text)):toBe(
				"Lucky Charm  [+10% luck per level]"
			)
		end)

		it("shows current value and MAX at max level without a next value", function()
			for _, upgrade in Upgrades.List do
				data.Upgrades[upgrade.Id] = upgrade.MaxLevel
			end
			local _, gui = openUpgrades()
			for _, upgrade in Upgrades.List do
				local card = gui:FindFirstChild(upgrade.Id, true)
				expect(#textsOf(card)):toBe(2)
				local second = plain(card:FindFirstChild("Line2").Text)
				expect(string.match(second, maxPatterns[upgrade.Id]) ~= nil):toBe(true)
				expect(string.find(second, ">", 1, true)):toBe(nil)
			end
		end)

		for _, viewport in viewports do
			it(`never overflows text at {viewport.X}x{viewport.Y}`, function()
				local _, gui = openUpgrades()
				local laidOut = Layout.Gui(gui, viewport)
				local bad: { string } = {}
				for _, child in laidOut.children do
					overflowing(child, bad)
				end
				expect(bad):toEqual({})
			end)

			it(`never overflows maxed rows at {viewport.X}x{viewport.Y}`, function()
				for _, upgrade in Upgrades.List do
					data.Upgrades[upgrade.Id] = upgrade.MaxLevel
				end
				local _, gui = openUpgrades()
				local laidOut = Layout.Gui(gui, viewport)
				local bad: { string } = {}
				for _, child in laidOut.children do
					overflowing(child, bad)
				end
				expect(bad):toEqual({})
			end)
		end
	end)

	describe("Starter offer", function()
		local function openOffer()
			local screen = boot("StarterOffer")
			screen:Open()
			world:flush()
			return screen, playerGui:FindFirstChild("ThockStarterOffer")
		end

		it("shows the configured contents as three reward tiles", function()
			local _, gui = openOffer()
			local starter = Monetization.ProductById.StarterPack
			local contents = gui:FindFirstChild("Contents", true)
			expect(#contents:GetChildren()):toBe(3)
			expect(gui:FindFirstChild("Tile1", true):FindFirstChild("Amount", true).Text):toBe(
				NumberFormat.Commas(starter.Amount)
			)
			expect(gui:FindFirstChild("Tile2", true):FindFirstChild("Amount", true).Text):toBe("2x Luck")
			expect(gui:FindFirstChild("Tile3", true):FindFirstChild("Amount", true).Text):toBe("Epic")
			for index = 1, 3 do
				expect(gui:FindFirstChild(`Tile{index}`, true):FindFirstChild("Icon", true) ~= nil):toBe(true)
			end
		end)

		it("has the ribbon, sparkle burst, one time badge, worth price and buy price", function()
			local _, gui = openOffer()
			local starter = Monetization.ProductById.StarterPack
			expect(gui:FindFirstChild("Ribbon", true):FindFirstChild("Title").Text):toBe("STARTER PACK")
			expect(gui:FindFirstChild("Sparkles", true) ~= nil):toBe(true)
			expect(gui:FindFirstChild("Badge", true):FindFirstChild("Text", true).Text):toBe("ONE TIME!")
			expect(string.find(gui:FindFirstChild("Worth", true).Text, "<s>", 1, true) ~= nil):toBe(true)
			expect(gui:FindFirstChild("Buy", true):FindFirstChild("Text", true).Text):toBe(
				`BUY  R$ {starter.PriceLabel}`
			)
		end)

		it("sends BUY into the existing purchase flow", function()
			local _, gui = openOffer()
			press(gui:FindFirstChild("Buy", true))
			expect(toasts):toEqual({ "Coming soon!" })
		end)

		it("closes through the X button and the No thanks link", function()
			local _, gui = openOffer()
			press(gui:FindFirstChild("Close", true))
			press(gui:FindFirstChild("NoThanks", true))
			expect(closed):toEqual({ "StarterOffer", "StarterOffer" })
		end)

		it("closes itself when already bought", function()
			data.StarterPackBought = true
			boot("StarterOffer")
			expect(closed[1]):toBe("StarterOffer")
		end)

		for _, viewport in viewports do
			it(`never overflows text at {viewport.X}x{viewport.Y}`, function()
				local _, gui = openOffer()
				local laidOut = Layout.Gui(gui, viewport)
				local bad: { string } = {}
				for _, child in laidOut.children do
					overflowing(child, bad)
				end
				expect(bad):toEqual({})
			end)
		end
	end)
end)
