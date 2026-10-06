local H = require("../harness/Harness")
local roblox = require("@lune/roblox")
local Layout = require("../../tools/ui_preview/Layout")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

local screens = "StarterPlayer.StarterPlayerScripts.Controllers.UIController"

describe("HUD golden fill", function()
	local world, playerGui

	local function build(count: number)
		local Signal = world:require("ReplicatedStorage.Packages.Signal")
		local player = world:newPlayer()
		world.Players.LocalPlayer = player
		world.tree.ReplicatedStorage.GetAttributeChangedSignal = function()
			return Signal.new()
		end
		playerGui = world:newInstance("Folder")
		local values: { [string]: any } = {
			GoldenProgress = count,
			Upgrades = { Golden = 0 },
			EquippedCharms = {},
		}
		local dataController = {
			Observe = function(_self: any, path: { any }, callback: any)
				callback(values[path[1]])
				return function() end
			end,
			Get = function(_self: any, path: { any }?)
				local node: any = values
				for _, part in path or {} do
					if type(node) ~= "table" then
						return nil
					end
					node = node[part]
				end
				return node
			end,
		}
		local rollController = {
			AutoChanged = Signal.new(),
			InBaseChanged = Signal.new(),
			IsInBase = function()
				return true
			end,
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
			RequestRoll = function()
				return true
			end,
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
		world.task.wait(0.3)
	end

	local function find(record: any, name: string): any
		if record.name == name then
			return record
		end
		for _, child in record.children do
			local found = find(child, name)
			if found then
				return found
			end
		end
		return nil
	end

	local function boundsAt(count: number): (any, any)
		build(count)
		local laidOut = Layout.Gui(playerGui:FindFirstChild("ThockHud"), roblox.Vector2.new(1280, 720))
		local golden = find({ name = "", children = laidOut.children }, "Golden")
		return golden, find(golden, "Fill")
	end

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
	end)

	for _, case in { { "0%", 0, 0 }, { "50%", 50, 0.5 }, { "98%", 98, 0.98 }, { "NEXT", 99, 1 } } do
		it(`keeps the fill inside the face at {case[1]}`, function()
			local golden, fill = boundsAt(case[2])
			expect(fill.x >= -0.01):toBe(true)
			expect(fill.y >= -0.01):toBe(true)
			expect(fill.x + fill.w <= golden.w + 0.01):toBe(true)
			expect(fill.y + fill.h <= golden.h + 0.01):toBe(true)
			expect(math.abs(fill.h - golden.h * case[3]) < 0.1):toBe(true)
			expect(math.abs(fill.y + fill.h - golden.h) < 0.1):toBe(true)
		end)
	end

	it("rounds the fill with the same corner radius as the button face and clips it", function()
		build(50)
		local golden = playerGui:FindFirstChild("ThockHud"):FindFirstChild("Golden", true)
		local fill = golden:FindFirstChild("Fill")
		local body = fill:FindFirstChild("Body")
		local faceCorner = golden:FindFirstChildOfClass("UICorner")
		local bodyCorner = body:FindFirstChildOfClass("UICorner")
		expect(bodyCorner ~= nil):toBe(true)
		expect(bodyCorner.CornerRadius):toEqual(faceCorner.CornerRadius)
		expect(fill.ClipsDescendants):toBe(true)
		expect(body.Size.X.Offset):toBe(golden.Size.X.Offset)
		expect(body.Size.Y.Offset):toBe(golden.Size.Y.Offset)
	end)

	it("keeps the NEXT shimmer inside the face with the same corner radius", function()
		build(99)
		local golden = playerGui:FindFirstChild("ThockHud"):FindFirstChild("Golden", true)
		local shimmer = golden:FindFirstChild("Shimmer")
		expect(shimmer.Visible):toBe(true)
		expect(shimmer.Size):toEqual(roblox.UDim2.fromScale(1, 1))
		expect(shimmer:FindFirstChildOfClass("UICorner").CornerRadius):toEqual(
			golden:FindFirstChildOfClass("UICorner").CornerRadius
		)
	end)
end)
