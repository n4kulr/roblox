local roblox = require("@lune/roblox")
local H = require("../harness/Harness")
local S = require("../support")

local Vector3, Enum = roblox.Vector3, roblox.Enum
local describe, it, expect, afterEach = H.describe, H.it, H.expect, H.afterEach

describe("KeyfallService", function()
	local world, services, fake, GameConfig, Keys, config, steal, tree

	local function setup(keyfallOverrides: any?, prepare: (() -> ())?)
		world = H.newWorld({ Time = 1700000000 })
		local original = world:require("ReplicatedStorage.Config.GameConfig")
		local copy = H.deepCopy(original)
		copy.Keyfall.Enabled = true
		for key, value in keyfallOverrides or {} do
			copy.Keyfall[key] = value
		end
		world.overrides[world:node("ReplicatedStorage.Config.GameConfig")] = copy
		GameConfig = copy
		config = copy.Keyfall
		steal = copy.Steal
		Keys = world:require("ReplicatedStorage.Config.Keys")
		tree = world.workspace
		local plots: { [any]: any } = {}
		fake = { Name = "PlotService", Plots = plots }
		function fake.GetPlot(_self, player: any)
			return if plots[player] then {} else nil
		end
		function fake.GetCaps(_self, player: any)
			return if plots[player] then plots[player].Caps else nil
		end
		function fake.GetBase(_self, player: any)
			return if plots[player] then plots[player].Base else nil
		end
		function fake.Assign(player: any, x: number)
			local caps = {}
			for slot = 1, GameConfig.BoardSlots do
				caps[slot] = world:newPart(`Slot{slot}`, x + slot, 1, 10)
			end
			plots[player] = { Base = world:newPart("Base", x, 0, 0), Caps = caps }
		end
		if prepare then
			prepare()
		end
		services = world:boot({ "KeyboardService", "StealService", "KeyfallService" }, { PlotService = fake })
	end

	afterEach(function()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	local function join(name: string, baseX: number, overrides: any?)
		local data: any = { PlaySeconds = 5000, Board = S.board("GlassTink", "PlainClack") }
		for key, value in overrides or {} do
			data[key] = value
		end
		local player, loaded = world:join({ Name = name }, data, false)
		fake.Assign(player, baseX)
		world.Data.Service.PlayerLoaded:Fire(player, loaded)
		return player, loaded
	end

	local function spawnAt(player: any, x: number, z: number)
		world:spawnCharacter(player, x, 3, z)
	end

	local function capsFolder(): any
		return tree:FindFirstChild("KeyfallCaps")
	end

	local function allCaps(): { any }
		return capsFolder():GetChildren()
	end

	local function landedCaps(): { any }
		local out = {}
		for _, cap in allCaps() do
			if cap:GetAttribute("Landed") == true then
				table.insert(out, cap)
			end
		end
		return out
	end

	local function goldenCaps(): { any }
		local out = {}
		for _, cap in allCaps() do
			if cap:GetAttribute("KeyId") == config.GoldenSpacebarKeyId then
				table.insert(out, cap)
			end
		end
		return out
	end

	local function runUntil(predicate: () -> boolean, maxSeconds: number): boolean
		local waited = 0
		while not predicate() and waited < maxSeconds do
			world:advance(0.1)
			waited += 0.1
		end
		return predicate()
	end

	local function stand(player: any, cap: any)
		local at = cap.CFrame.Position
		world:moveCharacter(player, at.X, 3, at.Z)
	end

	local function count(player: any): number
		return player.Character:GetAttribute("KeyfallCount") or 0
	end

	local function grabNext(player: any): string
		expect(runUntil(function()
			return #landedCaps() > 0
		end, 60)):toBe(true)
		local cap = landedCaps()[1]
		local keyId = cap:GetAttribute("KeyId")
		stand(player, cap)
		world:advance(0.2)
		return keyId
	end

	local function fill(player: any, amount: number): { string }
		local ids = {}
		for _ = 1, amount do
			table.insert(ids, grabNext(player))
		end
		return ids
	end

	local function eventsOf(kind: number): { any }
		local out = {}
		for _, entry in world:firedOf("KeyfallEvent") do
			if entry.Args[1] == kind then
				table.insert(out, entry)
			end
		end
		return out
	end

	local function sorted(list: { string }): { string }
		local copy = table.clone(list)
		table.sort(copy)
		return copy
	end

	local function idsOf(caps: { any }): { string }
		local out = {}
		for _, cap in caps do
			table.insert(out, cap:GetAttribute("KeyId"))
		end
		return out
	end

	local function deliverAll(player: any, baseX: number)
		world:moveCharacter(player, baseX, 3, 0)
		world:advance(0.2)
	end

	describe("disabled", function()
		it("builds nothing, drops nothing and refuses knocks when Enabled is false", function()
			setup({ Enabled = false })
			expect(tree:FindFirstChild("KeyfallArena")):toBeNil()
			expect(tree:FindFirstChild("KeyfallCaps")):toBeNil()
			world:advance(120)
			expect(tree:FindFirstChild("KeyfallCaps")):toBeNil()
			local player = world:join({ UserId = 9001, Name = "Knocker" })
			expect(world:invoke("Knock", player, 9002)):toBe(false)
		end)
	end)

	describe("arena", function()
		it("builds a placeholder floor at the arena centre when none is authored", function()
			setup()
			local arena = tree:FindFirstChild("KeyfallArena")
			expect(arena ~= nil):toBe(true)
			local floor = arena:FindFirstChild("Floor")
			expect(floor.Size.Y):toBe(config.ArenaRadius * 2)
			local at = floor.CFrame.Position
			expect(at.X):toBe(config.ArenaCenter.X)
			expect(at.Z):toBe(config.ArenaCenter.Z)
			expect(#arena:GetChildren() <= 3):toBe(true)
		end)

		it("uses an authored workspace.Arena floor for position and size", function()
			setup(nil, function()
				local arena = world:newInstance("Folder")
				arena.Name = "Arena"
				local floor = world:newPart("Floor", 100, 5, -50)
				floor.Size = Vector3.new(60, 2, 40)
				floor.Parent = arena
				arena.Parent = world.workspace
			end)
			expect(tree:FindFirstChild("KeyfallArena")):toBeNil()
			world:advance(60)
			expect(#allCaps()):toBeGreaterThan(5)
			for _, cap in allCaps() do
				local at = cap.CFrame.Position
				expect(math.sqrt((at.X - 100) ^ 2 + (at.Z + 50) ^ 2)):toBeLessThan(20.001)
				expect(at.Y):toBeGreaterThan(5)
			end
		end)
	end)

	describe("drops", function()
		it("spawns one falling cap per interval", function()
			setup()
			expect(#allCaps()):toBe(0)
			world:advance(config.DropIntervalSeconds + 0.1)
			expect(#allCaps()):toBe(1)
			world:advance(config.DropIntervalSeconds)
			expect(#allCaps()):toBe(2)
			world:advance(config.DropIntervalSeconds)
			expect(#allCaps()):toBe(3)
		end)

		it("starts high, falls, then lands", function()
			setup()
			world:advance(config.DropIntervalSeconds + 0.1)
			local cap = allCaps()[1]
			expect(cap:GetAttribute("Landed")):toBe(false)
			expect(cap.CFrame.Position.Y):toBeGreaterThan(config.ArenaCenter.Y + 10)
			world:advance(0.4)
			local mid = cap.CFrame.Position.Y
			world:advance(0.4)
			expect(cap.CFrame.Position.Y):toBeLessThan(mid)
			world:advance(0.6)
			expect(cap:GetAttribute("Landed")):toBe(true)
			expect(cap.CFrame.Position.Y):toBeLessThan(config.ArenaCenter.Y + 2)
			expect(cap.Anchored):toBe(true)
		end)

		it("drops inside the arena disc with a valid key id", function()
			setup({ DropIntervalSeconds = 0.5, MaxLiveCaps = 100 })
			world:advance(40)
			expect(#allCaps()):toBeGreaterThan(10)
			for _, cap in allCaps() do
				local at = cap.CFrame.Position
				local dx, dz = at.X - config.ArenaCenter.X, at.Z - config.ArenaCenter.Z
				expect(math.sqrt(dx * dx + dz * dz)):toBeLessThan(config.ArenaRadius + 0.001)
				expect(Keys.ById[cap:GetAttribute("KeyId")] ~= nil):toBe(true)
			end
		end)

		it("never drops exclusive keys", function()
			setup({ DropIntervalSeconds = 0.2, MaxLiveCaps = 1000, CapLifetimeSeconds = 1000, DropLuck = 100000 })
			world:advance(120)
			expect(#allCaps()):toBeGreaterThan(300)
			for _, cap in allCaps() do
				expect(Keys.ById[cap:GetAttribute("KeyId")].Exclusive):toBe(false)
			end
		end)

		it("stops spawning at MaxLiveCaps", function()
			setup({ MaxLiveCaps = 4, CapLifetimeSeconds = 1000 })
			world:advance(60)
			expect(#allCaps()):toBe(4)
		end)

		it("resumes spawning once caps are removed", function()
			setup({ MaxLiveCaps = 2, CapLifetimeSeconds = 1000 })
			world:advance(30)
			expect(#allCaps()):toBe(2)
			allCaps()[1]:Destroy()
			expect(#allCaps()):toBe(1)
		end)

		it("expires caps after their lifetime", function()
			setup({ MaxLiveCaps = 1, CapLifetimeSeconds = 5, DropIntervalSeconds = 100 })
			world:advance(100.1)
			local cap = allCaps()[1]
			expect(cap ~= nil):toBe(true)
			world:advance(1.2 + 4.5)
			expect(cap.Parent ~= nil):toBe(true)
			world:advance(1)
			expect(cap.Parent):toBeNil()
			expect(#allCaps()):toBe(0)
		end)

		it("keeps the live count bounded by lifetime", function()
			setup()
			world:advance(120)
			expect(#allCaps()):toBeLessThan(config.CapLifetimeSeconds / config.DropIntervalSeconds + 3)
		end)
	end)

	describe("pickup", function()
		it("picks up a landed cap in range", function()
			setup({ MaxLiveCaps = 1, CapLifetimeSeconds = 1000 })
			local player = join("Ann", 200)
			spawnAt(player, 0, 0)
			expect(runUntil(function()
				return #landedCaps() == 1
			end, 20)):toBe(true)
			local cap = landedCaps()[1]
			local keyId = cap:GetAttribute("KeyId")
			stand(player, cap)
			world:advance(0.3)
			expect(count(player)):toBe(1)
			expect(cap.Parent):toBeNil()
			expect(services.KeyfallService:IsCarrying(player)):toBe(true)
			expect(player.Character:GetAttribute("KeyfallCount")):toBe(1)
			local stack = {}
			for _, child in player.Character:GetChildren() do
				if child.Name == "KeyfallStack" then
					table.insert(stack, child)
				end
			end
			expect(#stack):toBe(1)
			expect(Keys.ById[keyId] ~= nil):toBe(true)
		end)

		it("ignores caps out of range", function()
			setup({ MaxLiveCaps = 1, CapLifetimeSeconds = 1000 })
			local player = join("Ann", 200)
			spawnAt(player, 0, 0)
			expect(runUntil(function()
				return #landedCaps() == 1
			end, 20)):toBe(true)
			local cap = landedCaps()[1]
			local at = cap.CFrame.Position
			world:moveCharacter(player, at.X + config.PickupRange + 1, 3, at.Z)
			world:advance(1)
			expect(count(player)):toBe(0)
			expect(cap.Parent ~= nil):toBe(true)
			world:moveCharacter(player, at.X + config.PickupRange - 1, 3, at.Z)
			world:advance(0.3)
			expect(count(player)):toBe(1)
		end)

		it("cannot grab a cap that is still falling", function()
			setup({ MaxLiveCaps = 1, CapLifetimeSeconds = 1000 })
			local player = join("Ann", 200)
			spawnAt(player, 0, 0)
			world:advance(config.DropIntervalSeconds + 0.3)
			local cap = allCaps()[1]
			expect(cap:GetAttribute("Landed")):toBe(false)
			stand(player, cap)
			world:advance(0.3)
			expect(count(player)):toBe(0)
			world:advance(1.5)
			expect(count(player)):toBe(1)
		end)

		it("stops at the carry limit and leaves the rest on the ground", function()
			setup({ MaxLiveCaps = 6, CapLifetimeSeconds = 1000 })
			local player = join("Ann", 200)
			spawnAt(player, 0, 0)
			fill(player, config.CarryLimit)
			expect(count(player)):toBe(config.CarryLimit)
			expect(runUntil(function()
				return #landedCaps() >= 2
			end, 30)):toBe(true)
			local extra = landedCaps()[1]
			stand(player, extra)
			world:advance(1)
			expect(count(player)):toBe(config.CarryLimit)
			expect(extra.Parent ~= nil):toBe(true)
		end)

		it("does not pick up while carrying a stolen key", function()
			setup({ MaxLiveCaps = 1, CapLifetimeSeconds = 1000 })
			local player = join("Ann", 200)
			spawnAt(player, 0, 0)
			player.Character:SetAttribute("CarryingKey", "GlassTink")
			expect(runUntil(function()
				return #landedCaps() == 1
			end, 20)):toBe(true)
			local cap = landedCaps()[1]
			stand(player, cap)
			world:advance(1)
			expect(count(player)):toBe(0)
			expect(cap.Parent ~= nil):toBe(true)
			player.Character:SetAttribute("CarryingKey", nil)
			world:advance(0.3)
			expect(count(player)):toBe(1)
		end)

		it("slows the player by the carried count and shows the stack", function()
			setup({ MaxLiveCaps = 4, CapLifetimeSeconds = 1000 })
			local player = join("Ann", 200)
			spawnAt(player, 0, 0)
			expect(world:walkSpeed(player)):toBe(16)
			for carried = 1, 3 do
				fill(player, 1)
				expect(world:walkSpeed(player)):toBe(steal.NormalWalkSpeed - config.CarrySlowPerCap * carried)
				local stack = 0
				for _, child in player.Character:GetChildren() do
					if child.Name == "KeyfallStack" then
						stack += 1
					end
				end
				expect(stack):toBe(carried)
			end
		end)

		it("does not let two players take the same cap", function()
			setup({ MaxLiveCaps = 1, CapLifetimeSeconds = 1000 })
			local first = join("Ann", 200)
			local second = join("Bea", -200)
			spawnAt(first, 0, 0)
			spawnAt(second, 0, 0)
			expect(runUntil(function()
				return #landedCaps() == 1
			end, 20)):toBe(true)
			local cap = landedCaps()[1]
			stand(first, cap)
			stand(second, cap)
			world:advance(0.3)
			expect(count(first) + count(second)):toBe(1)
		end)
	end)

	describe("steal interaction", function()
		it("refuses steals while carrying keyfall caps, then allows them after delivery", function()
			setup({ MaxLiveCaps = 3, CapLifetimeSeconds = 1000 })
			local victim, victimData = join("Vic", 300)
			local thief, thiefData = join("Bob", -300, { Board = S.board("OfficeTap") })
			spawnAt(victim, 300, 0)
			spawnAt(thief, 0, 0)
			fill(thief, 1)
			expect(services.KeyfallService:IsCarrying(thief)):toBe(true)
			local prompt = fake.Plots[victim].Caps[1]:FindFirstChild("StealPrompt")
			world:moveCharacter(thief, 301, 3, 10)
			prompt.PromptButtonHoldBegan:Fire(thief)
			prompt.Triggered:Fire(thief)
			prompt.PromptButtonHoldEnded:Fire(thief)
			expect(victimData.Board[1]):toBe("GlassTink")
			expect(thief.Character:GetAttribute("CarryingKey")):toBeNil()
			local rejected = {}
			for _, entry in world:firedOf("StealAlert") do
				if entry.Target == thief and entry.Args[3] == 9 then
					table.insert(rejected, entry.Args[1])
				end
			end
			expect(rejected):toEqual({ "You're already carrying a key!" })
			deliverAll(thief, -300)
			expect(services.KeyfallService:IsCarrying(thief)):toBe(false)
			expect(thiefData.Board[2] ~= nil):toBe(true)
			world:moveCharacter(thief, 301, 3, 10)
			prompt.PromptButtonHoldBegan:Fire(thief)
			prompt.Triggered:Fire(thief)
			prompt.PromptButtonHoldEnded:Fire(thief)
			expect(victimData.Board[1]):toBe("")
			expect(thief.Character:GetAttribute("CarryingKey")):toBe("GlassTink")
		end)
	end)

	describe("delivery", function()
		it("adds every carried cap to the board or inventory and counts discoveries", function()
			setup({ MaxLiveCaps = 6, CapLifetimeSeconds = 1000 })
			local player, data = join("Ann", 200)
			spawnAt(player, 0, 0)
			local before = S.totals(data)
			local discoveredBefore = H.deepCopy(data.Discovered)
			local ids = fill(player, config.CarryLimit)
			expect(count(player)):toBe(config.CarryLimit)
			world:clearFired()
			deliverAll(player, 200)
			local after = S.totals(data)
			local expected = table.clone(before)
			for _, id in ids do
				expected[id] = (expected[id] or 0) + 1
			end
			expect(after):toEqual(expected)
			local expectedDiscovered = table.clone(discoveredBefore)
			for _, id in ids do
				expectedDiscovered[id] = (expectedDiscovered[id] or 0) + 1
			end
			expect(data.Discovered):toEqual(expectedDiscovered)
			expect(player.Character:GetAttribute("KeyfallCount")):toBeNil()
			expect(world:walkSpeed(player)):toBe(steal.NormalWalkSpeed)
			expect(services.KeyfallService:IsCarrying(player)):toBe(false)
			for _, child in player.Character:GetChildren() do
				expect(child.Name ~= "KeyfallStack"):toBe(true)
			end
			local toasts = {}
			for _, entry in world:firedOf("KeyfallEvent") do
				if entry.Target == player then
					table.insert(toasts, entry.Args)
				end
			end
			expect(#toasts):toBe(1)
			expect(toasts[1][1]):toBe(4)
			expect(toasts[1][2]):toBe("")
			expect(toasts[1][3]):toBe(config.CarryLimit)
		end)

		it("does not deliver outside the deliver radius", function()
			setup({ MaxLiveCaps = 3, CapLifetimeSeconds = 1000 })
			local player, data = join("Ann", 200)
			spawnAt(player, 0, 0)
			local before = S.totals(data)
			fill(player, 1)
			world:moveCharacter(player, 200 + steal.DeliverRadius + 2, 3, 0)
			world:advance(1)
			expect(count(player)):toBe(1)
			expect(S.totals(data)):toEqual(before)
		end)

		it("keeps the caps when the player has no loaded data to deliver into", function()
			setup({ MaxLiveCaps = 3, CapLifetimeSeconds = 1000 })
			local player = join("Ann", 200)
			spawnAt(player, 0, 0)
			fill(player, 1)
			world.Data._data[player] = nil
			world:moveCharacter(player, 200, 3, 0)
			world:advance(1)
			expect(services.KeyfallService:IsCarrying(player)):toBe(true)
		end)
	end)

	describe("knock", function()
		local function carrier(amount: number): (any, any, { string })
			local victim = join("Vic", 200)
			local attacker = join("Bob", -200)
			spawnAt(victim, 0, 0)
			local ids = fill(victim, amount)
			local at = victim.Character.HumanoidRootPart.CFrame.Position
			spawnAt(attacker, at.X + config.KnockRange - 1, at.Z)
			world:advance(0.2)
			return victim, attacker, ids
		end

		it("drops the top carried cap on the ground where the target stands", function()
			setup({ MaxLiveCaps = 3, CapLifetimeSeconds = 1000 })
			local victim, attacker, ids = carrier(2)
			local at = victim.Character.HumanoidRootPart.CFrame.Position
			local before = #allCaps()
			expect(world:invoke("Knock", attacker, victim.UserId)):toBe(true)
			expect(count(victim)):toBe(1)
			expect(#allCaps()):toBe(before + 1)
			local dropped
			for _, cap in allCaps() do
				if cap:GetAttribute("Landed") and cap:GetAttribute("KeyId") == ids[2] then
					local position = cap.CFrame.Position
					if math.abs(position.X - at.X) < 0.01 and math.abs(position.Z - at.Z) < 0.01 then
						dropped = cap
					end
				end
			end
			expect(dropped ~= nil):toBe(true)
			expect(dropped.CFrame.Position.Y):toBeLessThan(at.Y)
		end)

		it("lets the dropped cap be picked up again", function()
			setup({ MaxLiveCaps = 3, CapLifetimeSeconds = 1000 })
			local victim, attacker, ids = carrier(2)
			world:invoke("Knock", attacker, victim.UserId)
			world:advance(0.3)
			expect(count(victim)):toBe(1)
			world:advance(1.5)
			expect(count(victim)):toBe(2)
			world:advance(0.2)
			expect(services.KeyfallService:IsCarrying(victim)):toBe(true)
			deliverAll(victim, 200)
			local delivered = S.totals(world.Data:Replica(victim).Data)
			for _, id in ids do
				expect((delivered[id] or 0) >= 1):toBe(true)
			end
		end)

		it("fails when the caller is out of range", function()
			setup({ MaxLiveCaps = 3, CapLifetimeSeconds = 1000 })
			local victim, attacker = carrier(1)
			local at = victim.Character.HumanoidRootPart.CFrame.Position
			world:moveCharacter(attacker, at.X + config.KnockRange + 2, 3, at.Z)
			expect(world:invoke("Knock", attacker, victim.UserId)):toBe(false)
			expect(count(victim)):toBe(1)
		end)

		it("fails on a target carrying nothing or an invalid target", function()
			setup({ MaxLiveCaps = 3, CapLifetimeSeconds = 1000 })
			local victim, attacker = carrier(1)
			expect(world:invoke("Knock", victim, attacker.UserId)):toBe(false)
			expect(world:invoke("Knock", attacker, 99999)):toBe(false)
			expect(world:invoke("Knock", attacker, "abc")):toBe(false)
			expect(world:invoke("Knock", attacker, S.nan())):toBe(false)
			expect(world:invoke("Knock", attacker, attacker.UserId)):toBe(false)
			expect(count(victim)):toBe(1)
		end)

		it("enforces the per-caller cooldown", function()
			setup({ MaxLiveCaps = 3, CapLifetimeSeconds = 1000 })
			local victim, attacker = carrier(3)
			expect(world:invoke("Knock", attacker, victim.UserId)):toBe(true)
			expect(world:invoke("Knock", attacker, victim.UserId)):toBe(false)
			expect(count(victim)):toBe(2)
			world:advance(config.KnockCooldown + 0.1)
			local carried = count(victim)
			expect(world:invoke("Knock", attacker, victim.UserId)):toBe(true)
			expect(count(victim)):toBe(carried - 1)
		end)

		it("clears the carry state when the last cap is knocked loose", function()
			setup({ MaxLiveCaps = 3, CapLifetimeSeconds = 1000 })
			local victim, attacker = carrier(1)
			expect(world:invoke("Knock", attacker, victim.UserId)):toBe(true)
			expect(victim.Character:GetAttribute("KeyfallCount")):toBeNil()
			expect(services.KeyfallService:IsCarrying(victim)):toBe(false)
			expect(world:walkSpeed(victim)):toBe(steal.NormalWalkSpeed)
		end)
	end)

	describe("death, reset and leaving", function()
		it("drops every carried cap where the player died", function()
			setup({ MaxLiveCaps = 3, CapLifetimeSeconds = 1000 })
			local player = join("Ann", 200)
			spawnAt(player, 0, 0)
			local ids = fill(player, 3)
			expect(#allCaps()):toBe(0)
			local at = player.Character.HumanoidRootPart.CFrame.Position
			world:killCharacter(player)
			expect(#allCaps()):toBe(3)
			expect(sorted(idsOf(allCaps()))):toEqual(sorted(ids))
			for _, cap in allCaps() do
				local position = cap.CFrame.Position
				expect(math.sqrt((position.X - at.X) ^ 2 + (position.Z - at.Z) ^ 2)):toBeLessThan(config.PickupRange)
				expect(cap:GetAttribute("Landed")):toBe(true)
			end
			expect(services.KeyfallService:IsCarrying(player)):toBe(false)
		end)

		it("does not pick caps up while dead, and can again after respawning", function()
			setup({ MaxLiveCaps = 3, CapLifetimeSeconds = 1000 })
			local player = join("Ann", 200)
			spawnAt(player, 0, 0)
			fill(player, 3)
			local at = player.Character.HumanoidRootPart.CFrame.Position
			world:killCharacter(player)
			world:advance(2)
			expect(count(player)):toBe(0)
			spawnAt(player, at.X, at.Z)
			world:advance(1)
			expect(count(player)):toBeGreaterThan(0)
		end)

		it("drops caps when the character is reset", function()
			setup({ MaxLiveCaps = 3, CapLifetimeSeconds = 1000 })
			local player = join("Ann", 200)
			spawnAt(player, 0, 0)
			local ids = fill(player, 2)
			local before = #allCaps()
			world:resetCharacter(player)
			expect(#allCaps()):toBe(before + 2)
			expect(services.KeyfallService:IsCarrying(player)):toBe(false)
			local found = idsOf(allCaps())
			for _, id in ids do
				expect(table.find(found, id) ~= nil):toBe(true)
			end
		end)

		it("makes carried caps vanish when the player leaves", function()
			setup({ MaxLiveCaps = 3, CapLifetimeSeconds = 1000 })
			local player = join("Ann", 200)
			spawnAt(player, 0, 0)
			fill(player, 3)
			expect(#allCaps()):toBe(0)
			world:removePlayer(player)
			expect(#allCaps()):toBe(0)
			world:advance(1)
			expect(services.KeyfallService:IsCarrying(player)):toBe(false)
		end)
	end)

	describe("golden spacebar", function()
		local function golden(overrides: any?): any
			local base: any = {
				DropIntervalSeconds = 1000,
				GoldenSpacebarMinSeconds = 10,
				GoldenSpacebarMaxSeconds = 10,
			}
			for key, value in overrides or {} do
				base[key] = value
			end
			return base
		end

		local function landedGolden(): any
			expect(runUntil(function()
				local caps = goldenCaps()
				return #caps == 1 and caps[1]:GetAttribute("Landed") == true
			end, 60)):toBe(true)
			return goldenCaps()[1]
		end

		it("first falls within the configured window", function()
			setup({ DropIntervalSeconds = 1000 })
			local started = world.clock
			local appeared: number? = nil
			for _ = 1, 700 do
				world:advance(1)
				if #eventsOf(1) > 0 then
					appeared = world.clock - started
					break
				end
			end
			expect(appeared ~= nil):toBe(true)
			expect((appeared :: number) >= config.GoldenSpacebarMinSeconds):toBe(true)
			expect((appeared :: number) <= config.GoldenSpacebarMaxSeconds + 1):toBe(true)
			expect(#goldenCaps()):toBe(1)
		end)

		it("announces itself to everyone with kind 1 and is gold neon and large", function()
			setup(golden())
			world:advance(10.5)
			local events = eventsOf(1)
			expect(#events):toBe(1)
			expect(events[1].Target):toBe("All")
			expect(events[1].Args[2]):toBe("")
			expect(events[1].Args[3]):toBe(Keys.ById.GoldenSpacebar.Index)
			local cap = goldenCaps()[1]
			expect(cap:GetAttribute("KeyId")):toBe("GoldenSpacebar")
			expect(cap.Material):toBe(Enum.Material.Neon)
			expect(cap.Size.X):toBeGreaterThan(2.5)
		end)

		it("only ever has one at a time", function()
			setup(golden())
			local peak = 0
			for _ = 1, 150 do
				world:advance(1)
				peak = math.max(peak, #goldenCaps())
			end
			expect(peak):toBe(1)
		end)

		it("announces kind 5 when it expires unclaimed after 60 seconds", function()
			setup(golden())
			world:advance(10.5)
			world:advance(1.2)
			expect(#eventsOf(5)):toBe(0)
			world:advance(58)
			expect(#eventsOf(5)):toBe(0)
			expect(#goldenCaps()):toBe(1)
			world:advance(2)
			local vanished = eventsOf(5)
			expect(#vanished):toBe(1)
			expect(vanished[1].Target):toBe("All")
			expect(vanished[1].Args[2]):toBe("")
			expect(#goldenCaps()):toBe(0)
		end)

		it("can fall again after one has been resolved", function()
			setup(golden())
			world:advance(10.5)
			world:advance(75)
			expect(#eventsOf(1)):toBe(2)
		end)

		it("tells everyone who grabbed it with kind 2", function()
			setup(golden())
			local player = join("Ann", 200)
			spawnAt(player, 0, 0)
			local cap = landedGolden()
			stand(player, cap)
			world:advance(0.3)
			local grabbed = eventsOf(2)
			expect(#grabbed):toBe(1)
			expect(grabbed[1].Target):toBe("All")
			expect(grabbed[1].Args[2]):toBe("Ann")
			expect(#goldenCaps()):toBe(0)
			expect(count(player)):toBe(1)
			expect(world:walkSpeed(player)):toBe(steal.NormalWalkSpeed - config.CarrySlowPerCap)
		end)

		it("tells everyone who claimed it with kind 3 and adds the exclusive key", function()
			setup(golden())
			local player, data = join("Ann", 200)
			spawnAt(player, 0, 0)
			local before = S.totals(data)
			stand(player, landedGolden())
			world:advance(0.3)
			world:clearFired()
			deliverAll(player, 200)
			local claimed = eventsOf(3)
			expect(#claimed):toBe(1)
			expect(claimed[1].Target):toBe("All")
			expect(claimed[1].Args[2]):toBe("Ann")
			expect(S.totals(data).GoldenSpacebar):toBe((before.GoldenSpacebar or 0) + 1)
			expect(data.Discovered.GoldenSpacebar):toBe(1)
			local own = {}
			for _, entry in world:firedOf("KeyfallEvent") do
				if entry.Target == player then
					table.insert(own, entry.Args)
				end
			end
			expect(#own):toBe(1)
			expect(own[1][1]):toBe(4)
			expect(own[1][3]):toBe(1)
		end)

		it("can be knocked loose and stays unique", function()
			setup(golden())
			local victim = join("Vic", 200)
			local attacker = join("Bob", -200)
			spawnAt(victim, 0, 0)
			stand(victim, landedGolden())
			world:advance(0.3)
			local at = victim.Character.HumanoidRootPart.CFrame.Position
			spawnAt(attacker, at.X + config.KnockRange - 1, at.Z)
			expect(world:invoke("Knock", attacker, victim.UserId)):toBe(true)
			expect(#goldenCaps()):toBe(1)
			expect(goldenCaps()[1]:GetAttribute("Landed")):toBe(true)
			expect(#eventsOf(5)):toBe(0)
			world:advance(config.GoldenSpacebarMinSeconds * 3)
			expect(#goldenCaps() <= 1):toBe(true)
		end)

		it("gets a fresh lifetime after being dropped", function()
			setup(golden({ GoldenSpacebarMinSeconds = 5, GoldenSpacebarMaxSeconds = 5 }))
			local player = join("Ann", 200)
			spawnAt(player, 0, 0)
			stand(player, landedGolden())
			world:advance(0.3)
			world:advance(50)
			world:killCharacter(player)
			world:advance(55)
			expect(#goldenCaps()):toBe(1)
			expect(#eventsOf(5)):toBe(0)
			world:advance(10)
			expect(#eventsOf(5)):toBe(1)
		end)

		it("vanishes with kind 5 when its carrier leaves", function()
			setup(golden())
			local player = join("Ann", 200)
			spawnAt(player, 0, 0)
			stand(player, landedGolden())
			world:advance(0.3)
			expect(count(player)):toBe(1)
			world:removePlayer(player)
			expect(#goldenCaps()):toBe(0)
			expect(#eventsOf(5)):toBe(1)
		end)
	end)
end)
