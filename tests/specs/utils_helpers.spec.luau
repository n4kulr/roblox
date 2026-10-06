local roblox = require("@lune/roblox")
local H = require("../harness/Harness")

local Vector3, Vector2, UDim2, Color3, Enum = roblox.Vector3, roblox.Vector2, roblox.UDim2, roblox.Color3, roblox.Enum

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

describe("Shared helpers", function()
	local world, Parts, Gui, KeyLegend, Character, Keys

	beforeEach(function()
		world = H.newWorld()
		Parts = world:require("ReplicatedStorage.Utils.Parts")
		Gui = world:require("ReplicatedStorage.Utils.Gui")
		KeyLegend = world:require("ReplicatedStorage.Utils.KeyLegend")
		Character = world:require("ServerScriptService.Utils.Character")
		Keys = world:require("ReplicatedStorage.Config.Keys")
	end)

	afterEach(function()
		world:destroy()
	end)

	describe("Parts", function()
		it("builds a passive anchored part with the given properties", function()
			local parent = world:newInstance("Folder")
			local part = Parts.New({
				Name = "Pad",
				Parent = parent,
				Anchored = true,
				Passive = true,
				Massless = true,
				Size = Vector3.new(2, 3, 4),
			})
			expect(part.Name):toBe("Pad")
			expect(part.Parent):toBe(parent)
			expect(part.Anchored):toBe(true)
			expect(part.CanCollide):toBe(false)
			expect(part.CanQuery):toBe(false)
			expect(part.CanTouch):toBe(false)
			expect(part.Massless):toBe(true)
			expect(part.Size):toEqual(Vector3.new(2, 3, 4))
		end)

		it("lets explicit collision flags override Passive", function()
			local part = Parts.New({ Passive = true, CanCollide = true, CanQuery = true })
			expect(part.CanCollide):toBe(true)
			expect(part.CanQuery):toBe(true)
			expect(part.CanTouch):toBe(false)
		end)

		it("leaves unspecified properties alone and smooths surfaces on request", function()
			local part = Parts.New({ Smooth = true })
			expect(part.Name):toBe("Part")
			expect(part.TopSurface):toBe(Enum.SurfaceType.Smooth)
			expect(part.BottomSurface):toBe(Enum.SurfaceType.Smooth)
		end)
	end)

	describe("Gui", function()
		it("builds a centered scaled label with a stroke", function()
			local surface = Gui.Surface(nil, { Name = "S", PixelsPerStud = 40 })
			local label = Gui.Label(surface, {
				Name = "L",
				Text = "A",
				Centered = true,
				Size = UDim2.fromScale(0.5, 0.5),
				StrokeThickness = 3,
				StrokeColor = Color3.new(0, 0, 0),
			})
			expect(label.Parent):toBe(surface)
			expect(label.Text):toBe("A")
			expect(label.TextScaled):toBe(true)
			expect(label.BackgroundTransparency):toBe(1)
			expect(label.AnchorPoint):toEqual(Vector2.new(0.5, 0.5))
			expect(label.Font):toBe(Gui.Font)
			local stroke = label:FindFirstChildOfClass("UIStroke")
			expect(stroke ~= nil):toBe(true)
			expect(stroke.Thickness):toBe(3)
		end)

		it("builds billboards and surfaces", function()
			local part = Parts.New({})
			local billboard = Gui.Billboard(part, { Name = "B", MaxDistance = 50, Enabled = false })
			expect(billboard.Parent):toBe(part)
			expect(billboard.MaxDistance):toBe(50)
			expect(billboard.Enabled):toBe(false)
			local surface = Gui.Surface(part, { Name = "S", Face = Enum.NormalId.Top, PixelsPerStud = 40 })
			expect(surface.PixelsPerStud):toBe(40)
			expect(surface.Face):toBe(Enum.NormalId.Top)
		end)
	end)

	describe("KeyLegend", function()
		it("mounts a rim and a letter on a cap", function()
			local cap = Parts.New({})
			local key = Keys.ById.PlainClack
			local surface = KeyLegend.Mount(cap, key)
			expect(surface.Parent):toBe(cap)
			expect(surface.Name):toBe("Top")
			local letter = surface:FindFirstChild("Letter")
			expect(letter.Text):toBe(string.upper(string.sub(key.Name, 1, 1)))
			expect(surface:FindFirstChild("Rim"):FindFirstChild("Stroke").Thickness):toBe(KeyLegend.RimThickness)
		end)
	end)

	describe("Character", function()
		it("finds the root and humanoid of a character", function()
			local player = world:newPlayer({})
			expect(Character.RootOf(player)):toBe(nil)
			expect(Character.RootOfModel(nil)):toBe(nil)
			expect(Character.HumanoidOf(nil)):toBe(nil)
			local character = world:spawnCharacter(player, 1, 2, 3)
			expect(Character.RootOf(player)):toBe(character:FindFirstChild("HumanoidRootPart"))
			expect(Character.HumanoidOf(character)):toBe(character:FindFirstChild("Humanoid"))
		end)
	end)

	describe("EggPlacement", function()
		it("shares the rect math with FloorGrid and blocks near the roll key", function()
			local FloorGrid = world:require("ReplicatedStorage.Rules.FloorGrid")
			local EggPlacement = world:require("ReplicatedStorage.Utils.EggPlacement")
			expect(EggPlacement.RectOf):toBe(FloorGrid.RectOf)
			local rect = { X = 0, Z = 0, HalfX = 2, HalfZ = 2 }
			expect(EggPlacement.IsBlocked(rect, 0, 0)):toBe(true)
			expect(EggPlacement.IsBlocked(rect, 100, 100)):toBe(false)
			expect(EggPlacement.IsBlocked(nil, 0, 0)):toBe(false)
		end)
	end)
end)
