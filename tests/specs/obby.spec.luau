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

	local function capAt(index: number): any
		local marker = course:FindFirstChild(`KeySpawn{index}`)
		for _, cap in pickups() do
			if (cap.CFrame.Position - marker.CFrame.Position).Magnitude < config.PickupHover + 0.01 then
				return cap
			end
		end
		return nil
	end

	local function takeAt(player: any, index: number): any
		local marker = course:FindFirstChild(`KeySpawn{index}`)
		moveTo(player, marker.CFrame:PointToWorldSpace(Vector3.new(0, 3, 0)))
		world:advance(config.TickSeconds)
		local cap = capAt(index)
		expect(cap ~= nil):toBe(true)
		expect(carried(player)):toBeNil()
		local keyId = cap:GetAttribute("KeyId")
		cap:FindFirstChild("ObbyTakePrompt").Triggered:Fire(player)
		return keyId
	end

	local function gainTaps(player: any, times: number)
		local part = course:FindFirstChild("Key1Body")
		moveTo(player, above(part, 2))
		local guard = 0
		while services.ObbyService:GetTaps(player) < times and guard < times * 8 do
			guard += 1
			world:advance(config.TapCooldown)
			moveTo(player, above(part, 2))
		end
		expect(services.ObbyService:GetTaps(player) >= times):toBe(true)
	end

	describe("course placement", function()
		local function placedAngle(): number
			local zone = course:FindFirstChild("Zone")
			local offset = zone.CFrame.Position - config.MapCenter
			return math.deg(math.atan2(offset.Z, offset.X))
		end

		local function expectOpposite(market: any)
			local expected = math.deg(
				math.atan2(market.Z - config.MapCenter.Z, market.X - config.MapCenter.X)
			) + 180
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
			zone.Size = Vector3.new(80, 80, 80)
			zone:SetAttribute("ObbyRole", "Zone")
			zone.Parent = authored
			local spawnPart = world:newPart("Mine", 300, 3, 300)
			spawnPart:SetAttribute("ObbyRole", "KeySpawn")
			spawnPart:SetAttribute("Stage", 2)
			spawnPart.Parent = authored
			authored.Parent = world.workspace
			boot()
			expect(course == authored):toBe(true)
			expect(authored:FindFirstChild("Lava")):toBeNil()
			expect(authored:FindFirstChild("Start")):toBeNil()
			local caps = pickups()
			expect(#caps):toBe(1)
			local rarity = Keys.ById[caps[1]:GetAttribute("KeyId")].Rarity
			expect(rarity == "Epic" or rarity == "Legendary"):toBe(true)
			local player = join("Edge")
			moveTo(player, Vector3.new(300, 5, 300))
			world:advance(config.TickSeconds)
			expect(world:walkSpeed(player)):toBe(Obby.SpeedFor(0))
			expect(carried(player)):toBeNil()
			caps[1]:FindFirstChild("ObbyTakePrompt").Triggered:Fire(player)
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

		it("reads studio role aliases", function()
			local authored = world:newInstance("Model")
			authored.Name = "Obby"
			local zone = world:newPart("Zone", 0, 20, 0)
			zone.Size = Vector3.new(200, 80, 200)
			zone:SetAttribute("ObbyRole", "Zone")
			zone.Parent = authored
			local home = world:newPart("Pad", 0, 3, 0)
			home.Size = Vector3.new(8, 1, 8)
			home:SetAttribute("ObbyRole", "Home")
			home.Parent = authored
			local gate = world:newPart("Barrier", 0, 8, -30)
			gate.Size = Vector3.new(20, 12, 2)
			gate:SetAttribute("ObbyRole", "SpeedGate")
			gate:SetAttribute("SpeedNeeded", 40)
			gate.Parent = authored
			local tap = world:newPart("Cap", 0, 3, 20)
			tap.Size = Vector3.new(6, 2, 6)
			tap.CanCollide = true
			tap:SetAttribute("ObbyRole", "TapKey")
			tap.Parent = authored
			authored.Parent = world.workspace
			boot()
			local player = join("Author")
			moveTo(player, above(tap, 2))
			world:advance(config.TickSeconds)
			expect(services.ObbyService:GetTaps(player)):toBe(1)
			expect(type(tap:GetAttribute("PressedAt"))):toBe("number")
			local blocked = above(gate, 2)
			moveTo(player, blocked)
			world:advance(config.TickSeconds)
			local root = player.Character.HumanoidRootPart.CFrame.Position
			expect((root - blocked).Magnitude > 1):toBe(true)
			expect(toasts(player, 9)[1]):toBe("Need 40 speed!")
			moveTo(player, above(home, 2))
			world:advance(config.TickSeconds)
			expect(fake.Homed[player]):toBe(1)
		end)
	end)

	describe("tap speed", function()
		it("starts at 24 inside the zone and restores 24 outside", function()
			boot()
			local player = join("Tapper")
			standOn(player, "Start")
			expect(world:walkSpeed(player)):toBe(24)
			expect(player.Character:GetAttribute("TapSpeed")):toBe(24)
			expect(player.Character:GetAttribute("ObbyTaps")):toBe(0)
			walkOut(player)
			expect(world:walkSpeed(player)):toBe(24)
			expect(player.Character:GetAttribute("TapSpeed")):toBeNil()
			expect(player.Character:GetAttribute("ObbyTaps")):toBeNil()
		end)

		it("gains speed from taps and caps at 80", function()
			boot()
			local player = join("Sprinter")
			gainTaps(player, 4)
			expect(services.ObbyService:GetTaps(player) >= 4):toBe(true)
			expect(world:walkSpeed(player)):toBe(Obby.SpeedFor(services.ObbyService:GetTaps(player)))
			gainTaps(player, 64)
			expect(services.ObbyService:GetTaps(player) >= 64):toBe(true)
			expect(world:walkSpeed(player)):toBe(Obby.SpeedFor(services.ObbyService:GetTaps(player)))
			expect(world:walkSpeed(player) >= config.GateSpeed):toBe(true)
		end)

		it("counts a key the player crosses between ticks", function()
			boot()
			local player = join("Dasher")
			local key = course:FindFirstChild("Key1Body")
			local gap = key.Size.Z / 2 + 0.5
			local before = key.CFrame:PointToWorldSpace(Vector3.new(0, key.Size.Y / 2 + 3, gap))
			local after = key.CFrame:PointToWorldSpace(Vector3.new(0, key.Size.Y / 2 + 3, -gap))
			moveTo(player, before)
			world:advance(config.TickSeconds)
			local startTaps = services.ObbyService:GetTaps(player)
			moveTo(player, after)
			world:advance(config.TickSeconds)
			expect(services.ObbyService:GetTaps(player) > startTaps):toBe(true)
		end)

		it("presses the key and the letter cap, then lets it rise", function()
			boot()
			local player = join("Click")
			local body = course:FindFirstChild("Key1Body")
			local top = course:FindFirstChild("Key1Top")
			local rest = body.CFrame
			local topRest = top.CFrame
			moveTo(player, above(body, 2))
			world:advance(config.TickSeconds)
			expect(body.CFrame.Position.Y < rest.Position.Y - 0.5):toBe(true)
			expect(top.CFrame.Position.Y < topRest.Position.Y - 0.5):toBe(true)
			walkOut(player)
			world:advance(config.PressSeconds)
			expect(body.CFrame.Position.Y):toBeCloseTo(rest.Position.Y, 1e-3)
			expect(top.CFrame.Position.Y):toBeCloseTo(topRest.Position.Y, 1e-3)
		end)

		it("announces the course once, then speed on the first tap", function()
			boot()
			local player = join("Toast")
			standOn(player, "Start")
			expect(toasts(player, 10)):toEqual({ "Step on the keys. Speed opens the gate!" })
			walkOut(player)
			standOn(player, "Start")
			expect(#toasts(player, 10)):toBe(1)
			gainTaps(player, 1)
			expect(toasts(player, 10)[2]):toBe(`Speed {Obby.SpeedFor(1)}  (+1 taps)`)
		end)

		it("remembers the obby hint after the upgrade tutorial", function()
			boot()
			local player, data = join("Guide", { Tutorial = 3 })
			standOn(player, "Start")
			expect(data.Tutorial):toBe(4)
			expect(toasts(player, 10)[1]):toBe("Step on the keys. Speed opens the gate!")
		end)

		it("skips the hint once it has been stored", function()
			boot()
			local player = join("Veteran", { Tutorial = 4 })
			standOn(player, "Start")
			expect(#toasts(player, 10)):toBe(0)
		end)

		it("keeps stolen-key carry speed over the tap speed", function()
			local plots = fake.Bases
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
				plots[player] = world:newPart("Base", x, 0, 0)
				world.Data.Service.PlayerLoaded:Fire(player, data)
				return player
			end
			local victim = assign("Vic", S.board("GlassTink", "PlainClack"), -5000)
			local thief = assign("Bob", S.board("OfficeTap"), 5000)
			world:spawnCharacter(victim, -5000, 3, 0)
			world:spawnCharacter(thief, -5000, 3, 10)
			local prompt = caps[victim][1]:FindFirstChild("StealPrompt")
			prompt.PromptButtonHoldBegan:Fire(thief)
			prompt.Triggered:Fire(thief)
			prompt.PromptButtonHoldEnded:Fire(thief)
			expect(thief.Character:GetAttribute("CarryingKey")):toBe("GlassTink")
			standOn(thief, "Start")
			expect(world:walkSpeed(thief)):toBe(GameConfig.Steal.CarryWalkSpeed)
			expect(services.ObbyService:IsCarrying(thief)):toBe(false)
		end)
	end)

	describe("speed gate", function()
		it("pushes a slow player back and lets a fast player through", function()
			boot()
			local player = join("Racer")
			local gate = course:FindFirstChild("SpeedGate")
			local blocked = above(gate, 2)
			moveTo(player, blocked)
			world:advance(config.TickSeconds)
			expect((player.Character.HumanoidRootPart.CFrame.Position - blocked).Magnitude > 1):toBe(true)
			expect(toasts(player, 9)[1]):toBe("Need 40 speed!")
			world:advance(config.TickSeconds * 3)
			expect(#toasts(player, 9)):toBe(1)
			gainTaps(player, 64)
			moveTo(player, blocked)
			world:advance(config.TickSeconds)
			expect((player.Character.HumanoidRootPart.CFrame.Position - blocked).Magnitude < 1):toBe(true)
		end)
	end)

	describe("key pickups", function()
		local function spawnCount(): number
			return #Obby.Layout().Spawns
		end

		it("floats one key over every spawn and waits for the hold prompt", function()
			boot()
			local caps = pickups()
			expect(#caps):toBe(spawnCount())
			local tags = world.fakeServices.CollectionService
			for _, cap in caps do
				expect(tags:HasTag(cap, "Spinner")):toBe(true)
				expect(cap.Anchored):toBe(true)
				expect(cap.CanCollide):toBe(false)
				expect(cap.Material ~= roblox.Enum.Material.Neon):toBe(true)
				local prompt = cap:FindFirstChild("ObbyTakePrompt")
				expect(prompt.HoldDuration > 0):toBe(true)
			end
			local player = join("Looker")
			local marker = course:FindFirstChild("KeySpawn1")
			moveTo(player, marker.CFrame:PointToWorldSpace(Vector3.new(0, 3, 0)))
			world:advance(config.TickSeconds * 3)
			expect(carried(player)):toBeNil()
			expect(#pickups()):toBe(spawnCount())
		end)

		it("paints each key in its rarity color using only the section rarities", function()
			boot()
			for _, cap in pickups() do
				local key = Keys.ById[cap:GetAttribute("KeyId")]
				local allowed = {}
				for _, option in config.Sections[cap:GetAttribute("Section")].Rarities do
					allowed[option.Name] = true
				end
				expect(allowed[key.Rarity]):toBe(true)
				expect(key.Exclusive):toBe(false)
				expect(cap.Color):toBe(Keys.GetRarity(key).Color)
			end
		end)

		it("gives the key when the prompt is held in range", function()
			boot()
			local player = join("Grabber")
			local keyId = takeAt(player, 1)
			expect(carried(player)):toBe(keyId)
			expect(#pickups()):toBe(spawnCount() - 1)
			expect(services.ObbyService:IsCarrying(player)):toBe(true)
			expect(player.Character:FindFirstChild("ObbyKeyCarried") ~= nil):toBe(true)
			expect(string.find(toasts(player, 11)[1], Keys.ById[keyId].Name, 1, true) ~= nil):toBe(true)
		end)

		it("ignores a prompt fired from out of range or outside the zone", function()
			boot()
			local player = join("Far")
			local cap = capAt(1)
			local marker = course:FindFirstChild("KeySpawn1")
			moveTo(player, marker.CFrame:PointToWorldSpace(Vector3.new(40, 3, 0)))
			world:advance(config.TickSeconds)
			cap:FindFirstChild("ObbyTakePrompt").Triggered:Fire(player)
			expect(carried(player)):toBeNil()
			expect(#pickups()):toBe(spawnCount())
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
			moveTo(player, Vector3.new(340, 6, 300))
			world:advance(config.TickSeconds)
			local cap = pickups()[1]
			cap:FindFirstChild("ObbyTakePrompt").Triggered:Fire(player)
			expect(carried(player)):toBeNil()
		end)

		it("empties the spawn and refills it after the respawn time", function()
			boot()
			local player = join("Waiter")
			expect(capAt(1) ~= nil):toBe(true)
			takeAt(player, 1)
			expect(capAt(1)):toBeNil()
			world:killCharacter(player)
			world:advance(config.RespawnSeconds - 1)
			expect(capAt(1)):toBeNil()
			expect(#pickups()):toBe(spawnCount() - 1)
			world:advance(1.5)
			expect(capAt(1) ~= nil):toBe(true)
			expect(#pickups()):toBe(spawnCount())
			expect(config.RespawnSeconds):toBe(60)
		end)

		it("lets a player hold only one obby key at a time", function()
			boot()
			local player = join("Greedy")
			local first = takeAt(player, 1)
			local second = capAt(2)
			moveTo(player, second.CFrame.Position + Vector3.new(0, 2, 0))
			world:advance(config.TickSeconds)
			second:FindFirstChild("ObbyTakePrompt").Triggered:Fire(player)
			expect(carried(player)):toBe(first)
			expect(#pickups()):toBe(spawnCount() - 1)
		end)

		it("gives different players different keys from separate spawns", function()
			boot()
			local a = join("Ann")
			local b = join("Ben")
			takeAt(a, 1)
			takeAt(b, 2)
			expect(carried(a) ~= nil and carried(b) ~= nil):toBe(true)
			expect(#pickups()):toBe(spawnCount() - 2)
		end)

		it("rolls a later-section rarity for the finish pedestal", function()
			boot()
			local allowed = {}
			for _, option in config.Sections[3].Rarities do
				allowed[option.Name] = true
			end
			local player = join("Late")
			local keyId = takeAt(player, 3)
			expect(allowed[Keys.ById[keyId].Rarity]):toBe(true)
		end)
	end)

	describe("delivery", function()
		it("adds the key to the inventory and discoveries at the player's own base", function()
			boot()
			local player, data = join("Courier")
			local keyId = takeAt(player, 1)
			world:advance(config.TickSeconds)
			expect(data.Inventory[keyId]):toBeNil()
			walkOut(player)
			expect(data.Inventory[keyId]):toBe(1)
			expect(data.Discovered[keyId]):toBe(1)
			expect(carried(player)):toBeNil()
			expect(services.ObbyService:IsCarrying(player)):toBe(false)
			expect((world.saves[player] or 0) > 0):toBe(true)
			expect(#toasts(player, 11)):toBe(2)
		end)

		it("auto places the key like a roll does", function()
			boot()
			local player, data = join("Placer", { Settings = { AutoPlace = true } })
			local keyId = takeAt(player, 1)
			walkOut(player)
			expect(data.Board[1]):toBe(keyId)
			expect(S.totals(data)[keyId]):toBe(1)
			expect(data.Discovered[keyId]):toBe(1)
		end)

		it("needs the player's own base, not any base", function()
			boot()
			local player, data = join("Lost")
			local other = join("Other")
			takeAt(player, 1)
			fake.Bases[other].CFrame = CFrame.new(60, 0, 60)
			moveTo(player, Vector3.new(60, 3, 60))
			world:advance(config.TickSeconds * 3)
			expect(carried(player) ~= nil):toBe(true)
			expect(next(data.Inventory)):toBeNil()
		end)
	end)

	describe("losing the key", function()
		it("drops the key on death without granting it", function()
			boot()
			local player, data = join("Faller")
			takeAt(player, 1)
			local count = #pickups()
			world:killCharacter(player)
			expect(services.ObbyService:IsCarrying(player)):toBe(false)
			expect(#toasts(player, 9)):toBe(1)
			world:advance(config.TickSeconds * 4)
			expect(#pickups()):toBe(count)
			expect(next(data.Inventory)):toBeNil()
		end)

		it("drops the key when the character is removed", function()
			boot()
			local player, data = join("Resetter")
			takeAt(player, 1)
			world:resetCharacter(player)
			expect(services.ObbyService:IsCarrying(player)):toBe(false)
			expect(next(data.Inventory)):toBeNil()
		end)

		it("kills a player who falls into the lava", function()
			boot()
			local player = join("Diver")
			local lava = course:FindFirstChild("Lava")
			moveTo(player, Vector3.new(lava.CFrame.Position.X, config.LavaTop + 2, lava.CFrame.Position.Z))
			world:advance(config.TickSeconds)
			expect(player.Character.Humanoid.Health):toBe(0)
		end)

		it("does not kill players on the pads or the keys", function()
			boot()
			local player = join("Hopper")
			for _, name in { "Start", "Safe", "Key1Body", "Finish" } do
				standOn(player, name)
				expect(player.Character.Humanoid.Health):toBe(100)
			end
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
			local keyId = takeAt(thief, 1)
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
			expect(carried(thief)):toBe("GlassTink")
			local cap = capAt(1)
			moveTo(thief, cap.CFrame.Position + Vector3.new(0, 2, 0))
			world:advance(config.TickSeconds)
			cap:FindFirstChild("ObbyTakePrompt").Triggered:Fire(thief)
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

		it("sets the respawn on the start, the safe zone and the finish", function()
			boot()
			local player = join("Checker")
			expect(respawnPosition(player)):toBeNil()
			standOn(player, "Start")
			expect(isAt(player, "Start")):toBe(true)
			standOn(player, "Safe")
			expect(isAt(player, "Safe")):toBe(true)
			standOn(player, "Finish")
			expect(isAt(player, "Finish")):toBe(true)
		end)

		it("keeps the checkpoint while running on the keys", function()
			boot()
			local player = join("Climber")
			standOn(player, "Safe")
			standOn(player, "Key1Body")
			expect(isAt(player, "Safe")):toBe(true)
		end)

		it("keeps the checkpoint through death even if the new character appears outside", function()
			boot()
			local player = join("Retry")
			standOn(player, "Safe")
			gainTaps(player, 4)
			local taps = services.ObbyService:GetTaps(player)
			world:killCharacter(player)
			world:resetCharacter(player)
			world:spawnCharacter(player, homeX, 3, homeZ)
			world:advance(config.TickSeconds * 4)
			expect(isAt(player, "Safe")):toBe(true)
			expect(services.ObbyService:GetTaps(player)):toBe(taps)
		end)

		it("clears the checkpoint and the speed when the player walks out", function()
			boot()
			local player = join("Quitter")
			standOn(player, "Safe")
			gainTaps(player, 4)
			expect(respawnPosition(player) ~= nil):toBe(true)
			walkOut(player)
			expect(respawnPosition(player)):toBeNil()
			expect(services.ObbyService:GetTaps(player)):toBe(0)
			expect(player.Character:GetAttribute("TapSpeed")):toBeNil()
		end)

		it("sends a player home from a home pad and clears the checkpoint", function()
			boot()
			local player = join("Homebody")
			standOn(player, "Safe")
			gainTaps(player, 4)
			moveTo(player, above(course:FindFirstChild("SafeHome"), 2))
			world:advance(config.TickSeconds)
			expect(fake.Homed[player]):toBe(1)
			world:advance(config.TickSeconds)
			expect(respawnPosition(player)):toBeNil()
			expect(services.ObbyService:GetTaps(player)):toBe(0)
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
			services = world:boot(
				{ "KeyboardService", "PlotService", "ObbyService" },
				{ PlotService = plotService }
			)
			course = world.workspace:FindFirstChild("Obby")
		end)

		it("puts the player on their base when they spawn", function()
			local player = joinReal("Real0")
			expect(nearBase(player)):toBe(true)
		end)

		it("respawns at the checkpoint after dying inside the obby", function()
			local player = joinReal("Real")
			standOn(player, "Safe")
			gainTaps(player, 4)
			local taps = services.ObbyService:GetTaps(player)
			die(player)
			local part = course:FindFirstChild("Safe")
			local expected = part.CFrame:PointToWorldSpace(Vector3.new(0, part.Size.Y / 2 + 4, 0))
			expect((rootPosition(player) - expected).Magnitude < 1):toBe(true)
			world:advance(config.TickSeconds * 2)
			expect(world:walkSpeed(player)):toBe(Obby.SpeedFor(taps))
			expect(nearBase(player)):toBe(false)
		end)

		it("respawns at the base again once the checkpoint is cleared", function()
			local player = joinReal("Real2")
			standOn(player, "Safe")
			walkOut(player)
			die(player)
			expect(nearBase(player)):toBe(true)
		end)

		it("sends a player home from a home pad with the real plot service", function()
			local player = joinReal("Real3")
			standOn(player, "Safe")
			moveTo(player, above(course:FindFirstChild("SafeHome"), 2))
			world:advance(config.TickSeconds)
			expect(nearBase(player)):toBe(true)
			world:advance(config.TickSeconds)
			die(player)
			expect(nearBase(player)):toBe(true)
		end)
	end)

	describe("cleanup", function()
		it("removes the built course, pickups and speed bonus on Destroy", function()
			boot()
			local player = join("Cleaner")
			gainTaps(player, 4)
			expect(world:walkSpeed(player)):toBe(25)
			services.ObbyService:Destroy()
			expect(world.workspace:FindFirstChild("Obby")):toBeNil()
			expect(world:walkSpeed(player)):toBe(24)
			expect(player.Character:GetAttribute("TapSpeed")):toBeNil()
			world:advance(config.RespawnSeconds * 2)
			expect(world.workspace:FindFirstChild("Obby")):toBeNil()
		end)

		it("clears checkpoints on Destroy", function()
			boot()
			local player = join("Cleaner2")
			standOn(player, "Safe")
			expect(fake.Respawns[player] ~= nil):toBe(true)
			services.ObbyService:Destroy()
			expect(fake.Respawns[player]):toBeNil()
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
		end)
	end)
end)
