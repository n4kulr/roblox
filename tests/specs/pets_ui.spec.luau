local H = require("../harness/Harness")
local roblox = require("@lune/roblox")

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

local screens = "StarterPlayer.StarterPlayerScripts.Controllers.UIController"

describe("Pets screen", function()
	local context, world, CharmConfig, Charms, screen, playerGui, data, observers, closed, toasts, market, refusal

	local function press(button: any)
		button.Activated:Fire({ UserInputType = roblox.Enum.UserInputType.MouseButton1 })
	end

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

	local function open(owned: { [string]: number })
		data.Charms = owned
		screen = world:require(`{screens}.Screens.Pets`).new(context)
		screen:Open()
		world.task.wait(0.4)
	end

	local function setCharms(owned: { [string]: number })
		data.Charms = owned
		for _, observer in observers do
			if observer.Path[1] == "Charms" then
				observer.Callback(owned)
			end
		end
	end

	local function names(holderName: string): { string }
		local holder = playerGui:FindFirstChild(holderName, true)
		local out = {}
		if holder then
			for _, card in holder:GetChildren() do
				if card.ClassName == "Frame" then
					table.insert(out, card.Name)
				end
			end
		end
		table.sort(out)
		return out
	end

	local function sorted(list: { string }): { string }
		local copy = table.clone(list)
		table.sort(copy)
		return copy
	end

	local function textOf(parent: any, name: string): string
		local node = parent:FindFirstChild(name, true)
		return if node then node.Text else ""
	end

	local function bonusTexts(): { [string]: string }
		local holder = playerGui:FindFirstChild("Bonuses", true)
		local out: { [string]: string } = {}
		if holder then
			for _, pill in holder:GetChildren() do
				if pill.ClassName == "Frame" then
					out[pill.Name] = textOf(pill, "Value")
				end
			end
		end
		return out
	end

	local function sectionTexts(): { string }
		local out = {}
		for _, item in playerGui:GetDescendants() do
			if item.ClassName == "TextLabel" then
				table.insert(out, item.Text)
			end
		end
		return out
	end

	local function hasText(text: string): boolean
		return table.find(sectionTexts(), text) ~= nil
	end

	local owned9 = {
		KeycapPin = 3,
		CloverFob = 1,
		BrassStab = 1,
		GoldenTick = 2,
		ThockPad = 1,
		StickyFingers = 1,
		LaserLens = 1,
		GoldSpacebar = 1,
		DiamondSpacebar = 1,
	}

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
		local Signal = world:require("ReplicatedStorage.Packages.Signal")
		CharmConfig = world:require("ReplicatedStorage.Config.Charms")
		Charms = world:require("ReplicatedStorage.Rules.Charms")
		local player = world:newPlayer({ Name = "Tester", DisplayName = "Tester" })
		player.GetAttributeChangedSignal = function()
			return Signal.new()
		end
		world.Players.LocalPlayer = player
		data = {}
		observers = {}
		closed = {}
		toasts = {}
		market = 0
		refusal = nil
		playerGui = world:newInstance("Folder")
		context = {
			Controllers = {
				DataController = {
					Get = function(_self: any, path: { any }?)
						return lookup(path or {})
					end,
					Observe = function(_self: any, path: { any }, callback: any)
						table.insert(observers, { Path = path, Callback = callback })
						callback(lookup(path))
						return function() end
					end,
				},
				RollController = {
					TeleportToMarket = function()
						market += 1
						return refusal == nil, refusal
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
			Toast = function(text: string, kind: string)
				table.insert(toasts, { Text = text, Kind = kind })
			end,
		}
	end)

	afterEach(function()
		if screen then
			screen:Destroy()
			screen = nil
		end
		expect(world.errors):toEqual({})
	end)

	it("keeps the same card instances when data is re-sent unchanged", function()
		open(owned9)
		local before = playerGui:FindFirstChild("Active", true):GetChildren()
		setCharms(table.clone(owned9))
		local after = playerGui:FindFirstChild("Active", true):GetChildren()
		expect(#after):toBe(#before)
		for index, card in before do
			expect(after[index] == card):toBe(true)
		end
	end)

	it("only rebuilds the cards whose count changed", function()
		open(owned9)
		local active = playerGui:FindFirstChild("Active", true)
		local stored = playerGui:FindFirstChild("Stored", true)
		local storedCards = stored:GetChildren()
		local target
		for _, card in storedCards do
			if card.ClassName == "Frame" then
				target = card
				break
			end
		end
		local untouched
		for _, card in active:GetChildren() do
			if card.ClassName == "Frame" then
				untouched = card
				break
			end
		end
		local more = table.clone(owned9)
		more[target.Name] = (more[target.Name] or 0) + 1
		setCharms(more)
		expect(untouched.Parent == playerGui:FindFirstChild("Active", true)):toBe(true)
		expect(playerGui:FindFirstChild("Stored", true):FindFirstChild(target.Name) == target):toBe(false)
	end)

	it("is a modal titled PETS", function()
		open(owned9)
		expect(screen.Modal):toBe(true)
		expect(hasText("PETS")):toBe(true)
	end)

	it("shows exactly the best active pets and stores the rest", function()
		open(owned9)
		local best = Charms.Best(owned9)
		expect(#best):toBe(CharmConfig.ActiveLimit)
		local activeIds: { [string]: boolean } = {}
		for _, id in best do
			activeIds[id] = true
		end
		local expectedActive: { string } = {}
		local expectedStored: { string } = {}
		for id, count in owned9 do
			local used = 0
			for _, bestId in best do
				if bestId == id then
					used += 1
				end
			end
			if used > 0 then
				table.insert(expectedActive, id)
			end
			if count - used > 0 then
				table.insert(expectedStored, id)
			end
		end
		expect(names("Active")):toEqual(sorted(expectedActive))
		expect(names("Stored")):toEqual(sorted(expectedStored))
		expect(hasText(`ACTIVE ({#best}/{CharmConfig.ActiveLimit})`)):toBe(true)
		expect(hasText("Only your best 6 pets are active")):toBe(true)
	end)

	it("shows the pet name, rarity, effect text and count on each card", function()
		open({ KeycapPin = 3, DiamondSpacebar = 1 })
		local card = playerGui:FindFirstChild("DiamondSpacebar", true)
		expect(textOf(card, "Name")):toBe("Diamond Dragon")
		expect(textOf(card:FindFirstChild("Rarity", true), "Text")):toBe("Mythic")
		expect(textOf(card, "Effect")):toBe(Charms.Describe("DiamondSpacebar"))
		expect(card:FindFirstChild("Count", true)):toBeNil()
		local stack = playerGui:FindFirstChild("KeycapPin", true)
		expect(textOf(stack:FindFirstChild("Count", true), "Text")):toBe("x3")
		expect(textOf(stack, "Effect")):toBe("x1.25 Income")
	end)

	it("sums the active bonuses with the Rules/Charms stacking math", function()
		local owned = {
			DiamondSpacebar = 1,
			GoldSpacebar = 1,
			LuckyCable = 1,
			CloverFob = 1,
			TurboSpring = 1,
			StickyFingers = 1,
			LaserLens = 1,
			GoldenTick = 1,
		}
		open(owned)
		local effects = Charms.Effects(Charms.Best(owned))
		local texts = bonusTexts()
		expect(texts.Income):toBe(`x{string.format("%g", math.floor(effects.Income * 100 + 0.5) / 100)} Income`)
		expect(texts.Luck):toBe(`x{string.format("%g", math.floor(effects.Luck * 100 + 0.5) / 100)} Luck`)
		expect(texts.Speed ~= nil or texts.Golden ~= nil or texts.Steal ~= nil or texts.Laser ~= nil):toBe(true)
	end)

	it("matches known combined totals", function()
		open({ DiamondSpacebar = 1, GoldSpacebar = 1, LuckyCable = 1, CloverFob = 1 })
		local texts = bonusTexts()
		expect(texts.Income):toBe("x14 Income")
		expect(texts.Luck):toBe("x2 Luck")
		expect(texts.Speed):toBeNil()
		expect(texts.Golden):toBeNil()
		expect(texts.Steal):toBeNil()
		expect(texts.Laser):toBeNil()
	end)

	it("formats every effect kind", function()
		open({
			TinySwitch = 1,
			QuickSpring = 1,
			GoldenTick = 1,
			StickyFingers = 1,
			LaserLens = 1,
		})
		local texts = bonusTexts()
		expect(texts.Speed):toBe("+30% Roll Speed")
		expect(texts.Golden):toBe("Golden -5 rolls")
		expect(texts.Steal):toBe("+25% Steal Speed")
		expect(texts.Laser):toBe("+10s Laser")
		expect(texts.Income):toBeNil()
		expect(texts.Luck):toBeNil()
	end)

	it("greys stored cards below the active ones", function()
		open(owned9)
		local stored = playerGui:FindFirstChild("Stored", true)
		local active = playerGui:FindFirstChild("Active", true)
		expect(#stored:GetChildren() > 0):toBe(true)
		expect(#active:GetChildren() > 0):toBe(true)
		expect(stored.LayoutOrder > active.LayoutOrder):toBe(true)
	end)

	it("hides the stored section when every pet is active", function()
		open({ KeycapPin = 2, DiamondSpacebar = 1 })
		expect(playerGui:FindFirstChild("Stored", true)):toBeNil()
		expect(hasText("Only your best 6 pets are active")):toBe(false)
		expect(hasText("ACTIVE (3/6)")):toBe(true)
	end)

	it("shows a friendly empty state with a SHOP button", function()
		open({})
		expect(hasText("Hatch eggs at the Egg Market to get pets!")):toBe(true)
		expect(playerGui:FindFirstChild("Bonuses", true)):toBeNil()
		expect(playerGui:FindFirstChild("Active", true)):toBeNil()
		local shop = playerGui:FindFirstChild("Shop", true)
		expect(shop ~= nil):toBe(true)
		expect(shop.Face.Text.Text):toBe("SHOP")
	end)

	it("teleports to the market from the empty state and closes the screen", function()
		open({})
		press(playerGui:FindFirstChild("Shop", true))
		expect(market):toBe(1)
		expect(closed):toEqual({ "Pets" })
	end)

	it("toasts the reason when the market teleport is refused", function()
		refusal = "Can't teleport while carrying a key!"
		open({})
		press(playerGui:FindFirstChild("Shop", true))
		expect(#closed):toBe(0)
		expect(toasts[1].Text):toBe(refusal)
		expect(toasts[1].Kind):toBe("Bad")
	end)

	it("updates live when Charms changes", function()
		open({})
		expect(hasText("Hatch eggs at the Egg Market to get pets!")):toBe(true)
		setCharms({ KeycapPin = 1 })
		expect(hasText("Hatch eggs at the Egg Market to get pets!")):toBe(false)
		expect(names("Active")):toEqual({ "KeycapPin" })
		expect(bonusTexts().Income):toBe("x1.25 Income")
		setCharms({ KeycapPin = 1, DiamondSpacebar = 1 })
		expect(names("Active")):toEqual({ "DiamondSpacebar", "KeycapPin" })
		expect(bonusTexts().Income):toBe("x10.25 Income")
		setCharms({})
		expect(hasText("Hatch eggs at the Egg Market to get pets!")):toBe(true)
	end)

	it("ignores unknown pet ids and bad counts", function()
		open({ KeycapPin = 1, Bogus = 4, ThockPad = 0 })
		expect(names("Active")):toEqual({ "KeycapPin" })
	end)

	it("closes through the red X", function()
		open(owned9)
		local close = playerGui:FindFirstChild("Close", true)
		expect(close ~= nil):toBe(true)
		press(close)
		expect(closed):toEqual({ "Pets" })
	end)
end)
