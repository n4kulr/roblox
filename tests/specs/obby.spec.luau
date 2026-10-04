local roblox = require("@lune/roblox")
local H = require("../harness/Harness")
local S = require("../support")

local Vector3, CFrame = roblox.Vector3, roblox.CFrame
local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

local homeX, homeZ = 400, 400

describe("ObbyService", function()
	local world, services, fake, GameConfig, Keys, Obby, config, course

	local function newFake()
		local plots: { [any]: any } = {}
		local plot: any = { Name = "PlotService", Bases = plots, Respawns = {}, Homed = {} }
		function plot.GetPlot(_self, player: any)
			return if plots[player] then {} else nil
		end
		function plot.GetBase(_self, player: any)
			return plots[player]
		end
		function plot.SetRespawn(_self, player: any, cframe: any)
			plot.Respawns[player] = cframe
		end
		function plot.SendHome(_self, player: any)
			plot.Homed[player] = (plot.Homed[player] or 0) + 1
			local base = plots[player]
			world:moveCharacter(player, base.CFrame.Position.X, 3, base.CFrame.Position.Z)
			return true
		end
		return plot
	end

	beforeEach(function()
		world = H.newWorld({ Time = 1700000000 })
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		Keys = world:require("ReplicatedStorage.Config.Keys")
		Obby = world:require("ReplicatedStorage.Rules.Obby")
		config = GameConfig.Obby
		fake = newFake()
	end)

	afterEach(function()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	local function boot(extra: { string }?, overrides: any?)
		local names = { "KeyboardService" }
		for _, name in extra or {} do
			table.insert(names, name)
		end
		table.insert(names, "ObbyService")
		local replace: any = { PlotService = fake }
		for key, value in overrides or {} do
			replace[key] = value
		end
		services = world:boot(names, replace)
		course = world.workspace:FindFirstChild("Obby")
	end

	local function join(name: string, overrides: any?, spawn: boolean?)
		local data: any = { Settings = { AutoPlace = false } }
		for key, value in overrides or {} do
			data[key] = value
		end
		local player, loaded = world:join({ Name = name }, data)
		fake.Bases[player] = world:newPart("Base", homeX, 0, homeZ)
		if spawn ~= false then
			world:spawnCharacter(player, homeX, 3, homeZ)
		end
		return player, loaded
	end

	local function above(part: any, lift: number?): any
		return part.CFrame:PointToWorldSpace(Vector3.new(0, part.Size.Y / 2 + (lift or 3), 0))
	end

	local function moveTo(player: any, position: any)
		world:moveCharacter(player, position.X, position.Y, position.Z)
	end

	local function standOn(player: any, partName: string)
		moveTo(player, above(course:FindFirstChild(partName)))
		world:advance(config.TickSeconds)
	end

	local function standAtSpawn(player: any, index: number)
		local marker = course:FindFirstChild(`KeySpawn{index}`)
		moveTo(player, marker.CFrame:PointToWorldSpace(Vector3.new(0, 3, 0)))
		world:advance(config.TickSeconds)
	end

	local function pickups(): { any }
		local out = {}
		for _, child in course:GetChildren() do
			if child.Name == "ObbyKey" then
				table.insert(out, child)
			end
		end
		return out
	end

	local function toasts(player: any, phase: number): { string }
		local out = {}
		for _, entry in world:firedOf("StealAlert") do
			if entry.Target == player and entry.Args[3] == phase then
				table.insert(out, entry.Args[1])
			end
		end
		return out
	end

	local function walkOut(player: any)
		moveTo(player, Vector3.new(homeX, 3, homeZ))
		world:advance(config.TickSeconds)
	end

	local function carried(player: any): any
		return player.Character:GetAttribute("CarryingKey")
	end

	describe("course placement", function()
		local function placedAngle(): number
			local zone = course:FindFirstChild("Zone")
			local offset = zone.CFrame.Position - config.MapCenter
			return math.deg(math.atan2(offset.Z, offset.X))
		end

		local function expectOpposite(market: any)
			local expected = math.deg(math.atan2(market.Z - config.MapCenter.Z, market.X - config.MapCenter.X)) + 180
			local diff = math.abs(placedAngle() - expected) % 360
			expect(math.min(diff, 360 - diff) <= 1):toBe(true)
		end

		local function addMarket(x: number, z: number)
			local market = world:newInstance("Model")
			market.Name = "Market"
			local counter = world:newPart("Counter", x, 2, z)
			counter.Parent = market
			market.Parent = world.workspace
		end

		it("builds an Obby model at runtime opposite the default market spot", function()
			boot()
			expect(course ~= nil):toBe(true)
			expectOpposite(config.FallbackMarket)
		end)

		for _, spot in { { 0, -14 }, { 40, -30 }, { -25, 18 }, { 70, 5 } } do
			it(`sits opposite a market at {spot[1]},{spot[2]}`, function()
				addMarket(spot[1], spot[2])
				boot()
				expectOpposite(Vector3.new(spot[1], 0, spot[2]))
			end)
		end

		it("builds nothing twice and parents the course in workspace", function()
			boot()
			local count = 0
			for _, child in world.workspace:GetChildren() do
				if string.sub(child.Name, 1, 4) == "Obby" then
					count += 1
				end
			end
			expect(count):toBe(1)
		end)

		it("uses an authored workspace.Obby as-is instead of building", function()
			local authored = world:newInstance("Model")
			authored.Name = "Obby"
			local zone = world:newPart("Zone", 300, 20, 300)
			zone.Size = Vector3.new(60, 60, 60)
			zone:SetAttribute("ObbyRole", "Zone")
			zone.Parent = authored
			local spawnPart = world:newPart("Mine", 300, 3, 300)
			spawnPart:SetAttribute("ObbyRole", "KeySpawn")
			spawnPart:SetAttribute("Stage", 2)
			spawnPart.Parent = authored
			authored.Parent = world.workspace
			boot()
			expect(course == authored):toBe(true)
			local count = 0
			for _, child in world.workspace:GetChildren() do
				if string.sub(child.Name, 1, 4) == "Obby" then
					count += 1
				end
			end
			expect(count):toBe(1)
			expect(authored:FindFirstChild("Lava1")):toBeNil()
			expect(authored:FindFirstChild("Start")):toBeNil()
			local caps = pickups()
			expect(#caps):toBe(1)
			expect(Keys.ById[caps[1]:GetAttribute("KeyId")].Rarity):toBe("Epic")
			expect(caps[1].CFrame.Position.X):toBe(300)
			local player = join("Edge")
			moveTo(player, Vector3.new(300, 3, 300))
			world:advance(config.TickSeconds)
			expect(world:walkSpeed(player)):toBe(Obby.SpeedFor(0))
			expect(carried(player) ~= nil):toBe(true)
		end)

		it("builds a differently named placeholder when workspace.Obby has no zone", function()
			local broken = world:newInstance("Model")
			broken.Name = "Obby"
			broken.Parent = world.workspace
			boot()
			expect(#world.warnings > 0):toBe(true)
			expect(world.workspace:FindFirstChild("ObbyPlaceholder") ~= nil):toBe(true)
			expect(world.workspace:FindFirstChild("ObbyPlaceholder"):FindFirstChild("Zone") ~= nil):toBe(true)
			world.warnings = {}
		end)
	end)

	describe("tap speed", function()
		it("sets the speed from lifetime rolls inside the zone and restores 24 outside", function()
			boot()
			local player = join("Tapper", { Rolls = 99 })
			standOn(player, "Start")
			expect(world:walkSpeed(player)):toBe(32)
			expect(player.Character:GetAttribute("TapSpeed")):toBe(32)
			walkOut(player)
			expect(world:walkSpeed(player)):toBe(24)
			expect(player.Character:GetAttribute("TapSpeed")):toBeNil()
		end)

		it("uses 24 inside the zone for a player with no rolls and caps at 44", function()
			boot()
			local fresh = join("Fresh", { Rolls = 0 })
			local veteran = join("Veteran", { Rolls = 5000000 })
			standOn(fresh, "Start")
			standOn(veteran, "Start")
			expect(world:walkSpeed(fresh)):toBe(24)
			expect(world:walkSpeed(veteran)):toBe(44)
		end)

		it("follows new rolls while the player stays inside", function()
			boot()
			local player, data = join("Roller", { Rolls = 8 })
			standOn(player, "Start")
			expect(world:walkSpeed(player)):toBe(27)
			data.Rolls = 9
			world:advance(config.TickSeconds)
			expect(world:walkSpeed(player)):toBe(28)
		end)

		it("announces the speed once on entering", function()
			boot()
			local player = join("Toast", { Rolls = 99 })
			standOn(player, "Start")
			world:advance(1)
			expect(toasts(player, 10)):toEqual({ "Tap speed: 32" })
			walkOut(player)
			standOn(player, "Start")
			expect(#toasts(player, 10)):toBe(2)
		end)

		it("applies the new speed to every player independently", function()
			boot()
			local slow = join("Slow", { Rolls = 0 })
			local fast = join("Fast", { Rolls = 999 })
			local outside = join("Outside")
			standOn(slow, "Start")
			standOn(fast, "Start")
			expect(world:walkSpeed(slow)):toBe(24)
			expect(world:walkSpeed(fast)):toBe(36)
			expect(world:walkSpeed(outside)):toBe(16)
		end)

		it("keeps stolen key carry speed on top of the tap speed", function()
			local plots = fake.Bases
			fake.Plots = {}
			local caps: { [any]: any } = {}
			function fake.GetCaps(_self, player: any)
				return caps[player]
			end
			fake.LockChanged = world:require("ReplicatedStorage.Packages.Signal").new()
			function fake.GetLockedUntil()
				return 0
			end
			function fake.IsLocked()
				return false
			end
			boot({ "StealService" })
			local function assign(name: string, board: any, x: number)
				local player, data = world:join({ Name = name }, { PlaySeconds = 5000, Board = board, Settings = { AutoPlace = false } }, false)
				local list = {}
				for slot = 1, GameConfig.BoardSlots do
					list[slot] = world:newPart(`Slot{slot}`, x + slot, 1, 10)
				end
				caps[player] = list
				plots[player] = world:newPart("Base", x, 0, 0)
				world.Data.Service.PlayerLoaded:Fire(player, data)
				return player, data
			end
			local victim = assign("Vic", S.board("GlassTink", "PlainClack"), -5000)
			local thief, thiefData = assign("Bob", S.board("OfficeTap"), 5000)
			thiefData.Rolls = 99
			world:spawnCharacter(victim, -5000, 3, 0)
			world:spawnCharacter(thief, -5000, 3, 10)
			local prompt = caps[victim][1]:FindFirstChild("StealPrompt")
			moveTo(thief, above(course:FindFirstChild("Start")))
			world:advance(config.TickSeconds)
			expect(world:walkSpeed(thief)):toBe(32)
			moveTo(thief, Vector3.new(-5000, 3, 10))
			world:advance(config.TickSeconds)
			expect(world:walkSpeed(thief)):toBe(24)
			prompt.PromptButtonHoldBegan:Fire(thief)
			prompt.Triggered:Fire(thief)
			prompt.PromptButtonHoldEnded:Fire(thief)
			expect(thief.Character:GetAttribute("CarryingKey")):toBe("GlassTink")
			expect(world:walkSpeed(thief)):toBe(GameConfig.Steal.CarryWalkSpeed)
			moveTo(thief, above(course:FindFirstChild("Start")))
			world:advance(config.TickSeconds * 4)
			expect(world:walkSpeed(thief)):toBe(GameConfig.Steal.CarryWalkSpeed)
			expect(services.ObbyService:IsCarrying(thief)):toBe(false)
			plots[thief].CFrame = CFrame.new(above(course:FindFirstChild("Start")))
			world:advance(config.TickSeconds)
			expect(thief.Character:GetAttribute("CarryingKey")):toBeNil()
			expect(world:walkSpeed(thief)):toBe(32)
		end)
	end)

	describe("key pickups", function()
		local function spawnCount(): number
			return #Obby.Layout().Spawns
		end

		it("floats one key over every spawn point when the course starts", function()
			boot()
			local caps = pickups()
			expect(#caps):toBe(spawnCount())
			local tags = world.fakeServices.CollectionService
			for _, cap in caps do
				expect(tags:HasTag(cap, "Spinner")):toBe(true)
				expect(cap.Anchored):toBe(true)
				expect(cap.CanCollide):toBe(false)
				expect(cap.Material ~= roblox.Enum.Material.Neon):toBe(true)
			end
			for index, point in Obby.Layout().Spawns do
				local marker = course:FindFirstChild(`KeySpawn{index}`)
				local found = false
				for _, cap in caps do
					if (cap.CFrame.Position - marker.CFrame.Position).Magnitude < config.PickupHover + 0.01 then
						found = found or cap:GetAttribute("Stage") == point.Stage
					end
				end
				expect(found):toBe(true)
			end
		end)

		it("paints each key in its rarity color using only the stage rarities", function()
			boot()
			for _, cap in pickups() do
				local key = Keys.ById[cap:GetAttribute("KeyId")]
				local allowed = {}
				for _, option in config.Stages[cap:GetAttribute("Stage")].Rarities do
					allowed[option.Name] = true
				end
				expect(allowed[key.Rarity]):toBe(true)
				expect(key.Exclusive):toBe(false)
				expect(cap.Color):toBe(Keys.GetRarity(key).Color)
			end
		end)

		it("hands the nearest key to a player within range", function()
			boot()
			local player = join("Grabber")
			local before = pickups()
			local marker = course:FindFirstChild("KeySpawn1")
			local target
			for _, cap in before do
				if (cap.CFrame.Position - marker.CFrame.Position).Magnitude < config.PickupHover + 0.01 then
					target = cap
				end
			end
			local keyId = target:GetAttribute("KeyId")
			standAtSpawn(player, 1)
			expect(carried(player)):toBe(keyId)
			expect(#pickups()):toBe(spawnCount() - 1)
			expect(target.Parent):toBeNil()
			expect(services.ObbyService:IsCarrying(player)):toBe(true)
			expect(player.Character:FindFirstChild("ObbyKeyCarried") ~= nil):toBe(true)
			expect(#toasts(player, 11)):toBe(1)
			expect(string.find(toasts(player, 11)[1], Keys.ById[keyId].Name, 1, true) ~= nil):toBe(true)
		end)

		it("ignores players that are out of range", function()
			boot()
			local player = join("Far")
			local marker = course:FindFirstChild("KeySpawn1")
			moveTo(player, marker.CFrame:PointToWorldSpace(Vector3.new(config.PickupRange + 2, 3, 0)))
			world:advance(config.TickSeconds * 4)
			expect(carried(player)):toBeNil()
			expect(#pickups()):toBe(spawnCount())
			moveTo(player, marker.CFrame:PointToWorldSpace(Vector3.new(4, 3, 0)))
			world:advance(config.TickSeconds)
			expect(carried(player) ~= nil):toBe(true)
		end)

		it("does not hand out keys outside the obby zone", function()
			local authored = world:newInstance("Model")
			authored.Name = "Obby"
			local zone = world:newPart("Zone", 300, 20, 300)
			zone.Size = Vector3.new(10, 10, 10)
			zone:SetAttribute("ObbyRole", "Zone")
			zone.Parent = authored
			local marker = world:newPart("Mine", 340, 3, 300)
			marker:SetAttribute("ObbyRole", "KeySpawn")
			marker.Parent = authored
			authored.Parent = world.workspace
			boot()
			local player = join("Outside")
			moveTo(player, Vector3.new(340, 3, 300))
			world:advance(config.TickSeconds * 3)
			expect(carried(player)):toBeNil()
		end)

		it("empties the spawn and refills it after the respawn time", function()
			boot()
			local player = join("Waiter")
			local marker = course:FindFirstChild("KeySpawn1")
			local function hasKeyAt(): boolean
				for _, cap in pickups() do
					if (cap.CFrame.Position - marker.CFrame.Position).Magnitude < config.PickupHover + 0.01 then
						return true
					end
				end
				return false
			end
			expect(hasKeyAt()):toBe(true)
			standAtSpawn(player, 1)
			expect(hasKeyAt()):toBe(false)
			world:killCharacter(player)
			world:advance(config.RespawnSeconds - 1)
			expect(hasKeyAt()):toBe(false)
			expect(#pickups()):toBe(spawnCount() - 1)
			world:advance(1.5)
			expect(hasKeyAt()):toBe(true)
			expect(#pickups()):toBe(spawnCount())
			expect(config.RespawnSeconds):toBe(60)
		end)

		it("only respawns the spawn that was emptied", function()
			boot()
			local player = join("Picky")
			standAtSpawn(player, 3)
			world:advance(config.RespawnSeconds / 2)
			expect(#pickups()):toBe(spawnCount() - 1)
			world:advance(config.RespawnSeconds)
			expect(#pickups()):toBe(spawnCount())
		end)

		it("lets a player hold only one obby key at a time", function()
			boot()
			local player = join("Greedy")
			standAtSpawn(player, 1)
			local first = carried(player)
			expect(first ~= nil):toBe(true)
			standAtSpawn(player, 2)
			world:advance(config.TickSeconds * 4)
			expect(carried(player)):toBe(first)
			expect(#pickups()):toBe(spawnCount() - 1)
			expect(#toasts(player, 11)):toBe(1)
		end)

		it("gives different players different keys from separate spawns", function()
			boot()
			local a = join("Ann")
			local b = join("Ben")
			standAtSpawn(a, 1)
			standAtSpawn(b, 2)
			expect(carried(a) ~= nil and carried(b) ~= nil):toBe(true)
			expect(#pickups()):toBe(spawnCount() - 2)
		end)

		it("rolls a key of the later-stage rarities for later spawns", function()
			boot()
			local lastStage = #config.Stages
			local allowed = {}
			for _, option in config.Stages[lastStage].Rarities do
				allowed[option.Name] = true
			end
			local checked = 0
			for index, point in Obby.Layout().Spawns do
				if point.Stage == lastStage then
					local player = join(`Late{index}`)
					standAtSpawn(player, index)
					expect(allowed[Keys.ById[carried(player)].Rarity]):toBe(true)
					checked += 1
				end
			end
			expect(checked >= 2):toBe(true)
		end)
	end)

	describe("delivery", function()
		it("adds the key to the inventory and discoveries at the player's own base", function()
			boot()
			local player, data = join("Courier", { Rolls = 12 })
			standAtSpawn(player, 1)
			local keyId = carried(player)
			world:advance(config.TickSeconds * 4)
			expect(data.Inventory[keyId]):toBeNil()
			walkOut(player)
			expect(data.Inventory[keyId]):toBe(1)
			expect(data.Discovered[keyId]):toBe(1)
			expect(data.Rolls):toBe(12)
			expect(carried(player)):toBeNil()
			expect(services.ObbyService:IsCarrying(player)):toBe(false)
			expect(player.Character:FindFirstChild("ObbyKeyCarried")):toBeNil()
			expect((world.saves[player] or 0) > 0):toBe(true)
			expect(#toasts(player, 11)):toBe(2)
			walkOut(player)
			expect(data.Inventory[keyId]):toBe(1)
		end)

		it("auto places the key like a roll does", function()
			boot()
			local player, data = join("Placer", { Settings = { AutoPlace = true } })
			standAtSpawn(player, 1)
			local keyId = carried(player)
			walkOut(player)
			expect(data.Board[1]):toBe(keyId)
			expect(S.totals(data)[keyId]):toBe(1)
			expect(data.Discovered[keyId]):toBe(1)
		end)

		it("counts repeat deliveries of the same key", function()
			boot()
			local player, data = join("Repeat")
			standAtSpawn(player, 1)
			local keyId = carried(player)
			data.Discovered[keyId] = 4
			walkOut(player)
			expect(data.Discovered[keyId]):toBe(5)
		end)

		it("needs the player's own base, not any base", function()
			boot()
			local player, data = join("Lost")
			local other = join("Other")
			standAtSpawn(player, 1)
			fake.Bases[other].CFrame = CFrame.new(60, 0, 60)
			moveTo(player, Vector3.new(60, 3, 60))
			world:advance(config.TickSeconds * 3)
			expect(carried(player) ~= nil):toBe(true)
			expect(next(data.Inventory)):toBeNil()
		end)
	end)

	describe("losing the key", function()
		it("drops the key on death without returning or granting it", function()
			boot()
			local player, data = join("Faller")
			standAtSpawn(player, 1)
			local count = #pickups()
			world:killCharacter(player)
			expect(services.ObbyService:IsCarrying(player)):toBe(false)
			expect(carried(player)):toBeNil()
			expect(#toasts(player, 9)):toBe(1)
			world:advance(config.TickSeconds * 4)
			expect(#pickups()):toBe(count)
			expect(next(data.Inventory)):toBeNil()
			expect(next(data.Discovered)):toBeNil()
			world:resetCharacter(player)
			world:spawnCharacter(player, homeX, 3, homeZ)
			world:advance(config.TickSeconds * 4)
			expect(next(data.Inventory)):toBeNil()
		end)

		it("drops the key when the character is removed", function()
			boot()
			local player, data = join("Resetter")
			standAtSpawn(player, 1)
			world:resetCharacter(player)
			expect(services.ObbyService:IsCarrying(player)):toBe(false)
			expect(next(data.Inventory)):toBeNil()
		end)

		it("drops the key when the player leaves", function()
			boot()
			local player = join("Leaver")
			standAtSpawn(player, 1)
			world:removePlayer(player)
			expect(services.ObbyService:IsCarrying(player)):toBe(false)
			world:advance(config.TickSeconds * 4)
			expect(#pickups()):toBe(#Obby.Layout().Spawns - 1)
		end)

		it("kills a player who falls into the lava", function()
			boot()
			local player = join("Diver")
			local lava = course:FindFirstChild("Lava1")
			moveTo(player, Vector3.new(lava.CFrame.Position.X, config.LavaTop + 2, lava.CFrame.Position.Z))
			world:advance(config.TickSeconds)
			expect(player.Character.Humanoid.Health):toBe(0)
		end)

		it("does not kill players on platforms or safe areas", function()
			boot()
			local player = join("Hopper")
			for _, name in { "Start", "Safe1", "Stage1Cap2Top", "Stage2Cap1Top", "Safe3", "Finish" } do
				standOn(player, name)
				expect(player.Character.Humanoid.Health):toBe(100)
			end
		end)

		it("does not kill players outside the zone", function()
			boot()
			local player = join("Walker")
			moveTo(player, Vector3.new(0, config.LavaTop + 2, 0))
			world:advance(config.TickSeconds * 3)
			expect(player.Character.Humanoid.Health):toBe(100)
		end)
	end)

	describe("stolen keys", function()
		local victim, thief, caps

		beforeEach(function()
			caps = {}
			function fake.GetCaps(_self, player: any)
				return caps[player]
			end
			fake.LockChanged = world:require("ReplicatedStorage.Packages.Signal").new()
			function fake.GetLockedUntil()
				return 0
			end
			function fake.IsLocked()
				return false
			end
			boot({ "StealService" })
			local function assign(name: string, board: any, x: number)
				local player, data = world:join(
					{ Name = name },
					{ PlaySeconds = 5000, Board = board, Settings = { AutoPlace = false } },
					false
				)
				local list = {}
				for slot = 1, GameConfig.BoardSlots do
					list[slot] = world:newPart(`Slot{slot}`, x + slot, 1, 10)
				end
				caps[player] = list
				fake.Bases[player] = world:newPart("Base", x, 0, 0)
				world.Data.Service.PlayerLoaded:Fire(player, data)
				return player
			end
			victim = assign("Vic", S.board("GlassTink", "PlainClack"), -5000)
			thief = assign("Bob", S.board("OfficeTap"), 5000)
			world:spawnCharacter(victim, -5000, 3, 0)
			world:spawnCharacter(thief, -5000, 3, 10)
		end)

		local function trySteal()
			local prompt = caps[victim][1]:FindFirstChild("StealPrompt")
			prompt.PromptButtonHoldBegan:Fire(thief)
			prompt.Triggered:Fire(thief)
			prompt.PromptButtonHoldEnded:Fire(thief)
		end

		it("blocks starting a steal while carrying an obby key", function()
			standAtSpawn(thief, 1)
			local keyId = carried(thief)
			expect(keyId ~= nil):toBe(true)
			moveTo(thief, Vector3.new(-5000, 3, 10))
			trySteal()
			local reasons = world:require("ReplicatedStorage.Rules.Steal").Reasons
			local rejected = {}
			for _, entry in world:firedOf("StealAlert") do
				if entry.Target == thief and entry.Args[3] == 9 then
					table.insert(rejected, entry.Args[1])
				end
			end
			expect(rejected[#rejected]):toBe(reasons.Carrying)
			expect(world.Data:Replica(victim).Data.Board[1]):toBe("GlassTink")
			expect(services.StealService:IsCarrying(thief)):toBe(false)
			expect(carried(thief)):toBe(keyId)
		end)

		it("blocks picking up an obby key while carrying a stolen one", function()
			trySteal()
			expect(services.StealService:IsCarrying(thief)):toBe(true)
			expect(carried(thief)):toBe("GlassTink")
			standAtSpawn(thief, 1)
			world:advance(config.TickSeconds * 4)
			expect(carried(thief)):toBe("GlassTink")
			expect(#pickups()):toBe(#Obby.Layout().Spawns)
			expect(services.ObbyService:IsCarrying(thief)):toBe(false)
		end)
	end)

	describe("checkpoints", function()
		local function respawnPosition(player: any): any
			local cframe = fake.Respawns[player]
			return if cframe then cframe.Position else nil
		end

		local function checkpointOf(name: string): any
			local part = course:FindFirstChild(name)
			return part.CFrame:PointToWorldSpace(Vector3.new(0, part.Size.Y / 2 + 4, 0))
		end

		local function isAt(player: any, name: string): boolean
			local position = respawnPosition(player)
			return position ~= nil and (position - checkpointOf(name)).Magnitude < 1e-3
		end

		it("sets the respawn point when standing in a safe area", function()
			boot()
			local player = join("Checker")
			expect(respawnPosition(player)):toBeNil()
			standOn(player, "Safe1")
			expect(isAt(player, "Safe1")):toBe(true)
			standOn(player, "Safe2")
			expect(isAt(player, "Safe2")):toBe(true)
		end)

		it("treats the start platform and the finish as safe areas too", function()
			boot()
			local player = join("Edges")
			standOn(player, "Start")
			expect(isAt(player, "Start")):toBe(true)
			standOn(player, "Finish")
			expect(isAt(player, "Finish")):toBe(true)
		end)

		it("keeps the checkpoint while hopping across stage platforms", function()
			boot()
			local player = join("Climber")
			standOn(player, "Safe1")
			standOn(player, "Stage2Cap1Top")
			standOn(player, "Stage2Cap2Top")
			expect(isAt(player, "Safe1")):toBe(true)
		end)

		it("keeps the checkpoint through death and the respawn outside the zone", function()
			boot()
			local player = join("Retry")
			standOn(player, "Safe2")
			world:killCharacter(player)
			world:resetCharacter(player)
			world:spawnCharacter(player, homeX, 3, homeZ)
			world:advance(config.TickSeconds * 4)
			expect(isAt(player, "Safe2")):toBe(true)
		end)

		it("clears the checkpoint when the player leaves the zone", function()
			boot()
			local player = join("Quitter")
			standOn(player, "Safe3")
			expect(respawnPosition(player) ~= nil):toBe(true)
			walkOut(player)
			expect(respawnPosition(player)):toBeNil()
		end)

		it("keeps checkpoints separate per player", function()
			boot()
			local a = join("Alpha")
			local b = join("Beta")
			standOn(a, "Safe1")
			standOn(b, "Safe3")
			expect(isAt(a, "Safe1")):toBe(true)
			expect(isAt(b, "Safe3")):toBe(true)
			walkOut(a)
			expect(respawnPosition(a)):toBeNil()
			expect(respawnPosition(b) ~= nil):toBe(true)
		end)

		it("sends a player home from a home pad and clears the checkpoint", function()
			boot()
			local player = join("Homebody")
			standOn(player, "Safe2")
			moveTo(player, above(course:FindFirstChild("Safe2Home"), 2))
			world:advance(config.TickSeconds)
			expect(fake.Homed[player]):toBe(1)
			world:advance(config.TickSeconds)
			expect(respawnPosition(player)):toBeNil()
			expect(course:FindFirstChild("StartHome")):toBeNil()
		end)
	end)

	describe("checkpoint respawn with PlotService", function()
		local function spawnParented(player: any, x: number, y: number, z: number): any
			local character = world:newInstance("Model")
			character.Name = player.Name
			local root = world:newPart("HumanoidRootPart", x, y, z)
			root.Parent = character
			local humanoid = world:newInstance("Humanoid")
			humanoid.Name = "Humanoid"
			humanoid.Parent = character
			character.Parent = world.workspace
			player.Character = character
			player.CharacterAdded:Fire(character)
			world:flush()
			return character
		end

		local function die(player: any)
			world:killCharacter(player)
			world:resetCharacter(player)
			spawnParented(player, 0, 3, 0)
		end

		local function rootPosition(player: any): any
			return player.Character.HumanoidRootPart.CFrame.Position
		end

		local function joinReal(name: string): any
			local player = world:join({ Name = name }, { Settings = { AutoPlace = false } })
			world:flush()
			spawnParented(player, 0, 3, 0)
			return player
		end

		local function nearBase(player: any): boolean
			local base = services.PlotService:GetBase(player)
			return (rootPosition(player) - base.CFrame.Position).Magnitude < 20
		end

		beforeEach(function()
			world.workspace = world:newInstance("Folder")
			local plotService = world:require("ServerScriptService.Services.PlotService")
			services = world:boot({ "KeyboardService", "PlotService", "ObbyService" }, { PlotService = plotService })
			course = world.workspace:FindFirstChild("Obby")
		end)

		it("puts the player on their base when they spawn", function()
			local player = joinReal("Real0")
			expect(nearBase(player)):toBe(true)
		end)

		it("respawns at the checkpoint after dying inside the obby", function()
			local player = joinReal("Real")
			standOn(player, "Safe2")
			die(player)
			local part = course:FindFirstChild("Safe2")
			local expected = part.CFrame:PointToWorldSpace(Vector3.new(0, part.Size.Y / 2 + 4, 0))
			expect((rootPosition(player) - expected).Magnitude < 1e-3):toBe(true)
			expect(world:walkSpeed(player)):toBe(24)
			expect(nearBase(player)):toBe(false)
		end)

		it("respawns at the base again once the checkpoint is cleared", function()
			local player = joinReal("Real2")
			standOn(player, "Safe1")
			walkOut(player)
			die(player)
			expect(nearBase(player)):toBe(true)
		end)

		it("sends a player home from a home pad with the real plot service", function()
			local player = joinReal("Real3")
			standOn(player, "Safe1")
			moveTo(player, above(course:FindFirstChild("Safe1Home"), 2))
			world:advance(config.TickSeconds)
			expect(nearBase(player)):toBe(true)
			world:advance(config.TickSeconds)
			die(player)
			expect(nearBase(player)):toBe(true)
		end)

		it("forgets the checkpoint when the player leaves", function()
			local player = joinReal("Real4")
			standOn(player, "Safe1")
			world:removePlayer(player)
			world:advance(config.TickSeconds * 2)
			expect(world.errors):toEqual({})
		end)
	end)

	describe("cleanup", function()
		it("removes the built course, pickups and speed bonus on Destroy", function()
			boot()
			local player = join("Cleaner", { Rolls = 99 })
			standAtSpawn(player, 1)
			expect(world:walkSpeed(player)):toBe(32)
			services.ObbyService:Destroy()
			expect(world.workspace:FindFirstChild("Obby")):toBeNil()
			expect(world:walkSpeed(player)):toBe(24)
			expect(player.Character:GetAttribute("TapSpeed")):toBeNil()
			expect(carried(player)):toBeNil()
			expect(player.Character:FindFirstChild("ObbyKeyCarried")):toBeNil()
			world:advance(config.RespawnSeconds * 2)
			expect(world.workspace:FindFirstChild("Obby")):toBeNil()
		end)

		it("clears checkpoints on Destroy", function()
			boot()
			local player = join("Cleaner2")
			standOn(player, "Safe1")
			expect(fake.Respawns[player] ~= nil):toBe(true)
			services.ObbyService:Destroy()
			expect(fake.Respawns[player]):toBeNil()
		end)

		it("stops respawning keys after Destroy", function()
			local authored = world:newInstance("Model")
			authored.Name = "Obby"
			local zone = world:newPart("Zone", 300, 20, 300)
			zone.Size = Vector3.new(60, 60, 60)
			zone:SetAttribute("ObbyRole", "Zone")
			zone.Parent = authored
			local marker = world:newPart("Mine", 300, 3, 300)
			marker:SetAttribute("ObbyRole", "KeySpawn")
			marker.Parent = authored
			authored.Parent = world.workspace
			boot()
			local player = join("Late")
			moveTo(player, Vector3.new(300, 3, 300))
			world:advance(config.TickSeconds)
			expect(#pickups()):toBe(0)
			services.ObbyService:Destroy()
			world:advance(config.RespawnSeconds * 3)
			expect(#pickups()):toBe(0)
		end)

		it("keeps an authored course but removes its pickups on Destroy", function()
			local authored = world:newInstance("Model")
			authored.Name = "Obby"
			local zone = world:newPart("Zone", 300, 20, 300)
			zone:SetAttribute("ObbyRole", "Zone")
			zone.Parent = authored
			local marker = world:newPart("Mine", 300, 3, 300)
			marker:SetAttribute("ObbyRole", "KeySpawn")
			marker.Parent = authored
			authored.Parent = world.workspace
			boot()
			expect(#pickups()):toBe(1)
			services.ObbyService:Destroy()
			expect(world.workspace:FindFirstChild("Obby") == authored):toBe(true)
			expect(#pickups()):toBe(0)
			expect(authored:FindFirstChild("Zone") ~= nil):toBe(true)
		end)

		it("forgets players who leave and keeps serving the others", function()
			boot()
			local gone = join("Gone", { Rolls = 99 })
			local stays = join("Stays", { Rolls = 99 })
			standOn(gone, "Start")
			standOn(stays, "Start")
			world:removePlayer(gone)
			world:advance(config.TickSeconds * 4)
			expect(world:walkSpeed(stays)):toBe(32)
		end)

		it("does nothing for players without data or a character", function()
			boot()
			local stranger = world:newPlayer()
			local noData = world:newPlayer()
			world:spawnCharacter(noData, 0, 3, 0)
			world:advance(config.TickSeconds * 4)
			expect(stranger.Character):toBeNil()
		end)
	end)
end)
