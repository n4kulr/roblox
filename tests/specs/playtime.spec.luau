local H = require("../harness/Harness")
local S = require("../support")
local roblox = require("@lune/roblox")
local Enum = roblox.Enum

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

local screens = "StarterPlayer.StarterPlayerScripts.Controllers.UIController"

describe("PlaytimeService", function()
	local world, services, GameConfig, Keys, player, data, tiers

	beforeEach(function()
		world = H.newWorld({ Time = 1700000000 })
		services = world:boot({ "KeyboardService", "PlaytimeService" })
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		Keys = world:require("ReplicatedStorage.Config.Keys")
		tiers = GameConfig.Playtime
		player, data = world:join(nil, { Settings = { AutoPlace = false } })
	end)

	local function claim(index: any, who: any?): boolean
		return world:invoke("ClaimPlaytime", who or player, index)
	end

	local function tierOf(kind: string): number
		for index, tier in tiers do
			if tier.Kind == kind then
				return index
			end
		end
		error(`no {kind} tier`)
	end

	local function keysOfRarity(rarity: string): number
		local total = 0
		for keyId, count in S.totals(data) do
			if Keys.ById[keyId].Rarity == rarity then
				total += count
			end
		end
		return total
	end

	it("defines ten tiers in time order from 10 seconds to an hour", function()
		expect(#tiers):toBe(10)
		expect(tiers[1].Seconds):toBe(10)
		expect(tiers[#tiers].Seconds):toBe(3600)
		for index = 2, #tiers do
			expect(tiers[index].Seconds > tiers[index - 1].Seconds):toBe(true)
		end
	end)

	it("publishes the session start and an empty claim mask", function()
		expect(player:GetAttribute("PlaytimeStart")):toBe(world.now)
		expect(player:GetAttribute("PlaytimeClaimed")):toBe(0)
	end)

	it("rejects every tier at join", function()
		for index = 1, #tiers do
			expect(claim(index)):toBe(false)
		end
		expect(data.Cash):toBe(0)
	end)

	it("unlocks tiers one by one as session time passes", function()
		world:advance(9)
		expect(claim(1)):toBe(false)
		world:advance(1)
		expect(claim(2)):toBe(false)
		expect(claim(1)):toBe(true)
		world:advance(40)
		expect(claim(2)):toBe(true)
		world:advance(69)
		expect(claim(3)):toBe(false)
		world:advance(1)
		expect(claim(3)):toBe(true)
	end)

	it("lets unlocked tiers be claimed in any order and keeps them available", function()
		world:advance(400)
		expect(claim(4)):toBe(true)
		expect(claim(2)):toBe(true)
		world:advance(1000)
		expect(claim(1)):toBe(true)
		expect(claim(3)):toBe(true)
		expect(player:GetAttribute("PlaytimeClaimed")):toBe(1 + 2 + 4 + 8)
	end)

	it("cannot claim a tier twice", function()
		world:advance(20)
		expect(claim(1)):toBe(true)
		local snapshot = S.snapshot(data)
		expect(claim(1)):toBe(false)
		expect(data.Cash):toBe(snapshot.Cash)
		expect(data.Boosts):toEqual(snapshot.Boosts)
		expect(data.Inventory):toEqual(snapshot.Inventory)
	end)

	it("pays the minimum cash when income is low", function()
		world:advance(20)
		expect(claim(1)):toBe(true)
		expect(data.Cash):toBe(tiers[1].Min)
	end)

	it("pays income seconds of cash when that beats the minimum", function()
		data.Board = S.fill("PlainClack", 8)
		data.IncomeAt = world.now
		local rate = services.KeyboardService:GetRate(player)
		expect(rate > 0):toBe(true)
		world:advance(20)
		local settled = data.Cash + rate * 20
		local expected = math.max(tiers[1].Min, math.floor(tiers[1].Amount * rate))
		expect(claim(1)):toBe(true)
		expect(math.abs(data.Cash - (settled + expected)) < 1e-6):toBe(true)
		expect(data.IncomeAt):toBe(world.now)
	end)

	it("adds paid cash to total earned", function()
		world:advance(20)
		expect(claim(1)):toBe(true)
		expect(data.TotalEarned):toBe(tiers[1].Min)
	end)

	it("extends the luck potion", function()
		local index = tierOf("LuckPotion")
		world:advance(tiers[index].Seconds)
		expect(claim(index)):toBe(true)
		expect(data.Boosts.LuckUntil):toBe(world.now + tiers[index].Amount)
	end)

	it("stacks onto an active luck potion", function()
		local index = tierOf("LuckPotion")
		world:advance(tiers[index].Seconds)
		data.Boosts.LuckUntil = world.now + 100
		expect(claim(index)):toBe(true)
		expect(data.Boosts.LuckUntil):toBe(world.now + 100 + tiers[index].Amount)
	end)

	it("extends the clicks potion and settles income first", function()
		local index = tierOf("ClicksPotion")
		data.Board = S.fill("PlainClack", 3)
		data.IncomeAt = world.now
		world:advance(tiers[index].Seconds)
		expect(claim(index)):toBe(true)
		expect(data.Boosts.ClicksUntil):toBe(world.now + tiers[index].Amount)
		expect(data.Cash):toBe(3 * tiers[index].Seconds)
		expect(data.IncomeAt):toBe(world.now)
	end)

	it("grants a random key of the tier rarity and counts it as discovered", function()
		local index = tierOf("Key")
		world:advance(tiers[index].Seconds)
		expect(claim(index)):toBe(true)
		expect(keysOfRarity(tiers[index].Rarity)):toBe(1)
		local discovered = 0
		for keyId, count in data.Discovered do
			expect(Keys.ById[keyId].Rarity):toBe(tiers[index].Rarity)
			discovered += count
		end
		expect(discovered):toBe(1)
	end)

	it("grants the right reward for every tier", function()
		world:advance(3600)
		for index, tier in tiers do
			local cash, luck, clicks = data.Cash, data.Boosts.LuckUntil, data.Boosts.ClicksUntil
			local keys = keysOfRarity(if tier.Kind == "Key" then tier.Rarity else "Common")
			expect(claim(index)):toBe(true)
			if tier.Kind == "Cash" then
				expect(data.Cash > cash):toBe(true)
			elseif tier.Kind == "LuckPotion" then
				expect(data.Boosts.LuckUntil > math.max(luck, world.now)):toBe(true)
			elseif tier.Kind == "ClicksPotion" then
				expect(data.Boosts.ClicksUntil > math.max(clicks, world.now)):toBe(true)
			else
				expect(keysOfRarity(tier.Rarity)):toBe(keys + 1)
			end
		end
		expect(player:GetAttribute("PlaytimeClaimed")):toBe(2 ^ #tiers - 1)
	end)

	it("resets the session when the player rejoins", function()
		world:advance(400)
		expect(claim(1)):toBe(true)
		world:removePlayer(player)
		world:advance(5)
		local again, againData = world:join(nil, { Settings = { AutoPlace = false } })
		expect(again:GetAttribute("PlaytimeStart")):toBe(world.now)
		expect(again:GetAttribute("PlaytimeClaimed")):toBe(0)
		expect(claim(1, again)):toBe(false)
		world:advance(10)
		expect(claim(1, again)):toBe(true)
		expect(againData.Cash):toBe(tiers[1].Min)
	end)

	it("forgets a player who left", function()
		world:advance(400)
		world:removePlayer(player)
		expect(claim(1)):toBe(false)
	end)

	it("keeps sessions separate between players", function()
		local other, otherData = world:join(nil, { Settings = { AutoPlace = false } })
		world:advance(20)
		expect(claim(1)):toBe(true)
		expect(otherData.Cash):toBe(0)
		expect(claim(1, other)):toBe(true)
		expect(claim(1, other)):toBe(false)
		expect(otherData.Cash):toBe(tiers[1].Min)
	end)

	it("ignores invalid indexes", function()
		world:advance(4000)
		local snapshot = S.snapshot(data)
		for _, bad in { 0, -1, 11, 255, 1.5, S.nan(), math.huge, -math.huge, "1", true, {}, 2 ^ 40 } do
			expect(claim(bad)):toBe(false)
		end
		expect(claim(nil)):toBe(false)
		expect(data.Cash):toBe(snapshot.Cash)
		expect(data.Boosts):toEqual(snapshot.Boosts)
		expect(data.Inventory):toEqual(snapshot.Inventory)
		expect(player:GetAttribute("PlaytimeClaimed")):toBe(0)
	end)

	it("returns false for a player without a session", function()
		local stranger = world:newPlayer()
		expect(claim(1, stranger)):toBe(false)
	end)

	it("clears its packet handler on Destroy", function()
		services.PlaytimeService:Destroy()
		expect(world:packets().ClaimPlaytime.OnServerInvoke):toBeNil()
	end)
end)

local function press(button: any)
	button.Activated:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
end

describe("Gifts screen", function()
	local world, playerGui, context, localPlayer, toasts, data

	local function build(name: string)
		return world:require(`{screens}.Screens.{name}`).new(context)
	end

	local function find(parent: any, name: string): any
		return parent:FindFirstChild(name, true)
	end

	local function tile(index: number): any
		return find(playerGui, `Gift{index}`)
	end

	local function statusOf(index: number): string
		return find(tile(index).Face, "Text").Text
	end

	beforeEach(function()
		world = H.newWorld({ Time = 1700000000, PrintErrors = false })
		local Signal = world:require("ReplicatedStorage.Packages.Signal")
		localPlayer = world:newPlayer({ Name = "Tester", DisplayName = "Tester" })
		localPlayer.GetAttributeChangedSignal = function()
			return Signal.new()
		end
		world.Players.LocalPlayer = localPlayer
		world.tree.ReplicatedStorage.GetAttributeChangedSignal = function()
			return Signal.new()
		end
		localPlayer:SetAttribute("PlaytimeStart", world.now)
		localPlayer:SetAttribute("PlaytimeClaimed", 0)
		data = {
			Cash = 0,
			IncomeAt = world.now,
			Board = { "PlainClack" },
			BoardTags = {},
			Inventory = {},
			Upgrades = { Luck = 0, Speed = 0, Slots = 0, Income = 0, Walls = 0, LockTime = 0, Golden = 0 },
			Boosts = { LuckUntil = 0, ClicksUntil = 0 },
			Rebirths = 0,
		}
		toasts = {}
		playerGui = world:newInstance("Folder")
		context = {
			Controllers = {
				DataController = {
					Get = function(_self: any, path: { any }?)
						local node: any = data
						for _, part in path or {} do
							node = if type(node) == "table" then node[part] else nil
						end
						return node
					end,
					Observe = function(_self: any, path: { any }, callback: any)
						local node: any = data
						for _, part in path do
							node = if type(node) == "table" then node[part] else nil
						end
						callback(node)
						return function() end
					end,
				},
			},
			PlayerGui = playerGui,
			Open = function() end,
			Close = function() end,
			IsOpen = function()
				return false
			end,
			Toast = function(text: string, kind: string?)
				table.insert(toasts, { text, kind })
			end,
		}
	end)

	it("builds ten gift tiles titled GIFTS with a hint", function()
		local screen = build("Daily")
		screen:Open()
		world:flush()
		for index = 1, 10 do
			expect(tile(index) ~= nil):toBe(true)
		end
		expect(find(playerGui, "Hint").Text):toBe("Play to unlock gifts!")
		expect(find(playerGui, "Title").Text):toBe("GIFTS")
		expect(#world.errors):toBe(0)
	end)

	it("shows live countdowns on locked tiles", function()
		local screen = build("Daily")
		screen:Open()
		world:flush()
		expect(statusOf(1)):toBe("0:10")
		expect(statusOf(2)):toBe("0:50")
		expect(statusOf(3)):toBe("2:00")
		expect(statusOf(10)):toBe("60:00")
		world:advance(5.3)
		world.fakeServices.RunService.Heartbeat:Fire(0.3)
		expect(statusOf(1)):toBe("0:05")
	end)

	it("shows READY once a tier unlocks and CLAIMED from the claim mask", function()
		localPlayer:SetAttribute("PlaytimeStart", world.now - 60)
		localPlayer:SetAttribute("PlaytimeClaimed", 1)
		local screen = build("Daily")
		screen:Open()
		world:flush()
		expect(statusOf(1)):toBe("CLAIMED")
		expect(find(tile(1).Face, "Check").Visible):toBe(true)
		expect(statusOf(2)):toBe("READY!")
		expect(find(tile(2).Face, "Check").Visible):toBe(false)
		expect(statusOf(3) ~= "READY!"):toBe(true)
	end)

	it("claims when the whole ready tile is clicked", function()
		localPlayer:SetAttribute("PlaytimeStart", world.now - 60)
		local fired = {}
		world:packets().ClaimPlaytime.Fire = function(_packet: any, index: number)
			table.insert(fired, index)
			return true
		end
		local screen = build("Daily")
		screen:Open()
		world:flush()
		press(tile(2))
		world:flush()
		expect(fired):toEqual({ 2 })
		expect(statusOf(2)):toBe("CLAIMED")
		expect(#toasts):toBe(1)
		expect(toasts[1][2]):toBe("Good")
		press(tile(2))
		world:flush()
		expect(fired):toEqual({ 2 })
	end)

	it("does not send claims for locked tiles", function()
		local fired = 0
		world:packets().ClaimPlaytime.Fire = function()
			fired += 1
			return true
		end
		local screen = build("Daily")
		screen:Open()
		world:flush()
		press(tile(5))
		world:flush()
		expect(fired):toBe(0)
		expect(#toasts):toBe(1)
		expect(toasts[1][2]):toBe("Info")
	end)

	it("toasts an error when the server refuses", function()
		localPlayer:SetAttribute("PlaytimeStart", world.now - 60)
		world:packets().ClaimPlaytime.Fire = function()
			return false
		end
		local screen = build("Daily")
		screen:Open()
		world:flush()
		press(tile(1))
		world:flush()
		expect(toasts[1][2]):toBe("Bad")
		expect(statusOf(1)):toBe("READY!")
	end)

	it("destroys cleanly", function()
		local screen = build("Daily")
		screen:Open()
		world:flush()
		screen:Destroy()
		expect(#world.errors):toBe(0)
	end)
end)

describe("Playtime progress", function()
	local Playtime, localPlayer, world

	beforeEach(function()
		world = H.newWorld({ Time = 1700000000 })
		Playtime = world:require(`{screens}.Playtime`)
		localPlayer = world:newPlayer()
	end)

	it("counts ready gifts and reports the next countdown", function()
		localPlayer:SetAttribute("PlaytimeStart", world.now)
		localPlayer:SetAttribute("PlaytimeClaimed", 0)
		local progress = Playtime.Read(localPlayer, world.now + 4)
		expect(progress.ReadyCount):toBe(0)
		expect(progress.NextLeft):toBe(6)
		progress = Playtime.Read(localPlayer, world.now + 60)
		expect(progress.ReadyCount):toBe(2)
		localPlayer:SetAttribute("PlaytimeClaimed", 1)
		progress = Playtime.Read(localPlayer, world.now + 60)
		expect(progress.ReadyCount):toBe(1)
		expect(progress.States[1]):toBe("Claimed")
	end)

	it("reports nothing before the session starts", function()
		local progress = Playtime.Read(localPlayer, world.now + 500)
		expect(progress.IsLoaded):toBe(false)
		expect(progress.ReadyCount):toBe(0)
		expect(progress.NextLeft):toBeNil()
	end)
end)
