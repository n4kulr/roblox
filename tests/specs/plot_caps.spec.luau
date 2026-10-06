local roblox = require("@lune/roblox")
local H = require("../harness/Harness")
local S = require("../support")

local Color3 = roblox.Color3

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

	it("renders fillers as sunk matte charcoal floor", function()
		local _, _, plot = join()
		local full = plot.Base.Size.Y / 2 + FloorGrid.CapHeight
		for _, cap in capsOf(plot) do
			if cap:GetAttribute("Filler") then
				expect(sameColor(cap.Color, Color3.fromRGB(58, 56, 62))):toBe(true)
				expect(cap.Material):toBe(roblox.Enum.Material.SmoothPlastic)
				expect(cap.Reflectance):toBe(0)
				expect(cap.Transparency):toBe(0)
				local top = plot.Base.CFrame:ToObjectSpace(cap.CFrame).Position.Y + cap.Size.Y / 2
				expect(top):toBeCloseTo(full - 0.35, 1e-6)
				expect(cap:FindFirstChild("Income")):toBeNil()
				expect(cap:FindFirstChild("Top")):toBeNil()
			end
		end
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
			expect(restTop(plot, cap)):toBeCloseTo(full, 1e-6)
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
		expect(sameColor(cap.Color, Color3.fromRGB(196, 210, 228))):toBe(true)
		expect(restTop(plot, cap)):toBeCloseTo(plot.Base.Size.Y / 2 + FloorGrid.CapHeight, 1e-6)
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
		expect(cap:FindFirstChild("Income").Amount.Text):toBe(`+{NumberFormat.Compact(Keys.GetIncome(other))}/s`)
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
