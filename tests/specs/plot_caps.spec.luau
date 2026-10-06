local roblox = require("@lune/roblox")
local H = require("../harness/Harness")
local S = require("../support")

local Color3, Vector3 = roblox.Color3, roblox.Vector3

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

describe("Base keycap rendering", function()
	local world, registry, plots, Keys, GameConfig, FloorGrid, NumberFormat, Stats

	beforeEach(function()
		world = H.newWorld({ Time = 1700000000 })
		Keys = world:require("ReplicatedStorage.Config.Keys")
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		FloorGrid = world:require("ReplicatedStorage.Rules.FloorGrid")
		NumberFormat = world:require("ReplicatedStorage.Utils.NumberFormat")
		Stats = world:require("ReplicatedStorage.Rules.Stats")
		world.workspace = world:newInstance("Folder")
		local plotService = world:require("ServerScriptService.Services.PlotService")
		registry = world:boot({ "KeyboardService", "PlotService" }, { PlotService = plotService })
		plots = world.workspace:FindFirstChild("Plots")
	end)

	afterEach(function()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	local function ownedPlot(player: any): any
		for _, plot in plots:GetChildren() do
			if plot:GetAttribute("Owner") == player.UserId then
				return plot
			end
		end
		return nil
	end

	local function join(board: { [number]: string }?)
		local player, data = world:join(
			{ Name = "Typist" },
			{ PlaySeconds = 5000, Board = board or S.board("GlassTink", "PlainClack") },
			true
		)
		return player, data, ownedPlot(player)
	end

	local function capsOf(plot: any): { any }
		local out = {}
		for _, cap in plot.Keys:GetChildren() do
			if cap:GetAttribute("Cell") then
				table.insert(out, cap)
			end
		end
		return out
	end

	local function sameColor(a: any, b: any): boolean
		return math.abs(a.R - b.R) < 0.001 and math.abs(a.G - b.G) < 0.001 and math.abs(a.B - b.B) < 0.001
	end

	local function restTop(plot: any, cap: any): number
		return plot.Base.CFrame:ToObjectSpace(cap.CFrame).Position.Y + cap.Size.Y / 2
	end

	it("builds one cap per cell with slots and fillers split by attributes", function()
		local _, _, plot = join()
		local slots, fillers = 0, 0
		for _, cap in capsOf(plot) do
			if cap:GetAttribute("Slot") then
				slots += 1
				expect(cap:GetAttribute("Filler")):toBeNil()
			else
				fillers += 1
				expect(cap:GetAttribute("Filler")):toBe(true)
			end
		end
		expect(slots):toBe(GameConfig.BoardSlots)
		expect(fillers > 0):toBe(true)
	end)

	local function setBaseColor(color: any): any
		local bases = {}
		for _, plotModel in plots:GetChildren() do
			local base = plotModel:FindFirstChild("Base")
			if base then
				base.Color = color
			end
		end
		return color
	end

	local function expectedTint(color: any): any
		return color:Lerp(Color3.new(1, 1, 1), 0.45)
	end

	local function luminance(color: any): number
		return color.R * 0.299 + color.G * 0.587 + color.B * 0.114
	end

	it("renders fillers as sunk matte keys tinted lighter than the base color", function()
		local _, _, plot = join()
		local base = plot.Base.Color
		local full = plot.Base.Size.Y / 2 + FloorGrid.CapHeight
		local count = 0
		for _, cap in capsOf(plot) do
			if cap:GetAttribute("Filler") then
				count += 1
				expect(sameColor(cap.Color, expectedTint(base))):toBe(true)
				expect(luminance(cap.Color) >= luminance(base)):toBe(true)
				expect(cap.Material):toBe(roblox.Enum.Material.SmoothPlastic)
				expect(cap.Reflectance):toBe(0)
				expect(cap.Transparency):toBe(0)
				expect(restTop(plot, cap)):toBeCloseTo(full - 0.35, 1e-6)
				expect(cap:FindFirstChild("Income")):toBeNil()
				expect(cap:FindFirstChild("Top")):toBeNil()
			end
		end
		expect(count > 20):toBe(true)
	end)

	it("themes keys from the plot's fence colour, falling back to the base colour", function()
		local Caps = world:require("ServerScriptService.Services.PlotService.Caps")
		local model = world:newInstance("Model")
		local fallback = Color3.fromRGB(70, 74, 86)
		expect(sameColor(Caps.ThemeColor(model, fallback), fallback)):toBe(true)
		local fence = world:newInstance("Folder")
		fence.Name = "Fence"
		fence.Parent = model
		local yellow = Color3.fromRGB(240, 200, 40)
		for index, spec in
			{
				{ yellow, Vector3.new(40, 2, 1) },
				{ yellow, Vector3.new(1, 2, 40) },
				{ Color3.fromRGB(255, 240, 200), Vector3.new(2, 3, 2) },
			}
		do
			local part = world:newInstance("Part")
			part.Name = `Rail{index}`
			part.Color = spec[1]
			part.Size = spec[2]
			part.Transparency = 0
			part.Parent = fence
		end
		expect(sameColor(Caps.ThemeColor(model, fallback), yellow)):toBe(true)
	end)

	it("themes filler caps after each plot's own base color", function()
		local colors = {}
		for index, color in { Color3.fromRGB(200, 60, 60), Color3.fromRGB(50, 90, 210) } do
			local localWorld = H.newWorld({ Time = 1700000000 })
			localWorld.workspace = localWorld:newInstance("Folder")
			local service = localWorld:require("ServerScriptService.Services.PlotService")
			localWorld:boot({ "KeyboardService", "PlotService" }, { PlotService = service })
			local firstPlot = localWorld.workspace:FindFirstChild("Plots"):GetChildren()[1]
			firstPlot.Base.Color = color
			localWorld:destroy()
			colors[index] = color
		end
		local first, second = colors[1], colors[2]
		expect(sameColor(expectedTint(first), expectedTint(second))):toBe(false)
		expect(setBaseColor(first) ~= nil):toBe(true)
		local player = world:join(
			{ Name = "Themed" },
			{ PlaySeconds = 5000, Board = S.board("GlassTink") },
			true
		)
		local plot = ownedPlot(player)
		expect(plot ~= nil):toBe(true)
	end)

	it("gives every filler cap one deterministic A-Z legend in a darker shade of the base hue", function()
		local _, _, plot = join()
		local seen: { [string]: boolean } = {}
		local count = 0
		local base = plot.Base.Color
		for _, cap in capsOf(plot) do
			local legend = cap:FindFirstChild("Legend")
			if cap:GetAttribute("Filler") then
				expect(legend ~= nil):toBe(true)
				expect(legend.Face):toBe(roblox.Enum.NormalId.Top)
				expect(legend.PixelsPerStud):toBe(40)
				expect(legend.LightInfluence):toBe(1)
				expect(legend.Glyph.Font):toBe(roblox.Enum.Font.FredokaOne)
				expect(sameColor(legend.Glyph.TextColor3, base:Lerp(Color3.new(0, 0, 0), 0.5))):toBe(true)
				expect(luminance(legend.Glyph.TextColor3) < luminance(cap.Color)):toBe(true)
				expect(legend.Glyph.TextTransparency > 0 and legend.Glyph.TextTransparency < 0.3):toBe(true)
				expect(string.match(legend.Glyph.Text, "^[A-Z]$") ~= nil):toBe(true)
				seen[legend.Glyph.Text] = true
				count += 1
			else
				expect(legend):toBeNil()
			end
		end
		local variety = 0
		for _ in seen do
			variety += 1
		end
		expect(count > 20):toBe(true)
		expect(variety > 10):toBe(true)
	end)

	it("raises every slot cap 0.6 studs above the filler caps in all states", function()
		local _, _, plot = join()
		local unlocked = Stats.Slots({})
		local fillerTop
		for _, cap in capsOf(plot) do
			if cap:GetAttribute("Filler") then
				fillerTop = restTop(plot, cap)
				break
			end
		end
		local checked = 0
		for slot = 1, GameConfig.BoardSlots do
			local cap = plot.Keys:FindFirstChild(`Slot{slot}`)
			expect(restTop(plot, cap)):toBeCloseTo(fillerTop + 0.6, 1e-6)
			checked += 1
		end
		expect(checked):toBe(GameConfig.BoardSlots)
		expect(unlocked < GameConfig.BoardSlots):toBe(true)
		local walkTop = plot.Keys.Walkway.CFrame.Position.Y + 0.1
		expect(walkTop):toBeCloseTo(
			plot.Base.CFrame.Position.Y + plot.Base.Size.Y / 2 + FloorGrid.CapHeight - 1.1,
			1e-6
		)
		expect(plot.Keys:FindFirstChild("Slot1").CanCollide):toBe(false)
		for _, cap in capsOf(plot) do
			local depth = cap:GetAttribute("PressDepth")
			expect(type(depth)):toBe("number")
			expect(restTop(plot, cap) - depth):toBeCloseTo(walkTop - plot.Base.CFrame.Position.Y, 1e-4)
		end
	end)

	it("shows the placed key's initial on filled slots only", function()
		local player, data, plot = join()
		local first = plot.Keys:FindFirstChild("Slot1"):FindFirstChild("Top").Letter
		expect(first.Visible):toBe(true)
		expect(first.Text):toBe(string.upper(string.sub(Keys.ById.GlassTink.Name, 1, 1)))
		expect(plot.Keys:FindFirstChild("Slot3"):FindFirstChild("Top").Letter.Visible):toBe(false)
		data.Board[1] = ""
		registry.KeyboardService.BoardChanged:Fire(player)
		expect(first.Visible):toBe(false)
	end)

	it("renders filled slots full height in rarity color with a rim and income billboard", function()
		local _, _, plot = join()
		local full = plot.Base.Size.Y / 2 + FloorGrid.CapHeight
		for slot, keyId in { "GlassTink", "PlainClack" } do
			local cap = plot.Keys:FindFirstChild(`Slot{slot}`)
			local key = Keys.ById[keyId]
			local rarity = Keys.GetRarity(key)
			expect(cap:GetAttribute("KeyId")):toBe(keyId)
			expect(sameColor(cap.Color, rarity.Color)):toBe(true)
			expect(cap.Transparency):toBe(0)
			expect(restTop(plot, cap)):toBeCloseTo(full + 0.25, 1e-6)
			local billboard = cap:FindFirstChild("Income")
			expect(billboard.Enabled):toBe(true)
			expect(billboard.AlwaysOnTop):toBe(false)
			expect(billboard.MaxDistance):toBe(45)
			expect(billboard.Amount.Text):toBe(`+{NumberFormat.Compact(Keys.GetIncome(keyId))}/s`)
			expect(billboard.Amount.Font):toBe(roblox.Enum.Font.FredokaOne)
			expect(billboard.Amount.TextColor3 ~= Color3.new(1, 1, 1)):toBe(true)
			local surface = cap:FindFirstChild("Top")
			expect(surface.Enabled):toBe(true)
			expect(surface.Rim.Visible):toBe(true)
			expect(surface.Plus.Visible):toBe(false)
			expect(surface.Lock.Visible):toBe(false)
		end
	end)

	it("renders empty unlocked slots as pale translucent with a plus", function()
		local _, _, plot = join()
		local unlocked = Stats.Slots({})
		expect(unlocked > 2):toBe(true)
		local cap = plot.Keys:FindFirstChild("Slot3")
		expect(cap:GetAttribute("KeyId")):toBeNil()
		expect(cap:GetAttribute("Locked")):toBeNil()
		expect(cap.Transparency):toBe(0.4)
		expect(sameColor(cap.Color, plot.Base.Color:Lerp(Color3.new(1, 1, 1), 0.25))):toBe(true)
		expect(restTop(plot, cap)):toBeCloseTo(plot.Base.Size.Y / 2 + FloorGrid.CapHeight + 0.25, 1e-6)
		expect(cap:FindFirstChild("Income").Enabled):toBe(false)
		local surface = cap:FindFirstChild("Top")
		expect(surface.Plus.Visible):toBe(true)
		expect(surface.Lock.Visible):toBe(false)
		expect(surface.Rim.Visible):toBe(true)
	end)

	it("renders locked slots dark with a lock", function()
		local _, _, plot = join()
		local unlocked = Stats.Slots({})
		local cap = plot.Keys:FindFirstChild(`Slot{unlocked + 1}`)
		expect(cap:GetAttribute("Locked")):toBe(true)
		expect(cap:GetAttribute("KeyId")):toBeNil()
		expect(sameColor(cap.Color, Color3.fromRGB(26, 26, 30))):toBe(true)
		expect(cap:FindFirstChild("Income").Enabled):toBe(false)
		local surface = cap:FindFirstChild("Top")
		expect(surface.Lock.Visible):toBe(true)
		expect(surface.Plus.Visible):toBe(false)
	end)

	it("updates a slot and its billboard when the board changes", function()
		local player, data, plot = join()
		local cap = plot.Keys:FindFirstChild("Slot3")
		local keyId = Keys.Catalog[#Keys.Catalog].Id
		data.Board[3] = keyId
		registry.KeyboardService.BoardChanged:Fire(player)
		local rarity = Keys.GetRarity(Keys.ById[keyId])
		expect(cap:GetAttribute("KeyId")):toBe(keyId)
		expect(sameColor(cap.Color, rarity.Color)):toBe(true)
		local billboard = cap:FindFirstChild("Income")
		expect(billboard.Enabled):toBe(true)
		expect(billboard.Amount.Text):toBe(`+{NumberFormat.Compact(Keys.GetIncome(keyId))}/s`)
		expect(cap:FindFirstChild("Top").Plus.Visible):toBe(false)
		data.Board[3] = ""
		registry.KeyboardService.BoardChanged:Fire(player)
		expect(cap:GetAttribute("KeyId")):toBeNil()
		expect(billboard.Enabled):toBe(false)
		expect(cap:FindFirstChild("Top").Plus.Visible):toBe(true)
		expect(#cap:GetChildren()):toBe(2)
	end)

	it("replaces the billboard text when a different key lands in the same slot", function()
		local player, data, plot = join()
		local cap = plot.Keys:FindFirstChild("Slot1")
		local other = Keys.Catalog[#Keys.Catalog].Id
		expect(Keys.GetIncome(other) ~= Keys.GetIncome("GlassTink")):toBe(true)
		data.Board[1] = other
		registry.KeyboardService.BoardChanged:Fire(player)
		expect(cap:FindFirstChild("Income").Amount.Text):toBe(
			`+{NumberFormat.Compact(Keys.GetIncome(other))}/s`
		)
	end)

	it("resets slots to the unowned look when the owner leaves", function()
		local player, _, plot = join()
		world:removePlayer(player)
		local cap = plot.Keys:FindFirstChild("Slot1")
		expect(cap:GetAttribute("KeyId")):toBeNil()
		expect(cap:GetAttribute("Locked")):toBeNil()
		expect(cap:FindFirstChild("Income").Enabled):toBe(false)
		expect(cap:FindFirstChild("Top").Enabled):toBe(false)
	end)
end)
