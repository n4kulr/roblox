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

	local function join(name: string, overrides: any?)
		local data: any = { PlaySeconds = 5000, Board = S.board("GlassTink", "PlainClack"), TheftLessonDone = true }
		for key, value in overrides or {} do
			data[key] = value
		end
		return world:join({ Name = name }, data, true)
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
		for _, part in plot.Walls:GetChildren() do
			out[part.Name] = part
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
		it("builds base-height walls on every unowned plot", function()
			expect(#plots:GetChildren()):toBe(GameConfig.PlotCount)
			for _, plot in plots:GetChildren() do
				local parts = wallParts(plot)
				expect(countKeys(parts)):toBe(5)
				for _, part in parts do
					expect(part.Size.Y):toBe(defense.WallBaseHeight)
					expect(part.Anchored):toBe(true)
					expect(part.CanCollide):toBe(true)
					expect(part.CastShadow):toBe(false)
				end
				expect(plot:GetAttribute("WallHeight")):toBe(defense.WallBaseHeight)
			end
		end)

		it("stands the walls on the base with the configured thickness", function()
			local plot = plots.Plot1
			local parts = wallParts(plot)
			local baseTop = plot.Base.Size.Y / 2
			for _, part in parts do
				local position = localPosition(plot, part)
				expect(position.Y - part.Size.Y / 2):toBeCloseTo(baseTop, 1e-3)
			end
			expect(parts.Back.Size.Z):toBe(defense.WallThickness)
			expect(parts.Left.Size.X):toBe(defense.WallThickness)
			expect(parts.Right.Size.X):toBe(defense.WallThickness)
			expect(parts.FrontLeft.Size.Z):toBe(defense.WallThickness)
			expect(localPosition(plot, parts.Back).Z):toBeCloseTo(22 - defense.WallThickness / 2, 1e-3)
			expect(localPosition(plot, parts.Left).X):toBeCloseTo(-22 + defense.WallThickness / 2, 1e-3)
			expect(localPosition(plot, parts.Right).X):toBeCloseTo(22 - defense.WallThickness / 2, 1e-3)
		end)

		it("leaves one centered entrance gap in the front edge facing the map center", function()
			for _, plot in plots:GetChildren() do
				local parts = wallParts(plot)
				local left, right = localPosition(plot, parts.FrontLeft), localPosition(plot, parts.FrontRight)
				local leftInner = left.X + parts.FrontLeft.Size.X / 2
				local rightInner = right.X - parts.FrontRight.Size.X / 2
				expect(rightInner - leftInner):toBeCloseTo(defense.EntranceWidth, 1e-3)
				expect(leftInner + rightInner):toBeCloseTo(0, 1e-3)
				expect(left.Z):toBeCloseTo(-22 + defense.WallThickness / 2, 1e-3)
				expect(right.Z):toBeCloseTo(-22 + defense.WallThickness / 2, 1e-3)
				local front = parts.FrontLeft.CFrame.Position
				if plot.Name == "Plot1" or plot.Name == "Plot5" then
					expect(Vector3.new(front.X, 0, front.Z).Magnitude < plot.Base.CFrame.Position.Magnitude):toBe(true)
				end
				expect(localPosition(plot, parts.Back).Z > 0):toBe(true)
				local outerLeft = left.X - parts.FrontLeft.Size.X / 2
				expect(outerLeft):toBeCloseTo(-22 + defense.WallThickness, 1e-3)
			end
		end)

		it("raises the wall by the Walls upgrade step per level", function()
			local step = Upgrades.ById.Walls.PerLevel
			expect(step):toBe(3)
			for level = 0, Upgrades.ById.Walls.MaxLevel do
				local player = join(`Owner{level}`, { Upgrades = { Walls = level } })
				local plot = registry.PlotService:GetPlot(player)
				local height = defense.WallBaseHeight + level * step
				expect(registry.PlotService:GetWallHeight(player)):toBe(height)
				for _, part in wallParts(plot) do
					expect(part.Size.Y):toBe(height)
				end
				expect(plot:GetAttribute("WallHeight")):toBe(height)
				world:removePlayer(player)
			end
		end)

		it("rebuilds the walls when the Walls upgrade is bought", function()
			local player, data = join("Builder", { Cash = 1e9 })
			local plot = registry.PlotService:GetPlot(player)
			expect(wallParts(plot).Back.Size.Y):toBe(defense.WallBaseHeight)
			expect(world:invoke("BuyUpgrade", player, "Walls")):toBe(true)
			expect(data.Upgrades.Walls):toBe(1)
			for _, part in wallParts(plot) do
				expect(part.Size.Y):toBe(defense.WallBaseHeight + 3)
			end
			expect(world:invoke("BuyUpgrade", player, "Walls")):toBe(true)
			for _, part in wallParts(plot) do
				expect(part.Size.Y):toBe(defense.WallBaseHeight + 6)
			end
			expect(countKeys(wallParts(plot))):toBe(5)
		end)

		it("drops back to base height when the owner leaves", function()
			local player = join("Leaver", { Upgrades = { Walls = 3 } })
			local plot = registry.PlotService:GetPlot(player)
			expect(wallParts(plot).Back.Size.Y):toBe(defense.WallBaseHeight + 9)
			world:removePlayer(player)
			for _, part in wallParts(plot) do
				expect(part.Size.Y):toBe(defense.WallBaseHeight)
			end
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
			local player = join("Stable")
			local plot = registry.PlotService:GetPlot(player)
			local before = identities(plot)
			local folder = plot.Walls
			for _ = 1, 5 do
				registry.KeyboardService.BoardChanged:Fire(player)
			end
			expect(plot.Walls == folder):toBe(true)
			local after = identities(plot)
			for name, part in before do
				expect(after[name] == part):toBe(true)
			end
			expect(countKeys(after)):toBe(5)
		end)

		it("resizes the same wall instances in place when the height changes", function()
			local player, data = join("Grower", { Cash = 1e9 })
			local plot = registry.PlotService:GetPlot(player)
			local before = identities(plot)
			expect(world:invoke("BuyUpgrade", player, "Walls")):toBe(true)
			expect(data.Upgrades.Walls):toBe(1)
			local after = identities(plot)
			for name, part in before do
				expect(after[name] == part):toBe(true)
				expect(part.Size.Y):toBe(defense.WallBaseHeight + 3)
				expect(localPosition(plot, part).Y - part.Size.Y / 2):toBeCloseTo(plot.Base.Size.Y / 2, 1e-3)
			end
			world:removePlayer(player)
			for name, part in before do
				expect(identities(plot)[name] == part):toBe(true)
				expect(part.Size.Y):toBe(defense.WallBaseHeight)
			end
		end)

		it("sets the safe flags on every wall part", function()
			for _, part in wallParts(plots.Plot1) do
				expect(part.CanCollide):toBe(true)
				expect(part.CanTouch):toBe(false)
				expect(part.CanQuery):toBe(false)
				expect(part.CastShadow):toBe(false)
				expect(part.Anchored):toBe(true)
			end
			expect(plots.Plot1.Walls.Parent == plots.Plot1):toBe(true)
		end)
	end)

	describe("authored plots", function()
		local authored: any
		local nested: any

		local function bootAuthored(withFence: boolean, withWalls: boolean)
			world:destroy()
			world = H.newWorld({ Time = 1700000000 })
			world.workspace = world:newInstance("Folder")
			local folder = world:newInstance("Folder")
			folder.Name = "Plots"
			authored = world:newInstance("Model")
			authored.Name = "Plot1"
			local origin = roblox.CFrame.new(300, 0.5, 0)
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
				local post = world:newInstance("Part")
				post.Name = "Rail"
				post.Size = Vector3.new(44, 3, 0.5)
				post.CFrame = origin * roblox.CFrame.new(0, 2, 22)
				post.Parent = fence
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

		it("builds walls from the base alone and never touches nested models", function()
			local plot = bootAuthored(false, false)
			for _, part in wallParts(plot) do
				local position = localPosition(plot, part)
				expect(math.abs(position.X) <= 22 and math.abs(position.Z) <= 22):toBe(true)
				expect(position.Y - part.Size.Y / 2):toBeCloseTo(plot.Base.Size.Y / 2, 1e-3)
			end
			expect(plot.Walls.Parent == plot):toBe(true)
			expect(#nested:GetChildren()):toBe(1)
			expect(#nested.Lamp:GetChildren()):toBe(1)
			expect(nested.Lamp.Post.CFrame.Position.X):toBeCloseTo(400, 1e-3)
			expect(nested.Lamp.Post.Size.Y):toBe(40)
			expect(plot.Base.Size.X):toBe(44)
			local player = join("Owner", { Upgrades = { Walls = 2 } })
			expect(registry.PlotService:GetPlot(player) == plot):toBe(true)
			expect(wallParts(plot).Back.Size.Y):toBe(defense.WallBaseHeight + 6)
			expect(#nested:GetChildren()):toBe(1)
			expect(#nested.Lamp:GetChildren()):toBe(1)
		end)

		it("insets the walls from an authored Fence without overlapping the key grid", function()
			local plot = bootAuthored(true, false)
			local parts = wallParts(plot)
			local FloorGrid = world:require("ReplicatedStorage.Rules.FloorGrid")
			expect(localPosition(plot, parts.Left).X - parts.Left.Size.X / 2 > -22):toBe(true)
			expect(localPosition(plot, parts.Left).X + parts.Left.Size.X / 2 <= -22 + FloorGrid.EdgeMargin + 1e-3):toBe(
				true
			)
			expect(localPosition(plot, parts.Back).Z + parts.Back.Size.Z / 2 < 22):toBe(true)
			for _, part in parts do
				expect(part.CanCollide):toBe(true)
			end
			expect(plot.Fence.Rail.Size.X):toBe(44)
			expect(#plot.Fence:GetChildren()):toBe(1)
		end)

		it("scales an authored Walls folder instead of creating code walls", function()
			local plot = bootAuthored(false, true)
			local walls = plot.Walls
			expect(#walls:GetChildren()):toBe(2)
			local before = { walls.Wall1, walls.Wall2 }
			for _, wall in before do
				expect(wall.Size.Y):toBe(defense.WallBaseHeight)
				expect(localPosition(plot, wall).Y - wall.Size.Y / 2):toBeCloseTo(plot.Base.Size.Y / 2, 1e-3)
				expect(wall.Size.Z):toBe(44)
			end
			local player = join("Owner", { Upgrades = { Walls = 3 } })
			expect(registry.PlotService:GetPlot(player) == plot):toBe(true)
			expect(#plot:GetChildren() > 0):toBe(true)
			local count = 0
			for _, child in plot:GetChildren() do
				if child.Name == "Walls" then
					count += 1
				end
			end
			expect(count):toBe(1)
			expect(plot.Walls == walls):toBe(true)
			expect(#walls:GetChildren()):toBe(2)
			for _, wall in before do
				expect(wall.Size.Y):toBe(defense.WallBaseHeight + 9)
				expect(localPosition(plot, wall).Y - wall.Size.Y / 2):toBeCloseTo(plot.Base.Size.Y / 2, 1e-3)
			end
			world:removePlayer(player)
			expect(walls.Wall1.Size.Y):toBe(defense.WallBaseHeight)
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
			local wallHeight = defense.WallBaseHeight + 3
			for _, laser in lasers do
				expect(laser.CanCollide):toBe(false)
				expect(laser.Anchored):toBe(true)
				expect(laser.Material == roblox.Enum.Material.Neon):toBe(true)
				expect(laser.Size.X):toBe(defense.EntranceWidth)
				local position = localPosition(plot, laser)
				expect(position.X):toBeCloseTo(0, 1e-3)
				expect(position.Z):toBeCloseTo(-22 + defense.WallThickness / 2, 1e-3)
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
