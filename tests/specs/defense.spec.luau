local roblox = require("@lune/roblox")
local H = require("../harness/Harness")
local S = require("../support")

local Vector3 = roblox.Vector3

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

describe("Base defense", function()
	local world, registry, plots, GameConfig, Upgrades, Steal, defense

	beforeEach(function()
		world = H.newWorld({ Time = 1700000000 })
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		Upgrades = world:require("ReplicatedStorage.Config.Upgrades")
		Steal = world:require("ReplicatedStorage.Rules.Steal")
		defense = GameConfig.Defense
		world.workspace = world:newInstance("Folder")
		local plotService = world:require("ServerScriptService.Services.PlotService")
		registry = world:boot(
			{ "KeyboardService", "PlotService", "StealService", "UpgradeService" },
			{ PlotService = plotService }
		)
		plots = world.workspace:FindFirstChild("Plots")
	end)

	afterEach(function()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	local function join(name: string, overrides: any?, fireLoaded: boolean?)
		local data: any = { PlaySeconds = 5000, Board = S.board("GlassTink", "PlainClack"), TheftLessonDone = true }
		for key, value in overrides or {} do
			data[key] = value
		end
		return world:join({ Name = name }, data, fireLoaded ~= false)
	end

	local function countKeys(table_: { [any]: any }): number
		local count = 0
		for _ in table_ do
			count += 1
		end
		return count
	end

	local function wallParts(plot: any): { [string]: any }
		local out = {}
		local folder = plot:FindFirstChild("GlassWalls")
		if folder then
			for _, part in folder:GetChildren() do
				out[part.Name] = part
			end
		end
		return out
	end

	local function localPosition(plot: any, part: any): any
		return plot.Base.CFrame:ToObjectSpace(part.CFrame).Position
	end

	local function triggerLock(_plot: any, player: any): any
		return world:invoke("LockBase", player)
	end

	local function lasersOf(plot: any): { any }
		local folder = plot:FindFirstChild("Lasers")
		return if folder then folder:GetChildren() else {}
	end

	local function localRelative(plot: any, player: any): any
		return plot.Base.CFrame:PointToObjectSpace(player.Character.HumanoidRootPart.CFrame.Position)
	end

	describe("walls", function()
		local inset = 0.95
		local function glassOnly(plot: any): { [string]: any }
			local out = {}
			for name, part in wallParts(plot) do
				if part.Material == roblox.Enum.Material.Glass then
					out[name] = part
				end
			end
			return out
		end

		it("builds no code walls at level 0", function()
			expect(#plots:GetChildren()):toBe(GameConfig.PlotCount)
			for _, plot in plots:GetChildren() do
				expect(plot:FindFirstChild("GlassWalls")):toBeNil()
				expect(plot:FindFirstChild("Walls")):toBeNil()
				expect(plot:GetAttribute("WallHeight")):toBe(0)
			end
		end)

		it("raises glass by the Walls upgrade step per level starting at the base top", function()
			local step = Upgrades.ById.Walls.PerLevel
			expect(step):toBe(3)
			for level = 1, Upgrades.ById.Walls.MaxLevel do
				local player = join(`Owner{level}`, { Upgrades = { Walls = level } })
				local plot = registry.PlotService:GetPlot(player)
				local height = level * step
				expect(registry.PlotService:GetWallHeight(player)):toBe(height)
				expect(plot:GetAttribute("WallHeight")):toBe(height)
				local glass = glassOnly(plot)
				expect(countKeys(glass)):toBe(5)
				for _, part in glass do
					expect(part.Size.Y):toBe(height)
					expect(localPosition(plot, part).Y - height / 2):toBeCloseTo(plot.Base.Size.Y / 2, 1e-3)
				end
				world:removePlayer(player)
				expect(plot:FindFirstChild("GlassWalls")):toBeNil()
				expect(plot:GetAttribute("WallHeight")):toBe(0)
			end
		end)

		it("styles glass panels as see-through blockers", function()
			local player = join("Styled", { Upgrades = { Walls = 1 } })
			local plot = registry.PlotService:GetPlot(player)
			for _, part in glassOnly(plot) do
				expect(part.Material == roblox.Enum.Material.Glass):toBe(true)
				expect(part.Transparency):toBeCloseTo(0.55, 1e-6)
				expect(part.Reflectance):toBeCloseTo(0.1, 1e-6)
				expect(part.CastShadow):toBe(false)
				expect(part.CanCollide):toBe(true)
				expect(part.CanQuery):toBe(false)
				expect(part.CanTouch):toBe(false)
				expect(part.Anchored):toBe(true)
				expect(math.abs(part.Size.X - 0.6) < 1e-4 or math.abs(part.Size.Z - 0.6) < 1e-4):toBe(true)
			end
		end)

		it("places pillars at the four corners and both sides of the entrance", function()
			local player = join("Pillars", { Upgrades = { Walls = 2 } })
			local plot = registry.PlotService:GetPlot(player)
			local parts = wallParts(plot)
			local cx = 22 - inset
			local gate = defense.EntranceWidth / 2 + 0.7
			local expected = {
				PillarBackLeft = { -cx, cx },
				PillarBackRight = { cx, cx },
				PillarFrontLeft = { -cx, -cx },
				PillarFrontRight = { cx, -cx },
				PillarGateLeft = { -gate, -cx },
				PillarGateRight = { gate, -cx },
			}
			for name, spot in expected do
				local pillar = parts[name]
				expect(pillar ~= nil):toBe(true)
				local position = localPosition(plot, pillar)
				expect(position.X):toBeCloseTo(spot[1], 1e-3)
				expect(position.Z):toBeCloseTo(spot[2], 1e-3)
				expect(pillar.Size.X):toBeCloseTo(1.4, 1e-4)
				expect(pillar.Size.Z):toBeCloseTo(1.4, 1e-4)
				expect(pillar.Size.Y):toBeCloseTo(6.4, 1e-3)
				expect(position.Y - pillar.Size.Y / 2):toBeCloseTo(plot.Base.Size.Y / 2, 1e-3)
				expect(pillar.Material == roblox.Enum.Material.Metal):toBe(true)
				expect(pillar.CastShadow):toBe(true)
				expect(pillar.CanCollide):toBe(true)
			end
			local gap = localPosition(plot, parts.PillarGateRight).X - localPosition(plot, parts.PillarGateLeft).X
			expect(gap - 1.4):toBeCloseTo(defense.EntranceWidth, 1e-3)
		end)

		it("tops each glass panel with a thin rail", function()
			local player = join("Railed", { Upgrades = { Walls = 1 } })
			local plot = registry.PlotService:GetPlot(player)
			local parts = wallParts(plot)
			for _, name in { "Back", "Left", "Right", "FrontLeft", "FrontRight" } do
				local glass, rail = parts[name], parts[`Rail{name}`]
				expect(rail ~= nil):toBe(true)
				expect(rail.Size.Y):toBeCloseTo(0.3, 1e-6)
				expect(localPosition(plot, rail).Y - rail.Size.Y / 2):toBeCloseTo(
					localPosition(plot, glass).Y + glass.Size.Y / 2,
					1e-3
				)
			end
		end)

		it("leaves one centered entrance gap in the front edge facing the map center", function()
			for index = 1, 5 do
				local player = join(`Gate{index}`, { Upgrades = { Walls = 1 } })
				local plot = registry.PlotService:GetPlot(player)
				local parts = wallParts(plot)
				local left, right = localPosition(plot, parts.FrontLeft), localPosition(plot, parts.FrontRight)
				local leftInner = left.X + parts.FrontLeft.Size.X / 2
				local rightInner = right.X - parts.FrontRight.Size.X / 2
				expect(rightInner - leftInner):toBeCloseTo(defense.EntranceWidth + 1.4, 1e-3)
				expect(leftInner + rightInner):toBeCloseTo(0, 1e-3)
				expect(left.Z):toBeCloseTo(-22 + inset, 1e-3)
				expect(localPosition(plot, parts.Back).Z > 0):toBe(true)
				local front = parts.FrontLeft.CFrame.Position
				if plot.Name == "Plot1" or plot.Name == "Plot5" then
					expect(Vector3.new(front.X, 0, front.Z).Magnitude < plot.Base.CFrame.Position.Magnitude):toBe(true)
				end
			end
		end)

		it("shows glass when the Walls upgrade is bought and hides it when the owner leaves", function()
			local player, data = join("Builder", { Cash = 1e9 })
			local plot = registry.PlotService:GetPlot(player)
			expect(plot:FindFirstChild("GlassWalls")):toBeNil()
			expect(world:invoke("BuyUpgrade", player, "Walls", 1)):toBe(true)
			expect(data.Upgrades.Walls):toBe(1)
			expect(wallParts(plot).Back.Size.Y):toBe(3)
			expect(world:invoke("BuyUpgrade", player, "Walls", 1)):toBe(true)
			expect(wallParts(plot).Back.Size.Y):toBe(6)
			world:removePlayer(player)
			expect(plot:FindFirstChild("GlassWalls")):toBeNil()
		end)
	end)

	describe("walk speed", function()
		it("uses the configured normal speed", function()
			expect(GameConfig.Steal.NormalWalkSpeed):toBe(24)
			expect(GameConfig.Steal.CarryWalkSpeed):toBe(18)
		end)

		it("sets every spawned character to the normal speed", function()
			local player = join("Runner")
			world:spawnCharacter(player, 0, 3, 0)
			world:flush()
			expect(world:walkSpeed(player)):toBe(GameConfig.Steal.NormalWalkSpeed)
			world:resetCharacter(player)
			world:spawnCharacter(player, 0, 3, 0)
			world:flush()
			expect(world:walkSpeed(player)):toBe(GameConfig.Steal.NormalWalkSpeed)
		end)

		it("fixes a character that spawned before the data loaded", function()
			local player, data = join("Early", { Upgrades = {} }, false)
			world:spawnCharacter(player, 0, 3, 0)
			expect(world:walkSpeed(player)):toBe(16)
			world.Data.Service.PlayerLoaded:Fire(player, data)
			world:flush()
			expect(world:walkSpeed(player)):toBe(GameConfig.Steal.NormalWalkSpeed)
		end)
	end)

	describe("lock base button", function()
		local function hasPad(plot: any): boolean
			for _, descendant in plot:GetDescendants() do
				if descendant.Name == "LockPad" or descendant.Name == "LockPrompt" then
					return true
				end
			end
			return false
		end

		it("has no lock pad or prompt in any plot", function()
			for _, plot in plots:GetChildren() do
				expect(hasPad(plot)):toBe(false)
			end
			local owner = join("Owner")
			expect(hasPad(registry.PlotService:GetPlot(owner))):toBe(false)
		end)

		it("locks the caller's own base through the LockBase packet", function()
			local owner = join("Owner")
			local other = join("Other")
			local plot = registry.PlotService:GetPlot(owner)
			expect(world:invoke("LockBase", owner)):toBe(true)
			expect(registry.PlotService:IsLocked(owner)):toBe(true)
			expect(registry.PlotService:IsLocked(other)):toBe(false)
			expect(plot:GetAttribute("LockedUntil")):toBe(world.now + defense.LockBaseSeconds)
			expect(#lasersOf(plot) >= 3):toBe(true)
		end)

		it("never locks someone else's base", function()
			local owner = join("Owner")
			local other = join("Other")
			expect(world:invoke("LockBase", other)):toBe(true)
			expect(registry.PlotService:IsLocked(other)):toBe(true)
			expect(registry.PlotService:IsLocked(owner)):toBe(false)
			expect(registry.PlotService:GetPlot(owner):GetAttribute("LockedUntil")):toBeNil()
		end)

		it("fails without a plot", function()
			local owner = join("Owner")
			world:removePlayer(owner)
			expect(world:invoke("LockBase", owner)):toBe(false)
		end)

		it("fails while locked and during the cooldown", function()
			local owner = join("Owner")
			expect(world:invoke("LockBase", owner)):toBe(true)
			expect(world:invoke("LockBase", owner)):toBe(false)
			world:advance(defense.LockBaseSeconds + 1)
			expect(world:invoke("LockBase", owner)):toBe(false)
			world:advance(defense.LockCooldownSeconds)
			expect(world:invoke("LockBase", owner)):toBe(true)
		end)
	end)

	describe("wall stability", function()
		local function identities(plot: any): { [string]: any }
			return wallParts(plot)
		end

		it("keeps the same wall instances when the board changes", function()
			local player = join("Stable", { Upgrades = { Walls = 2 } })
			local plot = registry.PlotService:GetPlot(player)
			local before = identities(plot)
			local folder = plot.GlassWalls
			for _ = 1, 5 do
				registry.KeyboardService.BoardChanged:Fire(player)
			end
			expect(plot.GlassWalls == folder):toBe(true)
			local after = identities(plot)
			for name, part in before do
				expect(after[name] == part):toBe(true)
			end
			expect(countKeys(after)):toBe(countKeys(before))
			expect(countKeys(after)):toBe(16)
		end)

		it("resizes the same instances in place when the level changes", function()
			local player, data = join("Grower", { Cash = 1e9, Upgrades = { Walls = 1 } })
			local plot = registry.PlotService:GetPlot(player)
			local before = identities(plot)
			expect(world:invoke("BuyUpgrade", player, "Walls", 1)):toBe(true)
			expect(data.Upgrades.Walls):toBe(2)
			local after = identities(plot)
			for name, part in before do
				expect(after[name] == part):toBe(true)
			end
			expect(before.Back.Size.Y):toBe(6)
			expect(localPosition(plot, before.Back).Y - 3):toBeCloseTo(plot.Base.Size.Y / 2, 1e-3)
			expect(before.PillarBackLeft.Size.Y):toBeCloseTo(6.4, 1e-3)
		end)

		it("reuses the cached instances when a new owner arrives", function()
			local player = join("First", { Upgrades = { Walls = 1 } })
			local plot = registry.PlotService:GetPlot(player)
			local before = identities(plot)
			world:removePlayer(player)
			expect(plot:FindFirstChild("GlassWalls")):toBeNil()
			local next = join("Second", { Upgrades = { Walls = 1 } })
			expect(registry.PlotService:GetPlot(next) == plot):toBe(true)
			for name, part in identities(plot) do
				expect(before[name] == part):toBe(true)
			end
		end)

		it("keeps the glass inside the plot model", function()
			local player = join("Parent", { Upgrades = { Walls = 1 } })
			local plot = registry.PlotService:GetPlot(player)
			expect(plot.GlassWalls.Parent == plot):toBe(true)
		end)
	end)

	describe("authored plots", function()
		local authored: any
		local nested: any

		local function bootAuthored(withFence: boolean, withWalls: boolean, options: any?)
			world:destroy()
			world = H.newWorld({ Time = 1700000000 })
			world.workspace = world:newInstance("Folder")
			local folder = world:newInstance("Folder")
			folder.Name = "Plots"
			authored = world:newInstance("Model")
			authored.Name = "Plot1"
			local origin = if options and options.Origin then options.Origin else roblox.CFrame.new(300, 0.5, 0)
			for name, size in
				{
					Base = Vector3.new(44, 1, 44),
					RollKey = Vector3.new(8, 3, 8),
					Board = Vector3.new(31, 1.5, 9.6),
				}
			do
				local part = world:newInstance("Part")
				part.Name = name
				part.Size = size
				part.CFrame = if name == "Base" then origin else origin * roblox.CFrame.new(0, 2, -10)
				part.Color = roblox.Color3.new(1, 1, 1)
				part.Parent = authored
			end
			nested = world:newInstance("Model")
			nested.Name = "Decor"
			local inner = world:newInstance("Model")
			inner.Name = "Lamp"
			local lampPart = world:newInstance("Part")
			lampPart.Name = "Post"
			lampPart.Size = Vector3.new(2, 40, 2)
			lampPart.CFrame = origin * roblox.CFrame.new(100, 20, 100)
			lampPart.Parent = inner
			inner.Parent = nested
			nested.Parent = authored
			if withFence then
				local fence = world:newInstance("Folder")
				fence.Name = "Fence"
				if options and options.Specs then
					local groups: { any } = { fence }
					for depth = 1, 2 do
						local group = world:newInstance("Model")
						group.Name = `Group{depth}`
						group.Parent = groups[depth]
						groups[depth + 1] = group
					end
					for index, spec in options.Specs do
						local part = world:newInstance("Part")
						part.Name = `Part{index}`
						part.Size = spec.Size
						part.CFrame = origin * roblox.CFrame.new(spec.Position)
						part.Parent = groups[(spec.Depth or 0) + 1]
					end
				else
					local post = world:newInstance("Part")
					post.Name = "Rail"
					post.Size = Vector3.new(44, 3, 0.5)
					post.CFrame = origin * roblox.CFrame.new(0, 2, 22)
					post.Parent = fence
				end
				fence.Parent = authored
			end
			if withWalls then
				local walls = world:newInstance("Folder")
				walls.Name = "Walls"
				for index, offset in { -20, 20 } do
					local wall = world:newInstance("Part")
					wall.Name = `Wall{index}`
					wall.Size = Vector3.new(1, 5, 44)
					wall.CFrame = origin * roblox.CFrame.new(offset, 0.5 + 2.5, 0)
					wall.Parent = walls
				end
				walls.Parent = authored
			end
			authored.Parent = folder
			folder.Parent = world.workspace
			local plotService = world:require("ServerScriptService.Services.PlotService")
			registry = world:boot(
				{ "KeyboardService", "PlotService", "StealService", "UpgradeService" },
				{ PlotService = plotService }
			)
			return authored
		end

		local function snapshot(fence: any): { [any]: { any } }
			local out = {}
			for _, part in fence:GetDescendants() do
				if part:IsA("BasePart") then
					out[part] = { part.Size, part.CFrame }
				end
			end
			return out
		end

		it("builds nothing at level 0 and leaves the fence untouched", function()
			local plot = bootAuthored(true, false)
			local before = snapshot(plot.Fence)
			expect(plot:FindFirstChild("GlassWalls")):toBeNil()
			expect(plot:GetAttribute("WallHeight")):toBeCloseTo(3, 1e-3)
			expect(snapshot(plot.Fence)):toEqual(before)
		end)

		it("stacks glass on top of the fence without touching authored parts", function()
			local plot = bootAuthored(true, false)
			local before = snapshot(plot.Fence)
			local player = join("Owner", { Upgrades = { Walls = 2 } })
			expect(registry.PlotService:GetPlot(player) == plot):toBe(true)
			local parts = wallParts(plot)
			local fenceTop = 3 + plot.Base.Size.Y / 2
			for _, name in { "Back", "Left", "Right", "FrontLeft", "FrontRight" } do
				local part = parts[name]
				expect(part.Size.Y):toBe(6)
				expect(localPosition(plot, part).Y - 3):toBeCloseTo(fenceTop, 1e-3)
			end
			expect(plot:GetAttribute("WallHeight")):toBeCloseTo(9, 1e-3)
			expect(registry.PlotService:GetWallHeight(player)):toBeCloseTo(9, 1e-3)
			local rail = plot.Fence.Rail
			local railFaceZ = 22 - rail.Size.Z / 2
			local backZ = localPosition(plot, parts.Back).Z
			expect(math.abs(backZ + parts.Back.Size.Z / 2 - railFaceZ) > 1e-3):toBe(true)
			expect(math.abs(backZ - parts.Back.Size.Z / 2 - railFaceZ) > 1e-3):toBe(true)
			expect(backZ + parts.Back.Size.Z / 2 < 22):toBe(true)
			expect(snapshot(plot.Fence)):toEqual(before)
			expect(#plot.Fence:GetChildren()):toBe(1)
			expect(plot.Fence.Rail.Size.X):toBe(44)
			expect(#nested:GetChildren()):toBe(1)
			expect(#nested.Lamp:GetChildren()):toBe(1)
			expect(nested.Lamp.Post.CFrame.Position.X):toBeCloseTo(400, 1e-3)
			expect(nested.Lamp.Post.Size.Y):toBe(40)
			expect(plot.GlassWalls.Parent == plot):toBe(true)
			expect(plot.Base.Size.X):toBe(44)
			world:removePlayer(player)
			expect(snapshot(plot.Fence)):toEqual(before)
			expect(plot:GetAttribute("WallHeight")):toBeCloseTo(3, 1e-3)
		end)

		local function railSpecs(hasGap: boolean, depth: number): { any }
			local function spec(size: any, position: any, level: number?)
				return { Size = size, Position = position, Depth = level or depth }
			end
			local specs = {
				spec(Vector3.new(40, 3, 1), Vector3.new(0, 2, 18.5)),
				spec(Vector3.new(1, 3, 38), Vector3.new(-19.5, 2, 0)),
				spec(Vector3.new(1, 3, 38), Vector3.new(19.5, 2, 0)),
				spec(Vector3.new(1.5, 4, 1.5), Vector3.new(-19.25, 2.5, -18.25), 0),
				spec(Vector3.new(1.5, 4, 1.5), Vector3.new(19.25, 2.5, -18.25), 0),
				spec(Vector3.new(1.5, 4, 1.5), Vector3.new(-19.25, 2.5, 18.25), 0),
				spec(Vector3.new(1.5, 4, 1.5), Vector3.new(19.25, 2.5, 18.25), 0),
			}
			if hasGap then
				table.insert(specs, spec(Vector3.new(14, 3, 1), Vector3.new(-13, 2, -18.5)))
				table.insert(specs, spec(Vector3.new(16, 3, 1), Vector3.new(12, 2, -18.5)))
			else
				table.insert(specs, spec(Vector3.new(40, 3, 1), Vector3.new(0, 2, -18.5)))
			end
			return specs
		end

		local function expectFramed(plot: any, gateLeft: number, gateRight: number)
			local parts = wallParts(plot)
			local inset = 22 - 0.95
			local sx = (19.5 + inset) / 2
			local sz = (18.5 + inset) / 2
			local expected = {
				PillarBackLeft = { -sx, sz },
				PillarBackRight = { sx, sz },
				PillarFrontLeft = { -sx, -sz },
				PillarFrontRight = { sx, -sz },
				PillarGateLeft = { gateLeft, -sz },
				PillarGateRight = { gateRight, -sz },
			}
			for name, spot in expected do
				expect(parts[name] ~= nil):toBe(true)
				local position = localPosition(plot, parts[name])
				expect(position.X):toBeCloseTo(spot[1], 1e-3)
				expect(position.Z):toBeCloseTo(spot[2], 1e-3)
			end
			local function glass(name: string, x: number, z: number, lengthX: number, lengthZ: number)
				local part = parts[name]
				expect(part ~= nil):toBe(true)
				local position = localPosition(plot, part)
				expect(position.X):toBeCloseTo(x, 1e-3)
				expect(position.Z):toBeCloseTo(z, 1e-3)
				expect(part.Size.X):toBeCloseTo(lengthX, 1e-3)
				expect(part.Size.Z):toBeCloseTo(lengthZ, 1e-3)
			end
			glass("Back", 0, sz, sx * 2, 0.6)
			glass("Left", -sx, 0, 0.6, sz * 2)
			glass("Right", sx, 0, 0.6, sz * 2)
			glass("FrontLeft", (-sx + gateLeft) / 2, -sz, gateLeft + sx, 0.6)
			glass("FrontRight", (gateRight + sx) / 2, -sz, sx - gateRight, 0.6)
		end

		it("centers pillars between the fence centerline and the plot edge inset and the off-center front gap", function()
			local plot = bootAuthored(true, false, { Specs = railSpecs(true, 0) })
			join("Owner", { Upgrades = { Walls = 2 } })
			expectFramed(plot, -6, 4)
			expect(wallParts(plot).Back.Size.Y):toBe(6)
		end)

		it("centers the entrance pillars on the fence's entry posts", function()
			local specs = railSpecs(true, 0)
			table.insert(specs, { Size = Vector3.new(1.5, 4, 1.5), Position = Vector3.new(-6.75, 2.5, -18.25), Depth = 0 })
			table.insert(specs, { Size = Vector3.new(1.5, 4, 1.5), Position = Vector3.new(4.75, 2.5, -18.25), Depth = 0 })
			local plot = bootAuthored(true, false, { Specs = specs })
			join("Owner", { Upgrades = { Walls = 1 } })
			expectFramed(plot, -6.75, 4.75)
		end)

		it("measures a rotated plot in base-local space", function()
			local origin = roblox.CFrame.new(300, 0.5, 40) * roblox.CFrame.Angles(0, math.rad(45), 0)
			local plot = bootAuthored(true, false, { Specs = railSpecs(true, 0), Origin = origin })
			join("Owner", { Upgrades = { Walls = 1 } })
			expectFramed(plot, -6, 4)
		end)

		it("measures fences made of nested models", function()
			for _, depth in { 1, 2 } do
				local plot = bootAuthored(true, false, { Specs = railSpecs(true, depth) })
				join(`Owner{depth}`, { Upgrades = { Walls = 1 } })
				expectFramed(plot, -6, 4)
			end
		end)

		it("falls back to the configured entrance centered when the front has no gap", function()
			local plot = bootAuthored(true, false, { Specs = railSpecs(false, 0) })
			join("Owner", { Upgrades = { Walls = 1 } })
			local half = defense.EntranceWidth / 2
			expectFramed(plot, -half, half)
		end)

		it("leaves the measured fence parts untouched", function()
			local plot = bootAuthored(true, false, { Specs = railSpecs(true, 1) })
			local before = snapshot(plot.Fence)
			join("Owner", { Upgrades = { Walls = 3 } })
			expect(snapshot(plot.Fence)):toEqual(before)
		end)

		it("starts the glass at the base top when there is no fence and ignores a legacy Walls folder", function()
			local plot = bootAuthored(false, true)
			local walls = plot.Walls
			local before = { walls.Wall1.Size, walls.Wall2.Size, walls.Wall1.CFrame }
			local player = join("Owner", { Upgrades = { Walls = 3 } })
			expect(registry.PlotService:GetPlot(player) == plot):toBe(true)
			expect(wallParts(plot).Back.Size.Y):toBe(9)
			expect(localPosition(plot, wallParts(plot).Back).Y - 4.5):toBeCloseTo(plot.Base.Size.Y / 2, 1e-3)
			expect(plot.Walls == walls):toBe(true)
			expect(#walls:GetChildren()):toBe(2)
			expect({ walls.Wall1.Size, walls.Wall2.Size, walls.Wall1.CFrame }):toEqual(before)
		end)
	end)

	describe("locking", function()
		it("locks only the base of the player who asks", function()
			local owner = join("Owner")
			local other = join("Other")
			local plot = registry.PlotService:GetPlot(owner)
			expect(#lasersOf(plot)):toBe(0)
			triggerLock(plot, owner)
			expect(registry.PlotService:IsLocked(owner)):toBe(true)
			expect(registry.PlotService:IsLocked(other)):toBe(false)
			expect(registry.PlotService:Lock(other)):toBe(true)
			expect(registry.PlotService:IsLocked(other)):toBe(true)
		end)

		it("rejects players without a plot", function()
			local owner = join("Owner")
			world:removePlayer(owner)
			expect(registry.PlotService:Lock(owner)):toBe(false)
		end)

		it("locks for the base time and exposes the lock attributes", function()
			local owner = join("Owner")
			local plot = registry.PlotService:GetPlot(owner)
			triggerLock(plot, owner)
			expect(registry.PlotService:GetLockedUntil(owner)):toBe(world.now + defense.LockBaseSeconds)
			expect(plot:GetAttribute("LockedUntil")):toBe(world.now + defense.LockBaseSeconds)
			expect(plot:GetAttribute("LockCooldownUntil")):toBe(
				world.now + defense.LockBaseSeconds + defense.LockCooldownSeconds
			)
		end)

		it("adds LockTime seconds per level", function()
			local step = Upgrades.ById.LockTime.PerLevel
			expect(step):toBe(10)
			for _, level in { 1, 4, Upgrades.ById.LockTime.MaxLevel } do
				local owner = join(`Locker{level}`, { Upgrades = { LockTime = level } })
				local plot = registry.PlotService:GetPlot(owner)
				local start = world.now
				triggerLock(plot, owner)
				expect(registry.PlotService:GetLockedUntil(owner)):toBe(start + defense.LockBaseSeconds + level * step)
				world:removePlayer(owner)
			end
		end)

		it("ends the lock then enforces the cooldown from the moment the lock ends", function()
			local owner = join("Owner")
			local plot = registry.PlotService:GetPlot(owner)
			local start = world.now
			triggerLock(plot, owner)
			triggerLock(plot, owner)
			expect(registry.PlotService:GetLockedUntil(owner)):toBe(start + defense.LockBaseSeconds)
			world:advance(defense.LockBaseSeconds - 1)
			expect(registry.PlotService:IsLocked(owner)):toBe(true)
			world:advance(1.5)
			expect(registry.PlotService:IsLocked(owner)):toBe(false)
			expect(#lasersOf(plot)):toBe(0)
			expect(registry.PlotService:GetLockCooldownUntil(owner)):toBe(
				start + defense.LockBaseSeconds + defense.LockCooldownSeconds
			)
			triggerLock(plot, owner)
			expect(registry.PlotService:IsLocked(owner)):toBe(false)
			world:advance(defense.LockCooldownSeconds - 2)
			triggerLock(plot, owner)
			expect(registry.PlotService:IsLocked(owner)):toBe(false)
			world:advance(2)
			triggerLock(plot, owner)
			expect(registry.PlotService:IsLocked(owner)):toBe(true)
		end)

		it("shows laser beams across the entrance and a countdown", function()
			local owner = join("Owner", { Upgrades = { Walls = 1 } })
			local plot = registry.PlotService:GetPlot(owner)
			expect(#lasersOf(plot)):toBe(0)
			triggerLock(plot, owner)
			local lasers = lasersOf(plot)
			expect(#lasers >= 3):toBe(true)
			local wallHeight = 6
			for _, laser in lasers do
				expect(laser.CanCollide):toBe(false)
				expect(laser.Anchored):toBe(true)
				expect(laser.Material == roblox.Enum.Material.Neon):toBe(true)
				expect(laser.Size.X):toBe(defense.EntranceWidth)
				local position = localPosition(plot, laser)
				expect(position.X):toBeCloseTo(0, 1e-3)
				expect(position.Z):toBeCloseTo(-22 + 0.95, 1e-3)
				expect(position.Y > plot.Base.Size.Y / 2 and position.Y < plot.Base.Size.Y / 2 + wallHeight):toBe(true)
			end
			local label = plot.LockAnchor.LockTimer.Countdown
			expect(label.Text):toBe("🔒 LOCKED 0:30")
			world:advance(5.2)
			expect(label.Text):toBe("🔒 LOCKED 0:25")
			expect(plot.LockAnchor.LockTimer.Adornee == plot.LockAnchor):toBe(true)
		end)

		it("clears the lock when the owner leaves and gives the next owner a fresh pad", function()
			local owner = join("Owner")
			local plot = registry.PlotService:GetPlot(owner)
			triggerLock(plot, owner)
			world:removePlayer(owner)
			expect(#lasersOf(plot)):toBe(0)
			expect(plot:GetAttribute("LockedUntil")):toBeNil()
			local next = join("Next")
			expect(registry.PlotService:GetPlot(next) == plot):toBe(true)
			expect(registry.PlotService:IsLocked(next)):toBe(false)
		end)

		it("fires LockChanged when a lock starts and ends", function()
			local owner = join("Owner")
			local plot = registry.PlotService:GetPlot(owner)
			local changed = 0
			registry.PlotService.LockChanged:Connect(function(player: any)
				expect(player == owner):toBe(true)
				changed += 1
			end)
			triggerLock(plot, owner)
			expect(changed):toBe(1)
			world:advance(defense.LockBaseSeconds + 0.5)
			expect(changed):toBe(2)
		end)
	end)

	describe("lasers", function()
		local function intruderSetup()
			local owner = join("Owner")
			local thief = join("Thief", { Board = S.board("OfficeTap") })
			local plot = registry.PlotService:GetPlot(owner)
			local inside = plot.Base.CFrame * roblox.CFrame.new(0, 3, 5)
			world:spawnCharacter(owner, 0, 3, 0)
			world:spawnCharacter(thief, 0, 3, 0)
			owner.Character.HumanoidRootPart.CFrame = inside
			thief.Character.HumanoidRootPart.CFrame = inside * roblox.CFrame.new(2, 0, 0)
			return owner, thief, plot, inside
		end

		it("knocks a non-owner inside the footprint out through the entrance", function()
			local owner, thief, plot, inside = intruderSetup()
			triggerLock(plot, owner)
			world:advance(0.25)
			local relative = localRelative(plot, thief)
			expect(relative.Z < -22):toBe(true)
			expect(math.abs(relative.X) <= defense.EntranceWidth / 2):toBe(true)
			local outward = plot.Base.CFrame.LookVector
			local velocity = thief.Character.HumanoidRootPart.AssemblyLinearVelocity
			expect(velocity:Dot(outward)):toBeCloseTo(defense.LaserKnockback, 1e-3)
			local facing = thief.Character.HumanoidRootPart.CFrame.LookVector
			expect(facing:Dot(outward)):toBeCloseTo(1, 1e-3)
			expect(owner.Character.HumanoidRootPart.CFrame == inside):toBe(true)
			local toasts = {}
			for _, entry in world:firedOf("StealAlert") do
				if entry.Target == thief and entry.Args[3] == 9 then
					table.insert(toasts, entry.Args[1])
				end
			end
			expect(toasts):toEqual({ "🔴 The lasers zapped you!" })
		end)

		it("leaves the owner and outsiders alone", function()
			local owner, thief, plot, inside = intruderSetup()
			local outside = plot.Base.CFrame * roblox.CFrame.new(0, 3, -40)
			thief.Character.HumanoidRootPart.CFrame = outside
			triggerLock(plot, owner)
			world:advance(1)
			expect(owner.Character.HumanoidRootPart.CFrame == inside):toBe(true)
			expect(thief.Character.HumanoidRootPart.CFrame == outside):toBe(true)
			expect(#world:firedOf("StealAlert")):toBe(0)
		end)

		it("does not knock anyone while the base is unlocked or after the lock ends", function()
			local owner, thief, plot = intruderSetup()
			local spot = thief.Character.HumanoidRootPart.CFrame
			world:advance(1)
			expect(thief.Character.HumanoidRootPart.CFrame == spot):toBe(true)
			triggerLock(plot, owner)
			world:advance(defense.LockBaseSeconds + 1)
			thief.Character.HumanoidRootPart.CFrame = spot
			world:advance(1)
			expect(thief.Character.HumanoidRootPart.CFrame == spot):toBe(true)
		end)

		it("keeps knocking a thief who walks back in", function()
			local owner, thief, plot, inside = intruderSetup()
			triggerLock(plot, owner)
			world:advance(0.25)
			thief.Character.HumanoidRootPart.CFrame = inside
			world:advance(0.25)
			expect(localRelative(plot, thief).Z < -22):toBe(true)
		end)
	end)

	describe("steals", function()
		local function stealSetup()
			local victim, victimData = join("Vic")
			local thief, thiefData = join("Bob", { Board = S.board("OfficeTap") })
			local plot = registry.PlotService:GetPlot(victim)
			local cap = registry.PlotService:GetCaps(victim)[1]
			local position = cap.CFrame.Position
			world:spawnCharacter(thief, position.X, 3, position.Z)
			world:spawnCharacter(victim, position.X + 100, 3, position.Z)
			return victim, victimData, thief, thiefData, plot, cap
		end

		local function attempt(cap: any, thief: any)
			local prompt = cap:FindFirstChild("StealPrompt")
			prompt.PromptButtonHoldBegan:Fire(thief)
			prompt.Triggered:Fire(thief)
			prompt.PromptButtonHoldEnded:Fire(thief)
		end

		local function alerts(player: any, phase: number): { any }
			local out = {}
			for _, entry in world:firedOf("StealAlert") do
				if entry.Target == player and entry.Args[3] == phase then
					table.insert(out, entry.Args)
				end
			end
			return out
		end

		it("rejects steals and disables the prompts while locked", function()
			local victim, victimData, thief, _, plot, cap = stealSetup()
			local prompt = cap:FindFirstChild("StealPrompt")
			expect(prompt.Enabled):toBe(true)
			triggerLock(plot, victim)
			expect(prompt.Enabled):toBe(false)
			for _, other in registry.PlotService:GetCaps(victim) do
				local stealPrompt = other:FindFirstChild("StealPrompt")
				if stealPrompt then
					expect(stealPrompt.Enabled):toBe(false)
				end
			end
			attempt(cap, thief)
			expect(victimData.Board[1]):toBe("GlassTink")
			expect(thief.Character:GetAttribute("CarryingKey")):toBeNil()
			local rejected = alerts(thief, 9)
			expect(#rejected):toBe(1)
			expect(rejected[1][1]):toBe(Steal.Reasons.Locked)
		end)

		it("allows steals again once the lock has ended", function()
			local victim, victimData, thief, _, plot, cap = stealSetup()
			triggerLock(plot, victim)
			world:advance(defense.LockBaseSeconds + 1)
			expect(registry.PlotService:IsLocked(victim)):toBe(false)
			local prompt = cap:FindFirstChild("StealPrompt")
			expect(prompt.Enabled):toBe(true)
			local position = cap.CFrame.Position
			world:moveCharacter(thief, position.X, 3, position.Z)
			attempt(cap, thief)
			expect(victimData.Board[1]):toBe("")
			expect(thief.Character:GetAttribute("CarryingKey")):toBe("GlassTink")
			expect(#alerts(victim, 2)):toBe(1)
		end)

		it("does not interrupt a thief who is already carrying a key out", function()
			local victim, _, thief, thiefData, plot, cap = stealSetup()
			attempt(cap, thief)
			expect(thief.Character:GetAttribute("CarryingKey")):toBe("GlassTink")
			triggerLock(plot, victim)
			world:advance(0.2)
			expect(thief.Character:GetAttribute("CarryingKey")):toBe("GlassTink")
			local base = registry.PlotService:GetBase(thief)
			local position = base.CFrame.Position
			world:moveCharacter(thief, position.X, 3, position.Z)
			world:advance(0.2)
			expect(thief.Character:GetAttribute("CarryingKey")):toBeNil()
			expect(thiefData.Board[2]):toBe("GlassTink")
		end)
	end)
end)
