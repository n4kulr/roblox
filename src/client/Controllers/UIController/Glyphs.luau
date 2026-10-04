--!strict

type Palette = {
	Body: Color3,
	Shade: Color3,
	Ink: Color3,
}

type Drawer = (art: Frame, palette: Palette) -> ()

export type BuildProps = {
	Parent: Instance,
	Name: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Color: Color3?,
}

local ink = Color3.fromRGB(28, 30, 40)
local plain = Color3.fromRGB(246, 248, 252)
local shadeAmount = 0.3
local pointCount = 5
local loopSegments = 16

local defaultColors: { [string]: Color3 } = {
	Golden = Color3.fromRGB(255, 200, 40),
	Star = Color3.fromRGB(255, 200, 40),
	Coin = Color3.fromRGB(255, 200, 40),
	Speed = Color3.fromRGB(255, 226, 70),
	Luck = Color3.fromRGB(96, 214, 90),
}

local function rect(
	parent: Instance,
	name: string,
	x: number,
	y: number,
	width: number,
	height: number,
	color: Color3,
	radius: number
): Frame
	local piece = Instance.new("Frame")
	piece.Name = name
	piece.BackgroundColor3 = color
	piece.BorderSizePixel = 0
	piece.Position = UDim2.fromScale(x, y)
	piece.Size = UDim2.fromScale(width, height)
	if radius > 0 then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(radius, 0)
		corner.Parent = piece
	end
	piece.Parent = parent
	return piece
end

local function spin(
	parent: Instance,
	name: string,
	centerX: number,
	centerY: number,
	width: number,
	height: number,
	color: Color3,
	radius: number,
	rotation: number
): Frame
	local piece = rect(parent, name, centerX, centerY, width, height, color, radius)
	piece.AnchorPoint = Vector2.new(0.5, 0.5)
	piece.Rotation = rotation
	return piece
end

local function letter(
	parent: Instance,
	text: string,
	x: number,
	y: number,
	width: number,
	height: number,
	color: Color3
)
	local label = Instance.new("TextLabel")
	label.Name = "Letter"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Position = UDim2.fromScale(x, y)
	label.Size = UDim2.fromScale(width, height)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Parent = parent
end

local function keycap(
	parent: Instance,
	x: number,
	y: number,
	size: number,
	skirt: Color3,
	face: Color3,
	radius: number
)
	rect(parent, "Skirt", x, y + size * 0.14, size, size * 0.84, skirt, radius)
	rect(parent, "Face", x + size * 0.1, y, size * 0.8, size * 0.72, face, radius)
end

local function star(art: Frame, palette: Palette)
	for index = 0, pointCount - 1 do
		local angle = index * 360 / pointCount
		local radians = math.rad(angle)
		spin(
			art,
			"Point",
			0.5 + 0.2 * math.sin(radians),
			0.52 - 0.2 * math.cos(radians),
			0.22,
			0.46,
			palette.Body,
			0.5,
			angle
		)
	end
	rect(art, "Core", 0.35, 0.37, 0.3, 0.3, palette.Shade, 0.5)
end

local function loop(art: Frame, palette: Palette)
	local ringRadius = 0.36
	for index = 0, loopSegments - 1 do
		local gapStart = index == 0 or index == loopSegments / 2
		local gapEnd = index == 1 or index == loopSegments / 2 + 1
		if not gapStart and not gapEnd then
			local angle = index * 360 / loopSegments
			local radians = math.rad(angle)
			spin(
				art,
				"Segment",
				0.5 + ringRadius * math.sin(radians),
				0.5 - ringRadius * math.cos(radians),
				0.19,
				0.11,
				if index < loopSegments / 2 then palette.Body else palette.Shade,
				0.5,
				angle
			)
		end
	end
	for side = 0, 1 do
		local angle = side * 180 + 11.25
		local radians = math.rad(angle)
		spin(
			art,
			"Head",
			0.5 + ringRadius * math.sin(radians),
			0.5 - ringRadius * math.cos(radians),
			0.24,
			0.24,
			if side == 0 then palette.Body else palette.Shade,
			0.12,
			angle + 45
		)
	end
end

local drawers: { [string]: Drawer } = {
	Base = function(art, palette)
		spin(art, "Roof", 0.5, 0.34, 0.78, 0.42, palette.Body, 0.18, 45)
		rect(art, "Wall", 0.2, 0.38, 0.6, 0.5, palette.Shade, 0.08)
		rect(art, "Door", 0.4, 0.58, 0.2, 0.3, palette.Ink, 0.12)
		rect(art, "Window", 0.28, 0.46, 0.14, 0.14, palette.Body, 0.2)
		rect(art, "Chimney", 0.66, 0.18, 0.12, 0.22, palette.Shade, 0.15)
	end,
	Trade = function(art, palette)
		spin(art, "Left", 0.34, 0.5, 0.46, 0.18, palette.Body, 0.4, -28)
		spin(art, "Right", 0.66, 0.5, 0.46, 0.18, palette.Shade, 0.4, 28)
		spin(art, "HeadLeft", 0.16, 0.36, 0.22, 0.22, palette.Body, 0.2, 45)
		spin(art, "HeadRight", 0.84, 0.64, 0.22, 0.22, palette.Shade, 0.2, 45)
	end,
	Walls = function(art, palette)
		rect(art, "Left", 0.1, 0.18, 0.22, 0.7, palette.Shade, 0.1)
		rect(art, "Mid", 0.39, 0.1, 0.22, 0.78, palette.Body, 0.1)
		rect(art, "Right", 0.68, 0.26, 0.22, 0.62, palette.Shade, 0.1)
		rect(art, "Cap", 0.08, 0.1, 0.84, 0.1, palette.Ink, 0.3)
	end,
	Lock = function(art, palette)
		rect(art, "Shackle", 0.28, 0.12, 0.44, 0.4, palette.Shade, 0.5)
		rect(art, "Hole", 0.38, 0.22, 0.24, 0.28, palette.Ink, 0.5)
		rect(art, "Body", 0.18, 0.4, 0.64, 0.48, palette.Body, 0.14)
		rect(art, "Keyhole", 0.44, 0.54, 0.12, 0.2, palette.Ink, 0.5)
	end,
	Slots = function(art, palette)
		for column = 0, 2 do
			keycap(art, 0.06 + column * 0.32, 0.22, 0.28, palette.Shade, palette.Body, 0.22)
		end
	end,
	Keys = function(art, palette)
		keycap(art, 0.04, 0.06, 0.92, palette.Shade, palette.Body, 0.2)
		letter(art, "A", 0.14, 0.12, 0.72, 0.5, palette.Ink)
	end,
	Clicks = function(art, palette)
		rect(art, "Skirt", 0.06, 0.4, 0.88, 0.52, palette.Shade, 0.22)
		rect(art, "Face", 0.15, 0.32, 0.7, 0.42, palette.Body, 0.22)
		spin(art, "Tick", 0.2, 0.16, 0.2, 0.07, palette.Body, 0.5, 35)
		spin(art, "Tick", 0.5, 0.1, 0.2, 0.07, palette.Body, 0.5, 90)
		spin(art, "Tick", 0.8, 0.16, 0.2, 0.07, palette.Body, 0.5, -35)
	end,
	Upgrades = function(art, palette)
		for index = 0, 2 do
			local apex = 0.2 + index * 0.25
			local color = if index == 0 then palette.Body else palette.Shade
			spin(art, "Arm", 0.35, apex + 0.11, 0.42, 0.13, color, 0.5, -38)
			spin(art, "Arm", 0.65, apex + 0.11, 0.42, 0.13, color, 0.5, 38)
		end
	end,
	Index = function(art, palette)
		for column = 0, 1 do
			for row = 0, 1 do
				local isLight = (column + row) % 2 == 0
				keycap(
					art,
					0.06 + column * 0.47,
					0.06 + row * 0.47,
					0.41,
					if isLight then palette.Shade else palette.Ink,
					if isLight then palette.Body else palette.Shade,
					0.2
				)
			end
		end
	end,
	Settings = function(art, palette)
		for index = 0, 3 do
			spin(art, "Teeth", 0.5, 0.5, 0.22, 0.96, palette.Shade, 0.18, index * 45)
		end
		rect(art, "Body", 0.17, 0.17, 0.66, 0.66, palette.Body, 0.5)
		rect(art, "Hole", 0.38, 0.38, 0.24, 0.24, palette.Shade, 0.5)
	end,
	Shop = function(art, palette)
		rect(art, "HandleLeft", 0.3, 0.14, 0.09, 0.34, palette.Shade, 0.5)
		rect(art, "HandleRight", 0.61, 0.14, 0.09, 0.34, palette.Shade, 0.5)
		rect(art, "HandleTop", 0.3, 0.1, 0.4, 0.1, palette.Shade, 0.5)
		rect(art, "Bag", 0.14, 0.32, 0.72, 0.58, palette.Body, 0.14)
		rect(art, "Band", 0.14, 0.32, 0.72, 0.16, palette.Shade, 0.3)
		rect(art, "Base", 0.14, 0.82, 0.72, 0.08, palette.Shade, 0.5)
	end,
	Leaderboard = function(art, palette)
		rect(art, "Second", 0.06, 0.44, 0.27, 0.46, palette.Shade, 0.12)
		rect(art, "First", 0.37, 0.26, 0.27, 0.64, palette.Body, 0.12)
		rect(art, "Third", 0.68, 0.56, 0.26, 0.34, palette.Shade, 0.12)
		letter(art, "2", 0.06, 0.5, 0.27, 0.28, palette.Ink)
		letter(art, "1", 0.37, 0.34, 0.27, 0.34, palette.Ink)
		letter(art, "3", 0.68, 0.6, 0.26, 0.24, palette.Ink)
		spin(art, "Crown", 0.5, 0.13, 0.13, 0.13, palette.Body, 0.2, 45)
	end,
	Daily = function(art, palette)
		rect(art, "Page", 0.1, 0.16, 0.8, 0.74, palette.Body, 0.14)
		rect(art, "Header", 0.1, 0.16, 0.8, 0.26, palette.Shade, 0.3)
		rect(art, "RingLeft", 0.27, 0.06, 0.1, 0.2, palette.Ink, 0.5)
		rect(art, "RingRight", 0.63, 0.06, 0.1, 0.2, palette.Ink, 0.5)
		for column = 0, 2 do
			for row = 0, 1 do
				rect(art, "Day", 0.22 + column * 0.22, 0.52 + row * 0.18, 0.14, 0.12, palette.Shade, 0.25)
			end
		end
	end,
	Gift = function(art, palette)
		rect(art, "Box", 0.14, 0.46, 0.72, 0.44, palette.Shade, 0.12)
		rect(art, "Lid", 0.08, 0.32, 0.84, 0.18, palette.Body, 0.25)
		rect(art, "RibbonBox", 0.44, 0.46, 0.12, 0.44, palette.Ink, 0)
		rect(art, "RibbonLid", 0.44, 0.32, 0.12, 0.18, palette.Ink, 0)
		spin(art, "BowLeft", 0.36, 0.2, 0.24, 0.17, palette.Ink, 0.5, -24)
		spin(art, "BowRight", 0.64, 0.2, 0.24, 0.17, palette.Ink, 0.5, 24)
	end,
	Pass = function(art, palette)
		local tilt = Instance.new("Frame")
		tilt.Name = "Tilt"
		tilt.BackgroundTransparency = 1
		tilt.BorderSizePixel = 0
		tilt.Size = UDim2.fromScale(1, 1)
		tilt.Rotation = -14
		tilt.Parent = art
		rect(tilt, "Ticket", 0.04, 0.24, 0.92, 0.52, palette.Body, 0.2)
		rect(tilt, "NotchLeft", -0.04, 0.42, 0.16, 0.16, palette.Shade, 0.5)
		rect(tilt, "NotchRight", 0.88, 0.42, 0.16, 0.16, palette.Shade, 0.5)
		for index = 0, 3 do
			rect(tilt, "Perforation", 0.66, 0.3 + index * 0.1, 0.05, 0.06, palette.Shade, 0.3)
		end
		rect(tilt, "Mark", 0.2, 0.36, 0.3, 0.28, palette.Shade, 0.5)
	end,
	Auto = loop,
	Rebirth = loop,
	Golden = star,
	Star = star,
	Luck = function(art, palette)
		spin(art, "Stem", 0.58, 0.84, 0.1, 0.3, palette.Shade, 0.5, 28)
		rect(art, "Leaf", 0.14, 0.1, 0.38, 0.38, palette.Body, 0.5)
		rect(art, "Leaf", 0.48, 0.1, 0.38, 0.38, palette.Body, 0.5)
		rect(art, "Leaf", 0.14, 0.44, 0.38, 0.38, palette.Body, 0.5)
		rect(art, "Leaf", 0.48, 0.44, 0.38, 0.38, palette.Body, 0.5)
		rect(art, "Core", 0.4, 0.4, 0.2, 0.2, palette.Shade, 0.5)
	end,
	Speed = function(art, palette)
		spin(art, "Upper", 0.58, 0.3, 0.24, 0.5, palette.Body, 0.2, 26)
		spin(art, "Lower", 0.42, 0.7, 0.24, 0.5, palette.Shade, 0.2, 26)
		spin(art, "Link", 0.5, 0.5, 0.5, 0.13, palette.Body, 0.3, -10)
	end,
	Coin = function(art, palette)
		rect(art, "Rim", 0.06, 0.06, 0.88, 0.88, palette.Shade, 0.5)
		rect(art, "Face", 0.14, 0.12, 0.72, 0.72, palette.Body, 0.5)
		letter(art, "$", 0.3, 0.26, 0.4, 0.44, palette.Ink)
	end,
}

local names = {
	"Base",
	"Trade",
	"Walls",
	"Lock",
	"Slots",
	"Keys",
	"Upgrades",
	"Index",
	"Settings",
	"Shop",
	"Leaderboard",
	"Daily",
	"Gift",
	"Pass",
	"Auto",
	"Rebirth",
	"Golden",
	"Star",
	"Clicks",
	"Luck",
	"Speed",
	"Coin",
}

local Glyphs = {
	Names = table.freeze(names),
}

function Glyphs.Has(name: string): boolean
	return drawers[name] ~= nil
end

function Glyphs.Build(name: string, props: BuildProps): Frame
	local draw = drawers[name]
	if not draw then
		error(`Glyphs: unknown glyph {name}`, 2)
	end
	local body = props.Color or defaultColors[name] or plain
	local palette: Palette = {
		Body = body,
		Shade = body:Lerp(Color3.new(0, 0, 0), shadeAmount),
		Ink = ink,
	}
	local holder = Instance.new("Frame")
	holder.Name = props.Name or "Icon"
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Size = props.Size or UDim2.fromOffset(48, 48)
	holder.Position = props.Position or UDim2.new()
	holder.AnchorPoint = props.AnchorPoint or Vector2.zero
	holder.LayoutOrder = props.LayoutOrder or 0
	local art = Instance.new("Frame")
	art.Name = "Art"
	art.BackgroundTransparency = 1
	art.BorderSizePixel = 0
	art.AnchorPoint = Vector2.new(0.5, 0.5)
	art.Position = UDim2.fromScale(0.5, 0.5)
	art.Size = UDim2.fromScale(1, 1)
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.AspectType = Enum.AspectType.FitWithinMaxSize
	ratio.Parent = art
	draw(art, palette)
	art.Parent = holder
	holder.Parent = props.Parent
	return holder
end

return Glyphs
