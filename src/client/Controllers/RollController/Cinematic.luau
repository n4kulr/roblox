--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Keys = require(ReplicatedStorage.Config.Keys)
local Trove = require(ReplicatedStorage.Packages.Trove)
local KeyModels = require(ReplicatedStorage.Utils.KeyModels)
local Kit = require(script.Parent.Parent.UIController.Kit)
local Tiers = require(script.Parent.Tiers)
local Viewport = require(script.Parent.Parent.UIController.Viewport)

type TroveInstance = typeof(Trove.new())

export type Payload = {
	Key: Keys.Key,
	Rarity: Keys.Rarity,
	IsGolden: boolean,
}

type Entry = {
	Payload: Payload,
	OnDone: (() -> ())?,
}

type Particle = {
	Frame: Frame,
	Born: number,
	Life: number,
	X: number,
	Y: number,
	VX: number,
	VY: number,
	Rot: number,
	Spin: number,
	Shape: number,
	IsRain: boolean,
	Color: Color3,
	Used: boolean,
}

type Star = {
	Frame: Frame,
	Angle: number,
	Speed: number,
	Phase: number,
}

type Crack = {
	Frame: Frame,
	Angle: number,
	Length: number,
}

type Ring = {
	Frame: Frame,
	Stroke: UIStroke,
}

type Ray = {
	Holder: Frame,
	Image: ImageLabel?,
	Diameter: number,
}

type Edge = {
	Frame: Frame,
	Gradient: UIGradient,
	Side: string,
}

type TitleSet = {
	Main: TextLabel,
	MainStroke: UIStroke,
	MainScale: UIScale,
	MainGradient: UIGradient,
	Red: TextLabel,
	Cyan: TextLabel,
}

export type Cinematic = {
	_trove: TroveInstance,
	_isLowGraphics: () -> boolean,
	_getControllers: () -> { [string]: any },
	_gui: ScreenGui,
	_world: Frame,
	_dim: Frame,
	_edges: { Edge },
	_vignette: { Frame },
	_flash: Frame,
	_hint: TextLabel,
	_glow: Frame,
	_model: Viewport.Handle,
	_title: TitleSet,
	_name: TextLabel,
	_nameScale: UIScale,
	_nameStroke: UIStroke,
	_rays: { Ray },
	_rings: { Ring },
	_cracks: { Crack },
	_stars: { Star },
	_particles: { Particle },
	_active: Entry?,
	_queued: Entry?,
	_tier: Tiers.Tier,
	_t: number,
	_low: boolean,
	_hasImpacted: boolean,
	_humanoid: Humanoid?,
	_baseOffset: Vector3,
	_modelKey: string,
	_destroyed: boolean,
	CanAccept: (self: Cinematic) -> boolean,
	Play: (self: Cinematic, payload: Payload, onDone: (() -> ())?) -> boolean,
	Step: (self: Cinematic, dt: number) -> (),
	Skip: (self: Cinematic) -> boolean,
	Seek: (self: Cinematic, seconds: number) -> (),
	IsPlaying: (self: Cinematic) -> boolean,
	QueuedCount: (self: Cinematic) -> number,
	Elapsed: (self: Cinematic) -> number,
	TierName: (self: Cinematic) -> string,
	VisibleParticles: (self: Cinematic) -> number,
	Destroy: (self: Cinematic) -> (),
}

local displayOrder = 8
local capSize = 230
local staticYaw = 28
local spinSpeed = 55
local chargeSpin = 520
local bobHeight = 0.06
local capY = -10
local titleY = -262
local nameY = 196
local collapseSeconds = 0.3
local rayDiameters = { 1500, 1050 }
local particleCap = 56
local starCap = 40
local crackCount = 14
local ringCap = 3
local lowScale = 0.35
local gravity = 900
local drag = 2.5
local white = Color3.new(1, 1, 1)
local black = Color3.new(0, 0, 0)
local pi = math.pi

local rainbow = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 92, 110)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 190, 70)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(110, 235, 110)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(70, 200, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(170, 110, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 92, 110)),
})

local Cinematic = {}
Cinematic.__index = Cinematic
Cinematic.ShouldPlay = Tiers.ShouldPlay
Cinematic.RankOf = Tiers.RankOf
Cinematic.TierFor = Tiers.For

local function clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

local function seg(t: number, a: number, b: number): number
	if b <= a then
		return if t >= b then 1 else 0
	end
	return clamp01((t - a) / (b - a))
end

local function lerp(a: number, b: number, x: number): number
	return a + (b - a) * x
end

local function outQuad(x: number): number
	return 1 - (1 - x) * (1 - x)
end

local function outCubic(x: number): number
	return 1 - (1 - x) ^ 3
end

local function inQuad(x: number): number
	return x * x
end

local function outBack(x: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

local function noise(x: number): number
	local s = math.sin(x * 127.1) * 43758.5453
	return s - math.floor(s)
end

local function box(parent: Instance, name: string, z: number): Frame
	local item = Instance.new("Frame")
	item.Name = name
	item.BackgroundColor3 = white
	item.BackgroundTransparency = 1
	item.BorderSizePixel = 0
	item.AnchorPoint = Vector2.new(0.5, 0.5)
	item.Position = UDim2.fromScale(0.5, 0.5)
	item.Size = UDim2.fromOffset(10, 10)
	item.ZIndex = z
	item.Active = false
	item.Visible = false
	item.Parent = parent
	return item
end

local function center(x: number, y: number): UDim2
	return UDim2.new(0.5, x, 0.5, y)
end

local function buildEdges(parent: Instance): { Edge }
	local edges: { Edge } = {}
	for _, side in { "Top", "Bottom", "Left", "Right" } do
		local frame = box(parent, `Edge{side}`, 16)
		frame.BackgroundTransparency = 0
		local isVertical = side == "Top" or side == "Bottom"
		frame.AnchorPoint = Vector2.new(if side == "Right" then 1 else 0, if side == "Bottom" then 1 else 0)
		frame.Position = UDim2.fromScale(if side == "Right" then 1 else 0, if side == "Bottom" then 1 else 0)
		frame.Size = if isVertical then UDim2.new(1, 0, 0, 16) else UDim2.new(0, 16, 1, 0)
		local gradient = Instance.new("UIGradient")
		gradient.Color = rainbow
		gradient.Parent = frame
		table.insert(edges, { Frame = frame, Gradient = gradient, Side = side })
	end
	return edges
end

local function buildVignette(parent: Instance): { Frame }
	local strips: { Frame } = {}
	local setups = {
		{ Name = "Left", Rotation = 0, Anchor = Vector2.new(0, 0), Position = UDim2.fromScale(0, 0) },
		{ Name = "Right", Rotation = 180, Anchor = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0) },
		{ Name = "Top", Rotation = 90, Anchor = Vector2.new(0, 0), Position = UDim2.fromScale(0, 0) },
		{ Name = "Bottom", Rotation = 270, Anchor = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1) },
	}
	for _, setup in setups do
		local frame = box(parent, `Vignette{setup.Name}`, 2)
		frame.BackgroundColor3 = black
		frame.AnchorPoint = setup.Anchor
		frame.Position = setup.Position
		local isSide = setup.Name == "Left" or setup.Name == "Right"
		frame.Size = if isSide then UDim2.fromScale(0.4, 1) else UDim2.fromScale(1, 0.45)
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = setup.Rotation
		gradient.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.5, 0.65),
			NumberSequenceKeypoint.new(1, 1),
		})
		gradient.Parent = frame
		table.insert(strips, frame)
	end
	return strips
end

local function buildTitle(parent: Instance): TitleSet
	local function make(name: string, color: Color3, outline: boolean, z: number): TextLabel
		local label = Kit.Label({
			Parent = parent,
			Name = name,
			Text = "",
			Size = UDim2.fromOffset(1300, 130),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = center(0, titleY),
			TextSize = 96,
			Color = color,
			Align = Enum.TextXAlignment.Center,
			Title = true,
			Outline = outline,
			StrokeSize = 10,
		})
		label.ZIndex = z
		label.Visible = false
		local scale = Instance.new("UIScale")
		scale.Parent = label
		return label
	end
	local red = make("TitleRed", Color3.fromRGB(255, 50, 80), false, 13)
	local cyan = make("TitleCyan", Color3.fromRGB(40, 230, 255), false, 13)
	local main = make("Title", white, true, 14)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	gradient.Parent = main
	return {
		Main = main,
		MainStroke = main:FindFirstChild("TextStroke") :: UIStroke,
		MainScale = main:FindFirstChildOfClass("UIScale") :: UIScale,
		MainGradient = gradient,
		Red = red,
		Cyan = cyan,
	}
end

function Cinematic.new(
	playerGui: Instance,
	trove: TroveInstance,
	isLowGraphics: () -> boolean,
	getControllers: () -> { [string]: any }
): Cinematic
	local gui, root = Kit.ScreenGui("RollCinematic", displayOrder, playerGui, trove)
	gui.IgnoreGuiInset = true
	gui.Enabled = false

	local dim = box(root, "Dim", 1)
	dim.AnchorPoint = Vector2.zero
	dim.Position = UDim2.fromScale(0, 0)
	dim.Size = UDim2.fromScale(1, 1)
	dim.BackgroundColor3 = black
	dim.BackgroundTransparency = 1

	local vignette = buildVignette(root)

	local world = Instance.new("Frame")
	world.Name = "World"
	world.BackgroundTransparency = 1
	world.BorderSizePixel = 0
	world.Size = UDim2.fromScale(1, 1)
	world.ZIndex = 3
	world.Parent = root

	local stars: { Star } = {}
	for index = 1, starCap do
		table.insert(stars, {
			Frame = box(world, `Star{index}`, 1),
			Angle = math.random() * 360,
			Speed = 0.6 + math.random() * 0.8,
			Phase = math.random(),
		})
	end

	local rays: { Ray } = {}
	for index, diameter in rayDiameters do
		local holder = Kit.Burst({ Parent = world, Diameter = diameter, Position = center(0, capY) })
		holder.Name = `Rays{index}`
		holder.ZIndex = 2 + index
		holder.Visible = false
		local image = holder:FindFirstChild("Image")
		table.insert(rays, {
			Holder = holder,
			Image = if image and image:IsA("ImageLabel") then image else nil,
			Diameter = diameter,
		})
	end

	local glow = box(world, "Glow", 5)
	Kit.Round(glow)

	local rings: { Ring } = {}
	for index = 1, ringCap do
		local ring = box(world, `Ring{index}`, 6)
		Kit.Round(ring)
		local stroke = Kit.Stroke(ring, white, 12)
		table.insert(rings, { Frame = ring, Stroke = stroke })
	end

	local cracks: { Crack } = {}
	for index = 1, crackCount do
		local frame = box(world, `Crack{index}`, 7)
		frame.BackgroundTransparency = 0
		frame.BackgroundColor3 = white
		Kit.Corner(frame, 4)
		table.insert(cracks, {
			Frame = frame,
			Angle = (index - 1) * (360 / crackCount) + (math.random() - 0.5) * 14,
			Length = 380 + math.random() * 260,
		})
	end

	local model = Viewport.new({
		Parent = world,
		Name = "KeyModel",
		Size = UDim2.fromOffset(capSize, capSize),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = center(0, capY),
		ZIndex = 10,
	})
	model.Frame.Visible = false

	local particles: { Particle } = {}
	for index = 1, particleCap do
		table.insert(particles, {
			Frame = box(world, `Piece{index}`, 12),
			Born = 0,
			Life = 1,
			X = 0,
			Y = 0,
			VX = 0,
			VY = 0,
			Rot = 0,
			Spin = 0,
			Shape = 1,
			IsRain = false,
			Color = white,
			Used = false,
		})
	end
	for _, piece in particles do
		piece.Frame.BackgroundTransparency = 0
	end

	local title = buildTitle(world)

	local nameLabel = Kit.Label({
		Parent = world,
		Name = "KeyName",
		Text = "",
		Size = UDim2.fromOffset(1000, 80),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = center(0, nameY),
		TextSize = 64,
		Align = Enum.TextXAlignment.Center,
		Title = true,
		StrokeSize = 7,
	})
	nameLabel.ZIndex = 15
	nameLabel.Visible = false
	local nameScale = Instance.new("UIScale")
	nameScale.Parent = nameLabel

	local edges = buildEdges(root)

	local flash = box(root, "Flash", 20)
	flash.AnchorPoint = Vector2.zero
	flash.Position = UDim2.fromScale(0, 0)
	flash.Size = UDim2.fromScale(1, 1)
	flash.BackgroundTransparency = 1

	local hint = Kit.Label({
		Parent = root,
		Name = "Hint",
		Text = "TAP TO SKIP",
		Size = UDim2.fromOffset(300, 30),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -22),
		TextSize = 20,
		Align = Enum.TextXAlignment.Center,
		Title = true,
		StrokeSize = 3,
	})
	hint.ZIndex = 21
	hint.Visible = false

	local self: Cinematic = setmetatable({
		_trove = trove,
		_isLowGraphics = isLowGraphics,
		_getControllers = getControllers,
		_gui = gui,
		_world = world,
		_dim = dim,
		_edges = edges,
		_vignette = vignette,
		_flash = flash,
		_hint = hint,
		_glow = glow,
		_model = model,
		_title = title,
		_name = nameLabel,
		_nameScale = nameScale,
		_nameStroke = nameLabel:FindFirstChild("TextStroke") :: UIStroke,
		_rays = rays,
		_rings = rings,
		_cracks = cracks,
		_stars = stars,
		_particles = particles,
		_active = nil,
		_queued = nil,
		_tier = Tiers.Get("Legendary"),
		_t = 0,
		_low = false,
		_hasImpacted = false,
		_humanoid = nil,
		_baseOffset = Vector3.zero,
		_modelKey = "",
		_destroyed = false,
	}, Cinematic) :: any

	trove:Connect(UserInputService.InputBegan, function(input: InputObject)
		local inputType = input.UserInputType
		if inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch then
			self:Skip()
		end
	end)
	trove:Add(function()
		self:Destroy()
	end)
	return self
end

local setDucked: (self: Cinematic, isDucked: boolean) -> ()

local function hideAll(self: Cinematic)
	for _, piece in self._particles do
		piece.Frame.Visible = false
		piece.Used = false
	end
	for _, star in self._stars do
		star.Frame.Visible = false
	end
	for _, crack in self._cracks do
		crack.Frame.Visible = false
	end
	for _, ring in self._rings do
		ring.Frame.Visible = false
	end
	for _, ray in self._rays do
		ray.Holder.Visible = false
	end
	for _, edge in self._edges do
		edge.Frame.Visible = false
	end
	self._glow.Visible = false
	self._flash.Visible = false
	self._hint.Visible = false
	self._name.Visible = false
	self._title.Main.Visible = false
	self._title.Red.Visible = false
	self._title.Cyan.Visible = false
	self._model.Frame.Visible = false
end

local function armParticles(self: Cinematic, payload: Payload)
	local tier = self._tier
	local base = payload.Rarity.Color
	local count = tier.Particles
	if self._low then
		count = math.floor(count * lowScale)
	end
	local palette =
		{ Kit.Shade(base, 0.3), white, Kit.Theme.Gold, base, Kit.Shade(base, 0.55), Kit.Theme.Pink }
	local ti = tier.ImpactAt
	local rainStart = math.floor(count * 0.45)
	for index, piece in self._particles do
		if index > count then
			piece.Used = false
			piece.Frame.Visible = false
		else
			local isRain = tier.Rain and index > rainStart
			piece.Used = true
			piece.IsRain = isRain
			piece.Shape = index % 3
			if tier.Rainbow then
				piece.Color = Color3.fromHSV(math.random(), 0.7, 1)
			else
				piece.Color = palette[math.random(1, #palette)]
			end
			piece.Rot = math.random() * 360
			piece.Spin = (math.random() - 0.5) * 900
			if isRain then
				local span = math.max(tier.Duration - 0.8 - ti, 0.5)
				piece.Born = ti + 0.15 + ((index - rainStart) / math.max(count - rainStart, 1)) * span
				piece.Life = 1.5 + math.random() * 0.6
				piece.X = (math.random() - 0.5) * 1500
				piece.Y = -470
				piece.VX = (math.random() - 0.5) * 60
				piece.VY = 300 + math.random() * 240
			else
				local angle = math.random() * pi * 2
				local speed = 360 + math.random() * 700
				piece.Born = ti + math.random() * 0.06
				piece.Life = (if tier.Rain then 1.7 else 1) + math.random() * 0.8
				piece.X = 0
				piece.Y = capY
				piece.VX = math.cos(angle) * speed
				piece.VY = math.sin(angle) * speed - 140
			end
			local shape = piece.Shape
			if shape == 1 then
				piece.Frame.Size = UDim2.fromOffset(math.random(10, 14), math.random(16, 22))
			elseif shape == 2 then
				local size = math.random(14, 22)
				piece.Frame.Size = UDim2.fromOffset(size, size)
			else
				piece.Frame.Size = if tier.Cracks
					then UDim2.fromOffset(math.random(26, 40), math.random(10, 16))
					else UDim2.fromOffset(math.random(10, 14), math.random(16, 22))
			end
			piece.Frame.BackgroundColor3 = piece.Color
		end
	end
end

local function armStars(self: Cinematic)
	local count = if self._low then math.floor(starCap * 0.4) else starCap
	for index, star in self._stars do
		star.Frame.BackgroundColor3 = if index % 3 == 0 then white else Color3.fromRGB(80, 245, 240)
		star.Frame.BackgroundTransparency = 0
		if index > count then
			star.Frame.Visible = false
		end
	end
end

local function titleText(payload: Payload, tier: Tiers.Tier): string
	local text
	if tier.Name == "Mini" then
		text = string.upper(payload.Rarity.Name)
	elseif tier.Name == "Mythic" then
		text = "MYTHIC!!"
	elseif tier.Name == "Secret" then
		text = "SECRET!!!"
	else
		text = `{string.upper(payload.Rarity.Name)}!`
	end
	if payload.IsGolden then
		text = `GOLDEN {text}`
	end
	return text
end

local function startEntry(self: Cinematic, entry: Entry)
	local payload = entry.Payload
	local rank = Tiers.RankOf(payload.Rarity)
	local tier = Tiers.For(rank)
	self._active = entry
	self._tier = tier
	self._t = 0
	self._hasImpacted = false
	self._low = self._isLowGraphics()
	hideAll(self)
	local base = payload.Rarity.Color
	if self._modelKey ~= payload.Key.Id or self._model.Model == nil then
		Viewport.Set(self._model, KeyModels.Build(payload.Key.Id))
		self._modelKey = payload.Key.Id
	end
	Viewport.Pose(self._model, staticYaw)
	local text = titleText(payload, tier)
	local title = self._title
	title.Main.Text = text
	title.Red.Text = text
	title.Cyan.Text = text
	title.Main.TextColor3 = Kit.Shade(base, 0.7)
	title.MainGradient.Color = if tier.Rainbow
		then rainbow
		else ColorSequence.new(white, Kit.Shade(base, if tier.Name == "Mini" then 0 else 0.05))
	self._name.Text = payload.Key.Name
	self._glow.BackgroundColor3 = Kit.Shade(base, 0.2)
	armParticles(self, payload)
	armStars(self)
	local player = Players.LocalPlayer
	local character = if player then player.Character else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	self._humanoid = humanoid
	self._baseOffset = if humanoid then humanoid.CameraOffset else Vector3.zero
	self._gui.Enabled = true
	setDucked(self, true)
	if tier.Swell then
		local sounds = self._getControllers().SoundController
		if sounds then
			sounds:PlaySwell(payload.Rarity, tier.ImpactAt, "Roll")
		end
	end
end

setDucked = function(self: Cinematic, isDucked: boolean)
	local music = self._getControllers().MusicController
	if music then
		music:SetDucked(isDucked)
	end
end

local function restoreCamera(self: Cinematic)
	local humanoid = self._humanoid
	if humanoid then
		humanoid.CameraOffset = self._baseOffset
	end
	self._humanoid = nil
end

local function palette(self: Cinematic, t: number): (Color3, Color3)
	local tier = self._tier
	local entry = self._active
	local base = if entry then entry.Payload.Rarity.Color else white
	if tier.Rainbow then
		return Color3.fromHSV((t * 0.35) % 1, 0.75, 1), Color3.fromHSV((t * 0.35 + 0.5) % 1, 0.75, 1)
	elseif tier.Name == "Mythic" then
		return base, Kit.Theme.Pink
	elseif tier.Name == "Legendary" then
		return Kit.Shade(base, 0.1), Kit.Shade(base, 0.6)
	end
	return base, Kit.Shade(base, 0.5)
end

local function renderBackdrop(self: Cinematic, t: number, fade: number)
	local tier = self._tier
	local function soften(alpha: number): number
		return 1 - (1 - alpha) * fade
	end
	local dimIn = outQuad(seg(t, 0, 0.25))
	self._dim.Visible = true
	self._dim.BackgroundTransparency = soften(lerp(1, tier.Dim, dimIn))
	for _, strip in self._vignette do
		strip.Visible = true
		strip.BackgroundTransparency = soften(lerp(1, 0.1, dimIn))
	end
end

local function renderCap(self: Cinematic, t: number, fade: number, charge: number, pulse: number)
	local tier = self._tier
	local ti = tier.ImpactAt
	local post = t - ti
	local sx, sy, scale, yOffset, rotation = 1, 1, 1, 0, 0
	local entry = tier.Entry
	if entry == "Pop" then
		scale = outBack(seg(t, 0, ti + 0.15))
	elseif entry == "Drop" then
		local fall = seg(t, 0.05, ti)
		yOffset = lerp(-560, 0, inQuad(fall))
		if t < ti then
			sx, sy = 0.88, 1.18
		end
	elseif entry == "Rise" then
		local enter = outCubic(seg(t, 0, 0.5))
		yOffset = lerp(340, 0, enter)
		scale = lerp(0.4, 1, enter)
	else
		local enter = outCubic(seg(t, 0.15, 1.3))
		yOffset = lerp(-560, 0, enter)
		scale = lerp(0.25, 1, enter)
		rotation = 720 * (1 - enter)
	end
	local jitterX, jitterY = 0, 0
	if tier.Charge and t < ti and not self._low then
		local amplitude = 2 + 16 * charge * charge
		jitterX = (noise(t * 53) - 0.5) * 2 * amplitude
		jitterY = (noise(t * 53 + 11) - 0.5) * 2 * amplitude
		rotation += (noise(t * 31 + 5) - 0.5) * 8 * charge
	end
	if post >= 0 then
		local wobble = math.exp(-post * 7) * math.cos(post * 24)
		sx *= 1 + tier.Squash * wobble
		sy *= 1 - tier.Squash * wobble
	end
	local collapse = 1 - fade
	yOffset += 330 * inQuad(collapse)
	scale *= 1 - 0.6 * collapse
	local cap = self._model.Frame
	cap.Visible = t >= 0.02 and fade > 0
	cap.Size = UDim2.fromOffset(capSize * sx * scale, capSize * sy * scale)
	cap.Position = center(jitterX, capY + yOffset + jitterY)
	cap.Rotation = rotation
	local handle = self._model
	if self._low then
		Viewport.Pose(handle, staticYaw)
	else
		local spin = staticYaw + t * spinSpeed
		if tier.Charge and t < ti then
			spin += chargeSpin * charge * charge * t
		end
		Viewport.Pose(handle, spin % 360, 0, 0, math.sin(t * 3.2) * bobHeight * handle.Radius * (if post >= 0 then 1 else 0.3))
	end
	local base = if self._active then self._active.Payload.Rarity.Color else white
	if tier.Rainbow and post >= 0 then
		Viewport.Light(handle, Color3.fromHSV((t * 0.6) % 1, 0.45, 1), 0.2)
	else
		Viewport.Light(handle, Kit.Shade(base, 0.7), pulse * 0.6)
	end
end

local function renderGlow(self: Cinematic, t: number, fade: number, charge: number, pulse: number)
	local tier = self._tier
	local post = t - tier.ImpactAt
	local glow = self._glow
	local amount
	if post < 0 then
		amount = if tier.Charge then pulse * 0.6 + charge * 0.3 else 0
	else
		amount = 0.75 + 0.25 * math.sin(t * 6)
	end
	glow.Visible = amount > 0.01
	local size = 330 + 150 * amount
	glow.Size = UDim2.fromOffset(size, size)
	glow.Position = center(0, capY)
	glow.BackgroundTransparency = 1 - (1 - lerp(0.9, 0.5, amount)) * fade
end

local function renderRays(self: Cinematic, t: number, fade: number, charge: number)
	local tier = self._tier
	local post = t - tier.ImpactAt
	local primary, secondary = palette(self, t)
	local bloom = outCubic(seg(post, 0, 0.45))
	local pre = if tier.Charge and post < 0 then 0.18 * charge else 0
	for index, ray in self._rays do
		if index > tier.Rays then
			ray.Holder.Visible = false
		else
			local amount = math.max(pre, bloom)
			local scale = if post < 0 then 0.45 + 0.2 * charge else lerp(0.3, 1, outQuad(bloom))
			local size = ray.Diameter * scale
			ray.Holder.Visible = amount > 0.01
			ray.Holder.Size = UDim2.fromOffset(size, size)
			ray.Holder.Rotation = (if index == 1 then 1 else -1) * t * (if tier.Rainbow then 55 else 28)
			local image = ray.Image
			if image then
				image.ImageColor3 = if index == 1 then primary else secondary
				image.ImageTransparency = 1 - (1 - lerp(1, 0.35, amount)) * fade
			end
		end
	end
end

local function renderRings(self: Cinematic, t: number, fade: number)
	local tier = self._tier
	local primary, secondary = palette(self, t)
	local reach = if tier.Name == "Mini" then 700 else 1500
	for index, ring in self._rings do
		if index > tier.Rings then
			ring.Frame.Visible = false
		else
			local age = t - (tier.ImpactAt + (index - 1) * 0.12)
			local progress = seg(age, 0, 0.75)
			ring.Frame.Visible = age >= 0 and progress < 1
			local size = lerp(80, reach, outCubic(progress))
			ring.Frame.Size = UDim2.fromOffset(size, size)
			ring.Frame.Position = center(0, capY)
			ring.Stroke.Thickness = lerp(18, 2, progress)
			ring.Stroke.Color = if index % 2 == 1 then primary else secondary
			ring.Stroke.Transparency = 1 - (1 - progress ^ 1.5) * fade
		end
	end
end

local function renderCracks(self: Cinematic, t: number, fade: number)
	local tier = self._tier
	local post = t - tier.ImpactAt
	local count = if self._low then crackCount // 2 else crackCount
	for index, crack in self._cracks do
		local frame = crack.Frame
		if not tier.Cracks or post < 0 or index > count then
			frame.Visible = false
		else
			local grow = outCubic(seg(post, 0, 0.18))
			local length = crack.Length * grow
			local radius = 120 + length / 2
			local angle = math.rad(crack.Angle)
			frame.Visible = length > 1
			frame.Size = UDim2.fromOffset(length, lerp(14, 4, seg(post, 0.1, 1)))
			frame.Position = center(math.cos(angle) * radius, capY + math.sin(angle) * radius)
			frame.Rotation = crack.Angle
			frame.BackgroundTransparency = 1 - (1 - seg(post, 0.5, 1.4)) * fade
		end
	end
end

local function renderParticles(self: Cinematic, t: number, fade: number)
	for _, piece in self._particles do
		local frame = piece.Frame
		local age = t - piece.Born
		if not piece.Used or age < 0 or age > piece.Life then
			frame.Visible = false
		else
			local x, y
			if piece.IsRain then
				x = piece.X + piece.VX * age
				y = piece.Y + piece.VY * age
			else
				local travel = (1 - math.exp(-drag * age)) / drag
				x = piece.X + piece.VX * travel
				y = piece.Y + piece.VY * travel + 0.5 * gravity * age * age
			end
			local remaining = piece.Life - age
			local pop = if piece.Shape == 2 then 1 + 0.3 * math.sin(age * 18) else 1
			frame.Visible = true
			frame.Position = center(x, y)
			frame.Rotation = piece.Rot + piece.Spin * age + (if piece.Shape == 2 then 45 else 0)
			frame.BackgroundTransparency = 1
				- (1 - (if remaining < 0.35 then 1 - remaining / 0.35 else 0)) * fade
			frame.Size = frame.Size
			if piece.Shape == 2 then
				local size = math.floor(16 * pop)
				frame.Size = UDim2.fromOffset(size, size)
			end
		end
	end
end

local function renderStars(self: Cinematic, t: number, fade: number)
	local tier = self._tier
	local count = if self._low then math.floor(starCap * 0.4) else starCap
	local appear = seg(t, 0.1, 0.6)
	for index, star in self._stars do
		local frame = star.Frame
		if not tier.Stars or index > count or appear <= 0 then
			frame.Visible = false
		else
			local progress = (t * 0.9 * star.Speed + star.Phase) % 1
			local distance = progress * progress * 950 + 30
			local angle = math.rad(star.Angle)
			local length = 8 + progress * progress * 150
			frame.Visible = fade > 0
			frame.Size = UDim2.fromOffset(length, 3 + progress * 4)
			frame.Position = center(math.cos(angle) * distance, capY + math.sin(angle) * distance)
			frame.Rotation = star.Angle
			frame.BackgroundTransparency = 1 - (1 - (1 - appear * (0.25 + 0.75 * progress))) * fade
		end
	end
end

local function renderEdges(self: Cinematic, t: number, fade: number)
	local tier = self._tier
	local post = t - tier.ImpactAt
	local pop = seg(post, 0, 0.25)
	for _, edge in self._edges do
		local frame = edge.Frame
		if not tier.Border or post < 0 then
			frame.Visible = false
		else
			local thickness = lerp(70, 16, outBack(pop))
			local isVertical = edge.Side == "Top" or edge.Side == "Bottom"
			frame.Visible = true
			frame.Size = if isVertical then UDim2.new(1, 0, 0, thickness) else UDim2.new(0, thickness, 1, 0)
			edge.Gradient.Rotation = (t * 140) % 360
			frame.BackgroundTransparency = 1 - (1 - (0.1 + 0.3 * (0.5 + 0.5 * math.sin(t * 10)))) * fade
		end
	end
end

local function renderFlash(self: Cinematic, t: number, pulse: number, charge: number)
	local tier = self._tier
	local post = t - tier.ImpactAt
	local flash = self._flash
	local transparency = 1
	if post >= 0 then
		transparency = lerp(tier.FlashStart, 1, outQuad(seg(post, 0, 0.3)))
	elseif tier.Charge then
		transparency = 1 - pulse * (0.1 + 0.18 * charge)
	end
	local base = if self._active then self._active.Payload.Rarity.Color else white
	flash.BackgroundColor3 = if tier.Charge then white else Kit.Shade(base, 0.6)
	flash.Visible = transparency < 0.995
	flash.BackgroundTransparency = transparency
end

local function renderTexts(self: Cinematic, t: number, fade: number)
	local tier = self._tier
	local title = self._title
	local tt = t - tier.TitleAt
	local function soften(alpha: number): number
		return 1 - (1 - alpha) * fade
	end
	if tt < 0 then
		title.Main.Visible = false
		title.Red.Visible = false
		title.Cyan.Visible = false
	else
		local alpha = 1 - seg(tt, 0, 0.1)
		local scale = lerp(2.8, tier.TitleScale * 1.15, outBack(seg(tt, 0, 0.3)))
		local rotation = lerp(-8, 0, outBack(seg(tt, 0, 0.35)))
		local offsetX = 0
		local chroma = (14 * (1 - seg(tt, 0, 0.7)) + 5) * (1 + 0.3 * math.sin(t * 30))
		local flicker = 0
		if tier.Glitch and tt > 0.4 then
			local slot = math.floor(t * 20)
			local glitch = noise(slot)
			if glitch > 0.82 then
				offsetX = (noise(slot + 3) - 0.5) * 44
				chroma *= 3
			end
			if glitch > 0.93 then
				flicker = 0.7
			end
		end
		title.Main.Visible = true
		title.Main.Position = center(offsetX, titleY)
		title.Main.TextTransparency = soften(math.max(alpha, flicker))
		title.MainStroke.Transparency = soften(math.max(alpha, flicker))
		title.MainScale.Scale = scale
		title.Main.Rotation = rotation
		title.MainGradient.Rotation = if tier.Rainbow then (t * 90) % 360 else 90
		local ghost = tier.Chroma
		title.Red.Visible = ghost
		title.Cyan.Visible = ghost
		if ghost then
			title.Red.Position = center(offsetX - chroma, titleY)
			title.Cyan.Position = center(offsetX + chroma, titleY)
			title.Red.TextTransparency = soften(math.max(alpha, 0.35))
			title.Cyan.TextTransparency = soften(math.max(alpha, 0.35))
			local copyScale = title.MainScale.Scale
			local redScale = title.Red:FindFirstChildOfClass("UIScale") :: UIScale
			local cyanScale = title.Cyan:FindFirstChildOfClass("UIScale") :: UIScale
			redScale.Scale = copyScale
			cyanScale.Scale = copyScale
			title.Red.Rotation = rotation
			title.Cyan.Rotation = rotation
		end
	end
	local nt = t - tier.NameAt
	local label = self._name
	if nt < 0 then
		label.Visible = false
	else
		local alpha = 1 - seg(nt, 0, 0.1)
		label.Visible = true
		self._nameScale.Scale = lerp(1.8, 1, outBack(seg(nt, 0, 0.25)))
		label.TextTransparency = soften(alpha)
		self._nameStroke.Transparency = soften(alpha)
	end
	local hint = self._hint
	hint.Visible = t >= Tiers.SkipDelay and fade > 0 and tier.Duration > 1
	hint.TextTransparency = 0.35
end

local function renderShake(self: Cinematic, t: number)
	local tier = self._tier
	local world = self._world
	if self._low then
		world.Position = UDim2.fromScale(0, 0)
		return
	end
	local post = t - tier.ImpactAt
	local decay = 0
	if post >= 0 and tier.ShakeSeconds > 0 then
		decay = clamp01(1 - post / tier.ShakeSeconds) ^ 2
	end
	local charge = if tier.Charge and post < 0 then 0.12 * seg(t, 0.5, tier.ImpactAt) else 0
	local amplitude = tier.ShakeUi * (decay + charge)
	world.Position =
		UDim2.fromOffset((noise(t * 61) - 0.5) * 2 * amplitude, (noise(t * 61 + 17) - 0.5) * 2 * amplitude)
	local humanoid = self._humanoid
	if humanoid and tier.ShakeCamera > 0 then
		local studs = tier.ShakeCamera * 0.5 * (decay + charge)
		humanoid.CameraOffset = self._baseOffset
			+ Vector3.new((noise(t * 47) - 0.5) * 2 * studs, (noise(t * 47 + 9) - 0.5) * 2 * studs, 0)
	end
end

local function render(self: Cinematic, t: number)
	local tier = self._tier
	local ti = tier.ImpactAt
	local fade = 1 - seg(t, tier.Duration - collapseSeconds, tier.Duration)
	local enterEnd = if tier.Entry == "Spin" then 1.3 else 0.5
	local charge = if tier.Charge then seg(t, enterEnd, ti) else 0
	local pulse = 0
	if tier.Charge and t > enterEnd and t < ti then
		local u = t - enterEnd
		pulse = math.max(0, math.sin(2 * pi * (2.5 * u + 5 * u * u)))
	end
	renderBackdrop(self, t, fade)
	renderStars(self, t, fade)
	renderRays(self, t, fade, charge)
	renderGlow(self, t, fade, charge, pulse)
	renderRings(self, t, fade)
	renderCracks(self, t, fade)
	renderCap(self, t, fade, charge, pulse)
	renderParticles(self, t, fade)
	renderEdges(self, t, fade)
	renderFlash(self, t, pulse, charge)
	renderTexts(self, t, fade)
	renderShake(self, t)
end

local function finish(self: Cinematic)
	local entry = self._active
	if not entry then
		return
	end
	self._active = nil
	restoreCamera(self)
	hideAll(self)
	self._world.Position = UDim2.fromScale(0, 0)
	self._dim.Visible = false
	for _, strip in self._vignette do
		strip.Visible = false
	end
	self._gui.Enabled = false
	setDucked(self, false)
	local queued = self._queued
	self._queued = nil
	local done = entry.OnDone
	if done then
		done()
	end
	if queued and not self._destroyed and not self._active then
		startEntry(self, queued)
		render(self, 0)
	end
end

function Cinematic.Play(self: Cinematic, payload: Payload, onDone: (() -> ())?): boolean
	if self._destroyed then
		return false
	end
	local entry: Entry = { Payload = payload, OnDone = onDone }
	if not self._active then
		startEntry(self, entry)
		render(self, 0)
		return true
	end
	if not self._queued then
		self._queued = entry
		return true
	end
	return false
end

function Cinematic.CanAccept(self: Cinematic): boolean
	return not self._destroyed and (self._active == nil or self._queued == nil)
end

function Cinematic.Step(self: Cinematic, dt: number)
	local entry = self._active
	if self._destroyed or not entry then
		return
	end
	local tier = self._tier
	self._t += dt
	if not self._hasImpacted and self._t >= tier.ImpactAt then
		self._hasImpacted = true
		local sounds = self._getControllers().SoundController
		if sounds then
			sounds:PlayReveal(entry.Payload.Rarity, "Roll")
		end
	end
	if self._t >= tier.Duration then
		finish(self)
		return
	end
	render(self, self._t)
end

function Cinematic.Skip(self: Cinematic): boolean
	if self._destroyed or not self._active or self._t < Tiers.SkipDelay then
		return false
	end
	finish(self)
	return true
end

function Cinematic.Seek(self: Cinematic, seconds: number)
	if self._destroyed or not self._active then
		return
	end
	self._t = math.clamp(seconds, 0, self._tier.Duration)
	render(self, self._t)
end

function Cinematic.IsPlaying(self: Cinematic): boolean
	return self._active ~= nil
end

function Cinematic.QueuedCount(self: Cinematic): number
	return if self._queued then 1 else 0
end

function Cinematic.Elapsed(self: Cinematic): number
	return self._t
end

function Cinematic.TierName(self: Cinematic): string
	return self._tier.Name
end

function Cinematic.VisibleParticles(self: Cinematic): number
	local count = 0
	for _, piece in self._particles do
		if piece.Frame.Visible then
			count += 1
		end
	end
	return count
end

function Cinematic.Destroy(self: Cinematic)
	if self._destroyed then
		return
	end
	self._destroyed = true
	if self._active then
		setDucked(self, false)
	end
	restoreCamera(self)
	self._active = nil
	self._queued = nil
	Viewport.Clear(self._model)
	self._modelKey = ""
end

return Cinematic
