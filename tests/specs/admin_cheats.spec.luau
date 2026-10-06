local H = require("../harness/Harness")
local roblox = require("@lune/roblox")
local Enum = roblox.Enum

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

local screenPath = "StarterPlayer.StarterPlayerScripts.Controllers.UIController.Screens.Cheats"

local function press(button: any)
	button.Activated:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
end

describe("Cheats screen", function()
	local world, player, playerGui, context, sent, toasts, opened, closed, Signal

	local function build()
		local screen = world:require(screenPath).new(context)
		return screen
	end

	local function gui()
		return playerGui:FindFirstChild("ThockCheats")
	end

	local function button(name: string)
		local found = gui():FindFirstChild(name, true)
		expect(found ~= nil):toBe(true)
		return found
	end

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
		Signal = world:require("ReplicatedStorage.Packages.Signal")
		player = world:newPlayer({ Name = "Dev", DisplayName = "Dev" })
		world.Players.LocalPlayer = player
		playerGui = world:newInstance("Folder")
		sent, toasts, opened, closed = {}, {}, 0, 0
		world:packets().AdminCommand.Fire = function(_packet: any, command: string, argument: string)
			table.insert(sent, { command, argument })
			return `ok {command}`
		end
		context = {
			Controllers = {},
			PlayerGui = playerGui,
			Open = function(name: string)
				if name == "Cheats" then
					opened += 1
				end
			end,
			Close = function(name: string)
				if name == "Cheats" then
					closed += 1
				end
			end,
			IsOpen = function()
				return false
			end,
			Toast = function(text: string)
				table.insert(toasts, text)
			end,
		}
	end)

	it("asks to open when an admin types /cheats", function()
		player:SetAttribute("IsAdmin", true)
		build()
		player.Chatted:Fire("/cheats")
		player.Chatted:Fire("  /CHEATS ")
		expect(opened):toBe(2)
	end)

	it("toggles closed when already open", function()
		player:SetAttribute("IsAdmin", true)
		context.IsOpen = function()
			return true
		end
		build()
		player.Chatted:Fire("/cheats")
		expect(closed):toBe(1)
		expect(opened):toBe(0)
	end)

	it("ignores /cheats for non-admins and never builds the gui", function()
		local screen = build()
		player.Chatted:Fire("/cheats")
		expect(opened):toBe(0)
		screen:Open()
		world:flush()
		expect(gui()):toBe(nil)
	end)

	it("ignores other chat", function()
		player:SetAttribute("IsAdmin", true)
		build()
		player.Chatted:Fire("/cheatsheet")
		player.Chatted:Fire("hello")
		expect(opened):toBe(0)
	end)

	it("listens to TextChatService when it is the active chat", function()
		player:SetAttribute("IsAdmin", true)
		local chat = world.fakeServices.TextChatService
		chat.ChatVersion = Enum.ChatVersion.TextChatService
		chat.SendingMessage = Signal.new()
		build()
		player.Chatted:Fire("/cheats")
		expect(opened):toBe(0)
		chat.SendingMessage:Fire({ Text = "/cheats" })
		expect(opened):toBe(1)
	end)

	it("opens and closes its modal for admins", function()
		player:SetAttribute("IsAdmin", true)
		local screen = build()
		screen:Open()
		world:flush()
		expect(gui() ~= nil):toBe(true)
		expect(gui().Enabled):toBe(true)
		press(button("Close"))
		expect(closed):toBe(1)
		screen:Close()
		world:flush()
		expect(gui().Enabled):toBe(false)
		screen:Destroy()
		expect(#world.errors):toBe(0)
	end)

	describe("buttons", function()
		local screen

		local function tap(name: string)
			press(button(name))
			world:flush()
		end

		beforeEach(function()
			player:SetAttribute("IsAdmin", true)
			screen = build()
			screen:Open()
			world:flush()
		end)

		it("sends the money commands", function()
			tap("Money1K")
			tap("Money1M")
			tap("Money1B")
			tap("Money1T")
			tap("MaxMoney")
			tap("ResetMoney")
			expect(sent):toEqual({
				{ "money", "1k" },
				{ "money", "1m" },
				{ "money", "1b" },
				{ "money", "1t" },
				{ "maxmoney", "" },
				{ "resetmoney", "" },
			})
		end)

		it("shows the server reply as a toast", function()
			tap("Money1K")
			expect(toasts):toEqual({ "ok money" })
		end)

		it("sends the custom amount through Add and Set", function()
			tap("AddAmount")
			expect(sent):toEqual({})
			expect(toasts):toEqual({ "Enter an amount" })
			button("AmountInput").Text = "2.5m"
			tap("AddAmount")
			tap("SetAmount")
			expect(sent):toEqual({ { "money", "2.5m" }, { "setmoney", "2.5m" } })
		end)

		it("sends the progress commands", function()
			tap("Rolls100")
			tap("NextGolden")
			tap("MaxUpgrades")
			tap("ResetUpgrades")
			tap("ForceRebirth")
			expect(sent):toEqual({
				{ "rolls", "100" },
				{ "golden", "" },
				{ "maxupgrades", "" },
				{ "resetupgrades", "" },
				{ "rebirth", "" },
			})
		end)

		it("sends the boost and egg commands", function()
			tap("LuckPotion")
			tap("ClicksPotion")
			tap("ReadyEggs")
			tap("HatchAll")
			expect(sent):toEqual({
				{ "luckpotion", "10" },
				{ "clickspotion", "10" },
				{ "readyeggs", "" },
				{ "hatchall", "" },
			})
		end)

		it("gives keys, eggs and pets with the count box", function()
			local Keys = world:require("ReplicatedStorage.Config.Keys")
			local Eggs = world:require("ReplicatedStorage.Config.Eggs")
			local Charms = world:require("ReplicatedStorage.Config.Charms")
			tap(`GiveRarity{Keys.Rarities[1].Name}`)
			tap(`GiveKey{Keys.Catalog[1].Id}`)
			button("CountInput").Text = "5"
			tap(`GiveEgg{Eggs.Catalog[1].Id}`)
			tap(`GivePet{Charms.Catalog[1].Id}`)
			expect(sent):toEqual({
				{ "givekey", `{Keys.Rarities[1].Name} 1` },
				{ "givekey", `{Keys.Catalog[1].Id} 1` },
				{ "giveegg", `{Eggs.Catalog[1].Id} 5` },
				{ "givepet", `{Charms.Catalog[1].Id} 5` },
			})
		end)

		it("appends the target field to every command", function()
			button("TargetInput").Text = "Buddy"
			tap("Money1K")
			tap("MaxUpgrades")
			button("TargetInput").Text = "all"
			tap("Rolls100")
			expect(sent):toEqual({
				{ "money", "1k Buddy" },
				{ "maxupgrades", "Buddy" },
				{ "rolls", "100 all" },
			})
		end)

		it("needs two taps to reset data", function()
			tap("ResetData")
			expect(sent):toEqual({})
			tap("ResetData")
			expect(sent):toEqual({ { "resetdata", "confirm" } })
			tap("ResetData")
			expect(#sent):toBe(1)
		end)

		it("disarms the reset confirmation after a few seconds", function()
			tap("ResetData")
			world:advance(5)
			tap("ResetData")
			expect(sent):toEqual({})
		end)
	end)
end)
