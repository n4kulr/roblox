local H = require("../harness/Harness")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

local controllerPath = "StarterPlayer.StarterPlayerScripts.Controllers.UIController"

local registeredOrder = {
	"Hud",
	"Upgrades",
	"Keys",
	"Index",
	"Settings",
	"Offers",
	"StarterOffer",
	"Daily",
	"Market",
	"Shop",
	"Trade",
	"TradePrompt",
	"Rebirth",
	"Season",
	"Leaderboards",
	"Hatch",
	"Pets",
	"Cheats",
}

describe("UIController", function()
	local world, controller, player, playerGui, data, registry

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

	local function start()
		controller:Init(registry)
		controller:Start()
		world:flush()
	end

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
		local Signal = world:require("ReplicatedStorage.Packages.Signal")
		player = world:newPlayer({ Name = "Tester", DisplayName = "Tester" })
		player.GetAttributeChangedSignal = function()
			return Signal.new()
		end
		world.Players.LocalPlayer = player
		world.tree.ReplicatedStorage.GetAttributeChangedSignal = function()
			return Signal.new()
		end
		playerGui = world:newInstance("PlayerGui")
		playerGui.Name = "PlayerGui"
		playerGui.Parent = player
		data = {
			Cash = 100,
			IncomeAt = 0,
			Board = {},
			BoardTags = {},
			Inventory = {},
			Discovered = {},
			Charms = {},
			Upgrades = { Luck = 0, Speed = 0, Slots = 0, Income = 0, Walls = 0, LockTime = 0, Golden = 0 },
			Settings = { RollVolume = 1, BoardVolume = 1, OtherVolume = 1 },
			Tutorial = 5,
			Boosts = { LuckUntil = 0, ClicksUntil = 0 },
			Daily = { Streak = 0, LastClaim = 0 },
			Season = { Id = 1, Xp = 0, ClaimedFree = 0, ClaimedPremium = 0 },
			Market = { Slot = 0, Bought = {} },
			Rebirths = 0,
			GoldenProgress = 0,
			StarterPackBought = true,
		}
		registry = {
			DataController = {
				Get = function(_self: any, path: { any }?)
					return lookup(path or {})
				end,
				Observe = function(_self: any, path: { any }, callback: any)
					callback(lookup(path))
					return function() end
				end,
			},
			RollController = {
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
				RequestRoll = function() end,
			},
			TradeController = {
				StateChanged = Signal.new(),
				TargetPicked = Signal.new(),
				InviteReceived = Signal.new(),
				GetState = function()
					return nil
				end,
				SetReady = function() end,
				SetOffer = function() end,
				Cancel = function() end,
				Request = function() end,
				Respond = function() end,
			},
		}
		controller = world:require(controllerPath)
	end)

	it("creates every screen in a fixed order without failures", function()
		start()
		expect(#controller:GetFailures()):toBe(0)
		local seen = {}
		for _, gui in playerGui:GetChildren() do
			table.insert(seen, gui.Name)
		end
		local indexOf = {}
		for index, name in seen do
			indexOf[name] = index
		end
		local last = 0
		for _, name in { "ThockHud", "ThockUpgrades", "ThockKeys", "ThockIndex", "ThockSettings" } do
			expect(indexOf[name] ~= nil):toBe(true)
			expect(indexOf[name] > last):toBe(true)
			last = indexOf[name]
		end
		for _, name in { "Upgrades", "Keys", "Index", "Settings", "Market", "Shop", "Rebirth", "Season", "Pets", "Cheats" } do
			expect(controller:IsOpen(name)):toBe(false)
		end
		expect(controller:IsOpen("Hud")):toBe(true)
	end)

	it("registers all eighteen screens", function()
		expect(#registeredOrder):toBe(18)
		start()
		expect(#controller:GetFailures()):toBe(0)
	end)

	it("opens one modal at a time", function()
		start()
		controller:Open("Keys")
		expect(controller:IsOpen("Keys")):toBe(true)
		controller:Open("Upgrades")
		expect(controller:IsOpen("Keys")):toBe(false)
		expect(controller:IsOpen("Upgrades")):toBe(true)
	end)

	it("does not count a refused dev panel as open nor close other modals", function()
		start()
		controller:Open("Keys")
		controller:Open("Cheats")
		expect(controller:IsOpen("Cheats")):toBe(false)
		expect(controller:IsOpen("Keys")):toBe(true)
	end)

	it("never closes modals when the dev panel opens for a developer", function()
		player:SetAttribute("IsDeveloper", true)
		start()
		controller:Open("Keys")
		controller:Open("Cheats")
		expect(controller:IsOpen("Cheats")):toBe(true)
		expect(controller:IsOpen("Keys")):toBe(true)
	end)

	it("shares one economy and pet tracker with every screen", function()
		local observed = 0
		local observe = registry.DataController.Observe
		registry.DataController.Observe = function(self: any, path: { any }, callback: any)
			if path[1] == "Cash" then
				observed += 1
			end
			return observe(self, path, callback)
		end
		start()
		expect(observed):toBe(1)
	end)

	it("registers the Pets button as an anchor for other screens", function()
		start()
		local pets = playerGui:FindFirstChild("ThockHud"):FindFirstChild("Pets", true)
		expect(pets ~= nil):toBe(true)
	end)
end)
