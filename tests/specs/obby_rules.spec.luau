local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local H = require("../harness/Harness")

local Vector3, CFrame = roblox.Vector3, roblox.CFrame
local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

local function angleOf(vector: any): number
	return math.deg(math.atan2(vector.Z, vector.X))
end

local function angleBetween(a: number, b: number): number
	local diff = math.abs(a - b) % 360
	return math.min(diff, 360 - diff)
end

describe("Obby rules", function()
	local world, Obby, GameConfig, config

	beforeEach(function()
		world = H.newWorld()
		Obby = world:require("ReplicatedStorage.Rules.Obby")
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		config = GameConfig.Obby
	end)

	afterEach(function()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	describe("SpeedFor", function()
		it("starts at the normal walk speed", function()
			expect(Obby.SpeedFor(0)):toBe(24)
			expect(GameConfig.Steal.NormalWalkSpeed):toBe(24)
		end)

		it("adds four per decade of lifetime rolls", function()
			expect(Obby.SpeedFor(9)):toBe(28)
			expect(Obby.SpeedFor(99)):toBe(32)
			expect(Obby.SpeedFor(999)):toBe(36)
			expect(Obby.SpeedFor(9999)):toBe(40)
		end)

		it("floors to an integer between decades", function()
			expect(Obby.SpeedFor(1)):toBe(25)
			expect(Obby.SpeedFor(5)):toBe(27)
			expect(Obby.SpeedFor(50)):toBe(30)
			for rolls = 0, 3000, 37 do
				expect(Obby.SpeedFor(rolls) % 1):toBe(0)
			end
		end)

		it("never exceeds the cap", function()
			expect(Obby.SpeedFor(99999)):toBe(44)
			expect(Obby.SpeedFor(1e6)):toBe(44)
			expect(Obby.SpeedFor(1e12)):toBe(44)
			expect(Obby.SpeedFor(math.huge)):toBe(44)
			expect(config.MaxSpeed):toBe(44)
		end)

		it("never decreases as rolls grow", function()
			local last = 0
			for rolls = 0, 200000, 997 do
				local speed = Obby.SpeedFor(rolls)
				expect(speed >= last):toBe(true)
				last = speed
			end
		end)

		it("treats negative and invalid rolls as zero", function()
			expect(Obby.SpeedFor(-50)):toBe(24)
			expect(Obby.SpeedFor(0 / 0)):toBe(24)
		end)
	end)

	describe("RarityFor", function()
		it("only returns the rarities configured for the stage", function()
			for stage, entry in config.Stages do
				local allowed = {}
				for _, option in entry.Rarities do
					allowed[option.Name] = true
				end
				for roll = 0, 0.999, 0.01 do
					expect(allowed[Obby.RarityFor(stage, roll)]):toBe(true)
				end
				expect(allowed[Obby.RarityFor(stage, 1)]):toBe(true)
			end
		end)

		it("follows the stage progression", function()
			expect(Obby.RarityFor(1, 0)):toBe("Rare")
			expect(Obby.RarityFor(1, 0.99)):toBe("Epic")
			expect(Obby.RarityFor(2, 0.5)):toBe("Epic")
			expect(Obby.RarityFor(3, 0)):toBe("Epic")
			expect(Obby.RarityFor(3, 0.99)):toBe("Legendary")
			expect(Obby.RarityFor(4, 0)):toBe("Legendary")
			expect(Obby.RarityFor(4, 0.999)):toBe("Mythic")
		end)

		it("keeps the Mythic chance small", function()
			local last = config.Stages[#config.Stages].Rarities
			local total, mythic = 0, 0
			for _, option in last do
				total += option.Weight
				if option.Name == "Mythic" then
					mythic = option.Weight
				end
			end
			expect(mythic > 0):toBe(true)
			expect(mythic / total <= 0.1):toBe(true)
		end)

		it("offers real keys for every configured rarity", function()
			local Keys = world:require("ReplicatedStorage.Config.Keys")
			for _, entry in config.Stages do
				for _, option in entry.Rarities do
					expect(#Keys.ByRarity[option.Name] > 0):toBe(true)
				end
			end
		end)
	end)

	describe("Contains", function()
		it("tests a point against a rotated box with an upward reach", function()
			local cframe = CFrame.new(10, 5, 0) * CFrame.Angles(0, math.rad(90), 0)
			local size = Vector3.new(4, 2, 10)
			expect(Obby.Contains(cframe, size, Vector3.new(10, 5, 0), 0)):toBe(true)
			expect(Obby.Contains(cframe, size, Vector3.new(14.5, 5, 0), 0)):toBe(true)
			expect(Obby.Contains(cframe, size, Vector3.new(10, 5, 3), 0)):toBe(false)
			expect(Obby.Contains(cframe, size, Vector3.new(10, 8, 0), 0)):toBe(false)
			expect(Obby.Contains(cframe, size, Vector3.new(10, 8, 0), 2)):toBe(true)
			expect(Obby.Contains(cframe, size, Vector3.new(10, 3.5, 0), 0)):toBe(false)
		end)
	end)

	describe("Entrance", function()
		local markers = {
			Vector3.new(0, 0, -14),
			Vector3.new(40, 0, -30),
			Vector3.new(-25, 0, 18),
			Vector3.new(60, 0, 1),
			Vector3.new(-3, 0, -90),
		}

		it("sits on the opposite side of the center from the market", function()
			for _, market in markers do
				local entrance = Obby.Entrance(market)
				local offset = entrance.Position - config.MapCenter
				expect(angleBetween(angleOf(offset), angleOf(market - config.MapCenter) + 180) <= 1):toBe(true)
			end
		end)

		it("is placed at the configured distance and ground height", function()
			for _, market in markers do
				local entrance = Obby.Entrance(market)
				local offset = entrance.Position - config.MapCenter
				expect(Vector3.new(offset.X, 0, offset.Z).Magnitude):toBeCloseTo(config.EntranceDistance, 1e-3)
				expect(entrance.Position.Y):toBe(config.GroundY)
			end
		end)

		it("runs the course radially away from the center", function()
			for _, market in markers do
				local entrance = Obby.Entrance(market)
				local outward = Vector3.new(entrance.Position.X, 0, entrance.Position.Z).Unit
				expect(entrance.LookVector:Dot(outward)):toBeCloseTo(1, 1e-3)
			end
		end)

		it("falls back to the default market when none is known or it sits on the center", function()
			local fallback = Obby.Entrance(nil)
			expect(fallback.Position.Z > 0):toBe(true)
			expect(fallback.Position.X):toBeCloseTo(0, 1e-3)
			local degenerate = Obby.Entrance(config.MapCenter)
			expect(degenerate.Position.Z):toBeCloseTo(fallback.Position.Z, 1e-3)
		end)
	end)

	describe("Layout", function()
		it("has the configured number of stages with safe areas between them", function()
			local layout = Obby.Layout()
			expect(#layout.Stages):toBe(#config.Stages)
			expect(#layout.Stages):toBe(4)
			expect(#layout.Areas):toBe(#layout.Stages + 1)
			expect(layout.Areas[1].Kind):toBe("Start")
			for index = 2, #layout.Areas - 1 do
				expect(layout.Areas[index].Kind):toBe("Safe")
			end
			expect(layout.Areas[#layout.Areas].Kind):toBe("Finish")
			for index, span in layout.Stages do
				expect(layout.Areas[index].D1):toBe(span.D0)
				expect(layout.Areas[index + 1].D0):toBe(span.D1)
			end
		end)

		it("keeps every jump completable at the base walk speed", function()
			local layout = Obby.Layout()
			local gravity = 196.2
			local jumpHeight = 7.2
			local airtime = 2 * math.sqrt(2 * jumpHeight / gravity)
			local reach = GameConfig.Steal.NormalWalkSpeed * airtime
			expect(config.MaxJump <= reach - 2):toBe(true)
			local previous = nil
			for _, platform in layout.Platforms do
				local from = previous or { X = 0, Width = layout.Width, D0 = 0, D1 = layout.Areas[1].D1 }
				if previous and previous.Stage ~= platform.Stage then
					from = { X = 0, Width = layout.Width, D0 = 0, D1 = platform.D0 - config.Stages[platform.Stage].Gap }
				end
				expect(Obby.Gap(from, platform) <= config.MaxJump):toBe(true)
				previous = platform
			end
			local last = layout.Platforms[#layout.Platforms]
			local finish = layout.Areas[#layout.Areas]
			expect(finish.D0 - last.D1 <= config.MaxJump):toBe(true)
		end)

		it("grows the hardest gap a little with every stage", function()
			local layout = Obby.Layout()
			local worst: { [number]: number } = {}
			local previous = nil
			for _, platform in layout.Platforms do
				if previous and previous.Stage == platform.Stage then
					worst[platform.Stage] = math.max(worst[platform.Stage] or 0, Obby.Gap(previous, platform))
				end
				previous = platform
			end
			for stage = 2, #config.Stages do
				expect(worst[stage] >= worst[stage - 1]):toBe(true)
			end
			expect(worst[#config.Stages] <= config.MaxJump):toBe(true)
		end)

		it("gives each stage two or three key spawns on its own platforms", function()
			local layout = Obby.Layout()
			local perStage: { [number]: number } = {}
			for _, spawn in layout.Spawns do
				perStage[spawn.Stage] = (perStage[spawn.Stage] or 0) + 1
			end
			for stage = 1, #config.Stages do
				expect(perStage[stage] >= 2 and perStage[stage] <= 3):toBe(true)
			end
			expect(perStage[#config.Stages] >= perStage[1]):toBe(true)
		end)

		it("keeps the platforms inside the course width", function()
			local layout = Obby.Layout()
			for _, platform in layout.Platforms do
				expect(math.abs(platform.X) + platform.Width / 2 <= layout.Width / 2 - 1):toBe(true)
			end
		end)
	end)
end)

describe("Obby course", function()
	local world, Obby, Course, GameConfig, config, model

	beforeEach(function()
		world = H.newWorld()
		Obby = world:require("ReplicatedStorage.Rules.Obby")
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		Course = world:require("ServerScriptService.Services.ObbyService.Course")
		config = GameConfig.Obby
		model = Course.Build(CFrame.new(), "Obby")
	end)

	afterEach(function()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	local function byRole(role: string): { any }
		local out = {}
		for _, part in model:GetDescendants() do
			if part:GetAttribute("ObbyRole") == role then
				table.insert(out, part)
			end
		end
		table.sort(out, function(a, b)
			return a.Name < b.Name
		end)
		return out
	end

	it("is deterministic", function()
		local again = Course.Build(CFrame.new(), "Obby")
		local first, second = model:GetDescendants(), again:GetDescendants()
		expect(#second):toBe(#first)
		for index, part in first do
			expect(second[index].Name):toBe(part.Name)
			if part:IsA("BasePart") then
				expect(second[index].CFrame):toBe(part.CFrame)
				expect(second[index].Size):toBe(part.Size)
			end
		end
	end)

	it("builds one lava slab per stage", function()
		local kills = byRole("Kill")
		expect(#kills):toBe(#config.Stages)
		for index, span in Obby.Layout().Stages do
			local lava = model:FindFirstChild(`Lava{index}`)
			expect(lava:GetAttribute("Stage")):toBe(index)
			expect(lava.Size.Z):toBeCloseTo(span.D1 - span.D0, 1e-6)
			expect(lava.CFrame.Position.Z):toBeCloseTo(-(span.D0 + span.D1) / 2, 1e-6)
		end
	end)

	it("makes the kill floor a dark red smooth plastic and never neon", function()
		for _, lava in byRole("Kill") do
			expect(lava.Material):toBe(roblox.Enum.Material.SmoothPlastic)
			local color = lava.Color
			expect(color.R > color.G and color.R > color.B):toBe(true)
			expect(color.R < 0.5):toBe(true)
			expect(color.G < 0.2):toBe(true)
		end
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				expect(part.Material ~= roblox.Enum.Material.Neon):toBe(true)
			end
		end
	end)

	it("builds safe areas between the stages with no kill parts", function()
		local safes = byRole("Checkpoint")
		local finish = byRole("Finish")
		expect(#safes):toBe(#config.Stages)
		expect(#finish):toBe(1)
		local layout = Obby.Layout()
		for _, area in layout.Areas do
			local name = if area.Kind == "Start" then "Start" elseif area.Kind == "Finish" then "Finish" else `Safe{area.Index}`
			local plinth = model:FindFirstChild(name)
			expect(plinth:GetAttribute("Safe")):toBe(area.Index)
			expect(plinth.Size.X):toBe(config.CourseWidth)
			expect(plinth.Size.Z):toBeCloseTo(config.SafeLength, 1e-6)
			expect(plinth.CFrame.Position.Y + plinth.Size.Y / 2):toBeCloseTo(layout.Top, 1e-6)
			for _, lava in byRole("Kill") do
				local gap = math.abs(lava.CFrame.Position.Z - plinth.CFrame.Position.Z)
				expect(gap >= (lava.Size.Z + plinth.Size.Z) / 2 - 1e-6):toBe(true)
			end
		end
	end)

	it("signs every safe area and the finish", function()
		local function textOf(sign: any): string
			local gui = sign:FindFirstChild("SignGui")
			local text = gui.Title.Text
			local subtitle = gui:FindFirstChild("Subtitle")
			return if subtitle then `{text}|{subtitle.Text}` else text
		end
		expect(textOf(model:FindFirstChild("StartSign"))):toBe("TAP OBBY|STAGE 1 AHEAD")
		for index = 1, #config.Stages - 1 do
			expect(textOf(model:FindFirstChild(`Safe{index}Sign`))):toBe(`SAFE ZONE|STAGE {index + 1} NEXT`)
		end
		expect(textOf(model:FindFirstChild("FinishSign"))):toBe("FINISH")
	end)

	it("builds keycap shaped platforms from the stage palette", function()
		for stage, entry in config.Stages do
			local top = model:FindFirstChild(`Stage{stage}Cap1Top`)
			local body = model:FindFirstChild(`Stage{stage}Cap1Body`)
			expect(top.Color):toBe(entry.Color)
			expect(body.Color.R <= top.Color.R and body.Color.G <= top.Color.G):toBe(true)
			expect(top.CFrame.Position.Y + top.Size.Y / 2):toBeCloseTo(Obby.Layout().Top, 1e-6)
		end
		local layout = Obby.Layout()
		for _, platform in layout.Platforms do
			expect(model:FindFirstChild(`Stage{platform.Stage}Cap{platform.Index}Top`) ~= nil):toBe(true)
		end
	end)

	it("puts one key spawn on each layout spawn with its stage", function()
		local spawns = byRole("KeySpawn")
		local layout = Obby.Layout()
		expect(#spawns):toBe(#layout.Spawns)
		for index, point in layout.Spawns do
			local marker = model:FindFirstChild(`KeySpawn{index}`)
			expect(marker:GetAttribute("Stage")):toBe(point.Stage)
			expect(marker.CFrame.Position.Z):toBeCloseTo(-point.D, 1e-6)
			expect(marker.CFrame.Position.X):toBeCloseTo(point.X, 1e-6)
		end
	end)

	it("covers the whole course with one invisible zone", function()
		local zones = byRole("Zone")
		expect(#zones):toBe(1)
		local zone = zones[1]
		expect(zone.Transparency):toBe(1)
		expect(zone.CanCollide):toBe(false)
		expect(model.PrimaryPart == zone):toBe(true)
		local layout = Obby.Layout()
		for _, area in layout.Areas do
			local middle = Vector3.new(0, layout.Top + 3, -(area.D0 + area.D1) / 2)
			expect(Obby.Contains(zone.CFrame, zone.Size, middle, 0)):toBe(true)
		end
		expect(Obby.Contains(zone.CFrame, zone.Size, Vector3.new(0, 3, 20), 0)):toBe(false)
	end)

	it("closes both sides so the lava cannot be walked around", function()
		local walls = byRole("Wall")
		expect(#walls >= 4):toBe(true)
		for _, wall in walls do
			expect(wall.Anchored):toBe(true)
		end
	end)

	it("anchors everything and keeps a modest part count", function()
		local count = 0
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				count += 1
				expect(part.Anchored):toBe(true)
			end
		end
		expect(count < 150):toBe(true)
	end)

	it("matches the committed Obby.rbxm", function()
		local roots = roblox.deserializeModel(fs.readFile("assets/map/Obby.rbxm"))
		expect(#roots):toBe(1)
		local saved = roots[1]
		expect(saved.Name):toBe("Obby")
		local savedParts, builtParts = 0, 0
		for _, part in saved:GetDescendants() do
			if part:IsA("BasePart") then
				savedParts += 1
				expect(part.Anchored):toBe(true)
				expect(part.Material ~= roblox.Enum.Material.Neon):toBe(true)
			end
		end
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				builtParts += 1
			end
		end
		expect(savedParts):toBe(builtParts)
		local zone = saved:FindFirstChild("Zone")
		expect(zone:GetAttribute("ObbyRole")):toBe("Zone")
		local offset = zone.CFrame.Position - config.MapCenter
		expect(angleBetween(angleOf(offset), angleOf(config.FallbackMarket - config.MapCenter) + 180) <= 1):toBe(true)
	end)
end)
