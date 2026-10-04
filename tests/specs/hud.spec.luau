local H = require("../harness/Harness")
local UDim2 = require("@lune/roblox").UDim2

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
	local world, playerGui, hudGui, offersGui, Glyphs

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
		local rollController = {
			AutoChanged = Signal.new(),
			IsAuto = function()
				return false
			end,
			SetAuto = function() end,
			TeleportToBase = function()
				return true
			end,
			RequestRoll = function() end,
		}
		local context = {
			Controllers = { DataController = dataController, RollController = rollController },
			PlayerGui = playerGui,
			Open = function() end,
			Close = function() end,
			IsOpen = function()
				return false
			end,
			Toast = function() end,
		}
		world:require(`{screens}.Screens.Hud`).new(context)
		world:require(`{screens}.Screens.Offers`).new(context)
		hudGui = playerGui:FindFirstChild("ThockHud")
		offersGui = playerGui:FindFirstChild("ThockOffers")
		Glyphs = world:require(`{screens}.Glyphs`)
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

	it("makes MY BASE a text-only button", function()
		local button = find(hudGui, "MyBase")
		expect(button ~= nil):toBe(true)
		expect(button.Face:FindFirstChild("Icon")):toBeNil()
		expect(button:FindFirstChild("Icon", true)):toBeNil()
		expect(button.Face.Text.Text):toBe("MY BASE")
	end)

	it("puts Shop, Leaderboard and Pass on the right", function()
		for _, name in { "Shop", "Leaderboard", "Pass" } do
			local button = find(hudGui, name)
			expect(button ~= nil):toBe(true)
			expect(isOnRight(button)):toBe(true)
		end
	end)

	it("keeps the left menu on the left", function()
		for _, name in { "Upgrades", "Keys", "Index", "Rebirth" } do
			expect(isOnRight(find(hudGui, name))):toBe(false)
		end
		expect(isOnRight(find(offersGui, "DailyRewards"))):toBe(false)
		expect(isOnRight(find(offersGui, "StarterPack"))):toBe(false)
	end)

	it("matches the right stack sizes", function()
		local shop = find(hudGui, "Shop").Size
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
		for _, name in { "Upgrades", "Keys", "Index", "Rebirth", "Shop", "Leaderboard", "Pass", "Auto" } do
			expect(find(hudGui, name).Face:FindFirstChild("Icon") ~= nil):toBe(true)
		end
		expect(find(offersGui, "DailyRewards").Face:FindFirstChild("Icon") ~= nil):toBe(true)
		expect(find(offersGui, "StarterPack").Face:FindFirstChild("Icon") ~= nil):toBe(true)
		expect(find(hudGui, "Settings").Face:FindFirstChild("Icon") ~= nil):toBe(true)
	end)

	it("builds every glyph with children", function()
		expect(#Glyphs.Names):toBeGreaterThan(14)
		for _, name in Glyphs.Names do
			local holder = world:newInstance("Frame")
			local built = Glyphs.Build(name, { Parent = holder, Size = UDim2.fromOffset(48, 48) })
			expect(#built:GetChildren()):toBeGreaterThan(0)
			expect(#built.Art:GetChildren()):toBeGreaterThan(1)
			expect(#holder:GetChildren()):toBe(1)
		end
	end)

	it("rejects unknown glyphs", function()
		expect(Glyphs.Has("Nope")):toBe(false)
		expect(function()
			Glyphs.Build("Nope", { Parent = world:newInstance("Frame") })
		end):toThrow("unknown glyph")
	end)
end)
