local H = require("../harness/Harness")
local S = require("../support")

local roblox = require("@lune/roblox")
local Enum = roblox.Enum

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

local groupId = 4242
local cooldown = 43200
local screens = "StarterPlayer.StarterPlayerScripts.Controllers.UIController"

local function childNamed(parent: any, name: string): any
	for _, child in parent:GetChildren() do
		if child.Name == name then
			return child
		end
	end
	return nil
end

local function configure(world: any, overrides: any?)
	local copy = H.deepCopy(world:require("ReplicatedStorage.Config.GameConfig"))
	local chest = table.clone(copy.GroupChest)
	chest.GroupId = groupId
	for key, value in overrides or {} do
		chest[key] = value
	end
	copy.GroupChest = chest
	world.overrides[world:node("ReplicatedStorage.Config.GameConfig")] = copy
	return copy
end

describe("GroupChestService", function()
	local world, services, player, data

	local function setup(overrides: any?, groupConfigured: boolean?)
		world = H.newWorld({ Time = 1700000000 })
		if groupConfigured ~= false then
			configure(world, overrides)
		end
		services = world:boot({ "KeyboardService", "GroupChestService" })
		player, data = world:join(nil, { Settings = { AutoPlace = false } })
		world:setGroupMember(player, groupId, true)
	end

	local function claim(who: any?): number
		return world:invoke("ClaimGroupChest", who or player)
	end

	beforeEach(function()
		setup()
	end)

	it("pays income-scaled Clicks and a luck potion, then records the claim", function()
		data.Board = S.fill("PlainClack", 5)
		data.IncomeAt = world.now
		local rate = services.KeyboardService:GetRate(player)
		expect(rate):toBeGreaterThan(0)
		local before = data.Cash
		expect(claim()):toBe(0)
		expect(data.Cash):toBe(before + math.floor(600 * rate))
		expect(data.Boosts.LuckUntil):toBe(world.now + 600)
		expect(data.GroupChestAt):toBe(world.now)
		expect((world.saves[player] or 0) > 0):toBe(true)
	end)

	it("pays at least the minimum when income is tiny", function()
		data.Board = {}
		local before = data.Cash
		expect(claim()):toBe(0)
		expect(data.Cash):toBe(before + 1000)
	end)

	it("settles income before paying out", function()
		data.Board = S.fill("PlainClack", 5)
		data.IncomeAt = world.now - 10
		local cash = data.Cash
		expect(claim()):toBe(0)
		expect(data.IncomeAt):toBe(world.now)
		expect(data.Cash):toBe(cash + 50 + math.floor(600 * services.KeyboardService:GetRate(player)))
	end)

	it("stacks onto an active luck potion", function()
		data.Boosts.LuckUntil = world.now + 300
		expect(claim()):toBe(0)
		expect(data.Boosts.LuckUntil):toBe(world.now + 900)
	end)

	it("returns 1 for players outside the group and changes nothing", function()
		world:setGroupMember(player, groupId, false)
		local snapshot = S.snapshot(data)
		expect(claim()):toBe(1)
		expect(data.Cash):toBe(snapshot.Cash)
		expect(data.GroupChestAt):toBe(0)
		expect(data.Boosts):toEqual(snapshot.Boosts)
	end)

	it("lets a player claim right after joining the group", function()
		world:setGroupMember(player, groupId, false)
		expect(claim()):toBe(1)
		world:setGroupMember(player, groupId, true)
		expect(claim()):toBe(0)
	end)

	it("returns 2 during the cooldown and 0 exactly when it ends", function()
		expect(claim()):toBe(0)
		local cash = data.Cash
		expect(claim()):toBe(2)
		world:advance(cooldown - 1)
		expect(claim()):toBe(2)
		expect(data.Cash):toBe(cash)
		world:advance(1)
		expect(claim()):toBe(0)
		expect(data.GroupChestAt):toBe(world.now)
	end)

	it("returns 3 when no group is configured", function()
		setup(nil, false)
		expect(world:require("ReplicatedStorage.Config.GameConfig").GroupChest.GroupId):toBe(0)
		local cash = data.Cash
		expect(claim()):toBe(3)
		expect(data.Cash):toBe(cash)
		expect(data.GroupChestAt):toBe(0)
	end)

	it("treats a failing group lookup as not in the group and recovers", function()
		world.groupFailures = 1
		expect(claim()):toBe(1)
		expect(data.GroupChestAt):toBe(0)
		expect(claim()):toBe(0)
	end)

	it("caches membership for 60 seconds", function()
		setup({ CooldownSeconds = 10 })
		expect(claim()):toBe(0)
		expect(world.groupChecks):toBe(1)
		world:setGroupMember(player, groupId, false)
		world:advance(20)
		expect(claim()):toBe(0)
		expect(world.groupChecks):toBe(1)
		world:advance(70)
		expect(claim()):toBe(1)
		expect(world.groupChecks):toBe(2)
	end)

	it("rejects players without loaded data", function()
		local stranger = world:newPlayer()
		world:setGroupMember(stranger, groupId, true)
		expect(claim(stranger)):toBe(2)
	end)

	it("clears its packet handler on Destroy", function()
		services.GroupChestService:Destroy()
		expect(world:packets().ClaimGroupChest.OnServerInvoke):toBeNil()
	end)
end)

describe("GroupChestService chest", function()
	local world

	beforeEach(function()
		world = H.newWorld({ Time = 1700000000 })
	end)

	it("builds a default chest with a prompt and a sign at the map center", function()
		local services = world:boot({ "KeyboardService", "GroupChestService" })
		local model = childNamed(world.workspace, "GroupChest")
		expect(model ~= nil):toBe(true)
		local body = childNamed(model, "Body")
		expect(body.Size.X):toBe(8)
		expect(model.PrimaryPart == body):toBe(true)
		expect(childNamed(model, "Lid") ~= nil):toBe(true)
		expect(childNamed(model, "Lock") ~= nil):toBe(true)
		expect(childNamed(childNamed(model, "Glow"), "GlowLight") ~= nil):toBe(true)
		local prompt = childNamed(body, "ChestPrompt")
		expect(prompt.HoldDuration):toBe(0.5)
		expect(prompt.MaxActivationDistance):toBe(12)
		expect(prompt.ActionText):toBe("Open")
		local sign = childNamed(body, "ChestSign")
		expect(childNamed(sign, "Title").Text):toBe("GROUP CHEST")
		expect(childNamed(sign, "Subtitle").Text):toBe("Like the game + join the group!")
		local config = world:require("ReplicatedStorage.Config.GameConfig")
		expect(body.CFrame.X):toBe(config.Obby.MapCenter.X)
		expect(body.CFrame.Z):toBe(config.Obby.MapCenter.Z)
		services.GroupChestService:Destroy()
		expect(childNamed(world.workspace, "GroupChest")):toBeNil()
	end)

	it("uses an authored chest and only adds the missing prompt and sign", function()
		local authored = world:newInstance("Model")
		authored.Name = "GroupChest"
		local part = world:newPart("Lid", 5, 2, 5)
		part.Parent = authored
		authored.PrimaryPart = part
		authored.Parent = world.workspace
		local services = world:boot({ "KeyboardService", "GroupChestService" })
		local chests = 0
		for _, child in world.workspace:GetChildren() do
			if child.Name == "GroupChest" then
				chests += 1
			end
		end
		expect(chests):toBe(1)
		expect(childNamed(authored, "Body")):toBeNil()
		expect(childNamed(part, "ChestPrompt") ~= nil):toBe(true)
		expect(childNamed(part, "ChestSign") ~= nil):toBe(true)
		services.GroupChestService:Destroy()
		expect(childNamed(world.workspace, "GroupChest") == authored):toBe(true)
		expect(childNamed(part, "ChestPrompt")):toBeNil()
		expect(childNamed(part, "ChestSign")):toBeNil()
	end)

	it("keeps an authored prompt of its own", function()
		local part = world:newPart("GroupChest", 0, 2, 0)
		local prompt = world:newInstance("ProximityPrompt")
		prompt.Name = "ChestPrompt"
		prompt.Parent = part
		part.Parent = world.workspace
		local services = world:boot({ "KeyboardService", "GroupChestService" })
		expect(childNamed(part, "ChestPrompt") == prompt):toBe(true)
		services.GroupChestService:Destroy()
		expect(childNamed(part, "ChestPrompt") == prompt):toBe(true)
		expect(childNamed(part, "ChestSign")):toBeNil()
	end)
end)

describe("GroupChest screen", function()
	local world, screen, toasts, opened, closed, claims, player, context

	local function chestSubtitle(): any
		local model = childNamed(world.workspace, "GroupChest")
		return childNamed(childNamed(childNamed(model, "Body"), "ChestSign"), "Subtitle")
	end

	local function tickScreen()
		world.fakeServices.RunService.Heartbeat:Fire(1)
	end

	local function build(overrides: any?, stored: number?)
		world = H.newWorld({ PrintErrors = false })
		configure(world, overrides)
		world:boot({ "KeyboardService", "GroupChestService" })
		world:packets().ClaimGroupChest.OnServerInvoke = nil
		local Signal = world:require("ReplicatedStorage.Packages.Signal")
		player = world:newPlayer({ Name = "Tester" })
		player.GetAttributeChangedSignal = function()
			return Signal.new()
		end
		world.Players.LocalPlayer = player
		world.tree.ReplicatedStorage.GetAttributeChangedSignal = function()
			return Signal.new()
		end
		toasts, opened, closed, claims = {}, {}, {}, {}
		local data: any = {
			Cash = 0,
			IncomeAt = world.now,
			Board = { "PlainClack", "PlainClack" },
			Upgrades = {},
			Boosts = { LuckUntil = 0, ClicksUntil = 0 },
			Rebirths = 0,
			GroupChestAt = stored or 0,
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
		}
		context = {
			Controllers = controllers,
			PlayerGui = world:newInstance("Folder"),
			Open = function(name: string)
				table.insert(opened, name)
			end,
			Close = function(name: string)
				table.insert(closed, name)
			end,
			IsOpen = function()
				return false
			end,
			Toast = function(text: string, kind: string?)
				table.insert(toasts, { Text = text, Kind = kind })
			end,
		}
		world:packets().ClaimGroupChest.Fire = function()
			local result = table.remove(claims, 1)
			return result
		end
		screen = world:require(`{screens}.Screens.GroupChest`).new(context)
	end

	local function find(ctx: any, name: string): any
		for _, gui in ctx.PlayerGui:GetChildren() do
			local found = gui:FindFirstChild(name, true)
			if found then
				return found
			end
		end
		return nil
	end

	local function trigger()
		tickScreen()
		local model = childNamed(world.workspace, "GroupChest")
		childNamed(childNamed(model, "Body"), "ChestPrompt").Triggered:Fire(player)
	end

	local function press(button: any)
		button.Activated:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
	end

	it("shows the join prompt on the sign for non-members", function()
		build()
		tickScreen()
		expect(chestSubtitle().Text):toBe("Like the game + join the group!")
		screen:Destroy()
	end)

	it("shows READY for members and a countdown during the cooldown", function()
		build()
		world:setGroupMember(player, groupId, true)
		tickScreen()
		expect(chestSubtitle().Text):toBe("READY!")
		screen:Destroy()
		build(nil, world.now - 3600)
		world:setGroupMember(player, groupId, true)
		tickScreen()
		expect(chestSubtitle().Text):toBe("Ready in 11:00:00")
		screen:Destroy()
	end)

	it("says the group is coming soon when none is configured", function()
		build({ GroupId = 0 })
		trigger()
		expect(chestSubtitle().Text):toBe("Group coming soon!")
		expect(opened):toEqual({ "GroupChest" })
		expect(find(context, "Message").Text):toBe("Group coming soon!")
		expect(find(context, "Join").Visible):toBe(false)
		screen:Destroy()
	end)

	it("celebrates a successful claim with a toast", function()
		build()
		claims = { 0 }
		trigger()
		expect(toasts):toEqual({ { Text = "+1.2K Clicks + 10 min Luck Potion!", Kind = "Gold" } })
		expect(closed):toEqual({ "GroupChest" })
		screen:Destroy()
	end)

	it("opens the join popup when the server says not in group", function()
		build()
		claims = { 1 }
		trigger()
		expect(opened):toEqual({ "GroupChest" })
		expect(find(context, "Message").Text):toBe("Like the game and join our group to open the chest!")
		expect(find(context, "Join").Visible):toBe(true)
		screen:Destroy()
	end)

	it("prompts to join and retries the claim automatically", function()
		build()
		claims = { 1, 0 }
		trigger()
		press(find(context, "Join"))
		expect(world.groupPrompts):toEqual({ groupId })
		expect(#claims):toBe(0)
		expect(toasts[1].Kind):toBe("Gold")
		screen:Destroy()
	end)

	it("falls back to a search hint when the join prompt is unavailable", function()
		build()
		world.groupPromptUnavailable = true
		claims = { 1 }
		trigger()
		press(find(context, "Join"))
		expect(find(context, "Hint").Text):toBe("Search THOCK group on Roblox")
		expect(world.groupPrompts):toEqual({})
		screen:Destroy()
	end)

	it("toasts the time left during the cooldown", function()
		build()
		claims = { 2 }
		world:setGroupMember(player, groupId, true)
		trigger()
		expect(toasts[1].Kind):toBe("Info")
		expect(toasts[1].Text:sub(1, 20)):toBe("Chest opens again in")
		screen:Destroy()
	end)

	it("toasts a failure when the request fails", function()
		build()
		claims = { false }
		trigger()
		expect(toasts[1].Kind):toBe("Bad")
		screen:Destroy()
	end)

	it("stops listening after Destroy", function()
		build()
		trigger()
		screen:Destroy()
		claims = { 0 }
		childNamed(childNamed(childNamed(world.workspace, "GroupChest"), "Body"), "ChestPrompt").Triggered:Fire(player)
		expect(#claims):toBe(1)
	end)
end)
