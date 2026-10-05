--!strict

type Canvas = {
	Art: Frame,
	Body: Color3,
	Shade: Color3,
	Light: Color3,
	Ink: Color3,
	IsOutline: boolean,
	Rect: (
		self: Canvas,
		name: string,
		x: number,
		y: number,
		width: number,
		height: number,
		color: Color3,
		radius: number
	) -> Frame,
	Spin: (
		self: Canvas,
		name: string,
		centerX: number,
		centerY: number,
		width: number,
		height: number,
		color: Color3,
		radius: number,
		rotation: number
	) -> Frame,
	Letter: (
		self: Canvas,
		text: string,
		x: number,
		y: number,
		width: number,
		height: number,
		color: Color3
	) -> (),
	Group: (self: Canvas, name: string, rotation: number) -> Canvas,
}

type Drawer = (canvas: Canvas) -> ()

export type BuildProps = {
	Parent: Instance,
	Name: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Color: Color3?,
}

local ink = Color3.fromRGB(26, 20, 52)
local plain = Color3.fromRGB(246, 248, 252)
local shadeAmount = 0.32
local lightAmount = 0.4
local grow = 0.055
local pointCount = 5
local loopSegments = 16
local red = Color3.fromRGB(255, 70, 80)
local white = Color3.new(1, 1, 1)

local defaultColors: { [string]: Color3 } = {
	Keys = plain,
	Upgrades = Color3.fromRGB(96, 224, 96),
	Index = Color3.fromRGB(120, 190, 255),
	Settings = Color3.fromRGB(190, 198, 220),
	Store = Color3.fromRGB(255, 96, 120),
	Market = Color3.fromRGB(255, 120, 72),
	Leaderboard = Color3.fromRGB(255, 214, 64),
	Daily = plain,
	Gift = Color3.fromRGB(255, 150, 60),
	Pass = Color3.fromRGB(255, 190, 60),
	Auto = Color3.fromRGB(200, 206, 224),
	Rebirth = Color3.fromRGB(190, 120, 255),
	Golden = Color3.fromRGB(255, 200, 40),
	Star = Color3.fromRGB(255, 200, 40),
	Clicks = Color3.fromRGB(255, 200, 40),
	Luck = Color3.fromRGB(96, 214, 90),
	Speed = Color3.fromRGB(255, 226, 70),
	Coin = Color3.fromRGB(255, 200, 40),
	Slots = Color3.fromRGB(120, 190, 255),
	Income = Color3.fromRGB(255, 200, 40),
	Walls = Color3.fromRGB(255, 140, 70),
	LockTime = Color3.fromRGB(255, 90, 100),
	Trade = Color3.fromRGB(70, 220, 210),
	Sound = Color3.fromRGB(120, 190, 255),
	Graphics = Color3.fromRGB(150, 120, 255),
	Code = Color3.fromRGB(255, 190, 60),
	Lock = Color3.fromRGB(255, 200, 40),
	Crown = Color3.fromRGB(255, 200, 40),
	Trophy = Color3.fromRGB(255, 200, 40),
	Close = white,
	Check = Color3.fromRGB(110, 238, 96),
	Plus = white,
	Minus = white,
	Robux = Color3.fromRGB(70, 220, 130),
	Home = Color3.fromRGB(255, 150, 60),
	Dice = plain,
	Flask = Color3.fromRGB(110, 238, 96),
	Globe = Color3.fromRGB(80, 170, 255),
	Clock = plain,
	Warning = Color3.fromRGB(255, 190, 40),
	Thief = Color3.fromRGB(170, 120, 255),
	Sparkle = Color3.fromRGB(255, 226, 90),
	Arrow = Color3.fromRGB(255, 214, 64),
	People = Color3.fromRGB(255, 170, 200),
	Run = Color3.fromRGB(255, 150, 60),
	Burst = Color3.fromRGB(255, 190, 40),
}

local function newPiece(
	canvas: Canvas,
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
	piece.Parent = canvas.Art
	return piece
end

local function newCanvas(
	art: Frame,
	palette: { Body: Color3, Shade: Color3, Light: Color3 },
	isOutline: boolean
): Canvas
	local canvas: any = {
		Art = art,
		Body = palette.Body,
		Shade = palette.Shade,
		Light = palette.Light,
		Ink = ink,
		IsOutline = isOutline,
	}
	function canvas.Rect(
		self: Canvas,
		name: string,
		x: number,
		y: number,
		width: number,
		height: number,
		color: Color3,
		radius: number
	): Frame
		if self.IsOutline then
			return newPiece(self, name, x - grow, y - grow, width + 2 * grow, height + 2 * grow, ink, radius)
		end
		return newPiece(self, name, x, y, width, height, color, radius)
	end
	function canvas.Spin(
		self: Canvas,
		name: string,
		centerX: number,
		centerY: number,
		width: number,
		height: number,
		color: Color3,
		radius: number,
		rotation: number
	): Frame
		local extra = if self.IsOutline then 2 * grow else 0
		local piece = newPiece(
			self,
			name,
			centerX,
			centerY,
			width + extra,
			height + extra,
			if self.IsOutline then ink else color,
			radius
		)
		piece.AnchorPoint = Vector2.new(0.5, 0.5)
		piece.Rotation = rotation
		return piece
	end
	function canvas.Letter(
		self: Canvas,
		text: string,
		x: number,
		y: number,
		width: number,
		height: number,
		color: Color3
	)
		if self.IsOutline then
			return
		end
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
		label.Parent = self.Art
	end
	function canvas.Group(self: Canvas, name: string, rotation: number): Canvas
		local frame = Instance.new("Frame")
		frame.Name = name
		frame.BackgroundTransparency = 1
		frame.BorderSizePixel = 0
		frame.Size = UDim2.fromScale(1, 1)
		frame.Rotation = rotation
		frame.Parent = self.Art
		local child =
			newCanvas(frame, { Body = self.Body, Shade = self.Shade, Light = self.Light }, self.IsOutline)
		return child
	end
	return canvas :: Canvas
end

local function keycap(
	c: Canvas,
	x: number,
	y: number,
	size: number,
	skirt: Color3,
	face: Color3,
	radius: number
)
	c:Rect("Skirt", x, y + size * 0.16, size, size * 0.82, skirt, radius)
	c:Rect("Face", x + size * 0.08, y, size * 0.84, size * 0.72, face, radius)
end

local function star(c: Canvas)
	for index = 0, pointCount - 1 do
		local angle = index * 360 / pointCount
		local radians = math.rad(angle)
		c:Spin(
			"Point",
			0.5 + 0.2 * math.sin(radians),
			0.54 - 0.2 * math.cos(radians),
			0.3,
			0.52,
			c.Body,
			0.4,
			angle
		)
	end
	c:Rect("Core", 0.27, 0.31, 0.46, 0.46, c.Body, 0.4)
	c:Spin("Shine", 0.5, 0.5, 0.14, 0.14, c.Light, 0.2, 45)
end

local function loop(c: Canvas)
	local ringRadius = 0.34
	for index = 0, loopSegments - 1 do
		local gapStart = index == 0 or index == loopSegments / 2
		local gapEnd = index == 1 or index == loopSegments / 2 + 1
		if not gapStart and not gapEnd then
			local angle = index * 360 / loopSegments
			local radians = math.rad(angle)
			c:Spin(
				"Segment",
				0.5 + ringRadius * math.sin(radians),
				0.5 - ringRadius * math.cos(radians),
				0.2,
				0.14,
				if index < loopSegments / 2 then c.Body else c.Light,
				0.5,
				angle
			)
		end
	end
	for side = 0, 1 do
		local angle = side * 180 + 11.25
		local radians = math.rad(angle)
		c:Spin(
			"Head",
			0.5 + ringRadius * math.sin(radians),
			0.5 - ringRadius * math.cos(radians),
			0.28,
			0.28,
			if side == 0 then c.Body else c.Light,
			0.14,
			angle + 45
		)
	end
end

local function arrow(c: Canvas, direction: number, centerY: number, color: Color3)
	local reach = 0.17
	local shaftLeft = if direction > 0 then 0.1 else 0.28
	c:Rect("Shaft", shaftLeft, centerY - 0.07, 0.62, 0.14, color, 0.5)
	local headX = if direction > 0 then 0.78 else 0.22
	c:Spin(
		"HeadTop",
		headX - direction * 0.03,
		centerY - reach / 2 - 0.01,
		0.34,
		0.14,
		color,
		0.5,
		direction * 45
	)
	c:Spin(
		"HeadBottom",
		headX - direction * 0.03,
		centerY + reach / 2 + 0.01,
		0.34,
		0.14,
		color,
		0.5,
		-direction * 45
	)
end

local function hexagon(c: Canvas, scale: number, color: Color3, name: string)
	local half = scale / 2
	for index = 0, 2 do
		c:Spin(name, 0.5, 0.5, scale, scale * 0.58, color, 0.18, index * 60)
	end
	return half
end

local drawers: { [string]: Drawer } = {
	Keys = function(c)
		keycap(c, 0.04, 0.06, 0.92, c.Shade, c.Body, 0.2)
		c:Rect("Shine", 0.2, 0.14, 0.34, 0.08, c.Light, 0.5)
		c:Letter("A", 0.22, 0.2, 0.56, 0.4, ink)
	end,
	Clicks = function(c)
		keycap(c, 0.05, 0.08, 0.9, c.Shade, c.Body, 0.24)
		c:Rect("Shine", 0.2, 0.17, 0.32, 0.07, c.Light, 0.5)
		c:Rect("Dish", 0.28, 0.27, 0.44, 0.3, c.Shade, 0.5)
		c:Rect("DishFace", 0.3, 0.26, 0.4, 0.28, c.Light, 0.5)
	end,
	Upgrades = function(c)
		for index = 0, 2 do
			local apex = 0.22 + index * 0.24
			local color = if index == 0 then c.Light else c.Body
			c:Spin("Arm", 0.34, apex + 0.1, 0.46, 0.15, color, 0.5, -40)
			c:Spin("Arm", 0.66, apex + 0.1, 0.46, 0.15, color, 0.5, 40)
		end
	end,
	Index = function(c)
		for column = 0, 1 do
			for row = 0, 1 do
				local isLight = (column + row) % 2 == 0
				keycap(
					c,
					0.05 + column * 0.48,
					0.05 + row * 0.48,
					0.42,
					if isLight then c.Shade else ink,
					if isLight then c.Body else c.Shade,
					0.2
				)
			end
		end
	end,
	Settings = function(c)
		for index = 0, 3 do
			c:Spin("Teeth", 0.5, 0.5, 0.24, 0.96, c.Shade, 0.2, index * 45)
		end
		c:Rect("Body", 0.16, 0.16, 0.68, 0.68, c.Body, 0.5)
		c:Rect("Hole", 0.37, 0.37, 0.26, 0.26, ink, 0.5)
	end,
	Store = function(c)
		c:Rect("HandleLeft", 0.3, 0.1, 0.1, 0.36, c.Shade, 0.5)
		c:Rect("HandleRight", 0.6, 0.1, 0.1, 0.36, c.Shade, 0.5)
		c:Rect("HandleTop", 0.3, 0.06, 0.4, 0.12, c.Shade, 0.5)
		c:Rect("Bag", 0.12, 0.3, 0.76, 0.62, c.Body, 0.16)
		c:Rect("Band", 0.12, 0.3, 0.76, 0.16, c.Shade, 0.3)
		c:Rect("Shine", 0.2, 0.52, 0.12, 0.28, c.Light, 0.5)
		c:Spin("Star", 0.6, 0.64, 0.2, 0.2, c.Light, 0.2, 45)
	end,
	Market = function(c)
		for index = 0, 3 do
			c:Rect(
				"Awning",
				0.08 + index * 0.21,
				0.14,
				0.2,
				0.26,
				if index % 2 == 0 then c.Body else plain,
				0.2
			)
		end
		c:Rect("Post", 0.14, 0.4, 0.09, 0.5, c.Shade, 0.2)
		c:Rect("Post", 0.77, 0.4, 0.09, 0.5, c.Shade, 0.2)
		c:Rect("Counter", 0.08, 0.6, 0.84, 0.3, c.Shade, 0.14)
		c:Rect("Cap", 0.3, 0.46, 0.16, 0.16, c.Light, 0.25)
		c:Rect("Cap", 0.54, 0.46, 0.16, 0.16, plain, 0.25)
	end,
	Leaderboard = function(c)
		c:Rect("Second", 0.05, 0.46, 0.28, 0.46, c.Shade, 0.12)
		c:Rect("First", 0.36, 0.28, 0.28, 0.64, c.Body, 0.12)
		c:Rect("Third", 0.67, 0.58, 0.28, 0.34, c.Shade, 0.12)
		c:Letter("2", 0.05, 0.52, 0.28, 0.28, ink)
		c:Letter("1", 0.36, 0.36, 0.28, 0.34, ink)
		c:Letter("3", 0.67, 0.62, 0.28, 0.24, ink)
		c:Spin("Crown", 0.5, 0.15, 0.15, 0.15, c.Light, 0.2, 45)
	end,
	Daily = function(c)
		c:Rect("Page", 0.1, 0.16, 0.8, 0.74, c.Body, 0.14)
		c:Rect("Header", 0.1, 0.16, 0.8, 0.26, red, 0.3)
		c:Rect("RingLeft", 0.27, 0.06, 0.1, 0.2, ink, 0.5)
		c:Rect("RingRight", 0.63, 0.06, 0.1, 0.2, ink, 0.5)
		for column = 0, 2 do
			for row = 0, 1 do
				c:Rect("Day", 0.2 + column * 0.22, 0.5 + row * 0.19, 0.16, 0.13, c.Shade, 0.25)
			end
		end
	end,
	Gift = function(c)
		c:Rect("Box", 0.14, 0.46, 0.72, 0.46, c.Shade, 0.12)
		c:Rect("Lid", 0.08, 0.3, 0.84, 0.2, c.Body, 0.25)
		c:Rect("RibbonBox", 0.44, 0.46, 0.12, 0.46, plain, 0)
		c:Rect("RibbonLid", 0.44, 0.3, 0.12, 0.2, plain, 0)
		c:Spin("BowLeft", 0.36, 0.2, 0.26, 0.18, plain, 0.5, -24)
		c:Spin("BowRight", 0.64, 0.2, 0.26, 0.18, plain, 0.5, 24)
	end,
	Pass = function(c)
		local tilt = c:Group("Tilt", -14)
		tilt:Rect("Ticket", 0.04, 0.22, 0.92, 0.56, c.Body, 0.2)
		tilt:Rect("NotchLeft", -0.05, 0.42, 0.17, 0.17, ink, 0.5)
		tilt:Rect("NotchRight", 0.88, 0.42, 0.17, 0.17, ink, 0.5)
		for index = 0, 3 do
			tilt:Rect("Perforation", 0.66, 0.29 + index * 0.1, 0.05, 0.06, c.Shade, 0.3)
		end
		tilt:Rect("Mark", 0.2, 0.36, 0.3, 0.28, c.Light, 0.5)
	end,
	Auto = loop,
	Rebirth = loop,
	Golden = star,
	Star = star,
	Luck = function(c)
		c:Spin("Stem", 0.58, 0.82, 0.1, 0.34, c.Shade, 0.5, 28)
		c:Rect("Leaf", 0.1, 0.06, 0.4, 0.4, c.Body, 0.5)
		c:Rect("Leaf", 0.5, 0.06, 0.4, 0.4, c.Body, 0.5)
		c:Rect("Leaf", 0.1, 0.44, 0.4, 0.4, c.Body, 0.5)
		c:Rect("Leaf", 0.5, 0.44, 0.4, 0.4, c.Body, 0.5)
		c:Rect("Core", 0.38, 0.38, 0.24, 0.24, c.Light, 0.5)
	end,
	Speed = function(c)
		for index = 0, 1 do
			local shift = index * 0.3
			local color = if index == 0 then c.Body else c.Light
			c:Spin("ArmUp", 0.28 + shift, 0.34, 0.5, 0.16, color, 0.5, 48)
			c:Spin("ArmDown", 0.28 + shift, 0.66, 0.5, 0.16, color, 0.5, -48)
		end
	end,
	Coin = function(c)
		c:Rect("Rim", 0.06, 0.06, 0.88, 0.88, c.Shade, 0.5)
		c:Rect("Face", 0.14, 0.12, 0.72, 0.72, c.Body, 0.5)
		c:Rect("Ring", 0.28, 0.26, 0.44, 0.44, c.Light, 0.5)
		c:Rect("Core", 0.36, 0.34, 0.28, 0.28, c.Body, 0.5)
	end,
	Slots = function(c)
		c:Rect("Case", 0.03, 0.24, 0.94, 0.56, c.Shade, 0.16)
		for row = 0, 2 do
			for column = 0, 5 do
				if row < 2 or column > 0 and column < 5 then
					c:Rect("Key", 0.1 + column * 0.14, 0.31 + row * 0.15, 0.11, 0.11, c.Light, 0.25)
				end
			end
		end
		c:Rect("Space", 0.3, 0.61, 0.4, 0.11, c.Body, 0.25)
	end,
	Income = function(c)
		for index = 0, 2 do
			local y = 0.58 - index * 0.17
			c:Rect("Edge", 0.12, y + 0.04, 0.76, 0.2, c.Shade, 0.5)
			c:Rect("Coin", 0.12, y, 0.76, 0.2, c.Body, 0.5)
			c:Rect("Shine", 0.22, y + 0.045, 0.3, 0.05, c.Light, 0.5)
		end
		c:Spin("Sparkle", 0.82, 0.18, 0.16, 0.16, c.Light, 0.15, 45)
	end,
	Walls = function(c)
		c:Rect("Wall", 0.04, 0.12, 0.92, 0.78, c.Shade, 0.1)
		for row = 0, 3 do
			local offset = if row % 2 == 0 then 0 else 0.14
			for column = 0, 2 do
				local x = 0.08 + column * 0.29 - offset
				local left = math.max(x, 0.08)
				local right = math.min(x + 0.26, 0.92)
				if right - left > 0.05 then
					c:Rect("Brick", left, 0.17 + row * 0.185, right - left, 0.15, c.Body, 0.2)
				end
			end
		end
	end,
	LockTime = function(c)
		c:Rect("Top", 0.14, 0.08, 0.72, 0.5, c.Body, 0.16)
		c:Spin("Tip", 0.5, 0.56, 0.52, 0.52, c.Body, 0.14, 45)
		c:Rect("Inner", 0.26, 0.18, 0.48, 0.38, c.Light, 0.16)
		c:Spin("InnerTip", 0.5, 0.52, 0.36, 0.36, c.Light, 0.14, 45)
		c:Rect("Laser", 0.04, 0.42, 0.92, 0.1, red, 0.5)
		c:Rect("LaserShine", 0.1, 0.44, 0.8, 0.03, plain, 0.5)
	end,
	Trade = function(c)
		arrow(c, 1, 0.3, c.Light)
		arrow(c, -1, 0.7, c.Body)
	end,
	Sound = function(c)
		c:Rect("Box", 0.1, 0.36, 0.22, 0.28, c.Shade, 0.12)
		c:Spin("Cone", 0.36, 0.5, 0.36, 0.36, c.Body, 0.1, 45)
		c:Rect("Cover", 0.3, 0.3, 0.1, 0.4, c.Body, 0)
		c:Rect("WaveSmall", 0.64, 0.38, 0.09, 0.24, c.Light, 0.5)
		c:Rect("WaveBig", 0.8, 0.26, 0.09, 0.48, c.Light, 0.5)
	end,
	Graphics = function(c)
		c:Rect("Frame", 0.06, 0.12, 0.88, 0.58, c.Shade, 0.12)
		c:Rect("Screen", 0.12, 0.18, 0.76, 0.44, c.Light, 0.08)
		c:Spin("Glare", 0.4, 0.4, 0.5, 0.1, c.Body, 0.5, -30)
		c:Rect("Neck", 0.44, 0.7, 0.12, 0.12, c.Shade, 0)
		c:Rect("Base", 0.28, 0.8, 0.44, 0.1, c.Shade, 0.5)
	end,
	Code = function(c)
		c:Rect("Card", 0.08, 0.16, 0.84, 0.68, c.Body, 0.16)
		c:Rect("Strip", 0.08, 0.28, 0.84, 0.12, c.Shade, 0)
		c:Rect("Line", 0.18, 0.5, 0.42, 0.08, c.Shade, 0.5)
		c:Rect("Line", 0.18, 0.64, 0.3, 0.08, c.Shade, 0.5)
		c:Spin("Star", 0.74, 0.62, 0.2, 0.2, c.Light, 0.2, 45)
	end,
	Lock = function(c)
		c:Rect("Shackle", 0.26, 0.08, 0.48, 0.58, c.Shade, 0.5)
		c:Rect("Hole", 0.38, 0.2, 0.24, 0.5, ink, 0.5)
		c:Rect("Body", 0.14, 0.42, 0.72, 0.5, c.Body, 0.16)
		c:Rect("Shine", 0.22, 0.5, 0.1, 0.26, c.Light, 0.5)
		c:Rect("Keyhole", 0.45, 0.56, 0.1, 0.2, ink, 0.5)
	end,
	Crown = function(c)
		c:Rect("Band", 0.1, 0.6, 0.8, 0.24, c.Body, 0.16)
		c:Spin("PointLeft", 0.2, 0.42, 0.26, 0.26, c.Body, 0.12, 45)
		c:Spin("PointMid", 0.5, 0.36, 0.3, 0.3, c.Body, 0.12, 45)
		c:Spin("PointRight", 0.8, 0.42, 0.26, 0.26, c.Body, 0.12, 45)
		c:Rect("Fill", 0.16, 0.4, 0.68, 0.26, c.Body, 0)
		c:Rect("Gem", 0.44, 0.64, 0.12, 0.12, red, 0.5)
		c:Rect("Gem", 0.2, 0.67, 0.09, 0.09, c.Light, 0.5)
		c:Rect("Gem", 0.71, 0.67, 0.09, 0.09, c.Light, 0.5)
	end,
	Trophy = function(c)
		c:Rect("HandleLeft", 0.06, 0.16, 0.26, 0.3, c.Shade, 0.5)
		c:Rect("HandleRight", 0.68, 0.16, 0.26, 0.3, c.Shade, 0.5)
		c:Rect("HoleLeft", 0.13, 0.23, 0.12, 0.16, ink, 0.5)
		c:Rect("HoleRight", 0.75, 0.23, 0.12, 0.16, ink, 0.5)
		c:Rect("Cup", 0.24, 0.08, 0.52, 0.46, c.Body, 0.3)
		c:Rect("Rim", 0.22, 0.08, 0.56, 0.1, c.Light, 0.5)
		c:Rect("Shine", 0.32, 0.22, 0.08, 0.22, c.Light, 0.5)
		c:Rect("Stem", 0.43, 0.52, 0.14, 0.2, c.Shade, 0)
		c:Rect("Base", 0.26, 0.72, 0.48, 0.18, c.Body, 0.2)
	end,
	Close = function(c)
		c:Spin("ArmA", 0.5, 0.5, 0.92, 0.2, c.Body, 0.5, 45)
		c:Spin("ArmB", 0.5, 0.5, 0.92, 0.2, c.Body, 0.5, -45)
	end,
	Check = function(c)
		c:Spin("Short", 0.3, 0.6, 0.38, 0.2, c.Body, 0.5, 45)
		c:Spin("Long", 0.58, 0.5, 0.72, 0.2, c.Body, 0.5, -52)
	end,
	Plus = function(c)
		c:Rect("Bar", 0.08, 0.4, 0.84, 0.2, c.Body, 0.5)
		c:Rect("Bar", 0.4, 0.08, 0.2, 0.84, c.Body, 0.5)
	end,
	Minus = function(c)
		c:Rect("Bar", 0.08, 0.4, 0.84, 0.2, c.Body, 0.5)
	end,
	Robux = function(c)
		hexagon(c, 0.94, c.Shade, "Rim")
		hexagon(c, 0.8, c.Body, "Face")
		hexagon(c, 0.5, c.Light, "Core")
		c:Rect("Dot", 0.4, 0.4, 0.2, 0.2, c.Body, 0.5)
	end,
	Home = function(c)
		c:Spin("Roof", 0.5, 0.34, 0.6, 0.6, c.Shade, 0.1, 45)
		c:Rect("Cut", 0.02, 0.5, 0.96, 0.2, c.Shade, 0)
		c:Rect("Body", 0.2, 0.46, 0.6, 0.44, c.Body, 0.1)
		c:Rect("Door", 0.42, 0.6, 0.18, 0.3, ink, 0.2)
		c:Rect("Chimney", 0.68, 0.16, 0.12, 0.2, c.Shade, 0.1)
	end,
	Dice = function(c)
		c:Rect("Side", 0.08, 0.14, 0.84, 0.8, c.Shade, 0.2)
		c:Rect("Face", 0.08, 0.06, 0.84, 0.76, c.Body, 0.2)
		for _, pip in { { 0.24, 0.2 }, { 0.62, 0.2 }, { 0.43, 0.38 }, { 0.24, 0.56 }, { 0.62, 0.56 } } do
			c:Rect("Pip", pip[1], pip[2], 0.14, 0.14, ink, 0.5)
		end
	end,
	Flask = function(c)
		c:Rect("Neck", 0.38, 0.08, 0.24, 0.3, c.Light, 0.12)
		c:Rect("Cork", 0.34, 0.04, 0.32, 0.12, c.Shade, 0.3)
		c:Rect("Bottle", 0.12, 0.3, 0.76, 0.62, c.Shade, 0.5)
		c:Rect("Liquid", 0.18, 0.44, 0.64, 0.42, c.Body, 0.4)
		c:Rect("Bubble", 0.3, 0.52, 0.12, 0.12, c.Light, 0.5)
		c:Rect("Bubble", 0.54, 0.64, 0.08, 0.08, c.Light, 0.5)
	end,
	Globe = function(c)
		c:Rect("Sphere", 0.06, 0.06, 0.88, 0.88, c.Body, 0.5)
		c:Rect("Land", 0.18, 0.22, 0.28, 0.24, c.Light, 0.4)
		c:Rect("Land", 0.5, 0.5, 0.3, 0.26, c.Light, 0.4)
		c:Rect("Land", 0.24, 0.6, 0.16, 0.16, c.Light, 0.5)
		c:Rect("Shine", 0.66, 0.2, 0.1, 0.18, c.Light, 0.5)
	end,
	Clock = function(c)
		c:Rect("Rim", 0.06, 0.06, 0.88, 0.88, c.Shade, 0.5)
		c:Rect("Face", 0.14, 0.14, 0.72, 0.72, c.Body, 0.5)
		c:Rect("HandA", 0.46, 0.24, 0.08, 0.3, ink, 0.5)
		c:Rect("HandB", 0.46, 0.46, 0.26, 0.08, ink, 0.5)
	end,
	Warning = function(c)
		c:Spin("Sign", 0.5, 0.5, 0.64, 0.64, c.Body, 0.16, 45)
		c:Rect("Bar", 0.45, 0.22, 0.1, 0.34, ink, 0.5)
		c:Rect("Dot", 0.45, 0.62, 0.1, 0.1, ink, 0.5)
	end,
	Thief = function(c)
		c:Rect("Head", 0.14, 0.1, 0.72, 0.8, c.Body, 0.5)
		c:Rect("Mask", 0.1, 0.34, 0.8, 0.26, ink, 0.4)
		c:Rect("EyeLeft", 0.26, 0.4, 0.17, 0.12, plain, 0.5)
		c:Rect("EyeRight", 0.57, 0.4, 0.17, 0.12, plain, 0.5)
		c:Rect("Mouth", 0.4, 0.7, 0.2, 0.06, ink, 0.5)
	end,
	Sparkle = function(c)
		c:Spin("Tall", 0.5, 0.5, 0.2, 0.9, c.Body, 0.5, 0)
		c:Spin("Wide", 0.5, 0.5, 0.9, 0.2, c.Body, 0.5, 0)
		c:Spin("DiagA", 0.5, 0.5, 0.18, 0.56, c.Light, 0.5, 45)
		c:Spin("DiagB", 0.5, 0.5, 0.18, 0.56, c.Light, 0.5, -45)
	end,
	Arrow = function(c)
		c:Rect("Shaft", 0.06, 0.4, 0.56, 0.2, c.Body, 0.5)
		c:Spin("HeadTop", 0.7, 0.36, 0.44, 0.2, c.Body, 0.5, 45)
		c:Spin("HeadBottom", 0.7, 0.64, 0.44, 0.2, c.Body, 0.5, -45)
	end,
	People = function(c)
		c:Rect("HeadBack", 0.54, 0.12, 0.3, 0.3, c.Shade, 0.5)
		c:Rect("BodyBack", 0.46, 0.46, 0.46, 0.38, c.Shade, 0.5)
		c:Rect("Head", 0.2, 0.18, 0.34, 0.34, c.Body, 0.5)
		c:Rect("Body", 0.1, 0.54, 0.54, 0.4, c.Body, 0.5)
	end,
	Run = function(c)
		c:Rect("Head", 0.52, 0.06, 0.24, 0.24, c.Body, 0.5)
		c:Spin("Torso", 0.46, 0.46, 0.2, 0.4, c.Body, 0.4, 20)
		c:Spin("ArmFront", 0.66, 0.46, 0.14, 0.34, c.Light, 0.5, -50)
		c:Spin("ArmBack", 0.28, 0.4, 0.14, 0.34, c.Light, 0.5, 50)
		c:Spin("LegFront", 0.58, 0.76, 0.16, 0.38, c.Shade, 0.5, -30)
		c:Spin("LegBack", 0.34, 0.74, 0.16, 0.38, c.Shade, 0.5, 40)
	end,
	Burst = function(c)
		for index = 0, 3 do
			c:Spin("Spike", 0.5, 0.5, 0.2, 0.96, if index % 2 == 0 then c.Body else c.Light, 0.4, index * 45)
		end
		c:Rect("Core", 0.28, 0.28, 0.44, 0.44, c.Light, 0.5)
	end,
}

local names = {
	"Keys",
	"Upgrades",
	"Index",
	"Settings",
	"Store",
	"Market",
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
	"Slots",
	"Income",
	"Walls",
	"LockTime",
	"Trade",
	"Sound",
	"Graphics",
	"Code",
	"Lock",
	"Crown",
	"Trophy",
	"Close",
	"Check",
	"Plus",
	"Minus",
	"Robux",
	"Home",
	"Dice",
	"Flask",
	"Globe",
	"Clock",
	"Warning",
	"Thief",
	"Sparkle",
	"Arrow",
	"People",
	"Run",
	"Burst",
}

local Glyphs = {
	Names = table.freeze(names),
}

function Glyphs.Has(name: string): boolean
	return drawers[name] ~= nil
end

function Glyphs.DefaultColor(name: string): Color3
	return defaultColors[name] or plain
end

function Glyphs.Build(name: string, props: BuildProps): Frame
	local draw = drawers[name]
	if not draw then
		error(`Glyphs: unknown glyph {name}`, 2)
	end
	local body = props.Color or defaultColors[name] or plain
	local palette = {
		Body = body,
		Shade = body:Lerp(Color3.new(0, 0, 0), shadeAmount),
		Light = body:Lerp(white, lightAmount),
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
	art.Size = UDim2.fromScale(0.92, 0.92)
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 1
	ratio.AspectType = Enum.AspectType.FitWithinMaxSize
	ratio.Parent = art
	draw(newCanvas(art, palette, true))
	draw(newCanvas(art, palette, false))
	art.Parent = holder
	holder.Parent = props.Parent
	return holder
end

return Glyphs
