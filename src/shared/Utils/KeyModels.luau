--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeyTiers = require(ReplicatedStorage.Config.KeyTiers)
local Keys = require(ReplicatedStorage.Config.Keys)
local AssetOverride = require(script.Parent.AssetOverride)
local FloorGrid = require(ReplicatedStorage.Rules.FloorGrid)

export type Context = {
	Parent: Instance,
	Origin: CFrame,
	Scale: number,
	Anchored: boolean,
}

export type Shape = "Square" | "Wide" | "Enter"

export type Decoration = {
	Name: string,
	Shape: Shape,
	Build: (Context) -> (),
}

type Options = {
	Rot: Vector3?,
	Shape: Enum.PartType?,
	Reflectance: number?,
	Transparency: number?,
}

type Rect = { X: number, Z: number, Width: number, Depth: number }

local decorations: { [string]: Decoration } = {}

local KeyModels = {
	PartLimit = 25,
	BaseWidth = 4,
	ViewScale = 2,
	LegendPixelsPerStud = 40,
	LegendAnchorName = "LegendAnchor",
	TopHeight = 1.95,
	Decorations = decorations,
}

local outline = Color3.fromRGB(26, 21, 48)
local legendFont = Enum.Font.FredokaOne
local legendTextColor = Color3.new(1, 1, 1)
local legendStrokeTransparency = 0.2
local legendMeshStroke = Color3.fromRGB(20, 18, 28)
local legendMeshFill = 0.62
local legendBaseFill = 1
local fallbackColor = Color3.fromRGB(200, 200, 205)
local skirtHeight = 1.4
local plateHeight = 0.5
local dishHeight = 0.1
local plateInset = 0.8
local dishInset = 1.7

local function rgb(red: number, green: number, blue: number): Color3
	return Color3.fromRGB(red, green, blue)
end

local gold = rgb(255, 205, 60)
local white = rgb(245, 247, 255)
local ember = rgb(255, 120, 40)
local lavaRed = rgb(230, 50, 30)
local ice = rgb(170, 225, 255)
local ink = rgb(22, 14, 40)
local violet = rgb(140, 70, 230)

local function piece(
	ctx: Context,
	name: string,
	size: Vector3,
	pos: Vector3,
	color: Color3,
	options: Options?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = ctx.Anchored
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = size * ctx.Scale
	local rot = if options and options.Rot then options.Rot else Vector3.zero
	part.CFrame = ctx.Origin
		* CFrame.new(pos * ctx.Scale)
		* CFrame.Angles(math.rad(rot.X), math.rad(rot.Y), math.rad(rot.Z))
	part.Color = color
	if options then
		if options.Shape then
			part.Shape = options.Shape
		end
		if options.Reflectance then
			part.Reflectance = options.Reflectance
		end
		if options.Transparency then
			part.Transparency = options.Transparency
		end
	end
	part.Parent = ctx.Parent
	return part
end

local ball = Enum.PartType.Ball
local disc = Enum.PartType.Cylinder

local function sphere(
	ctx: Context,
	name: string,
	diameter: number,
	pos: Vector3,
	color: Color3,
	shine: number?
): Part
	return piece(
		ctx,
		name,
		Vector3.new(diameter, diameter, diameter),
		pos,
		color,
		{ Shape = ball, Reflectance = shine }
	)
end

local function ring(
	ctx: Context,
	prefix: string,
	radius: number,
	height: number,
	count: number,
	size: Vector3,
	colorAt: (number) -> Color3
)
	for index = 1, count do
		local angle = (index - 1) / count * math.pi * 2
		piece(
			ctx,
			`{prefix}{index}`,
			size,
			Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius),
			colorAt(index),
			{ Rot = Vector3.new(0, -math.deg(angle), 0) }
		)
	end
end

local function halo(ctx: Context, prefix: string, height: number, colorAt: (number) -> Color3)
	ring(ctx, prefix, 1.9, height, 8, Vector3.new(0.9, 0.3, 0.45), colorAt)
end

local function rainbow(index: number): Color3
	return Color3.fromHSV(((index - 1) % 8) / 8, 0.7, 1)
end

local function voidTone(index: number): Color3
	return if index % 2 == 0 then violet else ink
end

local function emitter(ctx: Context, name: string, pos: Vector3, color: Color3): Part
	local anchor = piece(ctx, name, Vector3.new(1.6, 0.2, 1.6), pos, color, { Transparency = 1 })
	local particles = Instance.new("ParticleEmitter")
	particles.Name = "Embers"
	particles.Color = ColorSequence.new(color)
	particles.Rate = 4
	particles.Lifetime = NumberRange.new(1.2, 2)
	particles.Speed = NumberRange.new(0.8, 1.6)
	particles.SpreadAngle = Vector2.new(25, 25)
	particles.Size = NumberSequence.new(0.18 * ctx.Scale, 0)
	particles.Transparency = NumberSequence.new(0.35, 1)
	particles.LightEmission = 0
	particles.Parent = anchor
	return anchor
end

local function thunder(ctx: Context)
	for side = -1, 1, 2 do
		local x = side * 0.8
		piece(ctx, `BoltTop{side}`, Vector3.new(0.5, 1.1, 0.4), Vector3.new(x, 1.2, 0), rgb(255, 230, 70), {
			Rot = Vector3.new(0, 0, side * -22),
		})
		piece(
			ctx,
			`BoltMid{side}`,
			Vector3.new(0.6, 0.9, 0.4),
			Vector3.new(x + side * 0.1, 0.55, 0),
			rgb(255, 214, 40),
			{ Rot = Vector3.new(0, 0, side * 28) }
		)
		piece(
			ctx,
			`BoltTip{side}`,
			Vector3.new(0.35, 0.7, 0.35),
			Vector3.new(x, 0.15, 0),
			rgb(255, 240, 130),
			{
				Rot = Vector3.new(0, 0, side * -18),
			}
		)
	end
	local cloud = rgb(226, 232, 248)
	sphere(ctx, "CloudA", 1.5, Vector3.new(-0.7, 3.5, 0), cloud)
	sphere(ctx, "CloudB", 1.9, Vector3.new(0.2, 3.8, 0), white)
	sphere(ctx, "CloudC", 1.4, Vector3.new(1.0, 3.45, 0), cloud)
	piece(ctx, "CloudBase", Vector3.new(2.6, 0.6, 1.3), Vector3.new(0.15, 3.1, 0), rgb(190, 198, 222))
end

local function sunburst(ctx: Context)
	sphere(ctx, "SunOrb", 1.5, Vector3.new(0, 1.1, 0), rgb(255, 196, 40), 0.15)
	ring(ctx, "SunRay", 1.55, 0.15, 8, Vector3.new(0.9, 0.2, 0.3), function(index)
		return if index % 2 == 0 then rgb(255, 150, 40) else rgb(255, 225, 90)
	end)
end

local function clover(ctx: Context)
	local leaf = rgb(70, 200, 90)
	for index = 1, 4 do
		local angle = (index - 1) * math.pi / 2 + math.pi / 4
		piece(
			ctx,
			`Leaf{index}`,
			Vector3.new(1.1, 0.4, 1.1),
			Vector3.new(math.cos(angle) * 0.6, 0.3, math.sin(angle) * 0.6),
			leaf:Lerp(white, (index % 2) * 0.12),
			{ Shape = ball }
		)
	end
	sphere(ctx, "CloverHeart", 0.6, Vector3.new(0, 0.55, 0), rgb(40, 150, 70))
	piece(ctx, "CloverStem", Vector3.new(0.2, 1.3, 0.2), Vector3.new(0.9, 0.5, -1.0), rgb(40, 130, 60), {
		Rot = Vector3.new(0, 0, -40),
	})
	sphere(ctx, "Dewdrop", 0.3, Vector3.new(0.5, 0.65, 0.6), rgb(190, 240, 255))
end

local function dragon(ctx: Context)
	local scales = rgb(60, 160, 90)
	local horn = rgb(250, 235, 200)
	for side = -1, 1, 2 do
		piece(ctx, `HornBase{side}`, Vector3.new(0.5, 0.9, 0.5), Vector3.new(side * 1.9, 0.6, 0.6), horn, {
			Rot = Vector3.new(0, 0, side * -12),
		})
		piece(ctx, `HornTip{side}`, Vector3.new(0.3, 0.8, 0.3), Vector3.new(side * 2.2, 1.35, 0.6), horn, {
			Rot = Vector3.new(0, 0, side * -32),
		})
		for index = 1, 3 do
			piece(
				ctx,
				`Wing{side}{index}`,
				Vector3.new(0.3, 1.5 - index * 0.2, 0.9),
				Vector3.new(side * (0.7 + index * 0.45), 0.85 + index * 0.1, -0.75),
				rgb(210, 60, 70):Lerp(scales, 0.15 * index),
				{ Rot = Vector3.new(0, 0, side * (-35 - index * 8)) }
			)
		end
		sphere(ctx, `DragonEye{side}`, 0.45, Vector3.new(side * 0.55, 0.35, 0.95), rgb(255, 220, 60))
	end
	for index = 1, 3 do
		piece(
			ctx,
			`Spine{index}`,
			Vector3.new(0.35, 0.5 + index * 0.1, 0.5),
			Vector3.new((index - 2) * 0.9, 0.35, -0.2),
			scales,
			{ Rot = Vector3.new(0, 0, 45) }
		)
	end
end

local function phoenix(ctx: Context)
	for index = 1, 5 do
		local tilt = (index - 3) * 24
		piece(
			ctx,
			`Feather{index}`,
			Vector3.new(0.55, 2.2, 0.15),
			Vector3.new((index - 3) * 0.55, 1.4 - math.abs(index - 3) * 0.12, 0),
			lavaRed:Lerp(rgb(255, 215, 70), (index - 1) / 4),
			{ Rot = Vector3.new(0, 0, -tilt) }
		)
	end
	sphere(ctx, "FlameHeart", 1.0, Vector3.new(0, 0.5, 0), ember, 0.1)
	sphere(ctx, "FlameCore", 0.55, Vector3.new(0, 0.6, 0.35), rgb(255, 225, 100))
end

local function frost(ctx: Context)
	ring(ctx, "IceSpike", 1.3, 0.9, 6, Vector3.new(0.35, 1.5, 0.35), function(index)
		return ice:Lerp(white, (index % 2) * 0.35)
	end)
	sphere(ctx, "FrostGem", 0.9, Vector3.new(0, 0.7, 0), rgb(90, 190, 255), 0.25)
	sphere(ctx, "Snowflake", 0.4, Vector3.new(0, 2.4, 0), white)
end

local function treasure(ctx: Context)
	piece(ctx, "ChestBody", Vector3.new(2.2, 0.9, 1.4), Vector3.new(0, 0.45, 0), rgb(150, 90, 45))
	piece(ctx, "ChestLid", Vector3.new(2.2, 0.5, 1.4), Vector3.new(0, 1.15, 0), rgb(175, 105, 55))
	piece(ctx, "ChestBand", Vector3.new(0.35, 1.5, 1.5), Vector3.new(0, 0.75, 0), gold, { Reflectance = 0.2 })
	piece(ctx, "ChestLock", Vector3.new(0.45, 0.45, 0.2), Vector3.new(0, 0.9, 0.75), gold)
	sphere(ctx, "GemRed", 0.5, Vector3.new(-0.7, 1.55, 0.2), rgb(235, 60, 80), 0.2)
	sphere(ctx, "GemBlue", 0.5, Vector3.new(0.6, 1.55, -0.1), rgb(70, 150, 255), 0.2)
	sphere(ctx, "GemGreen", 0.4, Vector3.new(0.05, 1.6, 0.4), rgb(70, 220, 130), 0.2)
end

local function lava(ctx: Context)
	local shine = 0.12
	sphere(ctx, "BlobCore", 1.6, Vector3.new(0, 0.55, 0), ember, shine)
	sphere(ctx, "BlobLeft", 1.0, Vector3.new(-1.0, 0.35, 0.4), lavaRed, shine)
	sphere(ctx, "BlobRight", 0.9, Vector3.new(0.9, 0.3, -0.5), lavaRed, shine)
	piece(ctx, "CrustA", Vector3.new(0.7, 0.4, 0.6), Vector3.new(0.6, 0.9, 0.5), rgb(60, 36, 36), {
		Rot = Vector3.new(0, 30, 10),
	})
	piece(ctx, "CrustB", Vector3.new(0.5, 0.35, 0.5), Vector3.new(-0.6, 1.1, -0.4), rgb(60, 36, 36), {
		Rot = Vector3.new(0, -20, -8),
	})
	for index, x in { -1.1, -0.2, 0.7, 1.4 } do
		local length = 0.7 + (index % 3) * 0.3
		local z = 1.55 - (index % 2) * 0.15
		piece(
			ctx,
			`DripStreak{index}`,
			Vector3.new(0.4, length, 0.4),
			Vector3.new(x, -length / 2 - 0.1, z),
			if index % 2 == 0 then ember else lavaRed,
			{ Reflectance = shine }
		)
		sphere(ctx, `DripDrop{index}`, 0.55, Vector3.new(x, -length - 0.2, z), ember, shine)
	end
	emitter(ctx, "EmberSource", Vector3.new(0, 1.4, 0), ember)
end

local function goldenSpace(ctx: Context)
	for stack = -1, 1, 2 do
		for index = 1, 3 do
			piece(
				ctx,
				`Coin{stack}{index}`,
				Vector3.new(0.25, 1.2, 1.2),
				Vector3.new(stack * 1.6, 0.15 + index * 0.26, 0),
				gold,
				{ Shape = disc, Rot = Vector3.new(0, 0, 90), Reflectance = 0.2 }
			)
		end
	end
	piece(ctx, "GoldBar", Vector3.new(1.8, 0.6, 0.9), Vector3.new(0, 0.3, 0), rgb(255, 225, 100), {
		Reflectance = 0.25,
	})
	for index = 1, 4 do
		piece(
			ctx,
			`Glint{index}`,
			Vector3.new(0.35, 0.35, 0.35),
			Vector3.new((index - 2.5) * 0.9, 1.0 + (index % 2) * 0.5, 0.7),
			rgb(255, 245, 200),
			{ Rot = Vector3.new(45, 0, 45) }
		)
	end
end

local function galaxy(ctx: Context)
	sphere(ctx, "Star", 1.2, Vector3.new(0, 1.0, 0), rgb(255, 214, 90), 0.15)
	piece(ctx, "OrbitDisc", Vector3.new(0.12, 3.6, 3.6), Vector3.new(0, 1.0, 0), violet, {
		Shape = disc,
		Rot = Vector3.new(0, 0, 90),
		Transparency = 0.6,
	})
	local planets = {
		{ Name = "PlanetRed", Angle = 0.4, Size = 0.7, Color = rgb(230, 80, 70) },
		{ Name = "PlanetBlue", Angle = 2.4, Size = 0.9, Color = rgb(70, 140, 255) },
		{ Name = "PlanetTeal", Angle = 4.3, Size = 0.55, Color = rgb(60, 220, 200) },
	}
	for _, planet in planets do
		sphere(
			ctx,
			planet.Name,
			planet.Size,
			Vector3.new(math.cos(planet.Angle) * 1.8, 1.0, math.sin(planet.Angle) * 1.8),
			planet.Color
		)
	end
	for index = 1, 4 do
		piece(
			ctx,
			`StarDust{index}`,
			Vector3.new(0.25, 0.25, 0.25),
			Vector3.new((index - 2.5) * 0.9, 2.3 + (index % 2) * 0.4, (index % 3 - 1) * 0.8),
			white,
			{ Rot = Vector3.new(45, 45, 0) }
		)
	end
end

local function aurora(ctx: Context)
	local colors = { rgb(70, 240, 170), rgb(70, 200, 240), rgb(160, 110, 255), rgb(255, 120, 200) }
	for index, color in colors do
		piece(
			ctx,
			`Ribbon{index}`,
			Vector3.new(0.5, 2.4 - index * 0.2, 0.15),
			Vector3.new((index - 2.5) * 0.75, 1.5 + (index % 2) * 0.3, 0),
			color,
			{ Rot = Vector3.new(0, 0, (index - 2.5) * 14), Transparency = 0.15 }
		)
	end
	for index = 1, 3 do
		piece(
			ctx,
			`AuroraStar{index}`,
			Vector3.new(0.3, 0.3, 0.3),
			Vector3.new((index - 2) * 1.2, 3.2 + (index % 2) * 0.4, 0.3),
			white,
			{ Rot = Vector3.new(45, 0, 45) }
		)
	end
end

local function eclipse(ctx: Context)
	sphere(ctx, "Moon", 1.6, Vector3.new(0, 1.3, 0), rgb(30, 24, 48))
	ring(ctx, "Corona", 1.25, 1.3, 10, Vector3.new(0.25, 0.9, 0.2), function(index)
		return if index % 2 == 0 then gold else rgb(255, 150, 50)
	end)
	piece(ctx, "CoronaGlow", Vector3.new(0.12, 2.4, 2.4), Vector3.new(0, 1.3, -0.5), gold, {
		Shape = disc,
		Rot = Vector3.new(0, 0, 90),
		Transparency = 0.5,
	})
end

local function meow(ctx: Context)
	local fur = rgb(255, 200, 230)
	for side = -1, 1, 2 do
		piece(ctx, `Ear{side}`, Vector3.new(0.9, 0.9, 0.5), Vector3.new(side * 1.1, 1.0, 0), fur, {
			Rot = Vector3.new(0, 0, 45),
		})
		piece(
			ctx,
			`EarInner{side}`,
			Vector3.new(0.5, 0.5, 0.2),
			Vector3.new(side * 1.1, 0.95, 0.25),
			rgb(255, 130, 170),
			{ Rot = Vector3.new(0, 0, 45) }
		)
		sphere(ctx, `CatEye{side}`, 0.4, Vector3.new(side * 0.6, 0.3, 1.0), ink)
		for whisker = 1, 2 do
			piece(
				ctx,
				`Whisker{side}{whisker}`,
				Vector3.new(1.0, 0.07, 0.07),
				Vector3.new(side * 1.5, 0.15 + whisker * 0.18, 1.1),
				white,
				{ Rot = Vector3.new(0, 0, side * (whisker - 1.5) * 20) }
			)
		end
	end
	sphere(ctx, "CatNose", 0.3, Vector3.new(0, 0.2, 1.1), rgb(255, 110, 150))
	halo(ctx, "MeowHalo", 3.0, rainbow)
end

local function voidEsc(ctx: Context)
	sphere(ctx, "VoidCore", 1.5, Vector3.new(0, 1.2, 0), ink, 0.1)
	ring(ctx, "VoidSwirl", 1.2, 1.2, 6, Vector3.new(0.7, 0.15, 0.3), voidTone)
	sphere(ctx, "VoidSpark", 0.3, Vector3.new(0.8, 2.2, 0.4), rgb(200, 150, 255))
	halo(ctx, "VoidHalo", 3.1, voidTone)
end

local function prism(ctx: Context)
	for index = 1, 7 do
		local angle = math.pi * (index - 1) / 6
		piece(
			ctx,
			`Arc{index}`,
			Vector3.new(0.6, 0.6, 0.5),
			Vector3.new(math.cos(angle) * 1.5, 0.3 + math.sin(angle) * 1.5, 0),
			Color3.fromHSV((index - 1) / 7, 0.75, 1),
			{ Rot = Vector3.new(0, 0, math.deg(angle)) }
		)
	end
	sphere(ctx, "PrismGem", 0.7, Vector3.new(0, 0.5, 0), white, 0.25)
	halo(ctx, "PrismHalo", 3.1, rainbow)
end

local function glitch(ctx: Context)
	local tones = { rgb(255, 60, 200), rgb(60, 230, 240), rgb(250, 250, 255), ink }
	for index = 1, 6 do
		piece(
			ctx,
			`Pixel{index}`,
			Vector3.new(0.6 + (index % 3) * 0.2, 0.5, 0.6),
			Vector3.new((index - 3.5) * 0.65, 0.4 + (index % 3) * 0.55, (index % 2) * 0.8 - 0.4),
			tones[(index - 1) % #tones + 1],
			{ Rot = Vector3.new(0, (index % 2) * 18, 0) }
		)
	end
	halo(ctx, "GlitchHalo", 3.1, function(index)
		return tones[(index - 1) % 3 + 1]
	end)
end

local definitions: { [string]: Decoration } = {
	ThunderKey = { Name = "Thunder", Shape = "Square", Build = thunder },
	SunburstKey = { Name = "Sunburst", Shape = "Square", Build = sunburst },
	FourLeafArtisan = { Name = "Clover", Shape = "Square", Build = clover },
	DragonSpacebar = { Name = "Dragon", Shape = "Wide", Build = dragon },
	PhoenixPlume = { Name = "Phoenix", Shape = "Square", Build = phoenix },
	FrostCrown = { Name = "Frost", Shape = "Square", Build = frost },
	TreasureTab = { Name = "Treasure", Shape = "Square", Build = treasure },
	LavaKey = { Name = "Lava", Shape = "Square", Build = lava },
	GoldenSpacebar = { Name = "Gold", Shape = "Wide", Build = goldenSpace },
	GalaxyEnter = { Name = "Galaxy", Shape = "Enter", Build = galaxy },
	AuroraAlt = { Name = "Aurora", Shape = "Square", Build = aurora },
	EclipseShift = { Name = "Eclipse", Shape = "Square", Build = eclipse },
	MeowKey = { Name = "Meow", Shape = "Square", Build = meow },
	VoidEsc = { Name = "Void", Shape = "Square", Build = voidEsc },
	PrismReturn = { Name = "Prism", Shape = "Square", Build = prism },
	GlitchTab = { Name = "Glitch", Shape = "Square", Build = glitch },
}
for keyId, decoration in definitions do
	decorations[keyId] = table.freeze(decoration)
end
table.freeze(decorations)

local function rects(shape: Shape): { Rect }
	if shape == "Wide" then
		return { { X = 0, Z = 0, Width = 6, Depth = 3.2 } }
	elseif shape == "Enter" then
		return {
			{ X = 0, Z = -1, Width = 4, Depth = 2 },
			{ X = 1, Z = 0.8, Width = 2, Depth = 2.4 },
		}
	end
	return { { X = 0, Z = 0, Width = KeyModels.BaseWidth, Depth = KeyModels.BaseWidth } }
end

local function legendLetter(key: Keys.Key): string
	return string.upper(string.sub(key.Name, 1, 1))
end

local function markLegend(model: Model, cap: BasePart, key: Keys.Key, strokeColor: Color3, fill: number)
	local anchor = Instance.new("Attachment")
	anchor.Name = KeyModels.LegendAnchorName
	anchor.Position = Vector3.new(0, cap.Size.Y / 2, 0)
	anchor.Parent = cap
	model:SetAttribute("LegendText", legendLetter(key))
	model:SetAttribute("LegendColor", legendTextColor)
	model:SetAttribute("LegendStrokeColor", strokeColor)
	model:SetAttribute("LegendStrokeTransparency", legendStrokeTransparency)
	model:SetAttribute("LegendFont", legendFont.Name)
	model:SetAttribute("LegendFill", fill)
end

local function addBase(model: Model, key: Keys.Key?, color: Color3, shape: Shape, scale: number)
	local rarity = if key then Keys.GetRarity(key) else nil
	local list = rects(shape)
	local ctx: Context = { Parent = model, Origin = CFrame.new(), Scale = scale, Anchored = true }
	local firstDish: Part? = nil
	for index, rect in list do
		local suffix = if index == 1 then "" else tostring(index)
		piece(
			ctx,
			`Skirt{suffix}`,
			Vector3.new(rect.Width, skirtHeight, rect.Depth),
			Vector3.new(rect.X, skirtHeight / 2, rect.Z),
			color:Lerp(outline, 0.35)
		)
		local top = piece(
			ctx,
			`Top{suffix}`,
			Vector3.new(rect.Width - plateInset, plateHeight, rect.Depth - plateInset),
			Vector3.new(rect.X, skirtHeight + plateHeight / 2, rect.Z),
			color
		)
		if rarity then
			Keys.ApplyFinish(top, rarity)
		end
		local dish = piece(
			ctx,
			`Dish{suffix}`,
			Vector3.new(rect.Width - dishInset, dishHeight, rect.Depth - dishInset),
			Vector3.new(rect.X, skirtHeight + plateHeight, rect.Z),
			color:Lerp(outline, 0.12)
		)
		firstDish = firstDish or dish
	end
	if key and firstDish then
		local gui = Instance.new("SurfaceGui")
		gui.Name = "Legend"
		gui.Face = Enum.NormalId.Top
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0
		gui.Adornee = firstDish
		local letter = Instance.new("TextLabel")
		letter.Name = "Letter"
		letter.BackgroundTransparency = 1
		letter.Size = UDim2.fromScale(1, 1)
		letter.Font = legendFont
		letter.Text = legendLetter(key)
		letter.TextColor3 = legendTextColor
		letter.TextStrokeColor3 = outline
		letter.TextStrokeTransparency = legendStrokeTransparency
		letter.TextScaled = true
		letter.Parent = gui
		gui.Parent = firstDish
		markLegend(model, firstDish, key, outline, legendBaseFill)
	end
end

function KeyModels.HasDecoration(keyId: string): boolean
	return decorations[KeyTiers.Parse(keyId)] ~= nil
end

function KeyModels.BuildScaled(variantId: string, scale: number): Model
	local keyId, tier = KeyTiers.Parse(variantId)
	local model = Instance.new("Model")
	model.Name = variantId
	local key = Keys.ById[keyId]
	local rarity = if key then Keys.GetRarity(key) else nil
	local color = if rarity then rarity.Color else fallbackColor
	local decoration = decorations[keyId]
	addBase(model, key, color, if decoration then decoration.Shape else "Square", scale)
	if decoration then
		decoration.Build({
			Parent = model,
			Origin = CFrame.new(0, KeyModels.TopHeight * scale, 0),
			Scale = scale,
			Anchored = true,
		})
	end
	local skirt = model:FindFirstChild("Skirt")
	if skirt and skirt:IsA("BasePart") then
		model.PrimaryPart = skirt
	end
	if tier > 0 then
		local tint, reflectance, material = Keys.VariantStyle(variantId)
		for _, name in { "Skirt", "Top" } do
			local part = model:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				part.Color = if name == "Skirt" then tint:Lerp(outline, 0.35) else tint
				part.Reflectance = reflectance
				part.Material = material
			end
		end
	end
	return model
end

local function meshTemplate(name: string): MeshPart?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local meshes = if assets then assets:FindFirstChild("Meshes") else nil
	local template = if meshes then meshes:FindFirstChild(name) else nil
	return if template and template:IsA("MeshPart") then template else nil
end

function KeyModels.Legend(cap: BasePart, key: Keys.Key, pixelsPerStud: number?): SurfaceGui
	local rarity = Keys.GetRarity(key)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "Top"
	surface.Face = Enum.NormalId.Top
	surface.Adornee = cap
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = pixelsPerStud or KeyModels.LegendPixelsPerStud
	surface.LightInfluence = 0
	surface.AlwaysOnTop = false
	local rim = Instance.new("Frame")
	rim.Name = "Rim"
	rim.BackgroundTransparency = 1
	rim.Size = UDim2.fromScale(1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = rarity.Color:Lerp(Color3.new(1, 1, 1), 0.45)
	stroke.Transparency = 0.1
	stroke.Parent = rim
	rim.Parent = surface
	local letter = Instance.new("TextLabel")
	letter.Name = "Letter"
	letter.BackgroundTransparency = 1
	letter.AnchorPoint = Vector2.new(0.5, 0.5)
	letter.Position = UDim2.fromScale(0.5, 0.5)
	letter.Size = UDim2.fromScale(legendMeshFill, legendMeshFill)
	letter.Font = legendFont
	letter.Text = legendLetter(key)
	letter.TextColor3 = legendTextColor
	letter.TextStrokeColor3 = legendMeshStroke
	letter.TextStrokeTransparency = legendStrokeTransparency
	letter.TextScaled = true
	letter.Parent = surface
	surface.Parent = cap
	return surface
end

function KeyModels.BuildMesh(variantId: string, template: MeshPart, scale: number): Model?
	local keyId = KeyTiers.Parse(variantId)
	local key = Keys.ById[keyId]
	if not key then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = variantId
	local cap = template:Clone()
	cap.Name = "Cap"
	local capSize = FloorGrid.CapSize()
	cap.Size = Vector3.new(capSize, FloorGrid.CapHeight, capSize) * scale
	cap.Anchored = true
	cap.CanCollide = false
	cap.CanQuery = false
	cap.CanTouch = false
	cap.CastShadow = false
	cap.CFrame = CFrame.new(0, cap.Size.Y / 2, 0)
	Keys.ApplyVariantFinish(cap, variantId)
	cap.Transparency = 0
	cap.Parent = model
	model.PrimaryPart = cap
	KeyModels.Legend(cap, key, KeyModels.LegendPixelsPerStud / scale)
	markLegend(model, cap, key, legendMeshStroke, legendMeshFill)
	KeyModels.Mount(cap, variantId)
	return model
end

function KeyModels.Build(keyId: string): Model
	local authored = AssetOverride.Find("Keys", keyId) or AssetOverride.Find("Keys", (KeyTiers.Parse(keyId)))
	if authored then
		return authored
	end
	local template = meshTemplate("Keycap")
	if template then
		local model = KeyModels.BuildMesh(keyId, template, KeyModels.ViewScale)
		if model then
			return model
		end
	end
	return KeyModels.BuildScaled(keyId, 1)
end

function KeyModels.BuildDecoration(keyId: string, origin: CFrame, scale: number, anchored: boolean): Model?
	local decoration = decorations[KeyTiers.Parse(keyId)]
	if not decoration then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = `{decoration.Name}Decor`
	decoration.Build({ Parent = model, Origin = origin, Scale = scale, Anchored = anchored })
	return model
end

function KeyModels.Mount(cap: BasePart, keyId: string): Model?
	local origin = cap.CFrame * CFrame.new(0, cap.Size.Y / 2, 0)
	local model = KeyModels.BuildDecoration(keyId, origin, cap.Size.X / KeyModels.BaseWidth, false)
	if not model then
		return nil
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			local weld = Instance.new("WeldConstraint")
			weld.Name = "CapWeld"
			weld.Part0 = cap
			weld.Part1 = descendant
			weld.Parent = descendant
		end
	end
	model.Parent = cap
	return model
end

return KeyModels
