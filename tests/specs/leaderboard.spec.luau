local H = require("../harness/Harness")
local S = require("../support")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

describe("TotalEarned", function()
	local world, services, GameConfig

	beforeEach(function()
		world = H.newWorld({ Time = 1700000000 })
		services = world:boot({ "KeyboardService", "PassService" })
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
	end)

	it("grows by the income paid when settling", function()
		local player, data = world:join(nil, { Board = S.fill("PlainClack", 3), IncomeAt = world.now - 100, Cash = 50 }, false)
		services.KeyboardService:Settle(player)
		expect(data.Cash):toBe(350)
		expect(data.TotalEarned):toBe(300)
	end)

	it("is not affected by spending", function()
		local player, data = world:join(nil, { Board = S.fill("PlainClack", 3), IncomeAt = world.now - 10, Cash = 500 }, false)
		services.KeyboardService:Settle(player)
		world.Data.Service:Set(player, { "Cash" }, 0)
		services.KeyboardService:Settle(player)
		expect(data.TotalEarned):toBe(30)
	end)

	it("accumulates across settles", function()
		local player, data = world:join(nil, { Board = S.fill("PlainClack", 2), IncomeAt = world.now - 10 }, false)
		services.KeyboardService:Settle(player)
		world:advance(5)
		services.KeyboardService:Settle(player)
		expect(data.TotalEarned):toBe(30)
	end)

	it("counts offline earnings", function()
		local _, data = world:join(
			nil,
			{ Board = S.fill("PlainClack", 4), IncomeAt = world.now - 1000, TotalEarned = 10 },
			true
		)
		local offline = math.floor(4 * 1000 * GameConfig.OfflineRate)
		expect(data.Cash):toBe(offline)
		expect(data.TotalEarned):toBe(10 + offline)
	end)

	it("counts the final settle when the player leaves", function()
		local player, data = world:join(nil, { Board = S.fill("PlainClack", 3) })
		services.KeyboardService:Settle(player)
		world:advance(20)
		world:removePlayer(player)
		expect(data.TotalEarned):toBe(60)
		expect(data.Cash):toBe(60)
	end)

	it("counts Clicks rewards", function()
		local Rewards = world:require("ServerScriptService.Utils.Rewards")
		local player, data = world:join()
		expect(Rewards.AddClicks(player, services, 2500)):toBe(true)
		expect(data.Cash):toBe(2500)
		expect(data.TotalEarned):toBe(2500)
	end)

	it("does not count failed grants", function()
		local Rewards = world:require("ServerScriptService.Utils.Rewards")
		local player, data = world:join()
		expect(Rewards.AddClicks(player, services, -5)):toBe(false)
		expect(data.TotalEarned):toBe(0)
	end)

	it("counts product Clicks", function()
		local bought = H.newWorld({ Time = 1700000000, AssetIds = { ClicksSmall = 777 } })
		bought:boot({ "KeyboardService", "PassService", "PurchaseService" })
		local player, data = bought:join()
		local amount = bought:require("ReplicatedStorage.Config.Monetization").ProductById.ClicksSmall.Amount
		local decision = bought:receipt(player, 777)
		expect(string.find(tostring(decision), "PurchaseGranted", 1, true) ~= nil):toBe(true)
		expect(data.Cash):toBe(amount)
		expect(data.TotalEarned):toBe(amount)
	end)
end)

describe("LeaderboardService", function()
	local world, services, GameConfig

	local function boot()
		services = world:boot({ "KeyboardService", "PassService", "LeaderboardService" })
	end

	local function board(player: any, index: number): { { Name: string, Value: number } }
		return world:invoke("GetLeaderboard", player, index)
	end

	local function seed(storeName: string, count: number)
		world.orderedStores[storeName] = world.orderedStores[storeName] or {}
		for userId = 1, count do
			world.orderedStores[storeName][tostring(userId)] = userId * 10
			world.userNames[userId] = `User{userId}`
		end
	end

	beforeEach(function()
		world = H.newWorld({ Time = 1700000000 })
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
	end)

	describe("leaderstats", function()
		it("creates Clicks, Rolls and Rebirths values from the data", function()
			boot()
			local player = world:join(nil, { Cash = 1234, Rolls = 56, Rebirths = 3 })
			local stats = player:FindFirstChild("leaderstats")
			expect(stats ~= nil):toBe(true)
			expect(stats.ClassName):toBe("Folder")
			expect(stats.Clicks.Value):toBe(1234)
			expect(stats.Rolls.Value):toBe(56)
			expect(stats.Rebirths.ClassName):toBe("NumberValue")
			expect(stats.Rebirths.Value):toBe(3)
		end)

		it("follows data changes at most once per second", function()
			boot()
			local player, data = world:join(nil, { Cash = 10, Rolls = 1, Rebirths = 0 })
			local stats = player:FindFirstChild("leaderstats")
			world.Data.Service:Set(player, { "Cash" }, 99)
			data.Rolls = 5
			data.Rebirths = 2
			world:advance(0.5)
			expect(stats.Clicks.Value):toBe(10)
			expect(stats.Rolls.Value):toBe(1)
			expect(stats.Rebirths.Value):toBe(0)
			world:advance(0.6)
			expect(stats.Clicks.Value):toBe(99)
			expect(stats.Rolls.Value):toBe(5)
			expect(stats.Rebirths.Value):toBe(2)
		end)

		it("gives each player their own folder", function()
			boot()
			local first = world:join(nil, { Cash = 1 })
			local second = world:join(nil, { Cash = 2 })
			expect(first:FindFirstChild("leaderstats").Clicks.Value):toBe(1)
			expect(second:FindFirstChild("leaderstats").Clicks.Value):toBe(2)
		end)

		it("does not create a second folder on repeated loads", function()
			boot()
			local player = world:join(nil, { Cash = 1 })
			world.Data.Service.PlayerLoaded:Fire(player, world.Data.Service:GetData(player))
			local folders = 0
			for _, child in player._children do
				if child.Name == "leaderstats" then
					folders += 1
				end
			end
			expect(folders):toBe(1)
		end)
	end)

	describe("submitting", function()
		it("writes each board for every player on the submit interval", function()
			boot()
			local player = world:join(nil, { TotalEarned = 900, Rolls = 40, Rebirths = 2 })
			expect(world.orderedWrites):toBe(0)
			world:advance(GameConfig.Leaderboards.SubmitSeconds + 1)
			local key = tostring(player.UserId)
			expect(world.orderedStores.TotalEarned_v1[key]):toBe(900)
			expect(world.orderedStores.Rolls_v1[key]):toBe(40)
			expect(world.orderedStores.Rebirths_v1[key]):toBe(2)
		end)

		it("writes the final values when a player leaves", function()
			boot()
			local player = world:join(nil, { TotalEarned = 5, Rolls = 6, Rebirths = 7 })
			world:removePlayer(player)
			local key = tostring(player.UserId)
			expect(world.orderedStores.TotalEarned_v1[key]):toBe(5)
			expect(world.orderedStores.Rolls_v1[key]):toBe(6)
			expect(world.orderedStores.Rebirths_v1[key]):toBe(7)
		end)

		it("survives datastore failures", function()
			boot()
			world.orderedDown = true
			local player = world:join(nil, { TotalEarned = 5 })
			world:advance(GameConfig.Leaderboards.SubmitSeconds + 1)
			world:removePlayer(player)
			expect(#world.errors):toBe(0)
			expect(next(world.orderedStores.TotalEarned_v1 or {})):toBeNil()
		end)
	end)

	describe("reading", function()
		it("returns the cached top entries sorted with names", function()
			seed("TotalEarned_v1", 5)
			boot()
			local viewer = world:join()
			local rows = board(viewer, 1)
			expect(#rows):toBe(5)
			expect(rows[1]):toEqual({ Name = "User5", Value = 50 })
			expect(rows[5]):toEqual({ Name = "User1", Value = 10 })
		end)

		it("keeps every board separate", function()
			seed("TotalEarned_v1", 3)
			world.orderedStores.Rolls_v1 = { ["9"] = 4 }
			world.orderedStores.Rebirths_v1 = { ["8"] = 2, ["9"] = 3 }
			world.userNames[8] = "Eight"
			world.userNames[9] = "Nine"
			boot()
			local viewer = world:join()
			expect(#board(viewer, 1)):toBe(3)
			expect(board(viewer, 2)):toEqual({ { Name = "Nine", Value = 4 } })
			expect(board(viewer, 3)):toEqual({ { Name = "Nine", Value = 3 }, { Name = "Eight", Value = 2 } })
		end)

		it("limits the list to the configured size", function()
			seed("Rolls_v1", GameConfig.Leaderboards.Size + 20)
			boot()
			local viewer = world:join()
			local rows = board(viewer, 2)
			expect(#rows):toBe(GameConfig.Leaderboards.Size)
			expect(rows[1].Value):toBe((GameConfig.Leaderboards.Size + 20) * 10)
		end)

		it("serves requests from the cache without touching the datastore", function()
			seed("TotalEarned_v1", 3)
			boot()
			local viewer = world:join()
			local reads = world.orderedReads
			for _ = 1, 10 do
				board(viewer, 1)
			end
			expect(world.orderedReads):toBe(reads)
		end)

		it("refreshes on the refresh interval", function()
			boot()
			local viewer = world:join()
			seed("TotalEarned_v1", 2)
			expect(#board(viewer, 1)):toBe(0)
			world:advance(GameConfig.Leaderboards.RefreshSeconds + 1)
			expect(#board(viewer, 1)):toBe(2)
		end)

		it("caches user names between refreshes", function()
			seed("TotalEarned_v1", 3)
			boot()
			local lookups = world.nameLookups
			expect(lookups):toBe(3)
			world:advance(GameConfig.Leaderboards.RefreshSeconds * 3 + 1)
			expect(world.nameLookups):toBe(lookups)
		end)

		it("falls back to a generic name when the lookup fails", function()
			seed("TotalEarned_v1", 2)
			world.userNames[2] = nil
			boot()
			local viewer = world:join()
			local rows = board(viewer, 1)
			expect(rows[1]):toEqual({ Name = "Player2", Value = 20 })
			expect(rows[2]):toEqual({ Name = "User1", Value = 10 })
		end)

		it("retries failed name lookups on the next refresh", function()
			seed("TotalEarned_v1", 1)
			world.nameFailures = 1
			boot()
			local viewer = world:join()
			expect(board(viewer, 1)[1].Name):toBe("Player1")
			world:advance(GameConfig.Leaderboards.RefreshSeconds + 1)
			expect(board(viewer, 1)[1].Name):toBe("User1")
		end)

		it("keeps the last good board when a refresh fails", function()
			seed("TotalEarned_v1", 3)
			boot()
			local viewer = world:join()
			world.orderedDown = true
			world:advance(GameConfig.Leaderboards.RefreshSeconds + 1)
			expect(#board(viewer, 1)):toBe(3)
			expect(#world.errors):toBe(0)
		end)

		it("rejects unknown boards", function()
			boot()
			local viewer = world:join()
			expect(board(viewer, 0)):toEqual({})
			expect(board(viewer, 4)):toEqual({})
			expect(board(viewer, 1.5)):toEqual({})
		end)
	end)

	describe("fallback", function()
		it("ranks the players in this server when the datastore is unavailable", function()
			world.orderedDown = true
			boot()
			local low = world:join({ Name = "Low" }, { TotalEarned = 10, Rolls = 90, Rebirths = 0 })
			local high = world:join({ Name = "High" }, { TotalEarned = 500, Rolls = 3, Rebirths = 4 })
			world:join({ Name = "Mid" }, { TotalEarned = 200, Rolls = 50, Rebirths = 1 })
			expect(board(low, 1)):toEqual({
				{ Name = "High", Value = 500 },
				{ Name = "Mid", Value = 200 },
				{ Name = "Low", Value = 10 },
			})
			expect(board(high, 2)[1]):toEqual({ Name = "Low", Value = 90 })
			expect(board(high, 3)[1]):toEqual({ Name = "High", Value = 4 })
		end)

		it("updates live as players join and leave", function()
			world.orderedDown = true
			boot()
			local first = world:join({ Name = "First" }, { TotalEarned = 1 })
			local second = world:join({ Name = "Second" }, { TotalEarned = 2 })
			expect(#board(first, 1)):toBe(2)
			world:removePlayer(second)
			expect(board(first, 1)):toEqual({ { Name = "First", Value = 1 } })
		end)

		it("is empty with nobody around", function()
			world.orderedDown = true
			boot()
			local viewer = world:join()
			world:removePlayer(viewer)
			expect(board(viewer, 1)):toEqual({})
		end)

		it("switches to the datastore once it recovers", function()
			world.orderedDown = true
			seed("TotalEarned_v1", 2)
			boot()
			local viewer = world:join({ Name = "Local" }, { TotalEarned = 7 })
			expect(board(viewer, 1)):toEqual({ { Name = "Local", Value = 7 } })
			world.orderedDown = false
			world:advance(GameConfig.Leaderboards.RefreshSeconds + 1)
			expect(#board(viewer, 1)):toBe(2)
			expect(board(viewer, 1)[1].Name):toBe("User2")
		end)
	end)

	it("clears its packet handler on Destroy", function()
		boot()
		services.LeaderboardService:Destroy()
		expect(world:packets().GetLeaderboard.OnServerInvoke):toBeNil()
	end)
end)
