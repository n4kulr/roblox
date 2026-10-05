local roblox = require("@lune/roblox")
local H = require("../harness/Harness")
local S = require("../support")

local Vector3, CFrame = roblox.Vector3, roblox.CFrame
local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

local homeX, homeZ = 400, 400
local goodPhase, badPhase = 11, 9

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

	local function boot(extra: { string }?)
		local names = { "KeyboardService" }
		for _, name in extra or {} do
			table.insert(names, name)
		end
		table.insert(names, "ObbyService")
		services = world:boot(names, { PlotService = fake })
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

	local function tick(count: number?)
		world:advance(config.TickSeconds * (count or 1))
	end

	local function standOn(player: any, partName: string)
		moveTo(player, above(course:FindFirstChild(partName)))
		tick()
	end

	local function standOnPart(player: any, part: any)
		moveTo(player, above(part))
		tick()
	end

	local function walkOut(player: any)
		moveTo(player, Vector3.new(homeX, 3, homeZ))
		tick()
	end

	local function keyPart(section: string, row: number, nearX: number?): any
		local best, bestDistance = nil, math.huge
		for _, cell in Obby.Layout().Cells do
			if cell.Section == section and cell.Row == row and cell.Kind == "Key" then
				local distance = math.abs(cell.X - (nearX or 0))
				if distance < bestDistance then
					best, bestDistance = cell, distance
				end
			end
		end
		return course:FindFirstChild(`Key_{section}_{row}_{best.Col}`)
	end

	local function tapsOf(player: any): any
		return player.Character:GetAttribute("ObbyTaps")
	end

	local function hop(player: any, count: number)
		local a = keyPart("RunA", 1)
		local b = keyPart("RunA", 2)
		for index = 1, count do
			standOnPart(player, if index % 2 == 1 then a else b)
		end
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

	local function carried(player: any): any
		return player.Character:GetAttribute("CarryingKey")
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

	local function capAt(index: number): any
		local marker = course:FindFirstChild(`KeySpawn{index}`)
		for _, cap in pickups() do
			if (cap.CFrame.Position - marker.CFrame.Position).Magnitude < config.Pickup.Hover + 0.01 then
				return cap
			end
		end
		return nil
	end

	local function nearSpawn(player: any, index: number)
		local marker = course:FindFirstChild(`KeySpawn{index}`)
		moveTo(player, marker.CFrame:PointToWorldSpace(Vector3.new(0, 3, 0)))
		tick()
	end

	local function hold(player: any, cap: any)
		local prompt = cap:FindFirstChild("TakePrompt")
		prompt.PromptButtonHoldBegan:Fire(player)
		prompt.Triggered:Fire(player)
		prompt.PromptButtonHoldEnded:Fire(player)
	end

	local function takeKey(player: any, index: number): any
		nearSpawn(player, index)
		local cap = capAt(index)
		hold(player, cap)
		return cap
	end

	local function author(parent: any, name: string, x: number, y: number, z: number, size: any, role: string, attributes: any?): any
		local part = world:newPart(name, x, y, z)
		part.Size = size
		part:SetAttribute("ObbyRole", role)
		for key, value in attributes or {} do
			part:SetAttribute(key, value)
		end
		part.Parent = parent
		return part
	end

	local function authoredNested(): any
		local model = world:newInstance("Model")
		model.Name = "Obby"
		local level = world:newInstance("Folder")
		level.Name = "Level1"
		level.Parent = model
		local deep = world:newInstance("Folder")
		deep.Name = "Deep"
		deep.Parent = level
		author(deep, "Zone", 300, 20, 300, Vector3.new(100, 60, 100), "Zone")
		author(level, "KeyA", 280, 1.25, 300, Vector3.new(8, 2.5, 8), "TapKey")
		author(deep, "KeyB", 289, 1.25, 300, Vector3.new(8, 2.5, 8), "TapKey")
		author(level, "Lava", 320, 0.5, 300, Vector3.new(8, 1, 8), "Kill")
		author(deep, "Pad", 300, 1, 320, Vector3.new(10, 2, 10), "Checkpoint")
		author(deep, "HomePad", 300, 1, 280, Vector3.new(6, 2, 6), "Home")
		author(level, "Gate", 300, 12, 340, Vector3.new(20, 24, 2), "SpeedGate", { RequiredSpeed = 30 })
		author(deep, "Pedestal", 320, 1, 320, Vector3.new(3, 1, 3), "KeySpawn", { Rarities = "Legendary" })
		author(level, "Pop", 280, 1.25, 320, Vector3.new(8, 2.5, 8), "PopUpKey", {
			RiseHeight = 10,
			UpSeconds = 1,
			PeriodSeconds = 2,
		})
		model.Parent = world.workspace
		return model
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

	describe("runway", function()
		local function tapKeys(): { any }
			local out = {}
			for _, part in course:GetDescendants() do
				if part:GetAttribute("ObbyRole") == "TapKey" then
					table.insert(out, part)
				end
			end
			return out
		end

		local function withRole(role: string): { any }
			local out = {}
			for _, part in course:GetDescendants() do
				if part:GetAttribute("ObbyRole") == role then
					table.insert(out, part)
				end
			end
			return out
		end

		it("spans 96 studs of keys across the full width with a key for every layout cell", function()
			boot()
			local layout = Obby.Layout()
			local keys = tapKeys()
			local popUps = withRole("PopUpKey")
			expect(#keys + #popUps):toBe(#layout.Cells)
			local origin = course:FindFirstChild("Zone").CFrame
			local low, high = math.huge, -math.huge
			for _, key in keys do
				local x = origin:PointToObjectSpace(key.CFrame.Position).X
				low = math.min(low, x - key.Size.X / 2)
				high = math.max(high, x + key.Size.X / 2)
			end
			expect(high - low):toBeCloseTo(96, 0.01)
			expect(course:FindFirstChild("Zone").Size.X):toBe(99)
		end)

		it("sizes full keys 6.56x2.2x6.56 with a small gap and staggers the rows", function()
			boot()
			local a = keyPart("RunA", 1)
			local b = keyPart("RunA", 2)
			local c = keyPart("RunA", 3)
			expect(a.Size):toBe(Vector3.new(6.56, 2.2, 6.56))
			local origin = course:FindFirstChild("Zone").CFrame
			local function localX(part: any)
				return origin:PointToObjectSpace(part.CFrame.Position).X
			end
			local function localZ(part: any)
				return origin:PointToObjectSpace(part.CFrame.Position).Z
			end
			expect(math.abs(math.abs(localZ(a) - localZ(b)) - 6.8)):toBeCloseTo(0, 1e-3)
			local xs = {}
			for _, row in { 1, 2, 3, 4 } do
				local keys = {}
				for _, key in tapKeys() do
					if string.find(key.Name, `Key_RunA_{row}_`, 1, true) == 1 and math.abs(key.Size.X - 6.56) < 1e-3 then
						table.insert(keys, localX(key))
					end
				end
				table.sort(keys)
				xs[row] = keys[1]
			end
			expect(xs[1] ~= xs[2] and xs[2] ~= xs[3] and xs[3] ~= xs[4]):toBe(true)
			expect(c ~= nil and b ~= nil):toBe(true)
		end)

		it("paints every tap key like a base floor key: cream, smooth plastic, no legends", function()
			boot()
			local cream = roblox.Color3.fromRGB(222, 218, 208)
			local count = 0
			for _, part in withRole("TapKey") do
				count += 1
				expect(part.Color):toBe(cream)
				expect(part.Material):toBe(roblox.Enum.Material.SmoothPlastic)
				expect(#part:GetChildren()):toBe(0)
			end
			expect(count > 0):toBe(true)
			local modifier = course:FindFirstChild("Key_RunA_1_1")
			expect(modifier:GetAttribute("Letter")):toBe("TAB")
			expect(modifier.Color):toBe(cream)
		end)

		it("paints pop-up keys in the Epic rarity color", function()
			boot()
			for _, part in withRole("PopUpKey") do
				expect(part.Color):toBe(Keys.RarityByName.Epic.Color)
			end
		end)

		it("prints keyboard letters on the caps", function()
			boot()
			local letters = ""
			for col = 2, 11 do
				local part = course:FindFirstChild(`Key_RunA_1_{col}`)
				if part then
					letters ..= part:GetAttribute("Letter")
				end
			end
			expect(string.sub(letters, 1, 10)):toBe("QWERTYUIOP")
			local asdf = course:FindFirstChild("Key_RunA_2_2")
			expect(asdf:GetAttribute("Letter")):toBe("A")
			local zxcv = course:FindFirstChild("Key_RunA_3_2")
			expect(zxcv:GetAttribute("Letter")):toBe("Z")
		end)

		it("makes lava a dark maroon kill slab under the second run only", function()
			boot()
			local lava = withRole("Kill")
			expect(#lava):toBe(1)
			expect(lava[1].Color.R > lava[1].Color.G and lava[1].Color.R < 0.5):toBe(true)
			expect(lava[1].Material):toBe(roblox.Enum.Material.SmoothPlastic)
		end)

		it("creates start, safe and end checkpoints and two home pads", function()
			boot()
			local names = {}
			for _, part in withRole("Checkpoint") do
				table.insert(names, part.Name)
			end
			table.sort(names)
			expect(names):toEqual({ "End", "Safe1", "Start" })
			local homes = {}
			for _, part in withRole("Home") do
				table.insert(homes, part.Name)
			end
			table.sort(homes)
			expect(homes):toEqual({ "EndHome", "Safe1Home" })
		end)

		it("signs the gate and the end pad", function()
			boot()
			local gate = course:FindFirstChild("SpeedGate")
			expect(gate:FindFirstChild("SignGui"):FindFirstChild("Title").Text):toBe("NEED 40 SPEED")
			expect(gate.Transparency > 0 and gate.Transparency < 1):toBe(true)
			expect(gate:GetAttribute("RequiredSpeed")):toBe(40)
			local sign = course:FindFirstChild("EndSign")
			expect(sign:FindFirstChild("SignGui"):FindFirstChild("Title").Text):toBe("LEVEL 1 COMPLETE")
			expect(course:FindFirstChild("EndWall") ~= nil):toBe(true)
		end)

		it("closes both sides with walls", function()
			boot()
			expect(course:FindFirstChild("SideWall-1") == nil):toBe(true)
			expect(course:FindFirstChild("SideWall1") ~= nil):toBe(true)
			expect(course:FindFirstChild("SideWall2") ~= nil):toBe(true)
			expect(course:FindFirstChild("SideBarrier1").CanCollide):toBe(true)
		end)

		it("tags pop-up keys, pedestals and the zone with their attributes", function()
			boot()
			local popUps = withRole("PopUpKey")
			expect(#popUps):toBe(2)
			for _, popUp in popUps do
				expect(popUp:GetAttribute("RiseHeight")):toBe(6)
				expect(popUp:GetAttribute("UpSeconds")):toBe(1.5)
				expect(popUp:GetAttribute("PeriodSeconds")):toBe(4)
			end
			local spawns = withRole("KeySpawn")
			expect(#spawns):toBe(3)
			expect(#withRole("Zone")):toBe(1)
			local specs = {}
			for index = 1, 3 do
				specs[index] = course:FindFirstChild(`KeySpawn{index}`):GetAttribute("Rarities")
			end
			expect(specs):toEqual({ "Rare,Epic", "Epic", "Epic,Legendary" })
		end)

		it("anchors everything", function()
			boot()
			local count = 0
			for _, part in course:GetDescendants() do
				if part:IsA("Part") then
					expect(part.Anchored):toBe(true)
					count += 1
				end
			end
			expect(count < 600):toBe(true)
		end)
	end)

	describe("tap counting", function()
		it("counts one tap for every key walked across", function()
			boot()
			local player = join("Walker")
			for row = 1, 6 do
				standOnPart(player, keyPart("RunA", row))
				expect(tapsOf(player)):toBe(row)
			end
		end)

		it("does not count standing still", function()
			boot()
			local player = join("Idler")
			standOnPart(player, keyPart("RunA", 1))
			tick(30)
			expect(tapsOf(player)):toBe(1)
		end)

		it("counts a key again after leaving it", function()
			boot()
			local player = join("Returner")
			local key = keyPart("RunA", 1)
			standOnPart(player, key)
			standOn(player, "Start")
			expect(tapsOf(player)):toBe(1)
			standOnPart(player, key)
			expect(tapsOf(player)):toBe(2)
		end)

		it("counts keys crossed within one sample", function()
			boot()
			local player = join("Sprinter")
			local first = keyPart("RunA", 1)
			standOnPart(player, first)
			local origin = course:FindFirstChild("Zone").CFrame
			local from = first.CFrame.Position
			local target = keyPart("RunA", 5, origin:PointToObjectSpace(from).X)
			local layout = Obby.Layout()
			local expected = 0
			local startLocal = origin:PointToObjectSpace(from)
			for row = 2, 5 do
				for _, cell in layout.Cells do
					if cell.Section == "RunA" and cell.Row == row and math.abs(cell.X - startLocal.X) <= cell.Width / 2 then
						expected += 1
					end
				end
			end
			moveTo(player, Vector3.new(from.X, from.Y + 0.5, target.CFrame.Position.Z))
			tick()
			expect(expected >= 3):toBe(true)
			expect(tapsOf(player)):toBe(1 + expected)
		end)

		it("treats a huge jump as a teleport and counts only the key landed on", function()
			boot()
			local player = join("Teleporter")
			standOnPart(player, keyPart("RunA", 1))
			standOnPart(player, keyPart("RunA", 8))
			expect(tapsOf(player)):toBe(2)
		end)

		it("ignores keys passed high in the air", function()
			boot()
			local player = join("Flyer")
			local key = keyPart("RunA", 1)
			moveTo(player, key.CFrame:PointToWorldSpace(Vector3.new(0, 14, 0)))
			tick(3)
			expect(tapsOf(player)):toBe(0)
		end)

		it("counts the pop-up key too", function()
			boot()
			world:advance(1.9)
			local player = join("Popper")
			local popUp = course:FindFirstChild("PopUp_SHIFT")
			standOnPart(player, popUp)
			expect(tapsOf(player)):toBe(1)
		end)
	end)

	describe("tap speed", function()
		it("applies the speed through WalkSpeed from the tap count", function()
			boot()
			local player = join("Tapper")
			standOn(player, "Start")
			expect(world:walkSpeed(player)):toBe(24)
			expect(player.Character:GetAttribute("TapSpeed")):toBe(24)
			hop(player, 4)
			expect(tapsOf(player)):toBe(4)
			expect(world:walkSpeed(player)):toBe(Obby.SpeedFor(4))
			expect(player.Character:GetAttribute("TapSpeed")):toBe(Obby.SpeedFor(4))
			hop(player, 20)
			expect(tapsOf(player)):toBe(24)
			expect(world:walkSpeed(player)):toBe(Obby.SpeedFor(24))
		end)

		it("keeps taps per player", function()
			boot()
			local a = join("Ann")
			local b = join("Ben")
			hop(a, 8)
			standOnPart(b, keyPart("RunA", 1))
			expect(tapsOf(a)):toBe(8)
			expect(tapsOf(b)):toBe(1)
			expect(world:walkSpeed(a)):toBe(Obby.SpeedFor(8))
			expect(world:walkSpeed(b)):toBe(Obby.SpeedFor(1))
		end)

		it("keeps stolen carry speed on top of the tap speed", function()
			boot()
			local player = join("Thief")
			player.Character:SetAttribute("StolenFromUserId", 5)
			world:require("ServerScriptService.Utils.WalkSpeed").Refresh(player.Character)
			expect(world:walkSpeed(player)):toBe(GameConfig.Steal.CarryWalkSpeed)
			hop(player, 12)
			expect(world:walkSpeed(player)):toBe(GameConfig.Steal.CarryWalkSpeed)
			expect(player.Character:GetAttribute("TapSpeed")):toBe(Obby.SpeedFor(12))
			player.Character:SetAttribute("StolenFromUserId", nil)
			hop(player, 4)
			expect(world:walkSpeed(player)):toBe(Obby.SpeedFor(tapsOf(player)))
		end)

		it("resets taps and speed when leaving the zone and restarts from zero", function()
			boot()
			local player = join("Leaver")
			hop(player, 12)
			expect(world:walkSpeed(player)):toBe(Obby.SpeedFor(12))
			walkOut(player)
			expect(tapsOf(player)):toBeNil()
			expect(player.Character:GetAttribute("TapSpeed")):toBeNil()
			expect(world:walkSpeed(player)):toBe(24)
			standOnPart(player, keyPart("RunA", 1))
			expect(tapsOf(player)):toBe(1)
		end)

		it("keeps taps through death and a checkpoint respawn", function()
			boot()
			local player = join("Survivor")
			hop(player, 12)
			standOn(player, "Safe1")
			world:killCharacter(player)
			world:resetCharacter(player)
			local pad = course:FindFirstChild("Safe1")
			local spot = above(pad, 4)
			world:spawnCharacter(player, spot.X, spot.Y, spot.Z)
			tick(2)
			expect(tapsOf(player)):toBe(12)
			expect(world:walkSpeed(player)):toBe(Obby.SpeedFor(12))
		end)

		it("resets taps when the respawn lands outside the zone", function()
			boot()
			local player = join("Homeward")
			hop(player, 12)
			world:killCharacter(player)
			world:resetCharacter(player)
			world:spawnCharacter(player, homeX, 3, homeZ)
			tick(2)
			expect(tapsOf(player)):toBeNil()
			expect(player.Character:GetAttribute("TapSpeed")):toBeNil()
			standOnPart(player, keyPart("RunA", 1))
			expect(tapsOf(player)):toBe(1)
		end)

		it("does not count the teleport to a checkpoint as taps", function()
			boot()
			local player = join("Porter")
			standOnPart(player, keyPart("RunA", 3))
			standOn(player, "Safe1")
			expect(tapsOf(player)):toBe(1)
		end)

		it("caps the speed at the maximum", function()
			boot()
			local player = join("Maxed")
			hop(player, 240)
			expect(world:walkSpeed(player)):toBe(80)
		end)
	end)

	describe("speed gate", function()
		local function gate(): any
			return course:FindFirstChild("SpeedGate")
		end

		local function toGate(player: any, z: number)
			local point = gate().CFrame:PointToWorldSpace(Vector3.new(0, 0, z))
			moveTo(player, Vector3.new(point.X, 3, point.Z))
			tick()
		end

		local function localZ(player: any): number
			return gate().CFrame:PointToObjectSpace(player.Character.HumanoidRootPart.CFrame.Position).Z
		end

		it("blocks a slow player and says what is needed", function()
			boot()
			local player = join("Slow")
			hop(player, 10)
			local before = player.Character.HumanoidRootPart.CFrame.Position
			toGate(player, 3)
			expect(localZ(player) > 0):toBe(true)
			expect(player.Character.HumanoidRootPart.CFrame.Position.Z):toBe(
				gate().CFrame:PointToWorldSpace(Vector3.new(0, 0, 3)).Z
			)
			expect(before ~= nil):toBe(true)
			expect(toasts(player, badPhase)):toEqual({ "Need 40 speed!" })
		end)

		it("rate limits the toast", function()
			boot()
			local player = join("Pushy")
			toGate(player, 3)
			tick(5)
			expect(#toasts(player, badPhase)):toBe(1)
			world:advance(config.Gate.ToastSeconds)
			tick()
			expect(#toasts(player, badPhase)):toBe(2)
		end)

		it("lets a player at the required speed through to the far side", function()
			boot()
			local player = join("Fast")
			hop(player, 16)
			expect(world:walkSpeed(player)):toBe(Obby.SpeedFor(16))
			toGate(player, 3)
			expect(localZ(player) < -1):toBe(true)
			expect(#toasts(player, goodPhase) >= 1):toBe(true)
			expect(#toasts(player, badPhase)):toBe(0)
			tick(3)
			expect(localZ(player) < -1):toBe(true)
		end)

		it("keeps out a player one tap short of the required speed", function()
			boot()
			local player = join("Almost")
			hop(player, 15)
			expect(world:walkSpeed(player)):toBe(Obby.SpeedFor(15))
			toGate(player, 3)
			expect(localZ(player) > 0):toBe(true)
			expect(#toasts(player, badPhase)):toBe(1)
		end)

		it("only affects players touching the gate and does not trap one beside it", function()
			boot()
			local player = join("Far")
			toGate(player, 20)
			expect(#toasts(player, badPhase)):toBe(0)
			expect(localZ(player) > 0):toBe(true)
		end)

		it("is decided per player", function()
			boot()
			local fast = join("Quick")
			local slow = join("Lazy")
			hop(fast, 16)
			toGate(fast, 3)
			toGate(slow, 3)
			expect(localZ(fast) < 0):toBe(true)
			expect(localZ(slow) > 0):toBe(true)
		end)

		it("reads the required speed from the attribute", function()
			boot()
			gate():SetAttribute("RequiredSpeed", 28)
			local player = join("Custom")
			toGate(player, 3)
			expect(toasts(player, badPhase)):toEqual({ "Need 28 speed!" })
			hop(player, 16)
			toGate(player, 3)
			expect(localZ(player) < 0):toBe(true)
		end)
	end)

	describe("pop-up keys", function()
		local function popUp(name: string): any
			return course:FindFirstChild(`PopUp_{name}`)
		end

		it("rises 6 studs for 1.5 seconds every 4 seconds", function()
			boot()
			local shift = popUp("SHIFT")
			local rest = shift.CFrame.Position.Y
			world:advance(0.5)
			expect(shift.CFrame.Position.Y):toBeCloseTo(rest + 6, 1e-6)
			expect(shift:GetAttribute("Raised")):toBe(true)
			world:advance(1.4)
			expect(shift.CFrame.Position.Y):toBeCloseTo(rest, 1e-6)
			expect(shift:GetAttribute("Raised")):toBe(false)
			world:advance(2.6)
			expect(shift.CFrame.Position.Y):toBeCloseTo(rest + 6, 1e-6)
		end)

		it("offsets the second pop-up by two seconds", function()
			boot()
			local shift = popUp("SHIFT")
			local enter = popUp("ENTER")
			local restShift = shift.CFrame.Position.Y
			local restEnter = enter.CFrame.Position.Y
			world:advance(0.5)
			expect(enter.CFrame.Position.Y):toBeCloseTo(restEnter, 1e-6)
			world:advance(2)
			expect(enter.CFrame.Position.Y):toBeCloseTo(restEnter + 6, 1e-6)
			expect(shift.CFrame.Position.Y):toBeCloseTo(restShift, 1e-6)
		end)

		it("rests its top flush with the other keys and is tall enough to wall the lane", function()
			boot()
			local shift = popUp("SHIFT")
			local plain = keyPart("RunA", 1)
			expect(shift.CFrame.Position.Y + shift.Size.Y / 2):toBeCloseTo(plain.CFrame.Position.Y + plain.Size.Y / 2, 1e-6)
			expect(shift.Size.Y >= config.Key.Height + config.PopUp.RiseHeight - 1e-3):toBe(true)
		end)

		it("goes back to rest on Destroy", function()
			boot()
			local shift = popUp("SHIFT")
			local rest = shift.CFrame.Position.Y
			world:advance(0.5)
			services.ObbyService:Destroy()
			expect(shift.CFrame.Position.Y):toBeCloseTo(rest, 1e-6)
			expect(shift:GetAttribute("Raised")):toBeNil()
		end)
	end)

	describe("authored course", function()
		it("discovers every role at any depth and builds nothing else", function()
			local authored = authoredNested()
			boot()
			expect(course == authored):toBe(true)
			expect(authored:FindFirstChild("Start", true)):toBeNil()
			expect(authored:FindFirstChild("SpeedGate", true)):toBeNil()
			local count = 0
			for _, child in world.workspace:GetChildren() do
				if string.sub(child.Name, 1, 4) == "Obby" then
					count += 1
				end
			end
			expect(count):toBe(1)
			local caps = pickups()
			expect(#caps):toBe(1)
			expect(Keys.ById[caps[1]:GetAttribute("KeyId")].Rarity):toBe("Legendary")
		end)

		it("counts nested tap keys and applies speed", function()
			authoredNested()
			boot()
			local player = join("Edge")
			moveTo(player, Vector3.new(280, 5.5, 300))
			tick()
			moveTo(player, Vector3.new(289, 5.5, 300))
			tick()
			expect(tapsOf(player)):toBe(2)
			expect(world:walkSpeed(player)):toBe(Obby.SpeedFor(2))
		end)

		it("kills in nested kill parts, sets nested checkpoints and uses nested homes", function()
			authoredNested()
			boot()
			local player = join("Roles")
			moveTo(player, Vector3.new(300, 5, 320))
			tick()
			expect(fake.Respawns[player] ~= nil):toBe(true)
			moveTo(player, Vector3.new(300, 3, 280))
			tick()
			expect(fake.Homed[player]):toBe(1)
			local victim = join("Victim")
			moveTo(victim, Vector3.new(320, 2, 300))
			tick()
			expect(victim.Character.Humanoid.Health):toBe(0)
		end)

		it("uses a nested speed gate with its own required speed", function()
			authoredNested()
			boot()
			local player = join("Gated")
			moveTo(player, Vector3.new(300, 3, 342))
			tick()
			expect(toasts(player, badPhase)):toEqual({ "Need 30 speed!" })
		end)

		it("animates a nested pop-up with its own attributes", function()
			local authored = authoredNested()
			boot()
			local pop = authored:FindFirstChild("Pop", true)
			local rest = pop.CFrame.Position.Y
			world:advance(0.5)
			expect(pop.CFrame.Position.Y):toBeCloseTo(rest + 10, 1e-6)
			world:advance(1)
			expect(pop.CFrame.Position.Y):toBeCloseTo(rest, 1e-6)
		end)

		it("does not hand out keys or taps outside its zone", function()
			authoredNested()
			boot()
			local player = join("Outside")
			moveTo(player, Vector3.new(280, 5.5, 200))
			tick(3)
			expect(tapsOf(player)):toBeNil()
		end)
	end)

	describe("key pedestals", function()
		it("floats one key over every pedestal behind a hold prompt", function()
			boot()
			local caps = pickups()
			expect(#caps):toBe(3)
			local tags = world.fakeServices.CollectionService
			for index = 1, 3 do
				local cap = capAt(index)
				expect(cap ~= nil):toBe(true)
				expect(tags:HasTag(cap, "Spinner")):toBe(true)
				expect(cap.Anchored):toBe(true)
				expect(cap.CanCollide):toBe(false)
				expect(cap.Material ~= roblox.Enum.Material.Neon):toBe(true)
				local prompt = cap:FindFirstChild("TakePrompt")
				expect(prompt.ActionText):toBe("Take")
				expect(prompt.ObjectText):toBe(Keys.ById[cap:GetAttribute("KeyId")].Name)
				expect(prompt.HoldDuration):toBe(1.5)
				expect(prompt.MaxActivationDistance):toBe(10)
			end
		end)

		it("rolls from each pedestal's rarities", function()
			local allowed = { { Rare = true, Epic = true }, { Epic = true }, { Epic = true, Legendary = true } }
			for round = 1, 6 do
				if round > 1 then
					world:destroy()
					world = H.newWorld({ Time = 1700000000 + round })
					GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
					Keys = world:require("ReplicatedStorage.Config.Keys")
					Obby = world:require("ReplicatedStorage.Rules.Obby")
					config = GameConfig.Obby
					fake = newFake()
				end
				boot()
				for index = 1, 3 do
					local key = Keys.ById[capAt(index):GetAttribute("KeyId")]
					expect(allowed[index][key.Rarity]):toBe(true)
					expect(key.Exclusive):toBe(false)
					expect(capAt(index).Color):toBe(Keys.GetRarity(key).Color)
				end
			end
		end)

		it("does not take a key just by standing next to it", function()
			boot()
			local player = join("Hover")
			nearSpawn(player, 1)
			tick(20)
			expect(carried(player)):toBeNil()
			expect(#pickups()):toBe(3)
			local cap = capAt(1)
			cap:FindFirstChild("TakePrompt").PromptButtonHoldBegan:Fire(player)
			tick(5)
			expect(carried(player)):toBeNil()
		end)

		it("hands the key over when the hold completes", function()
			boot()
			local player = join("Grabber")
			local target = capAt(1)
			local keyId = target:GetAttribute("KeyId")
			takeKey(player, 1)
			expect(carried(player)):toBe(keyId)
			expect(#pickups()):toBe(2)
			expect(target.Parent):toBeNil()
			expect(services.ObbyService:IsCarrying(player)):toBe(true)
			expect(player.Character:FindFirstChild("ObbyKeyCarried") ~= nil):toBe(true)
			expect(#toasts(player, goodPhase)):toBe(1)
			expect(string.find(toasts(player, goodPhase)[1], Keys.ById[keyId].Name, 1, true) ~= nil):toBe(true)
		end)

		it("rejects a prompt trigger from a player who is far away", function()
			boot()
			local player = join("Faraway")
			standOn(player, "Start")
			hold(player, capAt(1))
			expect(carried(player)):toBeNil()
			expect(#pickups()):toBe(3)
		end)

		it("rejects a trigger from a dead player or one outside the zone", function()
			boot()
			local outside = join("Outsider")
			hold(outside, capAt(1))
			expect(carried(outside)):toBeNil()
			local dead = join("Ghost")
			nearSpawn(dead, 1)
			dead.Character.Humanoid.Health = 0
			hold(dead, capAt(1))
			expect(carried(dead)):toBeNil()
			expect(#pickups()):toBe(3)
		end)

		it("lets a player hold only one obby key at a time", function()
			boot()
			local player = join("Greedy")
			takeKey(player, 1)
			local first = carried(player)
			takeKey(player, 2)
			tick(4)
			expect(carried(player)):toBe(first)
			expect(#pickups()):toBe(2)
			expect(#toasts(player, goodPhase)):toBe(1)
		end)

		it("gives different players different pedestals", function()
			boot()
			local a = join("Ann")
			local b = join("Ben")
			takeKey(a, 1)
			takeKey(b, 2)
			expect(carried(a) ~= nil and carried(b) ~= nil):toBe(true)
			expect(#pickups()):toBe(1)
		end)

		it("refills only the emptied pedestal after the respawn time", function()
			boot()
			local player = join("Waiter")
			takeKey(player, 1)
			expect(capAt(1)):toBeNil()
			world:advance(config.RespawnSeconds - 1)
			expect(capAt(1)):toBeNil()
			expect(#pickups()):toBe(2)
			world:advance(1.5)
			expect(capAt(1) ~= nil):toBe(true)
			expect(#pickups()):toBe(3)
			expect(config.RespawnSeconds):toBe(60)
		end)

		it("can be taken again after it refills", function()
			boot()
			local a = join("First")
			takeKey(a, 3)
			walkOut(a)
			world:advance(config.RespawnSeconds + 1)
			local b = join("Second")
			takeKey(b, 3)
			expect(carried(b) ~= nil):toBe(true)
		end)
	end)

	describe("delivery", function()
		it("adds the key to the inventory and discoveries at the player's own base", function()
			boot()
			local player, data = join("Courier", { Rolls = 12 })
			takeKey(player, 1)
			local keyId = carried(player)
			tick(4)
			expect(data.Inventory[keyId]):toBeNil()
			walkOut(player)
			expect(data.Inventory[keyId]):toBe(1)
			expect(data.Discovered[keyId]):toBe(1)
			expect(data.Rolls):toBe(12)
			expect(carried(player)):toBeNil()
			expect(services.ObbyService:IsCarrying(player)):toBe(false)
			expect(player.Character:FindFirstChild("ObbyKeyCarried")):toBeNil()
			expect((world.saves[player] or 0) > 0):toBe(true)
			expect(#toasts(player, goodPhase)):toBe(2)
			walkOut(player)
			expect(data.Inventory[keyId]):toBe(1)
		end)

		it("auto places the key like a roll does", function()
			boot()
			local player, data = join("Placer", { Settings = { AutoPlace = true } })
			takeKey(player, 1)
			local keyId = carried(player)
			walkOut(player)
			expect(data.Board[1]):toBe(keyId)
			expect(S.totals(data)[keyId]):toBe(1)
			expect(data.Discovered[keyId]):toBe(1)
		end)

		it("counts repeat deliveries of the same key", function()
			boot()
			local player, data = join("Repeat")
			takeKey(player, 1)
			local keyId = carried(player)
			data.Discovered[keyId] = 4
			walkOut(player)
			expect(data.Discovered[keyId]):toBe(5)
		end)

		it("needs the player's own base, not any base", function()
			boot()
			local player, data = join("Lost")
			local other = join("Other")
			takeKey(player, 1)
			fake.Bases[other].CFrame = CFrame.new(60, 0, 60)
			moveTo(player, Vector3.new(60, 3, 60))
			tick(3)
			expect(carried(player) ~= nil):toBe(true)
			expect(next(data.Inventory)):toBeNil()
		end)
	end)

	describe("losing the key", function()
		it("drops the key on death without returning or granting it", function()
			boot()
			local player, data = join("Faller")
			takeKey(player, 1)
			world:killCharacter(player)
			expect(services.ObbyService:IsCarrying(player)):toBe(false)
			expect(carried(player)):toBeNil()
			expect(#toasts(player, badPhase)):toBe(1)
			tick(4)
			expect(#pickups()):toBe(2)
			expect(next(data.Inventory)):toBeNil()
			expect(next(data.Discovered)):toBeNil()
			world:resetCharacter(player)
			world:spawnCharacter(player, homeX, 3, homeZ)
			tick(4)
			expect(next(data.Inventory)):toBeNil()
		end)

		it("drops the key when the character is removed", function()
			boot()
			local player, data = join("Resetter")
			takeKey(player, 1)
			world:resetCharacter(player)
			expect(services.ObbyService:IsCarrying(player)):toBe(false)
			expect(next(data.Inventory)):toBeNil()
		end)

		it("drops the key when the player leaves", function()
			boot()
			local player = join("Quitter")
			takeKey(player, 1)
			world:removePlayer(player)
			expect(services.ObbyService:IsCarrying(player)):toBe(false)
			tick(4)
			expect(#pickups()):toBe(2)
		end)

		it("kills a player who falls into the lava", function()
			boot()
			local player = join("Diver")
			local lava = course:FindFirstChild("Lava")
			moveTo(player, Vector3.new(lava.CFrame.Position.X, config.LavaTop + 2, lava.CFrame.Position.Z))
			tick()
			expect(player.Character.Humanoid.Health):toBe(0)
		end)

		it("does not kill players on keys, pads or the end pad", function()
			boot()
			local player = join("Hopper")
			for _, name in { "Start", "Safe1", "Approach", "End" } do
				standOn(player, name)
				expect(player.Character.Humanoid.Health):toBe(100)
			end
			for _, part in course:GetDescendants() do
				if string.find(part.Name, "Key_RunB_", 1, true) == 1 then
					standOnPart(player, part)
					expect(player.Character.Humanoid.Health):toBe(100)
				end
			end
		end)

		it("does not kill players outside the zone", function()
			boot()
			local player = join("Walker")
			moveTo(player, Vector3.new(0, config.LavaTop + 2, 0))
			tick(3)
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
			takeKey(thief, 1)
			local keyId = carried(thief)
			expect(keyId ~= nil):toBe(true)
			moveTo(thief, Vector3.new(-5000, 3, 10))
			trySteal()
			local reasons = world:require("ReplicatedStorage.Rules.Steal").Reasons
			local rejected = toasts(thief, badPhase)
			expect(rejected[#rejected]):toBe(reasons.Carrying)
			expect(world.Data:Replica(victim).Data.Board[1]):toBe("GlassTink")
			expect(services.StealService:IsCarrying(thief)):toBe(false)
			expect(carried(thief)):toBe(keyId)
		end)

		it("blocks taking an obby key while carrying a stolen one", function()
			trySteal()
			expect(services.StealService:IsCarrying(thief)):toBe(true)
			expect(carried(thief)):toBe("GlassTink")
			takeKey(thief, 1)
			tick(4)
			expect(carried(thief)):toBe("GlassTink")
			expect(#pickups()):toBe(3)
			expect(services.ObbyService:IsCarrying(thief)):toBe(false)
		end)
	end)

	describe("checkpoints", function()
		local function respawnPosition(player: any): any
			local cframe = fake.Respawns[player]
			return if cframe then cframe.Position else nil
		end

		local function isAt(player: any, name: string): boolean
			local part = course:FindFirstChild(name)
			local expected = part.CFrame:PointToWorldSpace(Vector3.new(0, part.Size.Y / 2 + 4, 0))
			local position = respawnPosition(player)
			return position ~= nil and (position - expected).Magnitude < 1e-3
		end

		it("sets the respawn point on the start pad, safe area and end pad", function()
			boot()
			local player = join("Checker")
			expect(respawnPosition(player)):toBeNil()
			standOn(player, "Start")
			expect(isAt(player, "Start")):toBe(true)
			standOn(player, "Safe1")
			expect(isAt(player, "Safe1")):toBe(true)
			standOn(player, "End")
			expect(isAt(player, "End")):toBe(true)
		end)

		it("keeps the checkpoint while hopping across keys", function()
			boot()
			local player = join("Climber")
			standOn(player, "Safe1")
			hop(player, 4)
			expect(isAt(player, "Safe1")):toBe(true)
		end)

		it("keeps the checkpoint through death and the respawn", function()
			boot()
			local player = join("Retry")
			standOn(player, "Safe1")
			world:killCharacter(player)
			world:resetCharacter(player)
			world:spawnCharacter(player, homeX, 3, homeZ)
			tick(4)
			expect(isAt(player, "Safe1")):toBe(false)
			expect(respawnPosition(player)):toBeNil()
		end)

		it("clears the checkpoint when the player leaves the zone", function()
			boot()
			local player = join("Quitter")
			standOn(player, "Safe1")
			expect(respawnPosition(player) ~= nil):toBe(true)
			walkOut(player)
			expect(respawnPosition(player)):toBeNil()
		end)

		it("keeps checkpoints separate per player", function()
			boot()
			local a = join("Alpha")
			local b = join("Beta")
			standOn(a, "Start")
			standOn(b, "End")
			expect(isAt(a, "Start")):toBe(true)
			expect(isAt(b, "End")):toBe(true)
			walkOut(a)
			expect(respawnPosition(a)):toBeNil()
			expect(respawnPosition(b) ~= nil):toBe(true)
		end)

		it("sends a player home from a home pad and clears the checkpoint", function()
			boot()
			local player = join("Homebody")
			standOn(player, "Safe1")
			moveTo(player, above(course:FindFirstChild("Safe1Home"), 2))
			tick()
			expect(fake.Homed[player]):toBe(1)
			tick()
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
			expect(nearBase(joinReal("Real0"))):toBe(true)
		end)

		it("respawns at the checkpoint after dying inside the obby and keeps the taps", function()
			local player = joinReal("Real")
			hop(player, 12)
			standOn(player, "Safe1")
			die(player)
			local part = course:FindFirstChild("Safe1")
			local expected = part.CFrame:PointToWorldSpace(Vector3.new(0, part.Size.Y / 2 + 4, 0))
			expect((rootPosition(player) - expected).Magnitude < 1e-3):toBe(true)
			tick(2)
			expect(tapsOf(player)):toBe(12)
			expect(world:walkSpeed(player)):toBe(Obby.SpeedFor(12))
			expect(nearBase(player)):toBe(false)
		end)

		it("respawns at the base again once the checkpoint is cleared", function()
			local player = joinReal("Real2")
			standOn(player, "Safe1")
			walkOut(player)
			die(player)
			expect(nearBase(player)):toBe(true)
			expect(world:walkSpeed(player)):toBe(24)
		end)

		it("sends a player home from a home pad with the real plot service", function()
			local player = joinReal("Real3")
			standOn(player, "Safe1")
			moveTo(player, above(course:FindFirstChild("Safe1Home"), 2))
			tick()
			expect(nearBase(player)):toBe(true)
			tick()
			die(player)
			expect(nearBase(player)):toBe(true)
		end)

		it("forgets the player when they leave", function()
			local player = joinReal("Real4")
			standOn(player, "Safe1")
			world:removePlayer(player)
			tick(2)
			expect(world.errors):toEqual({})
		end)
	end)

	describe("keycap mesh skin", function()
		local function bootSkinned(id: string)
			world.overrides[world.tree.ReplicatedStorage.Config.Meshes] =
				{ Keycap = id, RollKey = "", KeyboardCase = "" }
			world:require("ServerScriptService.Utils.MeshTemplates").Load()
			boot()
			world:advance(0.5)
		end

		it("swaps every tap and pop-up key for a keycap mesh with the same shape and attributes", function()
			bootSkinned("rbxassetid://1")
			local plain = course:FindFirstChild("Key_RunA_1_2")
			expect(plain:IsA("MeshPart")):toBe(true)
			expect(plain.Size):toBe(Vector3.new(6.56, 2.2, 6.56))
			expect(plain:GetAttribute("ObbyRole")):toBe("TapKey")
			expect(plain.Color):toBe(roblox.Color3.fromRGB(222, 218, 208))
			local shift = course:FindFirstChild("PopUp_SHIFT")
			expect(shift:IsA("MeshPart")):toBe(true)
			expect(shift:GetAttribute("ObbyRole")):toBe("PopUpKey")
			expect(shift.Color):toBe(Keys.RarityByName.Epic.Color)
			for _, part in course:GetDescendants() do
				local role = part:GetAttribute("ObbyRole")
				if role == "TapKey" or role == "PopUpKey" then
					expect(part:IsA("MeshPart")):toBe(true)
				end
			end
		end)

		it("still counts taps and raises pop-ups on the swapped parts", function()
			bootSkinned("rbxassetid://1")
			local player = join("Skinned")
			hop(player, 6)
			expect(tapsOf(player)):toBe(6)
			local shift = course:FindFirstChild("PopUp_SHIFT")
			local rest = shift.CFrame.Position.Y
			local highest, lowest = rest, rest
			for _ = 1, 16 do
				world:advance(0.5)
				highest = math.max(highest, shift.CFrame.Position.Y)
				lowest = math.min(lowest, shift.CFrame.Position.Y)
			end
			expect(highest - lowest):toBeCloseTo(6, 1e-3)
		end)

		it("keeps plain parts when the mesh fails to load", function()
			world.meshFailures["rbxassetid://2"] = true
			bootSkinned("rbxassetid://2")
			expect(course:FindFirstChild("Key_RunA_1_2"):IsA("Part")):toBe(true)
		end)
	end)

	describe("cleanup", function()
		it("removes the built course, pickups, taps and speed bonus on Destroy", function()
			boot()
			local player = join("Cleaner")
			hop(player, 12)
			takeKey(player, 1)
			expect(world:walkSpeed(player)):toBe(Obby.SpeedFor(tapsOf(player)))
			services.ObbyService:Destroy()
			expect(world.workspace:FindFirstChild("Obby")):toBeNil()
			expect(world:walkSpeed(player)):toBe(24)
			expect(player.Character:GetAttribute("TapSpeed")):toBeNil()
			expect(tapsOf(player)):toBeNil()
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

		it("keeps an authored course but removes its pickups and stops everything on Destroy", function()
			local authored = authoredNested()
			boot()
			expect(#pickups()):toBe(1)
			services.ObbyService:Destroy()
			expect(world.workspace:FindFirstChild("Obby") == authored):toBe(true)
			expect(#pickups()):toBe(0)
			expect(authored:FindFirstChild("Zone", true) ~= nil):toBe(true)
			world:advance(config.RespawnSeconds * 3)
			expect(#pickups()):toBe(0)
		end)

		it("forgets players who leave and keeps serving the others", function()
			boot()
			local gone = join("Gone")
			local stays = join("Stays")
			hop(gone, 8)
			hop(stays, 8)
			world:removePlayer(gone)
			tick(4)
			expect(world:walkSpeed(stays)):toBe(Obby.SpeedFor(8))
			expect(tapsOf(stays)):toBe(8)
		end)

		it("does nothing for players without data or a character", function()
			boot()
			local stranger = world:newPlayer()
			local noData = world:newPlayer()
			world:spawnCharacter(noData, 0, 3, 0)
			tick(4)
			expect(stranger.Character):toBeNil()
		end)
	end)
end)
