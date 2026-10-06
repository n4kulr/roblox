local roblox = require("@lune/roblox")
local H = require("../harness/Harness")

local CFrame = roblox.CFrame
local Vector3 = roblox.Vector3

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

describe("CosmeticService", function()
	local world, FloorGrid

	beforeEach(function()
		world = H.newWorld()
		FloorGrid = world:require("ReplicatedStorage.Rules.FloorGrid")
	end)

	afterEach(function()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	local function addPart(name: string, cframe: any, size: any, parent: any?): any
		local part = world:newInstance("Part")
		part.Name = name
		part.CFrame = cframe
		part.Size = size
		part.Parent = parent or world.workspace
		return part
	end

	local function boot(): any
		world:boot({ "CosmeticService" })
		return world.workspace:FindFirstChild("CosmeticKeys")
	end

	local function capsOf(model: any): { any }
		local out = {}
		for _, child in model:GetChildren() do
			if child:GetAttribute("Cosmetic") then
				table.insert(out, child)
			end
		end
		return out
	end

	local function checkInside(model: any, diameter: number)
		local frame = model:GetAttribute("Frame")
		local half = FloorGrid.CapSize() / 2
		for _, cap in capsOf(model) do
			local position = frame:PointToObjectSpace(cap.CFrame.Position)
			expect(math.abs(position.Y + 0.35 - FloorGrid.CapHeight / 2) < 1e-4):toBe(true)
			local x = math.abs(position.X) + half
			local z = math.abs(position.Z) + half
			expect(math.sqrt(x * x + z * z) <= diameter / 2 - 0.5 + 1e-4):toBe(true)
		end
	end

	it("does nothing when keyboardstuff does not exist", function()
		addPart("Baseplate", CFrame.new(0, 0, 0), Vector3.new(40, 1, 40))
		expect(boot()):toBeNil()
	end)

	it("covers a flat cylinder lying with its X axis up, inside the circle only", function()
		local part = addPart(
			"KeyboardStuff",
			CFrame.new(10, 5, -4) * CFrame.Angles(0, 0, math.pi / 2),
			Vector3.new(2, 50, 50)
		)
		local model = boot()
		expect(model ~= nil):toBe(true)
		local caps = capsOf(model)
		expect(#caps > 100):toBe(true)
		checkInside(model, 50)
		local frame = model:GetAttribute("Frame")
		expect(frame.Position.Y):toBeCloseTo(part.CFrame.Position.Y + 1, 1e-4)
		expect(frame.UpVector.Y):toBeCloseTo(1, 1e-4)
	end)

	it("covers a flat block using its smaller horizontal extent as the diameter", function()
		addPart("keyboardstuff", CFrame.new(0, 3, 0), Vector3.new(60, 2, 36))
		local model = boot()
		checkInside(model, 36)
		local frame = model:GetAttribute("Frame")
		expect(frame.Position.Y):toBeCloseTo(4, 1e-4)
		local reach = 0
		for _, cap in capsOf(model) do
			reach = math.max(reach, math.abs(cap.CFrame.Position.X), math.abs(cap.CFrame.Position.Z))
		end
		expect(reach <= 18):toBe(true)
		expect(reach > 10):toBe(true)
	end)

	it("finds the part anywhere in the workspace and with any casing", function()
		local folder = world:newInstance("Folder")
		folder.Parent = world.workspace
		local deeper = world:newInstance("Model")
		deeper.Parent = folder
		addPart("KEYBOARDSTUFF", CFrame.new(0, 3, 0), Vector3.new(30, 2, 30), deeper)
		expect(boot() ~= nil):toBe(true)
	end)

	it("handles a part whose thickness axis is Z", function()
		addPart("keyboardstuff", CFrame.new(0, 3, 0) * CFrame.Angles(math.pi / 2, 0, 0), Vector3.new(30, 30, 2))
		local model = boot()
		expect(model:GetAttribute("Frame").UpVector.Y):toBeCloseTo(1, 1e-4)
		expect(model:GetAttribute("Frame").Position.Y):toBeCloseTo(4, 1e-4)
		checkInside(model, 30)
	end)

	it("builds anchored non-colliding caps plus one invisible collidable walkway at cap-top height", function()
		addPart("keyboardstuff", CFrame.new(0, 3, 0), Vector3.new(40, 2, 40))
		local model = boot()
		for _, cap in capsOf(model) do
			expect(cap.Anchored):toBe(true)
			expect(cap.CanCollide):toBe(false)
		end
		local walkways = {}
		for _, child in model:GetChildren() do
			if child.Name == "Walkway" then
				table.insert(walkways, child)
			end
		end
		expect(#walkways):toBe(1)
		local walkway = walkways[1]
		expect(walkway.CanCollide):toBe(true)
		expect(walkway.Anchored):toBe(true)
		expect(walkway.Transparency):toBe(1)
		local top = walkway.CFrame.Position.Y + 0.1
		expect(top):toBeCloseTo(4 + FloorGrid.CapHeight, 1e-4)
	end)

	it("gives every cap one legend and colors mostly dark with some soft accents", function()
		addPart("keyboardstuff", CFrame.new(0, 3, 0), Vector3.new(80, 2, 80))
		local model = boot()
		local caps = capsOf(model)
		local accents = 0
		local seen: { [string]: boolean } = {}
		for _, cap in caps do
			local legend = cap:FindFirstChild("Legend")
			expect(legend ~= nil):toBe(true)
			expect(legend.Face):toBe(roblox.Enum.NormalId.Top)
			expect(legend.LightInfluence):toBe(1)
			expect(legend.PixelsPerStud):toBe(40)
			seen[legend.Glyph.Text] = true
			local color = cap.Color
			if math.abs(color.R - 58 / 255) > 0.001 or math.abs(color.G - 56 / 255) > 0.001 then
				accents += 1
			end
			expect(color.R < 0.75 and color.G < 0.75 and color.B < 0.75):toBe(true)
		end
		local share = accents / #caps
		expect(share > 0.07 and share < 0.28):toBe(true)
		local variety = 0
		for _ in seen do
			variety += 1
		end
		expect(variety > 15):toBe(true)
	end)

	it("builds the same layout every time", function()
		addPart("keyboardstuff", CFrame.new(0, 3, 0), Vector3.new(40, 2, 40))
		local model = boot()
		local first = {}
		for _, cap in capsOf(model) do
			first[cap.Name] = cap:FindFirstChild("Legend").Glyph.Text
		end
		world:destroy()
		world = H.newWorld()
		addPart("keyboardstuff", CFrame.new(0, 3, 0), Vector3.new(40, 2, 40))
		local again = boot()
		for _, cap in capsOf(again) do
			expect(cap:FindFirstChild("Legend").Glyph.Text):toBe(first[cap.Name])
		end
	end)
end)
