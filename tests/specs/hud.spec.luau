local H = require("../harness/Harness")
local roblox = require("@lune/roblox")
local UDim2 = roblox.UDim2
local Enum = roblox.Enum

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

local screens = "StarterPlayer.StarterPlayerScripts.Controllers.UIController"

local function read(node: any, key: string): any
	local ok, value = pcall(function()
		return node[key]
	end)
	return if ok then value else nil
end

local function find(root: any, name: string): any
	return root:FindFirstChild(name, true)
end

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

local function isOnRight(node: any): boolean
	local current = node
	while current do
		local anchor = read(current, "AnchorPoint")
		local position = read(current, "Position")
		if anchor and anchor.X >= 0.5 then
			return true
		end
		if position and position.X.Scale >= 0.5 then
			return true
		end
		current = current.Parent
	end
	return false
end

describe("HUD", function()
	local world, playerGui, hudGui, offersGui
	local opened, calls, toasts, refusal, inBase, rollRequests, rollController

	beforeEach(function()
		world = H.newWorld()
		local Signal = world:require("ReplicatedStorage.Packages.Signal")
		local player = world:newPlayer()
		world.Players.LocalPlayer = player
		world.tree.ReplicatedStorage.GetAttributeChangedSignal = function()
			return Signal.new()
		end
		playerGui = world:newInstance("Folder")
		local dataController = {
			Observe = function(_self: any, _path: any, callback: any)
				callback(nil)
				return function() end
			end,
			Get = function()
				return nil
			end,
		}
		opened = {}
		calls = { Base = 0, Market = 0 }
		toasts = {}
		refusal = nil
		inBase = true
		rollRequests = 0
		rollController = {
			AutoChanged = Signal.new(),
			InBaseChanged = Signal.new(),
			IsInBase = function()
				return inBase
			end,
			IsAuto = function()
				return false
			end,
			SetAuto = function() end,
			TeleportToBase = function()
				calls.Base += 1
				return refusal == nil, refusal
			end,
			TeleportToMarket = function()
				calls.Market += 1
				return refusal == nil, refusal
			end,
			RequestRoll = function()
				rollRequests += 1
				return true
			end,
		}
		local context = {
			Controllers = { DataController = dataController, RollController = rollController },
			PlayerGui = playerGui,
			Open = function(name: string)
				table.insert(opened, name)
			end,
			Close = function() end,
			IsOpen = function()
				return false
			end,
			Toast = function(text: string)
				table.insert(toasts, text)
			end,
		}
		world:require(`{screens}.Screens.Hud`).new(context)
		world:require(`{screens}.Screens.Offers`).new(context)
		hudGui = playerGui:FindFirstChild("ThockHud")
		offersGui = playerGui:FindFirstChild("ThockOffers")
	end)

	local function texts(): { string }
		local out = {}
		for _, gui in { hudGui, offersGui } do
			for _, item in gui:GetDescendants() do
				if item.ClassName == "TextLabel" or item.ClassName == "TextButton" then
					table.insert(out, item.Text)
				end
			end
		end
		return out
	end

	it("builds both screens", function()
		expect(hudGui ~= nil):toBe(true)
		expect(offersGui ~= nil):toBe(true)
		expect(#world.errors):toBe(0)
	end)

	it("puts SHOP left of MY BASE at the top center with identical sizes", function()
		local myBase = find(hudGui, "MyBase")
		local shop = find(hudGui, "Shop")
		expect(myBase ~= nil):toBe(true)
		expect(shop ~= nil):toBe(true)
		expect(myBase.Face.Text.Text):toBe("BASE")
		expect(shop.Face.Text.Text):toBe("SHOP")
		expect(myBase.Size.X.Offset):toBe(shop.Size.X.Offset)
		expect(myBase.Size.Y.Offset):toBe(shop.Size.Y.Offset)
		expect(myBase.Parent == shop.Parent):toBe(true)
		expect(myBase.Parent.Name):toBe("TopBar")
		expect(myBase.Parent.AnchorPoint.X):toBe(0.5)
		expect(myBase.Parent.Position.X.Scale):toBe(0.5)
		expect(shop.Position.X.Offset < myBase.Position.X.Offset):toBe(true)
		expect(isOnRight(myBase.Parent)):toBe(true)
		expect(find(hudGui, "MyBase"):FindFirstChild("Icon", true) ~= nil):toBe(true)
		expect(find(hudGui, "Shop"):FindFirstChild("Icon", true) ~= nil):toBe(true)
	end)

	it("blocks the SHOP teleport while carrying a key and allows it otherwise", function()
		local Travel = world:require("StarterPlayer.StarterPlayerScripts.Controllers.RollController.Travel")
		local carrier = world:newInstance("Model")
		carrier:SetAttribute("CarryingKey", "GlassTink")
		local blocked, message = Travel.ToMarket(carrier, world:newInstance("Folder"))
		expect(blocked):toBe(false)
		expect(message):toBe(Travel.CarryMessage)
		local freeBlocked, freeMessage = Travel.ToMarket(world:newInstance("Model"), world:newInstance("Folder"))
		expect(freeBlocked):toBe(false)
		expect(freeMessage):toBe(Travel.MarketMessage)
	end)

	it("sends MY BASE and SHOP presses to the matching teleports", function()
		press(find(hudGui, "MyBase"))
		press(find(hudGui, "Shop"))
		expect(calls.Base):toBe(1)
		expect(calls.Market):toBe(1)
	end)

	it("toasts the reason when a teleport is refused", function()
		refusal = "Can't teleport while carrying a key!"
		press(find(hudGui, "MyBase"))
		press(find(hudGui, "Shop"))
		expect(#toasts):toBe(2)
		expect(toasts[1]):toBe("Can't teleport while carrying a key!")
	end)

	it("puts Store, Leaderboard and Pass on the right", function()
		for _, name in { "Store", "Leaderboard", "Pass" } do
			local button = find(hudGui, name)
			expect(button ~= nil):toBe(true)
			expect(isOnRight(button)):toBe(true)
		end
		expect(find(hudGui, "Store").Face.Text.Text):toBe("STORE")
	end)

	it("has no CHARMS button in the menu", function()
		expect(find(hudGui, "Charms")):toBeNil()
		for _, text in texts() do
			expect(string.find(string.upper(text), "CHARM", 1, true)):toBeNil()
		end
	end)

	it("puts KEYS before UPGRADES in the left menu", function()
		expect(find(hudGui, "Keys").LayoutOrder < find(hudGui, "Upgrades").LayoutOrder):toBe(true)
		expect(find(hudGui, "Keys").LayoutOrder):toBe(1)
		expect(find(hudGui, "Upgrades").LayoutOrder):toBe(2)
		expect(find(hudGui, "Index").LayoutOrder):toBe(3)
	end)

	describe("roll in base", function()
		local function click(button: any)
			button.MouseButton1Down:Fire()
		end

		local function bottomColor(button: any): any
			return button.Face.Paint.Color.Keypoints[1].Value
		end

		local function tag()
			return find(hudGui, "BaseTag")
		end

		it("shows no warning inside the base", function()
			expect(tag().Visible):toBe(false)
			click(find(hudGui, "Roll"))
			expect(rollRequests):toBe(1)
			expect(#toasts):toBe(0)
		end)

		it("greys the ROLL button and shows GO TO YOUR BASE outside", function()
			local Theme = world:require(`{screens}.Kit.Theme`)
			rollController.InBaseChanged:Fire(false)
			expect(tag().Visible):toBe(true)
			expect(tag().Text.Text):toBe("GO TO YOUR BASE")
			expect(bottomColor(find(hudGui, "Roll"))):toBe(Theme.Colors.Grey:Lerp(roblox.Color3.new(1, 1, 1), 0.25))
			rollController.InBaseChanged:Fire(true)
			expect(tag().Visible):toBe(false)
			expect(bottomColor(find(hudGui, "Roll"))):toBe(Theme.Colors.Gold:Lerp(roblox.Color3.new(1, 1, 1), 0.25))
		end)

		it("toasts and refuses a roll click outside the base", function()
			inBase = false
			rollController.InBaseChanged:Fire(false)
			click(find(hudGui, "Roll"))
			expect(rollRequests):toBe(0)
			expect(#toasts):toBe(1)
			expect(toasts[1]):toBe("Go to your base to roll!")
		end)

		it("pulses MY BASE when the click is refused", function()
			inBase = false
			click(find(hudGui, "Roll"))
			expect(find(hudGui, "MyBase"):FindFirstChild("PulseScale") ~= nil):toBe(true)
		end)
	end)

	it("keeps the left menu on the left", function()
		for _, name in { "Upgrades", "Keys", "Index", "Rebirth" } do
			expect(isOnRight(find(hudGui, name))):toBe(false)
		end
		expect(isOnRight(find(hudGui, "DailyRewards"))):toBe(false)
		expect(isOnRight(find(hudGui, "Pets"))):toBe(false)
	end)

	it("puts PETS in the left grid slot STARTER used to hold and STARTER on the right", function()
		local pets = find(hudGui, "Pets")
		local starter = find(hudGui, "StarterPack")
		expect(pets.Face.Text.Text):toBe("PETS")
		expect(pets.Parent == find(hudGui, "Keys").Parent):toBe(true)
		expect(pets.LayoutOrder):toBe(6)
		expect(pets.Face:FindFirstChild("Icon") ~= nil):toBe(true)
		expect(starter.Face.Text.Text):toBe("STARTER")
		expect(isOnRight(starter)):toBe(true)
		expect(starter.Parent == find(hudGui, "Store").Parent):toBe(true)
		expect(starter.LayoutOrder < find(hudGui, "Store").LayoutOrder):toBe(true)
	end)

	it("opens the starter offer from the right column and the pets screen from PETS", function()
		press(find(hudGui, "StarterPack"))
		press(find(hudGui, "Pets"))
		expect(opened):toEqual({ "StarterOffer", "Pets" })
	end)

	it("keeps the right column clear of the bottom-right stat chips", function()
		local side = find(hudGui, "Side")
		local stats = find(hudGui, "Multipliers")
		expect(side.AnchorPoint.Y):toBe(1)
		local sideBottom = side.Position.Y.Offset
		local statsTop = stats.Position.Y.Offset - stats.Size.Y.Offset
		expect(sideBottom <= statsTop):toBe(true)
	end)

	it("matches the right stack sizes", function()
		local shop = find(hudGui, "Store").Size
		for _, name in { "Leaderboard", "Pass" } do
			local size = find(hudGui, name).Size
			expect(size.X.Offset):toBe(shop.X.Offset)
			expect(size.Y.Offset):toBe(shop.Y.Offset)
		end
	end)

	it("has no New stock element", function()
		expect(find(offersGui, "MarketStock")):toBeNil()
		for _, text in texts() do
			expect(string.find(string.lower(text), "new stock", 1, true)):toBeNil()
		end
	end)

	it("makes Golden and Auto equal squares", function()
		local golden = find(hudGui, "Golden").Size
		local auto = find(hudGui, "Auto").Size
		expect(golden.X.Offset):toBeGreaterThan(0)
		expect(golden.X.Offset):toBe(golden.Y.Offset)
		expect(auto.X.Offset):toBe(auto.Y.Offset)
		expect(golden.X.Offset):toBe(auto.X.Offset)
	end)

	it("fills the whole golden square", function()
		local golden = find(hudGui, "Golden")
		expect(golden.Fill.Size.X.Scale):toBe(1)
	end)

	it("keeps emojis out of every label and button", function()
		for _, text in texts() do
			expect(hasEmoji(text)):toBe(false)
		end
	end)

	it("adds glyph icons to the menu buttons", function()
		for _, name in { "Upgrades", "Keys", "Index", "Rebirth", "Store", "Leaderboard", "Pass", "Auto" } do
			expect(find(hudGui, name).Face:FindFirstChild("Icon") ~= nil):toBe(true)
		end
		expect(find(hudGui, "DailyRewards").Face:FindFirstChild("Icon") ~= nil):toBe(true)
		expect(find(hudGui, "StarterPack").Face:FindFirstChild("Icon") ~= nil):toBe(true)
		expect(find(hudGui, "Settings").Face:FindFirstChild("Icon") ~= nil):toBe(true)
	end)

	describe("dev button", function()
		it("is hidden until the server marks the player a developer", function()
			local dev = find(hudGui, "Dev")
			expect(dev ~= nil):toBe(true)
			expect(dev.Visible):toBe(false)
			world.Players.LocalPlayer:SetAttribute("IsDeveloper", true)
			expect(dev.Visible):toBe(true)
			world.Players.LocalPlayer:SetAttribute("IsDeveloper", false)
			expect(dev.Visible):toBe(false)
		end)

		it("sits directly right of Settings with the same size", function()
			local settings = find(hudGui, "Settings")
			local dev = find(hudGui, "Dev")
			expect(dev.Size):toEqual(settings.Size)
			expect(dev.Position.Y):toEqual(settings.Position.Y)
			expect(dev.Position.X.Offset > settings.Position.X.Offset + settings.Size.X.Offset - 1):toBe(true)
			expect(dev.Position.X.Offset - settings.Position.X.Offset < settings.Size.X.Offset + 20):toBe(true)
			expect(dev.Face:FindFirstChild("Icon") ~= nil):toBe(true)
		end)

		it("toggles the dev panel when pressed", function()
			world.Players.LocalPlayer:SetAttribute("IsDeveloper", true)
			press(find(hudGui, "Dev"))
			expect(opened[#opened]):toBe("Cheats")
		end)
	end)

	it("uses the uploaded icon atlas and falls back to Star for names it lacks", function()
		local Kit = world:require(`{screens}.Kit`)
		local IconAtlas = world:require(`{screens}.IconAtlas`)
		local holder = world:newInstance("Frame")
		local atlasIcon = Kit.Icon({ Parent = holder, Glyph = "Keys" })
		expect(atlasIcon.ClassName):toBe("ImageLabel")
		expect(atlasIcon.Image):toBe(IconAtlas.Image)
		local fallback = Kit.Icon({ Parent = holder, Glyph = "NotAnAtlasIcon" })
		expect(fallback.ClassName):toBe("ImageLabel")
		expect(fallback.ImageRectOffset):toBe(IconAtlas.Rects.Star)
	end)
end)
