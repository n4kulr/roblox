local H = require("../harness/Harness")
local S = require("../support")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

describe("Rules.Rebirth", function()
	local Rebirth

	beforeEach(function()
		Rebirth = H.newWorld():require("ReplicatedStorage.Rules.Rebirth")
	end)

	it("starts at the base cost and grows geometrically", function()
		expect(Rebirth.Cost(0)):toBe(1000000)
		expect(Rebirth.Cost(1)):toBe(4000000)
		expect(Rebirth.Cost(2)):toBe(16000000)
		expect(Rebirth.Cost(5)):toBe(1024000000)
	end)

	it("treats bad counts as zero rebirths", function()
		expect(Rebirth.Cost(-3)):toBe(1000000)
		expect(Rebirth.Cost(S.nan())):toBe(1000000)
		expect(Rebirth.IncomeMultiplier(-1)):toBe(1)
	end)

	it("adds the configured income per rebirth", function()
		expect(Rebirth.IncomeMultiplier(0)):toBe(1)
		expect(Rebirth.IncomeMultiplier(1)):toBeCloseTo(1.5, 1e-9)
		expect(Rebirth.IncomeMultiplier(2)):toBeCloseTo(2, 1e-9)
		expect(Rebirth.IncomeMultiplier(10)):toBeCloseTo(6, 1e-9)
	end)
end)

describe("RebirthService", function()
	local world, services, Rebirth, player, data

	beforeEach(function()
		world = H.newWorld({ Time = 1700000000 })
		services = world:boot({ "KeyboardService", "PassService", "RebirthService" })
		Rebirth = world:require("ReplicatedStorage.Rules.Rebirth")
	end)

	local function join(overrides: any)
		player, data = world:join(nil, overrides, false)
		return player, data
	end

	local function rebirth(): boolean
		return world:invoke("Rebirth", player)
	end

	it("rejects a player without enough Clicks and changes nothing", function()
		join({ Cash = 999999, IncomeAt = world.now, Upgrades = { Luck = 2, Speed = 1, Slots = 1 } })
		local before = H.deepCopy(data)
		expect(rebirth()):toBe(false)
		expect(data):toEqual(before)
	end)

	it("accepts exactly the cost", function()
		join({ Cash = 1000000, IncomeAt = world.now })
		expect(rebirth()):toBe(true)
		expect(data.Rebirths):toBe(1)
	end)

	it("settles income before checking the cost", function()
		join({ Cash = 999000, IncomeAt = world.now - 1000, Board = S.fill("PlainClack", 3) })
		expect(rebirth()):toBe(true)
		expect(data.Rebirths):toBe(1)
		expect(data.Cash):toBe(0)
	end)

	it("resets Clicks, upgrades and the income clock", function()
		join({ Cash = 5000000, IncomeAt = world.now - 5, Upgrades = { Luck = 4, Speed = 3, Slots = 2 } })
		expect(rebirth()):toBe(true)
		expect(data.Cash):toBe(0)
		expect(data.IncomeAt):toBe(world.now)
		expect(data.Upgrades):toEqual({ Luck = 0, Speed = 0, Slots = 0, Income = 0, Walls = 0, LockTime = 0, Golden = 0 })
		expect(data.Rebirths):toBe(1)
	end)

	it("resets the Income and base defense upgrades", function()
		join({
			Cash = 5000000,
			IncomeAt = world.now,
			Upgrades = { Luck = 1, Speed = 1, Slots = 1, Income = 6, Walls = 2, LockTime = 3 },
		})
		expect(rebirth()):toBe(true)
		expect(data.Upgrades):toEqual({ Luck = 0, Speed = 0, Slots = 0, Income = 0, Walls = 0, LockTime = 0, Golden = 0 })
	end)

	it("keeps keys, discoveries and everything else", function()
		join({
			Cash = 1000000,
			IncomeAt = world.now,
			Board = S.fill("PlainClack", 8),
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
		expect(data.Board[8]):toBe("PlainClack")
	end)

	it("moves keys beyond the base slots to the inventory", function()
		local GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		local board = S.fill("PlainClack", 12)
		board[11] = "GlassTink"
		board[12] = "GlassTink"
		join({
			Cash = 1000000,
			IncomeAt = world.now,
			Board = board,
			Upgrades = { Luck = 0, Speed = 0, Slots = 1 },
			Inventory = { GlassTink = 1 },
		})
		local before = S.totals(data)
		expect(rebirth()):toBe(true)
		for index = GameConfig.BaseSlots + 1, 12 do
			expect(data.Board[index]):toBe("")
		end
		for index = 1, GameConfig.BaseSlots do
			expect(data.Board[index]):toBe("PlainClack")
		end
		expect(data.Inventory.GlassTink):toBe(3)
		expect(S.totals(data)):toEqual(before)
	end)

	it("announces a board change", function()
		join({ Cash = 1000000, IncomeAt = world.now })
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
		join({ Cash = 1000000, IncomeAt = world.now })
		expect(rebirth()):toBe(true)
		data.Cash = 3999999
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

	describe("income", function()
		it("multiplies the board rate by the rebirth multiplier", function()
			join({ Board = S.fill("PlainClack", 3), Rebirths = 2 })
			expect(services.KeyboardService:GetRate(player)):toBe(6)
		end)

		it("pays the multiplied rate when settling", function()
			join({ Board = S.fill("PlainClack", 4), Rebirths = 1, IncomeAt = world.now - 100 })
			services.KeyboardService:Settle(player)
			expect(data.Cash):toBe(math.floor(4 * 1.5) * 100)
		end)

		it("stacks with pass multipliers", function()
			join({ Board = S.fill("PlainClack", 3), Rebirths = 2 })
			player:SetAttribute("Pass_DoubleClicks", true)
			expect(services.KeyboardService:GetRate(player)):toBe(12)
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
		local plots = world.workspace:FindFirstChild("Plots")
		local player, data = world:join(nil, {
			Cash = 5000000,
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
