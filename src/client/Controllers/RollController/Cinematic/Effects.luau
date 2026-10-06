--!strict

local Kit = require(script.Parent.Parent.Parent.UIController.Kit)
local Easing = require(script.Parent.Easing)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)
local Build = require(script.Parent.Build)

type Payload = Types.Payload
type Cinematic = Types.Cinematic
local seg = Easing.Seg
local lerp = Easing.Lerp
local outQuad = Easing.OutQuad
local outCubic = Easing.OutCubic
local outBack = Easing.OutBack
local capY = Config.CapY
local starCap = Config.StarCap
local crackCount = Config.CrackCount
local gravity = Config.Gravity
local drag = Config.Drag
local white = Config.White

local Effects = {}

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

function Effects.Rays(self: Cinematic, t: number, fade: number, charge: number)
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

function Effects.Rings(self: Cinematic, t: number, fade: number)
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
			ring.Frame.Position = Build.Center(0, capY)
			ring.Stroke.Thickness = lerp(18, 2, progress)
			ring.Stroke.Color = if index % 2 == 1 then primary else secondary
			ring.Stroke.Transparency = 1 - (1 - progress ^ 1.5) * fade
		end
	end
end

function Effects.Cracks(self: Cinematic, t: number, fade: number)
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
			frame.Position = Build.Center(math.cos(angle) * radius, capY + math.sin(angle) * radius)
			frame.Rotation = crack.Angle
			frame.BackgroundTransparency = 1 - (1 - seg(post, 0.5, 1.4)) * fade
		end
	end
end

function Effects.Particles(self: Cinematic, t: number, fade: number)
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
			frame.Position = Build.Center(x, y)
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

function Effects.Stars(self: Cinematic, t: number, fade: number)
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
			frame.Position = Build.Center(math.cos(angle) * distance, capY + math.sin(angle) * distance)
			frame.Rotation = star.Angle
			frame.BackgroundTransparency = 1 - (1 - (1 - appear * (0.25 + 0.75 * progress))) * fade
		end
	end
end

function Effects.Edges(self: Cinematic, t: number, fade: number)
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

return Effects
