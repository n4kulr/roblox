--!strict

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local Enum = roblox.Enum
local Vector3 = roblox.Vector3
local CFrame = roblox.CFrame
local Color3 = roblox.Color3

type Part = roblox.Instance

local outputPath = "assets/map/ThockMap.rbxm"
local plotCount = 8
local plotRadius = 80
local ringRadius = 54
local tau = math.pi * 2

local palette = {
	Color3.fromRGB(255, 99, 132),
	Color3.fromRGB(255, 159, 64),
	Color3.fromRGB(255, 214, 51),
	Color3.fromRGB(76, 217, 100),
	Color3.fromRGB(64, 196, 255),
	Color3.fromRGB(110, 120, 255),
	Color3.fromRGB(182, 108, 255),
	Color3.fromRGB(255, 120, 200),
}

local grassColor = Color3.fromRGB(104, 190, 84)
local pathColors = { Color3.fromRGB(240, 228, 196), Color3.fromRGB(226, 208, 168) }
local woodColor = Color3.fromRGB(140, 96, 64)

local seed = 7
local function random(): number
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end

local function between(low: number, high: number): number
	return low + (high - low) * random()
end

local function polar(angle: number, radius: number, height: number): Vector3
	return Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius)
end

local function newPart(
	parent: Part,
	name: string,
	size: Vector3,
	cframe: typeof(CFrame.new()),
	color: typeof(Color3.new()),
	collide: boolean?
): Part
	local part = roblox.Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = collide ~= false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function newBall(parent: Part, name: string, diameter: number, position: Vector3, color: typeof(Color3.new())): Part
	local part = newPart(parent, name, Vector3.new(diameter, diameter, diameter), CFrame.new(position), color)
	part.Shape = Enum.PartType.Ball
	return part
end

local function newFolder(name: string, parent: Part?): Part
	local folder = roblox.Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function newModel(name: string, parent: Part): Part
	local model = roblox.Instance.new("Model")
	model.Name = name
	model.Parent = parent
	return model
end

local function lighten(color: typeof(Color3.new()), amount: number): typeof(Color3.new())
	return Color3.new(
		color.R + (1 - color.R) * amount,
		color.G + (1 - color.G) * amount,
		color.B + (1 - color.B) * amount
	)
end

local function darken(color: typeof(Color3.new()), amount: number): typeof(Color3.new())
	return Color3.new(color.R * (1 - amount), color.G * (1 - amount), color.B * (1 - amount))
end

local function buildFence(model: Part, origin: typeof(CFrame.new()), color: typeof(Color3.new()))
	local fence = newFolder("Fence", model)
	local top = 1.5
	local function rail(name: string, size: Vector3, offset: Vector3)
		newPart(fence, name, size, origin * CFrame.new(offset + Vector3.new(0, 0.5 + top / 2, 0)), color)
	end
	rail("Back", Vector3.new(43, top, 1), Vector3.new(0, 0, 21.5))
	rail("Left", Vector3.new(1, top, 42), Vector3.new(-21.5, 0, 0))
	rail("Right", Vector3.new(1, top, 42), Vector3.new(21.5, 0, 0))
	rail("FrontLeft", Vector3.new(15.5, top, 1), Vector3.new(-14.25, 0, -21.5))
	rail("FrontRight", Vector3.new(15.5, top, 1), Vector3.new(14.25, 0, -21.5))
	local postColor = lighten(color, 0.45)
	for index, offset in
		{
			Vector3.new(-21.5, 0, 21.5),
			Vector3.new(21.5, 0, 21.5),
			Vector3.new(-21.5, 0, -21.5),
			Vector3.new(21.5, 0, -21.5),
			Vector3.new(-6.5, 0, -21.5),
			Vector3.new(6.5, 0, -21.5),
		}
	do
		newPart(
			fence,
			`Post{index}`,
			Vector3.new(2, 2.6, 2),
			origin * CFrame.new(offset + Vector3.new(0, 0.5 + 1.3, 0)),
			postColor
		)
	end
end

local function buildSign(model: Part, origin: typeof(CFrame.new()), color: typeof(Color3.new()))
	local sign = newFolder("Sign", model)
	local anchor = origin * CFrame.new(-15, 0.5, -17)
	newPart(sign, "Post", Vector3.new(1.2, 4, 1.2), anchor * CFrame.new(0, 2, 0), woodColor)
	newPart(sign, "Panel", Vector3.new(10, 5, 0.5), anchor * CFrame.new(0, 6.5, 0), color)
	newPart(sign, "Trim", Vector3.new(10.8, 5.8, 0.3), anchor * CFrame.new(0, 6.5, 0.1), darken(color, 0.35))
end

local function buildPlots(parent: Part)
	local folder = newFolder("Plots", parent)
	for index = 1, plotCount do
		local angle = (index - 1) / plotCount * tau
		local position = Vector3.new(math.cos(angle) * plotRadius, 0.5, math.sin(angle) * plotRadius)
		local origin = CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
		local color = palette[index]
		local model = newModel(`Plot{index}`, folder)
		local base = newPart(model, "Base", Vector3.new(44, 1, 44), origin, Color3.fromRGB(70, 74, 86))
		newPart(
			model,
			"RollKey",
			Vector3.new(8, 3, 8),
			origin * CFrame.new(0, 2, -10),
			Color3.fromRGB(215, 215, 220)
		)
		newPart(
			model,
			"Board",
			Vector3.new(31, 1.5, 9.6),
			origin * CFrame.new(0, 1.25, 12),
			Color3.fromRGB(35, 36, 42)
		)
		buildFence(model, origin, color)
		buildSign(model, origin, color)
		model.PrimaryPart = base
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		model:SetAttribute("UseMeshes", true)
	end
end

local function giantKeycap(parent: Part, name: string, cframe: typeof(CFrame.new()), width: number, color: typeof(Color3.new()))
	local model = newModel(name, parent)
	local body = width * 0.5
	newPart(model, "Body", Vector3.new(width, body, width), cframe * CFrame.new(0, body / 2, 0), darken(color, 0.15))
	newPart(
		model,
		"Top",
		Vector3.new(width * 0.82, body * 0.35, width * 0.82),
		cframe * CFrame.new(0, body + body * 0.175, 0),
		color
	)
	newPart(
		model,
		"Dish",
		Vector3.new(width * 0.5, 0.3, width * 0.5),
		cframe * CFrame.new(0, body + body * 0.35 + 0.1, 0),
		lighten(color, 0.4),
		false
	)
end

local function buildPaths(parent: Part)
	local folder = newFolder("Paths", parent)
	local path = newFolder("Ring", folder)
	local tiles = 96
	local radius = ringRadius
	local length = 2 * (radius - 5) * math.tan(math.pi / tiles) + 0.05
	for tile = 1, tiles do
		local angle = (tile - 0.5) / tiles * tau
		local position = polar(angle, radius, 0.5)
		local cframe = CFrame.lookAt(position, Vector3.new(0, 0.5, 0))
		newPart(path, `Tile{tile}`, Vector3.new(length, 1, 10), cframe, pathColors[tile % 2 + 1])
	end
end

local function buildKeyboard(parent: Part, cframe: typeof(CFrame.new()))
	local model = newModel("GiantKeyboard", parent)
	newPart(model, "Case", Vector3.new(48, 3, 18), cframe * CFrame.new(0, 1.5, 0), Color3.fromRGB(70, 74, 100))
	newPart(model, "Plate", Vector3.new(45, 0.6, 15), cframe * CFrame.new(0, 3.2, 0), Color3.fromRGB(40, 42, 58), false)
	local keyColors = {
		Color3.fromRGB(240, 240, 245),
		Color3.fromRGB(255, 120, 190),
		Color3.fromRGB(100, 200, 255),
		Color3.fromRGB(255, 214, 51),
	}
	local columns = 11
	local rows = 4
	for row = 1, rows do
		for column = 1, columns do
			local x = (column - (columns + 1) / 2) * 3.9
			local z = (row - (rows + 1) / 2) * 3.4 - 0.5
			local color = if row == 1 and column > 9 then keyColors[2] else keyColors[(row + column) % 2 * 2 + 1]
			newPart(
				model,
				`Key{row}_{column}`,
				Vector3.new(3.2, 1.6, 2.8),
				cframe * CFrame.new(x, 4.3, z),
				color,
				false
			)
		end
	end
	newPart(
		model,
		"Space",
		Vector3.new(16, 1.6, 2.8),
		cframe * CFrame.new(0, 4.3, 6.4),
		keyColors[1],
		false
	)
end

local function buildMouse(parent: Part, cframe: typeof(CFrame.new()))
	local model = newModel("GiantMouse", parent)
	local body = newPart(model, "Body", Vector3.new(14, 6, 22), cframe * CFrame.new(0, 3, 0), Color3.fromRGB(240, 240, 248))
	body.Shape = Enum.PartType.Ball
	newPart(model, "Shell", Vector3.new(13, 3, 20), cframe * CFrame.new(0, 4.6, 0), Color3.fromRGB(248, 248, 255))
	newPart(model, "LeftButton", Vector3.new(6, 0.8, 8), cframe * CFrame.new(-3.2, 6.3, -5.5), Color3.fromRGB(255, 120, 190), false)
	newPart(model, "RightButton", Vector3.new(6, 0.8, 8), cframe * CFrame.new(3.2, 6.3, -5.5), Color3.fromRGB(100, 200, 255), false)
	newPart(model, "Wheel", Vector3.new(1.2, 2, 3), cframe * CFrame.new(0, 6.6, -4), Color3.fromRGB(60, 60, 70), false)
	local points = {
		Vector3.new(0, 0.6, -11),
		Vector3.new(0, 0.6, -15),
		Vector3.new(3, 0.6, -19),
		Vector3.new(8, 0.6, -22),
		Vector3.new(14, 0.6, -22),
		Vector3.new(19, 0.6, -19),
		Vector3.new(22, 0.6, -14),
		Vector3.new(26, 0.6, -10),
	}
	for index = 1, #points - 1 do
		local from = cframe * CFrame.new(points[index])
		local to = cframe * CFrame.new(points[index + 1])
		local distance = (to.Position - from.Position).Magnitude
		local middle = (to.Position + from.Position) / 2
		newPart(
			model,
			`Cable{index}`,
			Vector3.new(1, 1, distance + 0.6),
			CFrame.lookAt(middle, to.Position),
			Color3.fromRGB(50, 52, 62),
			false
		)
	end
end

local function buildTree(parent: Part, index: number, position: Vector3)
	local model = newModel(`Tree{index}`, parent)
	local trunkHeight = between(7, 10)
	local trunk = newPart(
		model,
		"Trunk",
		Vector3.new(trunkHeight, 2.4, 2.4),
		CFrame.new(position + Vector3.new(0, trunkHeight / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		woodColor
	)
	trunk.Shape = Enum.PartType.Cylinder
	local green = Color3.fromRGB(70 + math.floor(between(0, 40)), 170 + math.floor(between(0, 40)), 80)
	local lower = between(11, 14)
	newBall(model, "CanopyLow", lower, position + Vector3.new(0, trunkHeight + lower * 0.25, 0), green)
	local upper = lower * 0.7
	newBall(
		model,
		"CanopyHigh",
		upper,
		position + Vector3.new(0, trunkHeight + lower * 0.6 + upper * 0.25, 0),
		lighten(green, 0.12)
	)
end

local function buildRock(parent: Part, index: number, position: Vector3)
	local size = between(4, 8)
	local rock = newBall(parent, `Rock{index}`, size, position + Vector3.new(0, size * 0.25, 0), Color3.fromRGB(150, 154, 166))
	rock.Size = Vector3.new(size, size * 0.6, size * between(0.8, 1.1))
	rock.CFrame = CFrame.new(position + Vector3.new(0, size * 0.2, 0)) * CFrame.Angles(0, between(0, tau), 0)
	rock.Material = Enum.Material.Slate
end

local function buildDecor(parent: Part)
	local decor = newFolder("Decor", parent)
	local caps = newFolder("Keycaps", decor)
	local capColors = {
		Color3.fromRGB(255, 99, 132),
		Color3.fromRGB(76, 217, 100),
		Color3.fromRGB(64, 196, 255),
		Color3.fromRGB(255, 214, 51),
		Color3.fromRGB(182, 108, 255),
		Color3.fromRGB(255, 159, 64),
	}
	local count = 0
	local function placeCap(angle: number, radius: number, width: number)
		count += 1
		local tilt = CFrame.Angles(between(-0.2, 0.2), between(0, tau), between(-0.2, 0.2))
		local cframe = CFrame.new(polar(angle, radius, 0)) * tilt
		giantKeycap(caps, `GiantKeycap{count}`, cframe, width, capColors[(count - 1) % #capColors + 1])
	end
	for index = 1, plotCount do
		local angle = (index - 0.5) / plotCount * tau
		placeCap(angle, if index % 2 == 0 then 98 else 108, between(7, 9))
	end
	placeCap(math.rad(0), 124, 9)
	placeCap(math.rad(180), 124, 9)
	local keyboardAngle = math.rad(112.5)
	local keyboardPosition = polar(keyboardAngle, 150, 0)
	buildKeyboard(decor, CFrame.lookAt(keyboardPosition, Vector3.new(0, 0, 0)))
	local mouseAngle = math.rad(292.5)
	local mousePosition = polar(mouseAngle, 148, 0)
	buildMouse(decor, CFrame.lookAt(mousePosition, Vector3.new(0, 0, 0)))
	local trees = newFolder("Trees", decor)
	local treeCount = 12
	for index = 1, treeCount do
		local angle = (index - 0.5) / treeCount * tau + between(-0.08, 0.08)
		buildTree(trees, index, polar(angle, between(178, 196), 0))
	end
	local rocks = newFolder("Rocks", decor)
	local rockSpots = {
		{ 20, 128 },
		{ 70, 132 },
		{ 160, 126 },
		{ 205, 134 },
		{ 250, 128 },
		{ 335, 130 },
	}
	for index, spot in rockSpots do
		buildRock(rocks, index, polar(math.rad(spot[1]), spot[2], 0))
	end
end

local function buildSpawn(parent: Part)
	local spawn = roblox.Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(Vector3.new(0, 0.5, 0))
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(255, 214, 51)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = parent
end

local function buildGround(parent: Part)
	newPart(parent, "Ground", Vector3.new(420, 1, 420), CFrame.new(0, -0.5, 0), grassColor)
end

local function build(): { Part }
	local roots = newFolder("Roots", nil)
	buildPlots(roots)
	buildPaths(roots)
	buildDecor(roots)
	buildSpawn(roots)
	buildGround(roots)
	local children = roots:GetChildren()
	for _, child in children do
		child.Parent = nil
	end
	return children
end

local roots = build()
fs.writeDir("assets/map")
fs.writeFile(outputPath, roblox.serializeModel(roots))

local count = 0
local function visit(instance: Part)
	if instance:IsA("BasePart") then
		count += 1
	end
	for _, child in instance:GetChildren() do
		visit(child)
	end
end
for _, root in roots do
	visit(root)
end
print(`Wrote {outputPath}: {#roots} roots, {count} parts`)
