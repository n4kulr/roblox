local H = require("../harness/Harness")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

describe("Rules.Season", function()
	local Season, GameConfig, SeasonLevels

	beforeEach(function()
		local world = H.newWorld()
		Season = world:require("ReplicatedStorage.Rules.Season")
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		SeasonLevels = world:require("ReplicatedStorage.Config.Season")
	end)

	local function progress(xp: number, free: number, premium: number)
		return { Xp = xp, ClaimedFree = free, ClaimedPremium = premium }
	end

	it("derives the level from xp", function()
		local per = GameConfig.Season.XpPerLevel
		expect(Season.Level(0)):toBe(0)
		expect(Season.Level(per - 1)):toBe(0)
		expect(Season.Level(per)):toBe(1)
		expect(Season.Level(per * 5 + 57)):toBe(5)
	end)

	it("caps the level at the last season level", function()
		expect(Season.Level(GameConfig.Season.XpPerLevel * 1000)):toBe(#SeasonLevels.Levels)
		expect(Season.Level(math.huge)):toBe(#SeasonLevels.Levels)
	end)

	it("never goes below zero", function()
		expect(Season.Level(-50)):toBe(0)
	end)

	it("only claims the next level in order", function()
		local season = progress(500, 0, 0)
		expect(Season.CanClaim(season, 1, false, false)):toBe(true)
		expect(Season.CanClaim(season, 2, false, false)):toBe(false)
		expect(Season.CanClaim(progress(500, 1, 0), 2, false, false)):toBe(true)
		expect(Season.CanClaim(progress(500, 1, 0), 1, false, false)):toBe(false)
	end)

	it("requires the level to be reached", function()
		expect(Season.CanClaim(progress(99, 0, 0), 1, false, false)):toBe(false)
		expect(Season.CanClaim(progress(100, 0, 0), 1, false, false)):toBe(true)
		expect(Season.CanClaim(progress(500, 5, 0), 6, false, false)):toBe(false)
	end)

	it("tracks the free and premium tracks separately", function()
		local season = progress(500, 3, 0)
		expect(Season.CanClaim(season, 1, true, true)):toBe(true)
		expect(Season.CanClaim(season, 4, true, true)):toBe(false)
		expect(Season.CanClaim(season, 4, false, true)):toBe(true)
	end)

	it("gates premium behind ownership", function()
		expect(Season.CanClaim(progress(500, 0, 0), 1, true, false)):toBe(false)
		expect(Season.CanClaim(progress(500, 0, 0), 1, true, true)):toBe(true)
	end)

	it("rejects levels outside the table and non-integers", function()
		local last = #SeasonLevels.Levels
		expect(Season.CanClaim(progress(1e9, last, 0), last + 1, false, false)):toBe(false)
		expect(Season.CanClaim(progress(500, 0, 0), 0.5, false, false)):toBe(false)
		expect(Season.CanClaim(progress(500, 0, 0), 0, false, false)):toBe(false)
	end)

	it("lists claimable rewards in order", function()
		local claims = Season.Claimable(progress(300, 1, 0), true)
		expect(#claims):toBe(5)
		expect(claims[1]):toEqual({ Level = 2, Premium = false })
		expect(claims[3]):toEqual({ Level = 1, Premium = true })
		expect(#Season.Claimable(progress(300, 1, 0), false)):toBe(2)
	end)

	it("looks up rewards by level and track", function()
		expect(Season.Reward(1, false)):toEqual(SeasonLevels.Levels[1].Free)
		expect(Season.Reward(1, true)):toEqual(SeasonLevels.Levels[1].Premium)
		expect(Season.Reward(999, false)):toBeNil()
	end)
end)

describe("SeasonService", function()
	local world, services, GameConfig, SeasonLevels, player, data

	beforeEach(function()
		world = H.newWorld({ Time = 1700000000, Seed = 3 })
		services = world:boot({ "KeyboardService", "PassService", "SeasonService", "RollService" })
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		SeasonLevels = world:require("ReplicatedStorage.Config.Season")
	end)

	local function join(season: any, extra: any?)
		local overrides = extra or {}
		overrides.Season = season
		player, data = world:joinAtBase(nil, overrides)
		return player, data
	end

	local function claim(level: number, premium: boolean): boolean
		return world:invoke("ClaimSeason", player, level, premium)
	end

	describe("season reset", function()
		it("resets progress when the season id changed", function()
			join({ Id = GameConfig.Season.Id + 1, Xp = 900, ClaimedFree = 4, ClaimedPremium = 2 })
			expect(data.Season):toEqual({ Id = GameConfig.Season.Id, Xp = 0, ClaimedFree = 0, ClaimedPremium = 0 })
		end)

		it("initialises a fresh profile for the current season", function()
			join({})
			expect(data.Season.Id):toBe(GameConfig.Season.Id)
			expect(data.Season.Xp):toBe(0)
		end)

		it("keeps progress within the same season", function()
			join({ Id = GameConfig.Season.Id, Xp = 250, ClaimedFree = 1, ClaimedPremium = 0 })
			expect(data.Season):toEqual({ Id = GameConfig.Season.Id, Xp = 250, ClaimedFree = 1, ClaimedPremium = 0 })
		end)
	end)

	describe("xp", function()
		it("adds XpPerRoll for a normal roll", function()
			join({ Id = GameConfig.Season.Id, Xp = 0, ClaimedFree = 0, ClaimedPremium = 0 })
			services.SeasonService:AddRoll(player, false)
			expect(data.Season.Xp):toBe(GameConfig.Season.XpPerRoll)
		end)

		it("adds XpPerGoldenRoll for a golden roll", function()
			join({ Id = GameConfig.Season.Id, Xp = 5, ClaimedFree = 0, ClaimedPremium = 0 })
			services.SeasonService:AddRoll(player, true)
			expect(data.Season.Xp):toBe(5 + GameConfig.Season.XpPerGoldenRoll)
		end)

		it("is awarded by successful rolls", function()
			join({ Id = GameConfig.Season.Id, Xp = 0, ClaimedFree = 0, ClaimedPremium = 0 })
			for _ = 1, 3 do
				world:invoke("Roll", player)
			end
			expect(data.Rolls):toBe(3)
			expect(data.Season.Xp):toBe(3 * GameConfig.Season.XpPerRoll)
		end)

		it("gives golden XP on the golden roll", function()
			join(
				{ Id = GameConfig.Season.Id, Xp = 0, ClaimedFree = 0, ClaimedPremium = 0 },
				{ Rolls = 500, GoldenProgress = GameConfig.GoldenRollEvery - 1 }
			)
			local _, isGolden = world:invoke("Roll", player)
			expect(isGolden):toBe(true)
			expect(data.Season.Xp):toBe(GameConfig.Season.XpPerGoldenRoll)
		end)

		it("gives no xp for rejected rolls", function()
			join({ Id = GameConfig.Season.Id, Xp = 0, ClaimedFree = 0, ClaimedPremium = 0 })
			for _ = 1, 10 do
				world:invoke("Roll", player)
			end
			expect(data.Season.Xp):toBe(data.Rolls * GameConfig.Season.XpPerRoll)
		end)
	end)

	describe("claims", function()
		local current

		beforeEach(function()
			current = { Id = GameConfig.Season.Id, Xp = 1000, ClaimedFree = 0, ClaimedPremium = 0 }
		end)

		it("grants the free reward and records the claim", function()
			join(current, { Cash = 0, IncomeAt = world.now })
			expect(claim(1, false)):toBe(true)
			expect(data.Season.ClaimedFree):toBe(1)
			expect(data.Season.ClaimedPremium):toBe(0)
			expect(data.Cash):toBe(SeasonLevels.Levels[1].Free.Amount)
			expect(data.TotalEarned):toBe(SeasonLevels.Levels[1].Free.Amount)
		end)

		it("enforces claiming in order", function()
			join(current, { IncomeAt = world.now })
			expect(claim(3, false)):toBe(false)
			expect(data.Season.ClaimedFree):toBe(0)
			expect(claim(1, false)):toBe(true)
			expect(claim(1, false)):toBe(false)
			expect(claim(2, false)):toBe(true)
			expect(data.Season.ClaimedFree):toBe(2)
		end)

		it("refuses levels that were not reached", function()
			current.Xp = 150
			join(current, { IncomeAt = world.now })
			expect(claim(1, false)):toBe(true)
			expect(claim(2, false)):toBe(false)
		end)

		it("refuses premium claims without the pass and grants nothing", function()
			join(current, { IncomeAt = world.now })
			expect(claim(1, true)):toBe(false)
			expect(data.Season.ClaimedPremium):toBe(0)
			expect(data.Cash):toBe(0)
		end)

		it("grants premium rewards once the pass is owned", function()
			join(current, { IncomeAt = world.now })
			player:SetAttribute("Pass_SeasonPremium", true)
			expect(claim(1, true)):toBe(true)
			expect(data.Season.ClaimedPremium):toBe(1)
			expect(data.Season.ClaimedFree):toBe(0)
			expect(data.Cash):toBe(SeasonLevels.Levels[1].Premium.Amount)
		end)

		it("grants potions", function()
			join(current, { IncomeAt = world.now })
			expect(claim(1, false)):toBe(true)
			expect(claim(2, false)):toBe(true)
			expect(data.Boosts.ClicksUntil):toBe(world.now + SeasonLevels.Levels[2].Free.Amount)
			expect(claim(3, false)):toBe(true)
			expect(data.Boosts.LuckUntil):toBe(world.now + SeasonLevels.Levels[3].Free.Amount)
		end)

		it("grants keys of the reward rarity", function()
			current.Xp = 100000
			join(current, { IncomeAt = world.now, Settings = { AutoPlace = false } })
			for level = 1, 5 do
				expect(claim(level, false)):toBe(true)
			end
			local total = 0
			for _, count in data.Inventory do
				total += count
			end
			expect(total):toBe(1)
			local Keys = world:require("ReplicatedStorage.Config.Keys")
			for keyId in data.Inventory do
				expect(Keys.ById[keyId].Rarity):toBe("Rare")
			end
		end)

		it("rejects malformed arguments", function()
			join(current, { IncomeAt = world.now })
			expect(world:invoke("ClaimSeason", player, "1", false)):toBe(false)
			expect(world:invoke("ClaimSeason", player, 1, "no")):toBe(false)
			expect(claim(0, false)):toBe(false)
			expect(claim(#SeasonLevels.Levels + 1, false)):toBe(false)
		end)

		it("fails for players without data", function()
			local stranger = world:newPlayer()
			expect(world:invoke("ClaimSeason", stranger, 1, false)):toBe(false)
		end)

		it("clears its packet handler on Destroy", function()
			services.SeasonService:Destroy()
			expect(world:packets().ClaimSeason.OnServerInvoke):toBeNil()
		end)
	end)
end)
