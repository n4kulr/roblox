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

		it("adds a quarter stud per tap", function()
			expect(Obby.SpeedFor(4)):toBe(25)
			expect(Obby.SpeedFor(64)):toBe(config.GateSpeed)
			expect(config.GateSpeed):toBe(40)
		end)

		it("never exceeds the cap", function()
			expect(Obby.SpeedFor(10000)):toBe(80)
			expect(Obby.SpeedFor(1e6)):toBe(80)
			expect(Obby.SpeedFor(math.huge)):toBe(80)
			expect(config.MaxSpeed):toBe(80)
		end)

		it("never decreases as taps grow", function()
			local last = 0
			for taps = 0, 400 do
				local speed = Obby.SpeedFor(taps)
				expect(speed >= last):toBe(true)
				last = speed
			end
		end)

		it("treats negative and invalid taps as zero", function()
			expect(Obby.SpeedFor(-50)):toBe(24)
			expect(Obby.SpeedFor(0 / 0)):toBe(24)
		end)
	end)

	describe("RarityFor", function()
		it("only returns the rarities configured for the section", function()
			for section, entry in config.Sections do
				local allowed = {}
				for _, option in entry.Rarities do
					allowed[option.Name] = true
				end
				for roll = 0, 0.999, 0.01 do
					expect(allowed[Obby.RarityFor(section, roll)]):toBe(true)
				end
				expect(allowed[Obby.RarityFor(section, 1)]):toBe(true)
			end
		end)

		it("follows the section progression", function()
			expect(Obby.RarityFor(1, 0)):toBe("Rare")
			expect(Obby.RarityFor(1, 0.99)):toBe("Epic")
			expect(Obby.RarityFor(2, 0)):toBe("Epic")
			expect(Obby.RarityFor(2, 0.99)):toBe("Legendary")
			expect(Obby.RarityFor(3, 0)):toBe("Legendary")
			expect(Obby.RarityFor(3, 0.99)):toBe("Mythic")
		end)

		it("keeps Mythic the rarest finish reward", function()
			local last = config.Sections[#config.Sections].Rarities
			local total, mythic, biggest = 0, 0, 0
			for _, option in last do
				total += option.Weight
				biggest = math.max(biggest, option.Weight)
				if option.Name == "Mythic" then
					mythic = option.Weight
				end
			end
			expect(mythic > 0):toBe(true)
			expect(mythic < biggest):toBe(true)
			expect(mythic / total < 0.2):toBe(true)
		end)

		it("offers real keys for every configured rarity", function()
			local Keys = world:require("ReplicatedStorage.Config.Keys")
			for _, entry in config.Sections do
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
				expect(angleBetween(angleOf(offset), angleOf(market - config.MapCenter) + 180) <= 1):toBe(
					true
				)
			end
		end)

		it("is placed at the configured distance and ground height", function()
			for _, market in markers do
				local entrance = Obby.Entrance(market)
				local offset = entrance.Position - config.MapCenter
				expect(Vector3.new(offset.X, 0, offset.Z).Magnitude):toBeCloseTo(
					config.EntranceDistance,
					1e-3
				)
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
		it("is a keyboard runway with a safe zone, a speed gate and a finish", function()
			local layout = Obby.Layout()
			expect(layout.Width):toBe(96)
			expect(#layout.Areas):toBe(4)
			expect(layout.Areas[1].Kind):toBe("Start")
			expect(layout.Areas[1].HasHome):toBe(false)
			expect(layout.Areas[2].Kind):toBe("Safe")
			expect(layout.Areas[2].HasHome):toBe(true)
			expect(layout.Areas[3].Kind):toBe("Gate")
			expect(layout.Areas[3].SpeedNeeded):toBe(config.GateSpeed)
			expect(layout.Areas[3].Title):toBe("NEED 40 SPEED")
			expect(layout.Areas[4].Kind):toBe("Finish")
			expect(layout.Areas[4].HasHome):toBe(true)
			expect(layout.Areas[4].Title):toBe("LEVEL 1 COMPLETE")
			expect(layout.Areas[1].D0):toBe(0)
			expect(layout.Areas[2].D0 > layout.Areas[1].D1)
			expect(layout.Areas[3].D0 > layout.Areas[2].D1)
			expect(layout.Areas[4].D0 > layout.Areas[3].D1)
			expect(layout.Areas[4].D1):toBe(layout.Length)
		end)

		it("gives the flat run enough keys to build gate speed", function()
			local layout = Obby.Layout()
			local flat, hazard, missing, popup = 0, 0, 0, 0
			for _, key in layout.Keys do
				if key.Section == 1 then
					flat += 1
				else
					hazard += 1
				end
				if key.Missing then
					missing += 1
					expect(key.Section):toBe(2)
				end
				if key.Popup then
					popup += 1
					expect(key.Missing):toBe(false)
				end
				expect(math.abs(key.X) + key.Size / 2 <= layout.Width / 2):toBe(true)
			end
			expect(config.FlatRows >= 12):toBe(true)
			expect(flat >= 64):toBe(true)
			expect(hazard > 0):toBe(true)
			expect(missing > 0):toBe(true)
			expect(popup > 0):toBe(true)
			expect(layout.HazardD1 > layout.HazardD0):toBe(true)
		end)

		it("places one pedestal in each section", function()
			local layout = Obby.Layout()
			expect(#layout.Spawns):toBe(3)
			for index, spawn in layout.Spawns do
				expect(spawn.Section):toBe(index)
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

	local function textOf(sign: any): string
		local gui = sign:FindFirstChild("SignGui")
		local text = gui.Title.Text
		local subtitle = gui:FindFirstChild("Subtitle")
		return if subtitle then `{text}|{subtitle.Text}` else text
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

	it("builds one maroon lava slab under the hazard rows", function()
		local kills = byRole("Kill")
		expect(#kills):toBe(1)
		local layout = Obby.Layout()
		local lava = model:FindFirstChild("Lava")
		expect(lava.Size.Z):toBeCloseTo(layout.HazardD1 - layout.HazardD0, 1e-6)
		expect(lava.Material):toBe(roblox.Enum.Material.SmoothPlastic)
		expect(lava.Color.R > lava.Color.G and lava.Color.R > lava.Color.B):toBe(true)
		expect(lava.Color.R < 0.5):toBe(true)
		expect(lava.Color.G < 0.2):toBe(true)
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				expect(part.Material ~= roblox.Enum.Material.Neon):toBe(true)
			end
		end
	end)

	it("signs the start, the safe zone, the gate and the finish", function()
		expect(textOf(model:FindFirstChild("StartSign"))):toBe("KEYBOARD ESCAPE|LEVEL 1")
		expect(textOf(model:FindFirstChild("SafeSign"))):toBe("SAFE ZONE|HOME PAD")
		expect(textOf(model:FindFirstChild("FinishSign"))):toBe("LEVEL 1 COMPLETE|LEVEL 2 COMING")
		expect(textOf(model:FindFirstChild("SpeedGate"))):toBe(
			`NEED {config.GateSpeed} SPEED|TAP KEYS TO GO FASTER`
		)
		expect(model:FindFirstChild("SpeedGate"):GetAttribute("SpeedNeeded")):toBe(config.GateSpeed)
	end)

	it("puts home pads only on the safe zone and the finish", function()
		local returns = byRole("Return")
		expect(#returns):toBe(2)
		expect(textOf(model:FindFirstChild("SafeHome"))):toBe("HOME")
		expect(textOf(model:FindFirstChild("FinishHome"))):toBe("HOME")
		expect(model:FindFirstChild("StartHome")):toBeNil()
	end)

	it("builds a keycap for every key that is not a hole", function()
		local layout = Obby.Layout()
		local present = 0
		for _, key in layout.Keys do
			local body = model:FindFirstChild(`Key{key.Index}Body`)
			if key.Missing then
				expect(body):toBeNil()
			else
				present += 1
				expect(body:GetAttribute("ObbyRole")):toBe(if key.Popup then "Popup" else "Tap")
				expect(body:GetAttribute("Letter")):toBe(key.Letter)
				local top = model:FindFirstChild(`Key{key.Index}Top`)
				expect(top ~= nil):toBe(true)
				if key.Letter ~= " " then
					expect(top.LetterGui.Letter.Text):toBe(key.Letter)
				end
			end
		end
		expect(#byRole("Tap") + #byRole("Popup")):toBe(present)
		expect(#byRole("Popup") > 0):toBe(true)
	end)

	it("puts one key spawn on each layout spawn with its section", function()
		local spawns = byRole("KeySpawn")
		local layout = Obby.Layout()
		expect(#spawns):toBe(#layout.Spawns)
		for index, point in layout.Spawns do
			local marker = model:FindFirstChild(`KeySpawn{index}`)
			expect(marker:GetAttribute("Section")):toBe(point.Section)
			expect(marker.CFrame.Position.Z):toBeCloseTo(-point.D, 1e-3)
			expect(marker.CFrame.Position.X):toBeCloseTo(point.X, 1e-3)
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
			expect(wall.CanCollide):toBe(true)
		end
	end)

	it("anchors everything", function()
		local count = 0
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				count += 1
				expect(part.Anchored):toBe(true)
			end
		end
		expect(count > 100):toBe(true)
		expect(count < 500):toBe(true)
	end)
end)
