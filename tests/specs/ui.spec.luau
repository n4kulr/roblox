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
