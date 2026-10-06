local H = require("../harness/Harness")
local S = require("../support")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

describe("Rules.Rebirth", function()
	local Rebirth, GameConfig

	beforeEach(function()
		local world = H.newWorld()
		Rebirth = world:require("ReplicatedStorage.Rules.Rebirth")
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
	end)

	it("starts at the base cost and applies each step in turn", function()
		local config = GameConfig.Rebirth
		expect(Rebirth.Cost(0)):toBe(config.BaseCost)
		local expected = config.BaseCost
		for index = 1, #config.CostSteps + 3 do
			expected *= config.CostSteps[index] or config.CostGrowth
			expect(Rebirth.Cost(index)):toBe(math.floor(expected))
		end
	end)

	it("always costs more than the previous rebirth", function()
		for count = 0, 20 do
			expect(Rebirth.Cost(count + 1)):toBeGreaterThan(Rebirth.Cost(count))
		end
	end)

	it("grows the cost faster than the income multiplier", function()
		local config = GameConfig.Rebirth
		for index = 1, #config.CostSteps do
			expect(config.CostSteps[index]):toBeGreaterThan(1 + config.IncomePerRebirth)
		end
		expect(config.CostGrowth):toBeGreaterThan(1 + config.IncomePerRebirth)
	end)

	it("treats bad counts as zero rebirths", function()
		expect(Rebirth.Cost(-3)):toBe(Rebirth.Cost(0))
		expect(Rebirth.Cost(S.nan())):toBe(Rebirth.Cost(0))
		expect(Rebirth.IncomeMultiplier(-1)):toBe(1)
	end)

	it("adds the configured income per rebirth", function()
		local perRebirth = GameConfig.Rebirth.IncomePerRebirth
		expect(Rebirth.IncomeMultiplier(0)):toBe(1)
		for count = 1, 10 do
			expect(Rebirth.IncomeMultiplier(count)):toBeCloseTo(1 + perRebirth * count, 1e-9)
		end
	end)
end)

describe("RebirthService", function()
	local world, services, Rebirth, Keys, GameConfig, player, data

	beforeEach(function()
		world = H.newWorld({ Time = 1700000000 })
		services = world:boot({ "KeyboardService", "PassService", "RebirthService" })
		Rebirth = world:require("ReplicatedStorage.Rules.Rebirth")
		Keys = world:require("ReplicatedStorage.Config.Keys")
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
	end)

	local function join(overrides: any)
		player, data = world:join(nil, overrides, false)
		return player, data
	end

	local function rebirth(): boolean
		return world:invoke("Rebirth", player)
	end

	local function boardIsEmpty(): boolean
		for index = 1, GameConfig.BoardSlots do
			if data.Board[index] ~= "" then
				return false
			end
		end
		return true
	end

	it("rejects a player without enough Clicks and changes nothing", function()
		join({
			Cash = Rebirth.Cost(0) - 1,
			IncomeAt = world.now,
			Upgrades = { Luck = 2, Speed = 1, Slots = 1 },
			Board = S.fill("PlainClack", 3),
		})
		local before = H.deepCopy(data)
		expect(rebirth()):toBe(false)
		expect(data):toEqual(before)
	end)

	it("accepts exactly the cost", function()
		join({ Cash = Rebirth.Cost(0), IncomeAt = world.now })
		expect(rebirth()):toBe(true)
		expect(data.Rebirths):toBe(1)
	end)

	it("settles income before checking the cost", function()
		join({ Cash = Rebirth.Cost(0) - 1000, IncomeAt = world.now - 1000, Board = S.fill("PlainClack", 3) })
		expect(rebirth()):toBe(true)
		expect(data.Rebirths):toBe(1)
		expect(data.Cash):toBe(0)
	end)

	it("resets Clicks, upgrades and the income clock", function()
		join({
			Cash = Rebirth.Cost(0) * 5,
			IncomeAt = world.now - 5,
			Upgrades = { Luck = 4, Speed = 3, Slots = 2 },
		})
		expect(rebirth()):toBe(true)
		expect(data.Cash):toBe(0)
		expect(data.IncomeAt):toBe(world.now)
		expect(data.Upgrades):toEqual({
			Luck = 0,
			Speed = 0,
			Slots = 0,
			Income = 0,
			Walls = 0,
			LockTime = 0,
			Golden = 0,
		})
		expect(data.Rebirths):toBe(1)
	end)

	it("resets the Income and base defense upgrades", function()
		join({
			Cash = Rebirth.Cost(0) * 5,
			IncomeAt = world.now,
			Upgrades = { Luck = 1, Speed = 1, Slots = 1, Income = 6, Walls = 2, LockTime = 3 },
		})
		expect(rebirth()):toBe(true)
		expect(data.Upgrades):toEqual({
			Luck = 0,
			Speed = 0,
			Slots = 0,
			Income = 0,
			Walls = 0,
			LockTime = 0,
			Golden = 0,
		})
	end)

	it("keeps keys, discoveries and everything else", function()
		join({
			Cash = Rebirth.Cost(0),
			IncomeAt = world.now,
			Board = S.fill("PlainClack", GameConfig.BaseSlots),
			Inventory = { GlassTink = 2 },
			Discovered = { PlainClack = 9, GlassTink = 2 },
			Rolls = 77,
			TotalEarned = 123,
			RedeemedCodes = { THOCK = true },
			Season = { Id = 1, Xp = 40, ClaimedFree = 0, ClaimedPremium = 0 },
		})
		local before = H.deepCopy(data)
		expect(rebirth()):toBe(true)
		expect(S.totals(data)):toEqual(S.totals(before))
		expect(data.Discovered):toEqual(before.Discovered)
		expect(data.Rolls):toBe(77)
		expect(data.TotalEarned):toBe(123)
		expect(data.RedeemedCodes):toEqual({ THOCK = true })
		expect(data.Season):toEqual(before.Season)
	end)

	it("clears the whole board into the inventory", function()
		local slots = GameConfig.BaseSlots + 2
		local board = S.fill("PlainClack", slots)
		board[slots - 1] = "GlassTink"
		board[slots] = "GlassTink"
		join({
			Cash = Rebirth.Cost(0),
			IncomeAt = world.now,
			Board = board,
			BoardTags = { [1] = "Gift" },
			Upgrades = { Luck = 0, Speed = 0, Slots = 1 },
			Inventory = { GlassTink = 1 },
		})
		local before = S.totals(data)
		expect(rebirth()):toBe(true)
		expect(boardIsEmpty()):toBe(true)
		expect(data.BoardTags[1]):toBe("")
		expect(data.Inventory.GlassTink):toBe(3)
		expect(data.Inventory.PlainClack):toBe(slots - 2)
		expect(S.totals(data)):toEqual(before)
	end)

	it("announces a board change", function()
		join({ Cash = Rebirth.Cost(0), IncomeAt = world.now })
		local fired = 0
		services.KeyboardService.BoardChanged:Connect(function()
			fired += 1
		end)
		world:flush()
		rebirth()
		world:flush()
		expect(fired):toBe(1)
	end)

	it("raises the cost for the next rebirth", function()
		join({ Cash = Rebirth.Cost(0), IncomeAt = world.now })
		expect(rebirth()):toBe(true)
		data.Cash = Rebirth.Cost(1) - 1
		expect(rebirth()):toBe(false)
		data.Cash = Rebirth.Cost(1)
		expect(rebirth()):toBe(true)
		expect(data.Rebirths):toBe(2)
	end)

	it("fails for players without data", function()
		local stranger = world:newPlayer()
		expect(world:invoke("Rebirth", stranger)):toBe(false)
	end)

	it("clears its packet handler on Destroy", function()
		services.RebirthService:Destroy()
		expect(world:packets().Rebirth.OnServerInvoke):toBeNil()
	end)

	describe("right after a rebirth", function()
		local function strongPlayer()
			join({
				Cash = Rebirth.Cost(0),
				IncomeAt = world.now - 3600,
				Board = S.fill("LavaKey", GameConfig.BaseSlots),
				Inventory = { MeowKey = 2 },
			})
		end

		it("has no Clicks and no pending income", function()
			strongPlayer()
			expect(rebirth()):toBe(true)
			expect(data.Cash):toBe(0)
			expect(data.IncomeAt):toBe(world.now)
			expect(services.KeyboardService:GetRate(player)):toBe(0)
			world:advance(GameConfig.SettleIntervalSeconds * 3)
			services.KeyboardService:Settle(player)
			expect(data.Cash):toBe(0)
		end)

		it("rejects an immediate second rebirth even with the best keys equipped", function()
			strongPlayer()
			expect(rebirth()):toBe(true)
			expect(world:invoke("EquipBest", player)):toBe(true)
			expect(services.KeyboardService:GetRate(player)).never:toBe(0)
			expect(rebirth()):toBe(false)
			expect(data.Rebirths):toBe(1)
			services.KeyboardService:Settle(player)
			expect(rebirth()):toBe(false)
			expect(data.Rebirths):toBe(1)
		end)

		it("does not grant the time before the rebirth again when Settle runs", function()
			strongPlayer()
			expect(rebirth()):toBe(true)
			world:invoke("EquipBest", player)
			services.KeyboardService:Settle(player)
			services.KeyboardService:Settle(player)
			expect(data.Cash):toBe(0)
		end)

		it("takes cost divided by income at the new multiplier to afford the next one", function()
			strongPlayer()
			expect(rebirth()):toBe(true)
			expect(world:invoke("EquipBest", player)):toBe(true)
			local rate = services.KeyboardService:GetRate(player)
			local baseRate = 0
			for index = 1, GameConfig.BoardSlots do
				if data.Board[index] ~= "" then
					baseRate += Keys.GetIncome(data.Board[index])
				end
			end
			expect(rate):toBe(math.floor(baseRate * Rebirth.IncomeMultiplier(1)))
			local cost = Rebirth.Cost(1)
			local seconds = math.ceil(cost / rate)
			world:setTime(world.now + seconds - 1)
			expect(rebirth()):toBe(false)
			expect(data.Cash):toBe(rate * (seconds - 1))
			world:setTime(world.now + 1)
			expect(rebirth()):toBe(true)
			expect(data.Rebirths):toBe(2)
		end)

		it("makes every rebirth take longer than the one before on the same keys", function()
			strongPlayer()
			local previousSeconds = 0
			for count = 1, 4 do
				expect(rebirth()):toBe(true)
				expect(world:invoke("EquipBest", player)):toBe(true)
				local rate = services.KeyboardService:GetRate(player)
				local seconds = math.ceil(Rebirth.Cost(count) / rate)
				expect(seconds):toBeGreaterThan(previousSeconds)
				previousSeconds = seconds
				world:setTime(world.now + seconds)
				services.KeyboardService:Settle(player)
			end
		end)
	end)

	describe("income", function()
		it("multiplies the board rate by the rebirth multiplier", function()
			join({ Board = S.fill("PlainClack", 3), Rebirths = 2 })
			expect(services.KeyboardService:GetRate(player)):toBe(math.floor(3 * Rebirth.IncomeMultiplier(2)))
		end)

		it("pays the multiplied rate when settling", function()
			join({ Board = S.fill("PlainClack", 4), Rebirths = 1, IncomeAt = world.now - 100 })
			services.KeyboardService:Settle(player)
			expect(data.Cash):toBe(math.floor(4 * Rebirth.IncomeMultiplier(1)) * 100)
		end)

		it("stacks with pass multipliers", function()
			join({ Board = S.fill("PlainClack", 3), Rebirths = 2 })
			player:SetAttribute("Pass_DoubleClicks", true)
			expect(services.KeyboardService:GetRate(player)):toBe(
				math.floor(3 * 2 * Rebirth.IncomeMultiplier(2))
			)
		end)

		it("is unchanged at zero rebirths", function()
			join({ Board = S.fill("PlainClack", 3) })
			expect(services.KeyboardService:GetRate(player)):toBe(3)
		end)
	end)
end)

describe("RebirthService with plots", function()
	it("removes the glass walls after a rebirth", function()
		local world = H.newWorld({ Time = 1700000000 })
		world.workspace = world:newInstance("Folder")
		local plotService = world:require("ServerScriptService.Services.PlotService")
		world:boot(
			{ "KeyboardService", "PassService", "PlotService", "RebirthService" },
			{ PlotService = plotService }
		)
		local Rebirth = world:require("ReplicatedStorage.Rules.Rebirth")
		local plots = world.workspace:FindFirstChild("Plots")
		local player, data = world:join(nil, {
			Cash = Rebirth.Cost(0),
			IncomeAt = world.now,
			Upgrades = { Walls = 2, LockTime = 1 },
		}, true)
		world:flush()
		local function glassVisible(): boolean
			for _, plot in plots:GetChildren() do
				local folder = plot:FindFirstChild("GlassWalls")
				if folder and folder.Parent ~= nil and plot:GetAttribute("Owner") == player.UserId then
					return true
				end
			end
			return false
		end
		expect(glassVisible()):toBe(true)
		expect(world:invoke("Rebirth", player)):toBe(true)
		world:flush()
		expect(data.Upgrades.Walls):toBe(0)
		expect(data.Upgrades.LockTime):toBe(0)
		expect(glassVisible()):toBe(false)
		expect(world.errors):toEqual({})
		world:destroy()
	end)
end)
