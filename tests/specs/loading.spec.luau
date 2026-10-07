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
		local letters = {}
		for _, name in { "T", "H", "O", "C", "K" } do
			table.insert(letters, name)
		end
		local found = {}
		for _, item in root.Content:GetChildren() do
			if item.Name == "Key" then
				table.insert(found, item.Face.Letter.Text)
			end
		end
		expect(found):toEqual(letters)
		expect(#world.errors):toBe(0)
	end)

	it("builds the key caps with a 3px outline and a gloss", function()
		start()
		local key = gui().Content:FindFirstChild("Key")
		expect(key.Face.UIStroke.Thickness):toBe(3)
		expect(key.Face.Gloss ~= nil):toBe(true)
		expect(key.Skirt ~= nil):toBe(true)
	end)

	it("types the keys down and back up", function()
		start()
		local face = gui().Content:FindFirstChild("Key").Face
		frames(0.05)
		frames(0.05)
		expect(face.Position.Y.Offset > 0):toBe(true)
		frames(1)
		expect(face.Position.Y.Offset <= 1):toBe(true)
	end)

	it("clicks once per press", function()
		start()
		frames(0.05)
		expect(gui():FindFirstChild("Click").Plays >= 1):toBe(true)
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

	it("plays the exit in about 0.8 seconds", function()
		local handle = start()
		player:SetAttribute("ClientReady", true)
		frames(2.2)
		expect(handle:IsDone()):toBe(false)
		frames(0.4)
		expect(handle:IsDone()):toBe(false)
		frames(0.5)
		expect(handle:IsDone()):toBe(true)
	end)

	it("shows plain text skip after 8 seconds and skip leaves once the game is loaded", function()
		local handle = start()
		frames(7.5)
		local skip = gui():FindFirstChild("Skip", true)
		expect(skip.Visible):toBe(false)
		frames(1)
		expect(skip.Visible):toBe(true)
		expect(skip.BackgroundTransparency):toBe(1)
		expect(skip:FindFirstChildOfClass("UICorner")):toBeNil()
		expect(gui().Background:FindFirstChild("Pulse") ~= nil):toBe(true)
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

	it("lights progress keys one by one as loading advances", function()
		start()
		local function lit()
			local count = 0
			for _, item in gui().Content.Under:GetChildren() do
				if string.find(item.Name, "^Bar") and item.Face.Position.Y.Offset > 0 then
					count += 1
				end
			end
			return count
		end
		expect(lit()):toBe(0)
		frames(1)
		local early = lit()
		frames(0.5)
		local later = lit()
		expect(early > 0):toBe(true)
		expect(later > early):toBe(true)
		expect(later < Config.ProgressKeys):toBe(true)
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
