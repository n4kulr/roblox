local H = require("../harness/Harness")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

describe("Loading screen", function()
	local world, player, playerGui, Loader, Progress, Config

	local function frames(seconds: number)
		local steps = math.round(seconds / 0.05)
		for _ = 1, steps do
			world.fakeServices.RunService.Heartbeat:Fire(0.05)
		end
	end

	local function start()
		return Loader.Start(player)
	end

	local function gui()
		return playerGui:FindFirstChild("ThockLoading")
	end

	local function keyCount(): number
		local count = 0
		for _, row in Config.Rows do
			count += #row
		end
		return count
	end

	local function lit(): number
		local count = 0
		local board = gui().Background.Board
		for _, row in board:GetChildren() do
			if row:IsA("Frame") then
				for _, key in row:GetChildren() do
					if string.find(key.Name, "^Key_") and key.Face.BackgroundColor3 ~= Config.Unlit then
						count += 1
					end
				end
			end
		end
		return count
	end

	beforeEach(function()
		world = H.newWorld()
		player = world:newPlayer()
		world.Players.LocalPlayer = player
		playerGui = world:newInstance("Folder")
		playerGui.Name = "PlayerGui"
		playerGui.Parent = player
		Loader = world:require("ReplicatedFirst.Loading.Loader")
		Progress = world:require("ReplicatedFirst.Loading.Progress")
		Config = world:require("ReplicatedFirst.Loading.Config")
	end)

	it("removes the default screen and builds its gui", function()
		start()
		expect(world.defaultScreenRemovals):toBe(1)
		local root = gui()
		expect(root ~= nil):toBe(true)
		expect(root.IgnoreGuiInset):toBe(true)
		expect(root.ResetOnSpawn):toBe(false)
		expect(root.DisplayOrder >= 100000):toBe(true)
		expect(root:FindFirstChild("Skip", true).Visible):toBe(false)
		expect(root:FindFirstChild("Tip", true).Text):toBe(Config.Tips[1])
		expect(root:FindFirstChild("Title", true).Text):toBe(Config.Title)
		expect(root:FindFirstChild("Status", true).Text):toBe("LOADING 0%")
		local found = 0
		for _, item in root.Background.Board:GetDescendants() do
			if string.find(item.Name, "^Key_") then
				found += 1
			end
		end
		expect(found):toBe(keyCount())
		expect(#world.errors):toBe(0)
	end)

	it("builds flat keys without pill corners or gloss", function()
		start()
		local key = gui().Background.Board:FindFirstChild("Key_1", true)
		expect(key.Face:FindFirstChild("Gloss")):toBeNil()
		expect(key:FindFirstChild("Skirt")):toBeNil()
		expect(key.Face.UICorner.CornerRadius.Offset):toBe(6)
	end)

	it("skip is plain text, not a filled pill", function()
		start()
		local skip = gui():FindFirstChild("Skip", true)
		expect(skip.BackgroundTransparency):toBe(1)
		expect(skip:FindFirstChildOfClass("UICorner")):toBeNil()
	end)

	it("exits and destroys itself once loaded and the client is ready", function()
		local handle = start()
		frames(1)
		expect(gui() ~= nil):toBe(true)
		player:SetAttribute("ClientReady", true)
		frames(4)
		expect(handle:IsDone()):toBe(true)
		expect(gui()):toBe(nil)
		expect(#world.errors):toBe(0)
	end)

	it("stays up while the game is not loaded", function()
		world.gameLoaded = false
		local handle = start()
		player:SetAttribute("ClientReady", true)
		frames(10)
		expect(handle:IsDone()):toBe(false)
		world.gameLoaded = true
		frames(4)
		expect(handle:IsDone()):toBe(true)
	end)

	it("stays up while the client is not ready", function()
		local handle = start()
		frames(20)
		expect(handle:IsDone()):toBe(false)
		expect(gui() ~= nil):toBe(true)
	end)

	it("gives up waiting for the client after the timeout", function()
		local handle = start()
		frames(Config.Timeout - 1)
		expect(handle:IsDone()):toBe(false)
		frames(5)
		expect(handle:IsDone()):toBe(true)
		expect(gui()):toBe(nil)
	end)

	it("plays the exit in about 0.7 seconds", function()
		local handle = start()
		player:SetAttribute("ClientReady", true)
		frames(2.2)
		expect(handle:IsDone()):toBe(false)
		frames(0.3)
		expect(handle:IsDone()):toBe(false)
		frames(0.5)
		expect(handle:IsDone()):toBe(true)
	end)

	it("shows the skip button after 8 seconds and skip leaves once the game is loaded", function()
		local handle = start()
		frames(7.5)
		local skip = gui():FindFirstChild("Skip", true)
		expect(skip.Visible):toBe(false)
		frames(1)
		expect(skip.Visible):toBe(true)
		skip.Activated:Fire({})
		frames(2)
		expect(handle:IsDone()):toBe(true)
	end)

	it("skip still waits for the game to load", function()
		world.gameLoaded = false
		local handle = start()
		frames(9)
		gui():FindFirstChild("Skip", true).Activated:Fire({})
		frames(3)
		expect(handle:IsDone()):toBe(false)
		world.gameLoaded = true
		frames(2)
		expect(handle:IsDone()):toBe(true)
	end)

	it("lights keyboard keys from top-left as loading advances", function()
		start()
		expect(lit()):toBe(0)
		frames(1)
		local early = lit()
		frames(0.5)
		local later = lit()
		expect(early > 0):toBe(true)
		expect(later > early):toBe(true)
		expect(later < keyCount()):toBe(true)
		expect(gui():FindFirstChild("Click").Plays >= 1):toBe(true)
	end)

	it("computes progress from stages and the content queue", function()
		local function target(input: any)
			return Progress.Target(input)
		end
		expect(target({ Loaded = false, Ready = false, TimedOut = false, Queue = 0, MaxQueue = 0 })):toBe(0)
		expect(target({ Loaded = false, Ready = false, TimedOut = false, Queue = 5, MaxQueue = 10 })):toBe(0.2)
		expect(target({ Loaded = true, Ready = false, TimedOut = false, Queue = 0, MaxQueue = 10 }) < 1):toBe(true)
		expect(target({ Loaded = true, Ready = true, TimedOut = false, Queue = 0, MaxQueue = 10 })):toBe(1)
		expect(target({ Loaded = true, Ready = false, TimedOut = true, Queue = 3, MaxQueue = 10 })):toBe(1)
		expect(target({ Loaded = false, Ready = true, TimedOut = false, Queue = 0, MaxQueue = 0 }) < 1):toBe(true)
	end)

	it("reads the ready attribute the client bootstrap sets", function()
		local source = require("@lune/fs").readFile("src/client/Bootstrap.client.luau")
		expect(string.find(source, "SetAttribute(Attributes.ClientReady, true)", 1, true) ~= nil):toBe(true)
		expect(Config.ReadyAttribute):toBe("ClientReady")
	end)
end)
