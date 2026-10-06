local H = require("../harness/Harness")
local roblox = require("@lune/roblox")
local Enum = roblox.Enum

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

local screens = "StarterPlayer.StarterPlayerScripts.Controllers.UIController"

local modals = {
	"Upgrades",
	"Keys",
	"Index",
	"Market",
	"Shop",
	"Season",
	"Daily",
	"Rebirth",
	"Leaderboards",
	"Settings",
	"Trade",
	"StarterOffer",
}

local allScreens = {
	"Hud",
	"Offers",
	"TradePrompt",
	"Upgrades",
	"Keys",
	"Index",
	"Market",
	"Hatch",
	"Shop",
	"Season",
	"Daily",
	"Rebirth",
	"Leaderboards",
	"Settings",
	"Trade",
	"StarterOffer",
}

local function hasEmoji(text: string): boolean
	for _, code in utf8.codes(text) do
		if code >= 0x2190 or code == 0xFE0F then
			return true
		end
	end
	return false
end

local function press(button: any)
	button.Activated:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
end

describe("UI screens", function()
	local world, playerGui, context, built, Glyphs

	local function boot(name: string)
		local screen = world:require(`{screens}.Screens.{name}`).new(context)
		built[name] = screen
		return screen
	end

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
		built = {}
		local Signal = world:require("ReplicatedStorage.Packages.Signal")
		local player = world:newPlayer({ Name = "Tester", DisplayName = "Tester" })
		player.GetAttributeChangedSignal = function()
			return Signal.new()
		end
		world.Players.LocalPlayer = player
		world.tree.ReplicatedStorage.GetAttributeChangedSignal = function()
			return Signal.new()
		end
		world:packets().GetLeaderboard.Fire = function()
			return { { Name = "Tester", Value = 1200 }, { Name = "Other", Value = 900 } }
		end
		local data: any = {
			Cash = 5000,
			IncomeAt = world.now,
			Board = { "PlainClack", "CreamyThock" },
			BoardTags = {},
			Inventory = { PlainClack = 2 },
			Discovered = { PlainClack = 1 },
			Upgrades = { Luck = 1, Speed = 0, Slots = 0, Income = 0, Walls = 0, LockTime = 0, Golden = 2 },
			Settings = { RollVolume = 1, BoardVolume = 1, OtherVolume = 1 },
			Tutorial = 5,
			Boosts = { LuckUntil = 0, ClicksUntil = 0 },
			Daily = { Streak = 0, LastClaim = 0 },
			Season = { Id = 1, Xp = 120, ClaimedFree = 0, ClaimedPremium = 0 },
			Market = { Slot = 0, Bought = {} },
			Rebirths = 0,
			GoldenProgress = 3,
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
		local tradeState: any = {
			Partner = "Pal",
			Phase = 1,
			Seconds = 0,
			MyReady = false,
			TheirReady = false,
			Mine = { { KeyId = "PlainClack", Count = 1 } },
			Theirs = {},
		}
		local cancelled = 0
		local controllers = {
			DataController = {
				Get = function(_self: any, path: { any }?)
					return lookup(path or {})
				end,
				Observe = function(_self: any, path: { any }, callback: any)
					callback(lookup(path))
					return function() end
				end,
			},
			RollController = {
				AutoChanged = Signal.new(),
				InBaseChanged = Signal.new(),
				IsInBase = function()
					return true
				end,
				IsAuto = function()
					return false
				end,
				SetAuto = function() end,
				TeleportToBase = function()
					return true
				end,
				TeleportToMarket = function()
					return true
				end,
				RequestRoll = function() end,
			},
			TradeController = {
				StateChanged = Signal.new(),
				TargetPicked = Signal.new(),
				InviteReceived = Signal.new(),
				GetState = function()
					return tradeState
				end,
				SetReady = function() end,
				SetOffer = function() end,
				Cancel = function()
					cancelled += 1
				end,
				Request = function() end,
				Respond = function() end,
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
		Glyphs = world:require(`{screens}.Glyphs`)
	end)

	local function allTexts(): { string }
		local out = {}
		for _, gui in playerGui:GetChildren() do
			for _, item in gui:GetDescendants() do
				if item.ClassName == "TextLabel" or item.ClassName == "TextButton" then
					table.insert(out, item.Text)
				end
			end
		end
		return out
	end

	it("builds every screen without errors", function()
		for _, name in allScreens do
			boot(name)
		end
		expect(#world.errors):toBe(0)
	end)

	for _, name in modals do
		it(`opens and closes {name} through its X button`, function()
			local closed = 0
			context.Close = function(target: string)
				if target == name then
					closed += 1
				end
			end
			local screen = boot(name)
			screen:Open()
			world:flush()
			local gui = playerGui:FindFirstChild(`Thock{name}`)
			expect(gui ~= nil):toBe(true)
			expect(gui.Enabled):toBe(true)
			local close = gui:FindFirstChild("Close", true)
			expect(close ~= nil):toBe(true)
			press(close)
			expect(closed):toBe(1)
			screen:Close()
			world:flush()
			expect(gui.Enabled):toBe(false)
			screen:Destroy()
			expect(#world.errors):toBe(0)
		end)
	end

	for _, name in modals do
		it(`closes {name} when the dim backdrop is clicked`, function()
			local closed = 0
			context.Close = function(target: string)
				if target == name then
					closed += 1
				end
			end
			local screen = boot(name)
			screen:Open()
			world:flush()
			local gui = playerGui:FindFirstChild(`Thock{name}`)
			local backdrop = gui:FindFirstChild("Backdrop", true)
			expect(backdrop ~= nil):toBe(true)
			expect(backdrop.Size.X.Scale):toBe(1)
			press(backdrop)
			expect(closed):toBe(1)
			screen:Destroy()
		end)
	end

	for _, name in modals do
		it(`dims the whole screen including the top bar and keeps {name} below it`, function()
			local screen = boot(name)
			screen:Open()
			world:flush()
			local gui = playerGui:FindFirstChild(`Thock{name}`)
			expect(gui.IgnoreGuiInset):toBe(true)
			local backdrop = gui:FindFirstChild("Backdrop", true)
			expect(backdrop.Size):toEqual(roblox.UDim2.fromScale(1, 1))
			expect(backdrop.Parent.Name):toBe("Root")
			local area = gui:FindFirstChild("Area", true)
			local factor = gui:FindFirstChild("ViewportScale", true).Scale
			expect(area.Position.Y.Offset * factor >= 58):toBe(true)
			expect(area.Position.Y.Offset * factor <= 58 + 40 * factor + 1):toBe(true)
			screen:Destroy()
		end)
	end

	describe("Keys screen", function()
		local function openKeys()
			local screen = boot("Keys")
			screen:Open()
			world:flush()
			return screen, playerGui:FindFirstChild("ThockKeys")
		end

		local function order(gui: any, id: string): number
			return gui:FindFirstChild(id, true).LayoutOrder
		end

		it("has no ON BOARD tags or keyboard count line", function()
			local _, gui = openKeys()
			for _, item in gui:GetDescendants() do
				if item.ClassName == "TextLabel" or item.ClassName == "TextButton" then
					expect(string.find(item.Text, "ON BOARD", 1, true)):toBeNil()
					expect(string.find(item.Text, "Keys on your keyboard", 1, true)):toBeNil()
				end
			end
			expect(gui:FindFirstChild("OnBoard", true)):toBeNil()
			expect(gui:FindFirstChild("BoardCount", true)):toBeNil()
			local counts = {}
			for _, item in gui:FindFirstChild("PlainClack", true):GetDescendants() do
				if item.ClassName == "TextLabel" and string.sub(item.Text, 1, 1) == "x" then
					table.insert(counts, item.Text)
				end
			end
			expect(counts):toEqual({ "x3" })
		end)

		it("shows income as the biggest text on each card", function()
			local _, gui = openKeys()
			local card = gui:FindFirstChild("CreamyThock", true)
			expect(card.Info.Text):toBe("+6/s")
			local infoSize = card.Info:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize
			local name = card:FindFirstChild("Name")
			local nameSize = name:FindFirstChildOfClass("UITextSizeConstraint").MaxTextSize
			expect(infoSize > nameSize * 1.5):toBe(true)
			expect(card.Info.Position.Y.Offset < name.Position.Y.Offset):toBe(true)
		end)

		it("sorts BEST by default and cycles BEST, RARITY, AMOUNT, NAME", function()
			local _, gui = openKeys()
			local sort = gui:FindFirstChild("Sort", true)
			expect(sort.Face.Text.Text):toBe("SORT: BEST")
			expect(sort:FindFirstChild("Icon", true) ~= nil):toBe(true)
			expect(order(gui, "CreamyThock") < order(gui, "PlainClack")):toBe(true)
			press(sort)
			expect(sort.Face.Text.Text):toBe("SORT: RARITY")
			press(sort)
			expect(sort.Face.Text.Text):toBe("SORT: AMOUNT")
			expect(order(gui, "PlainClack") < order(gui, "CreamyThock")):toBe(true)
			press(sort)
			expect(sort.Face.Text.Text):toBe("SORT: NAME")
			expect(order(gui, "CreamyThock") < order(gui, "PlainClack")):toBe(true)
			press(sort)
			expect(sort.Face.Text.Text):toBe("SORT: BEST")
		end)

		it("remembers the sort mode when reopened", function()
			local screen, gui = openKeys()
			press(gui:FindFirstChild("Sort", true))
			screen:Close()
			screen:Open()
			world:flush()
			expect(gui:FindFirstChild("Sort", true).Face.Text.Text):toBe("SORT: RARITY")
		end)
	end)

	describe("Season screen", function()
		local claims

		local function openSeason()
			claims = {}
			world:packets().ClaimSeason.Fire = function(_self: any, level: number, premium: boolean)
				table.insert(claims, { level, premium })
				return true
			end
			local screen = boot("Season")
			screen:Open()
			world:flush()
			return screen, playerGui:FindFirstChild("ThockSeason")
		end

		local function tile(gui: any, level: number, track: string): any
			return gui:FindFirstChild(`Level{level}`, true):FindFirstChild(track)
		end

		it("claims a reward by clicking anywhere on its green tile", function()
			local _, gui = openSeason()
			local free = tile(gui, 1, "Free")
			expect(free.Hit ~= nil):toBe(true)
			expect(free.Hit.Size):toEqual(roblox.UDim2.fromScale(1, 1))
			press(free.Hit)
			world:advance(1)
			expect(claims):toEqual({ { 1, false } })
		end)

		it("keeps the CLAIM button working", function()
			local _, gui = openSeason()
			press(gui:FindFirstChild("Claim", true))
			world:advance(1)
			expect(claims):toEqual({ { 1, false } })
		end)

		it("ignores tiles that are not claimable", function()
			local _, gui = openSeason()
			press(tile(gui, 2, "Free").Hit)
			press(tile(gui, 1, "Premium").Hit)
			world:advance(1)
			expect(#claims):toBe(0)
		end)

		it("does not double-claim while a claim is in flight", function()
			local _, gui = openSeason()
			press(tile(gui, 1, "Free").Hit)
			press(tile(gui, 1, "Free").Hit)
			world:advance(1)
			expect(#claims):toBe(1)
		end)
	end)

	describe("Store screen", function()
		local toasts

		local function openShop()
			toasts = {}
			context.Toast = function(text: string)
				table.insert(toasts, text)
			end
			local screen = boot("Shop")
			screen:Open()
			world:flush()
			return screen, playerGui:FindFirstChild("ThockShop")
		end

		it("is one scrolling page without tabs or section headers", function()
			local _, gui = openShop()
			expect(gui:FindFirstChild("Tabs", true)):toBeNil()
			expect(gui:FindFirstChild("PassesHeader", true)):toBeNil()
			expect(gui:FindFirstChild("ProductsHeader", true)):toBeNil()
			local list = gui:FindFirstChild("List", true)
			expect(list.ClassName):toBe("ScrollingFrame")
			local names = {}
			for _, child in list:GetChildren() do
				if child.ClassName == "Frame" then
					names[child.LayoutOrder] = child.Name
				end
			end
			expect(names[1]):toBe("StarterBanner")
			expect(names[2]):toBe("Passes")
			expect(names[3]):toBe("Products")
		end)

		it("lays passes in two columns and potions in a single row", function()
			local Monetization = world:require("ReplicatedStorage.Config.Monetization")
			local _, gui = openShop()
			local passes = gui:FindFirstChild("Passes", true)
			local products = gui:FindFirstChild("Products", true)
			expect(passes:FindFirstChildOfClass("UIGridLayout").CellSize.X.Scale):toBe(0.5)
			expect(#passes:GetChildren() - 1):toBe(#Monetization.Passes)
			local boosts = #Monetization.Products - 1
			expect(#products:GetChildren() - 1):toBe(boosts)
			expect(math.abs(products:FindFirstChildOfClass("UIGridLayout").CellSize.X.Scale - 1 / boosts) < 0.001):toBe(true)
			expect(products.Size.Y.Offset):toBe(142)
		end)

		it("keeps cards to an icon, a name, one short line and a price", function()
			local _, gui = openShop()
			local card = gui:FindFirstChild("Passes", true):FindFirstChild("DoubleLuck")
			expect(card:FindFirstChild("Icon") ~= nil):toBe(true)
			expect(card:FindFirstChild("Name").Text):toBe("x2 Luck")
			expect(card:FindFirstChild("Description") ~= nil):toBe(true)
			expect(card:FindFirstChild("Buy") ~= nil):toBe(true)
			local potion = gui:FindFirstChild("Products", true):FindFirstChild("LuckPotion")
			expect(potion:FindFirstChild("Description")):toBeNil()
			expect(potion:FindFirstChild("Buy") ~= nil):toBe(true)
		end)

		it("keeps purchase flows: unavailable items say Coming soon", function()
			local _, gui = openShop()
			press(gui:FindFirstChild("StarterBanner", true):FindFirstChild("Buy"))
			press(gui:FindFirstChild("Passes", true):FindFirstChild("DoubleClicks"):FindFirstChild("Buy"))
			press(gui:FindFirstChild("Products", true):FindFirstChild("ServerLuck"):FindFirstChild("Buy"))
			expect(toasts):toEqual({ "Coming soon!", "Coming soon!", "Coming soon!" })
		end)
	end)

	it("keeps the HUD on the standard inset", function()
		boot("Hud")
		expect(playerGui:FindFirstChild("ThockHud").IgnoreGuiInset):toBe(false)
	end)

	it("keeps emojis out of every label and button on every screen", function()
		for _, name in allScreens do
			local screen = boot(name)
			if screen.Modal then
				screen:Open()
			end
		end
		world:flush()
		for _, text in allTexts() do
			expect(hasEmoji(text)):toBe(false)
		end
	end)

	it("keeps emojis out of the display names of upgrades, passes and products", function()
		local Upgrades = world:require("ReplicatedStorage.Config.Upgrades")
		local Monetization = world:require("ReplicatedStorage.Config.Monetization")
		for _, upgrade in Upgrades.List do
			expect(hasEmoji(upgrade.Name)):toBe(false)
		end
		for _, pass in Monetization.Passes do
			expect(hasEmoji(pass.Name)):toBe(false)
		end
		for _, product in Monetization.Products do
			expect(hasEmoji(product.Name)):toBe(false)
		end
	end)

	it("gives every upgrade a glyph that exists", function()
		local Upgrades = world:require("ReplicatedStorage.Config.Upgrades")
		expect(#Upgrades.List):toBeGreaterThan(6)
		for _, upgrade in Upgrades.List do
			expect(type(upgrade.Glyph)):toBe("string")
			expect(Glyphs.Has(upgrade.Glyph)):toBe(true)
		end
	end)

	it("shows every upgrade including Golden Touch on the Upgrades screen", function()
		local Upgrades = world:require("ReplicatedStorage.Config.Upgrades")
		local screen = boot("Upgrades")
		screen:Open()
		world:flush()
		local gui = playerGui:FindFirstChild("ThockUpgrades")
		for _, upgrade in Upgrades.List do
			local card = gui:FindFirstChild(upgrade.Id, true)
			expect(card ~= nil):toBe(true)
			expect(card:FindFirstChild("Name").Text):toBe(upgrade.Name)
			expect(card:FindFirstChild("Icon", true) ~= nil):toBe(true)
		end
		local golden = gui:FindFirstChild("Golden", true)
		expect(golden.Preview.Text):toBe("Every 90 > 85 rolls")
	end)

	it("builds every glyph used by the icon helpers", function()
		for _, name in Glyphs.Names do
			local holder = world:newInstance("Frame")
			Glyphs.Build(name, { Parent = holder })
			expect(#holder:GetChildren()):toBe(1)
		end
	end)
end)
