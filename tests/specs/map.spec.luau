local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local H = require("../harness/Harness")

local Vector3, CFrame = roblox.Vector3, roblox.CFrame
local describe, it, expect = H.describe, H.it, H.expect

local function load(): { [string]: any }
	local roots: { [string]: any } = {}
	for _, root in roblox.deserializeModel(fs.readFile("assets/map/ThockMap.rbxm")) do
		roots[root.Name] = root
	end
	return roots
end

local function countParts(instance: any): number
	local total = if instance:IsA("BasePart") then 1 else 0
	for _, child in instance:GetChildren() do
		total += countParts(child)
	end
	return total
end

describe("ThockMap model", function()
	local roots = load()

	it("has the expected top-level items", function()
		for _, name in { "Plots", "Arena", "Paths", "Decor", "SpawnLocation", "Ground" } do
			expect(roots[name] ~= nil):toBe(true)
		end
		expect(roots.SpawnLocation.ClassName):toBe("SpawnLocation")
		expect(roots.SpawnLocation.Neutral):toBe(true)
		expect(roots.SpawnLocation.Duration):toBe(0)
	end)

	it("keeps the part count under budget and everything anchored", function()
		local total = 0
		for _, root in roots do
			total += countParts(root)
			local stack = { root }
			while #stack > 0 do
				local item = table.remove(stack) :: any
				if item:IsA("BasePart") then
					expect(item.Anchored):toBe(true)
				end
				for _, child in item:GetChildren() do
					table.insert(stack, child)
				end
			end
		end
		expect(total < 600):toBe(true)
	end)

	it("matches the placeholder plot geometry", function()
		local plots = roots.Plots:GetChildren()
		expect(#plots):toBe(8)
		for index = 1, 8 do
			local model = roots.Plots:FindFirstChild(`Plot{index}`)
			expect(model.ClassName):toBe("Model")
			expect(model.PrimaryPart == model.Base):toBe(true)
			expect(model.ModelStreamingMode == roblox.Enum.ModelStreamingMode.Atomic):toBe(true)
			local angle = (index - 1) / 8 * math.pi * 2
			local position = Vector3.new(math.cos(angle) * 80, 0.5, math.sin(angle) * 80)
			local origin = CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
			local expected = {
				Base = { Vector3.new(44, 1, 44), origin },
				Stem = { Vector3.new(3, 2, 3), origin * CFrame.new(0, 1.5, -10) },
				RollKey = { Vector3.new(8, 3, 8), origin * CFrame.new(0, 4, -10) },
				Board = { Vector3.new(31, 1.5, 9.6), origin * CFrame.new(0, 1.25, 12) },
			}
			for name, spec in expected do
				local part = model:FindFirstChild(name)
				expect(part:IsA("BasePart")):toBe(true)
				expect((part.Size - spec[1]).Magnitude):toBeCloseTo(0, 1e-4)
				expect((part.CFrame.Position - spec[2].Position).Magnitude):toBeCloseTo(0, 1e-3)
				expect((part.CFrame.LookVector - spec[2].LookVector).Magnitude):toBeCloseTo(0, 1e-4)
			end
			expect(model:FindFirstChild("Fence") ~= nil):toBe(true)
			expect(model:FindFirstChild("Sign") ~= nil):toBe(true)
		end
	end)

	it("has a round arena floor sized for Keyfall", function()
		local floor = roots.Arena:FindFirstChild("Floor")
		expect(floor.Shape == roblox.Enum.PartType.Cylinder):toBe(true)
		expect(floor.Size):toBe(Vector3.new(1, 80, 80))
		expect((floor.CFrame.Position - Vector3.new(0, 0.5, 0)).Magnitude):toBeCloseTo(0, 1e-4)
		expect(math.abs(floor.CFrame.RightVector.Y)):toBeCloseTo(1, 1e-4)
		expect(roots.Arena.PrimaryPart == floor):toBe(true)
	end)

	it("has paths, ground and a clear spawn", function()
		expect(#roots.Paths:GetChildren()):toBe(8)
		expect(roots.Ground.Size):toBe(Vector3.new(420, 1, 420))
		expect(roots.Ground.CFrame.Position.Y + roots.Ground.Size.Y / 2):toBeCloseTo(0, 1e-4)
		local spawn = roots.SpawnLocation.CFrame.Position
		for index = 1, 8 do
			local base = roots.Plots:FindFirstChild(`Plot{index}`).Base.CFrame.Position
			expect((spawn - base).Magnitude > 30):toBe(true)
		end
		expect(#roots.Decor.Trees:GetChildren()):toBe(12)
		expect(#roots.Decor.Keycaps:GetChildren() >= 10):toBe(true)
		expect(roots.Decor:FindFirstChild("GiantKeyboard") ~= nil):toBe(true)
		expect(roots.Decor:FindFirstChild("GiantMouse") ~= nil):toBe(true)
	end)

	it("keeps decor away from every plot base", function()
		for _, item in roots.Decor:GetDescendants() do
			if item:IsA("BasePart") then
				for index = 1, 8 do
					local base = roots.Plots:FindFirstChild(`Plot{index}`).Base.CFrame.Position
					local flat = Vector3.new(item.CFrame.Position.X - base.X, 0, item.CFrame.Position.Z - base.Z)
					expect(flat.Magnitude > 34):toBe(true)
				end
			end
		end
	end)
end)
