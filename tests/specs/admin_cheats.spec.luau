local H = require("../harness/Harness")
local roblox = require("@lune/roblox")
local Enum = roblox.Enum

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach
local Vector3 = roblox.Vector3

local screenPath = "StarterPlayer.StarterPlayerScripts.Controllers.UIController.Screens.Cheats"

local function press(button: any)
	button.Activated:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
end

describe("Dev panel", function()
	local world, player, playerGui, context, sent, toasts, opened, closed

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

	it("builds nothing for non-developers", function()
		local screen = build()
		screen:Open()
		world:flush()
		expect(gui()):toBe(nil)
	end)

	it("is not a modal screen", function()
		local screen = build()
		expect(screen.Modal):toBe(false)
		expect(screen.StartsOpen):toBe(false)
	end)

	it("has no chat command trigger", function()
		player:SetAttribute("IsDeveloper", true)
		build()
		player.Chatted:Fire("/cheats")
		expect(opened):toBe(0)
	end)

	it("opens a compact window titled THOCK DEV", function()
		player:SetAttribute("IsDeveloper", true)
		local screen = build()
		screen:Open()
		world:flush()
		expect(gui().Enabled):toBe(true)
		expect(button("Window").Size.X.Offset):toBe(300)
		expect(button("Title").Text):toBe("THOCK DEV")
		expect(button("Title").Font):toBe(Enum.Font.Code)
		expect(button("Window").BackgroundTransparency < 0.5):toBe(true)
		expect(#world.errors):toBe(0)
	end)

	it("stays open when a command is clicked", function()
		player:SetAttribute("IsDeveloper", true)
		local screen = build()
		screen:Open()
		world:flush()
		press(button("Money1K"))
		world:flush()
		press(button("MaxMoney"))
		world:flush()
		expect(closed):toBe(0)
		expect(gui().Enabled):toBe(true)
	end)

	it("closes only through the X button", function()
		player:SetAttribute("IsDeveloper", true)
		local screen = build()
		screen:Open()
		world:flush()
		press(button("Close"))
		expect(closed):toBe(1)
		screen:Close()
		expect(gui().Enabled):toBe(false)
		screen:Open()
		expect(gui().Enabled):toBe(true)
		screen:Destroy()
		expect(#world.errors):toBe(0)
	end)

	it("closes itself when the developer attribute goes away", function()
		player:SetAttribute("IsDeveloper", true)
		build()
		player:SetAttribute("IsDeveloper", false)
		expect(closed):toBe(1)
	end)

	it("minimizes to the title bar and back", function()
		player:SetAttribute("IsDeveloper", true)
		local screen = build()
		screen:Open()
		world:flush()
		local fullHeight = button("Window").Size.Y.Offset
		press(button("Minimize"))
		expect(button("Window").Size.Y.Offset < fullHeight):toBe(true)
		expect(button("Content").Visible):toBe(false)
		press(button("Minimize"))
		expect(button("Window").Size.Y.Offset):toBe(fullHeight)
		expect(button("Content").Visible):toBe(true)
	end)

	it("drags by the title bar and remembers the position", function()
		player:SetAttribute("IsDeveloper", true)
		local screen = build()
		screen:Open()
		world:flush()
		local window = button("Window")
		local startX, startY = window.Position.X.Offset, window.Position.Y.Offset
		local scale = button("ViewportScale").Scale
		button("TitleBar").InputBegan:Fire({
			UserInputType = Enum.UserInputType.MouseButton1,
			Position = Vector3.new(100, 100, 0),
		})
		world.fakeServices.UserInputService.InputChanged:Fire({
			UserInputType = Enum.UserInputType.MouseMovement,
			Position = Vector3.new(130, 120, 0),
		})
		world.fakeServices.UserInputService.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
		world.fakeServices.UserInputService.InputChanged:Fire({
			UserInputType = Enum.UserInputType.MouseMovement,
			Position = Vector3.new(400, 400, 0),
		})
		expect(window.Position.X.Offset):toBeCloseTo(startX + 30 / scale, 1)
		expect(window.Position.Y.Offset):toBeCloseTo(startY + 20 / scale, 1)
		local moved = window.Position.X.Offset
		screen:Close()
		screen:Open()
		expect(window.Position.X.Offset):toBe(moved)
	end)

	it("keeps the title bar on screen while dragging", function()
		player:SetAttribute("IsDeveloper", true)
		local screen = build()
		screen:Open()
		world:flush()
		button("TitleBar").InputBegan:Fire({
			UserInputType = Enum.UserInputType.MouseButton1,
			Position = Vector3.new(0, 0, 0),
		})
		world.fakeServices.UserInputService.InputChanged:Fire({
			UserInputType = Enum.UserInputType.MouseMovement,
			Position = Vector3.new(-5000, -5000, 0),
		})
		local window = button("Window")
		expect(window.Position.Y.Offset):toBe(0)
		expect(window.Position.X.Offset > -300):toBe(true)
	end)

	it("switches tabs without closing", function()
		player:SetAttribute("IsDeveloper", true)
		local screen = build()
		screen:Open()
		world:flush()
		expect(button("PageMONEY").Visible):toBe(true)
		expect(button("PageITEMS").Visible):toBe(false)
		press(button("TabITEMS"))
		expect(button("PageMONEY").Visible):toBe(false)
		expect(button("PageITEMS").Visible):toBe(true)
		expect(closed):toBe(0)
	end)

	it("shows the last result in the status line", function()
		player:SetAttribute("IsDeveloper", true)
		local screen = build()
		screen:Open()
		world:flush()
		press(button("Money1K"))
		world:flush()
		expect(button("Status").Text):toBe("ok money")
	end)

	it("shows server errors in the status line", function()
		player:SetAttribute("IsDeveloper", true)
		world:packets().AdminCommand.Fire = function()
			return "Not allowed"
		end
		local screen = build()
		screen:Open()
		world:flush()
		press(button("Money1K"))
		world:flush()
		expect(button("Status").Text):toBe("Not allowed")
	end)

	describe("buttons", function()
		local screen

		local function tap(name: string)
			press(button(name))
			world:flush()
		end

		beforeEach(function()
			player:SetAttribute("IsDeveloper", true)
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


		it("sends the custom amount through Add and Set", function()
			tap("AddAmount")
			expect(sent):toEqual({})
			expect(button("Status").Text):toBe("Enter an amount")
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

		it("resets a named player only after two taps and never sends all", function()
			button("TargetInput").Text = "Buddy"
			tap("ResetData")
			expect(sent):toEqual({})
			tap("ResetData")
			expect(sent):toEqual({ { "resetdata", "confirm Buddy" } })
		end)

		it("needs two taps to remove all pets and honours the target", function()
			tap("RemovePets")
			expect(sent):toEqual({})
			tap("RemovePets")
			expect(sent):toEqual({ { "removepets", "" } })
			button("TargetInput").Text = "Buddy"
			tap("RemovePets")
			tap("RemovePets")
			expect(sent[2]):toEqual({ "removepets", "Buddy" })
		end)

		it("confirms the two danger buttons independently", function()
			tap("ResetData")
			tap("RemovePets")
			expect(sent):toEqual({})
			tap("RemovePets")
			expect(sent):toEqual({ { "removepets", "" } })
		end)
	end)
end)
