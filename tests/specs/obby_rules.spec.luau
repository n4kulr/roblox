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
		it("starts at the normal walk speed and adds a quarter per tap", function()
			expect(Obby.SpeedFor(0)):toBe(24)
			expect(GameConfig.Steal.NormalWalkSpeed):toBe(24)
			expect(Obby.SpeedFor(4)):toBe(25)
			expect(Obby.SpeedFor(8)):toBe(26)
			expect(Obby.SpeedFor(64)):toBe(40)
		end)

		it("floors between whole speeds", function()
			expect(Obby.SpeedFor(1)):toBe(24)
			expect(Obby.SpeedFor(3)):toBe(24)
			expect(Obby.SpeedFor(7)):toBe(25)
			expect(Obby.SpeedFor(63)):toBe(39)
			for taps = 0, 400, 7 do
				expect(Obby.SpeedFor(taps) % 1):toBe(0)
			end
		end)

		it("never decreases as taps grow", function()
			local previous = 0
			for taps = 0, 400 do
				local speed = Obby.SpeedFor(taps)
				expect(speed >= previous):toBe(true)
				previous = speed
			end
		end)

		it("caps at the maximum speed", function()
			expect(Obby.SpeedFor(224)):toBe(80)
			expect(Obby.SpeedFor(225)):toBe(80)
			expect(Obby.SpeedFor(1e9)):toBe(80)
			expect(Obby.SpeedFor(math.huge)):toBe(80)
			expect(config.MaxSpeed):toBe(80)
			expect(config.SpeedPerTap):toBe(0.25)
		end)

		it("treats negative and invalid taps as zero", function()
			expect(Obby.SpeedFor(-5)):toBe(24)
			expect(Obby.SpeedFor(0 / 0)):toBe(24)
		end)
	end)

	describe("RarityFor", function()
		it("picks only from the listed rarities", function()
			for step = 0, 20 do
				expect(Obby.RarityFor("Epic", step / 20)):toBe("Epic")
				local rarity = Obby.RarityFor("Rare,Epic", step / 20)
				expect(rarity == "Rare" or rarity == "Epic"):toBe(true)
			end
		end)

		it("splits evenly by default and honors weights", function()
			expect(Obby.RarityFor("Rare,Epic", 0.1)):toBe("Rare")
			expect(Obby.RarityFor("Rare,Epic", 0.9)):toBe("Epic")
			expect(Obby.RarityFor("Rare:3,Epic:1", 0.7)):toBe("Rare")
			expect(Obby.RarityFor("Rare:3,Epic:1", 0.8)):toBe("Epic")
		end)

		it("falls back to Rare for empty or unknown specs", function()
			expect(Obby.RarityFor("", 0.5)):toBe("Rare")
			expect(Obby.RarityFor("Nonsense", 0.5)):toBe("Rare")
			expect(Obby.RarityFor("Nonsense, Legendary", 0.5)):toBe("Legendary")
		end)
	end)

	describe("Contains and KeyContains", function()
		it("tests a point against a rotated box with an upward reach", function()
			local cframe = CFrame.new(10, 5, 0) * CFrame.Angles(0, math.rad(90), 0)
			local size = Vector3.new(4, 2, 10)
			expect(Obby.Contains(cframe, size, Vector3.new(10, 5, 0), 0)):toBe(true)
			expect(Obby.Contains(cframe, size, Vector3.new(14.5, 5, 0), 0)):toBe(true)
			expect(Obby.Contains(cframe, size, Vector3.new(10, 5, 3), 0)):toBe(false)
			expect(Obby.Contains(cframe, size, Vector3.new(10, 8, 0), 0)):toBe(false)
			expect(Obby.Contains(cframe, size, Vector3.new(10, 8, 0), 2)):toBe(true)
		end)

		it("counts a point standing on a key but not one far above or inside it", function()
			local cframe = CFrame.new(0, 1.25, 0)
			local size = Vector3.new(8, 2.5, 8)
			expect(Obby.KeyContains(cframe, size, Vector3.new(0, 5.5, 0))):toBe(true)
			expect(Obby.KeyContains(cframe, size, Vector3.new(3.9, 5.5, -3.9))):toBe(true)
			expect(Obby.KeyContains(cframe, size, Vector3.new(4.1, 5.5, 0))):toBe(false)
			expect(Obby.KeyContains(cframe, size, Vector3.new(0, 14, 0))):toBe(false)
			expect(Obby.KeyContains(cframe, size, Vector3.new(0, 1, 0))):toBe(false)
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
		local function cellsOf(layout: any, section: string, row: number): { any }
			local out = {}
			for _, cell in layout.Cells do
				if cell.Section == section and cell.Row == row then
					table.insert(out, cell)
				end
			end
			table.sort(out, function(a, b)
				return a.X < b.X
			end)
			return out
		end

		it("is 96 studs wide and every key stays inside it", function()
			local layout = Obby.Layout()
			expect(config.Width):toBe(96)
			expect(layout.Width):toBe(96)
			for _, cell in layout.Cells do
				expect(cell.X - cell.Width / 2 >= -48 - 1e-6):toBe(true)
				expect(cell.X + cell.Width / 2 <= 48 + 1e-6):toBe(true)
				expect(cell.Kind == "PopUp" or cell.Width <= config.Key.Size + 1e-6):toBe(true)
			end
		end)

		it("is deterministic", function()
			local a = Obby.Layout()
			local b = Obby.Layout()
			expect(#a.Cells):toBe(#b.Cells)
			expect(a.Length):toBe(b.Length)
			for index, cell in a.Cells do
				expect(cell.X):toBe(b.Cells[index].X)
				expect(cell.D):toBe(b.Cells[index].D)
				expect(cell.Letter):toBe(b.Cells[index].Letter)
			end
		end)

		it("staggers rows by a quarter key and repeats every four rows", function()
			local layout = Obby.Layout()
			local firstLetters = {}
			for row = 1, 5 do
				local cells = cellsOf(layout, "RunA", row)
				firstLetters[row] = cells[2].X
			end
			local seen = {}
			for row = 1, 4 do
				seen[string.format("%.3f", firstLetters[row])] = true
			end
			local count = 0
			for _ in seen do
				count += 1
			end
			expect(count):toBe(4)
			expect(firstLetters[5]):toBeCloseTo(firstLetters[1], 1e-6)
			local pitch = config.Key.Size + config.Key.Gap
			expect(firstLetters[2] - firstLetters[1]):toBeCloseTo(pitch * 0.25, 1e-6)
			expect(firstLetters[3] - firstLetters[1]):toBeCloseTo(pitch * 0.5 - pitch, 1e-6)
		end)

		it("cycles the keyboard rows for the letters", function()
			local layout = Obby.Layout()
			local rows = { "QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM" }
			for row = 1, 6 do
				local letters = rows[(row - 1) % 3 + 1]
				local cells = cellsOf(layout, "RunA", row)
				local checked = 0
				for _, cell in cells do
					if cell.Kind == "Key" then
						checked += 1
						expect(string.find(letters, cell.Letter, 1, true) ~= nil):toBe(true)
					end
				end
				expect(checked >= 5):toBe(true)
				expect(cells[2].Letter):toBe(string.sub(letters, 1, 1))
			end
		end)

		it("marks the leftmost key of every row as a modifier", function()
			local layout = Obby.Layout()
			for row = 1, 12 do
				expect(cellsOf(layout, "RunA", row)[1].Kind):toBe("Modifier")
			end
		end)

		it("runs the sections in order with checkpoints, a gate and an end pad", function()
			local layout = Obby.Layout()
			local names = {}
			for _, area in layout.Areas do
				table.insert(names, area.Name)
			end
			expect(names):toEqual({ "Start", "Safe1", "Approach", "End" })
			expect(#layout.Runs):toBe(2)
			expect(layout.Runs[1].D1 <= layout.Areas[2].D0 + 1e-6):toBe(true)
			expect(layout.Runs[2].D0 >= layout.Areas[2].D1 - 1e-6):toBe(true)
			expect(layout.GateD > layout.Areas[3].D1 - 1e-6):toBe(true)
			expect(layout.GateD < layout.Areas[4].D0 + 1e-6):toBe(true)
			expect(layout.Length >= layout.Areas[4].D1 - 1e-6):toBe(true)
		end)

		it("leaves a few holes in the second run and none in the first", function()
			local layout = Obby.Layout()
			local function count(section: string): number
				local total = 0
				for _, cell in layout.Cells do
					if cell.Section == section then
						total += 1
					end
				end
				return total
			end
			expect(count("RunB") < count("RunA")):toBe(true)
			expect(count("RunA") - count("RunB") >= 6):toBe(true)
			expect(count("RunA") - count("RunB") <= 40):toBe(true)
		end)

		it("places two pop-up keys as wide keys on their rows", function()
			local layout = Obby.Layout()
			local popUps = {}
			for _, cell in layout.Cells do
				if cell.Kind == "PopUp" then
					table.insert(popUps, cell)
				end
			end
			expect(#popUps):toBe(2)
			for _, popUp in popUps do
				expect(popUp.Width):toBe(24)
				for _, cell in layout.Cells do
					if cell ~= popUp and cell.Section == "RunB" and cell.Row == popUp.Row then
						expect(math.abs(cell.X - popUp.X) >= (cell.Width + popUp.Width) / 2 - 0.5 - 1e-6):toBe(true)
					end
				end
			end
		end)

		it("puts three key pedestals in the first run, over a lava hole, and on the end pad", function()
			local layout = Obby.Layout()
			expect(#layout.Pedestals):toBe(3)
			expect(layout.Pedestals[1].Section):toBe("RunA")
			expect(layout.Pedestals[2].Section):toBe("RunB")
			expect(layout.Pedestals[3].Section):toBe("End")
			for _, cell in layout.Cells do
				local pedestal = layout.Pedestals[2]
				local overlaps = math.abs(cell.X - pedestal.X) < cell.Width / 2
					and math.abs(cell.D - pedestal.D) < cell.Length / 2
				expect(overlaps):toBe(false)
			end
			expect(layout.Pedestals[1].Rarities):toBe("Rare,Epic")
			expect(layout.Pedestals[2].Rarities):toBe("Epic")
			expect(layout.Pedestals[3].Rarities):toBe("Epic,Legendary")
		end)
	end)
end)
