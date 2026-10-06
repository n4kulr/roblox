--!strict

local Kit = require(script.Parent.Parent.Parent.UIController.Kit)
local Tiers = require(script.Parent.Parent.Tiers)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

type Payload = Types.Payload
type Cinematic = Types.Cinematic
local capY = Config.CapY
local starCap = Config.StarCap
local lowScale = Config.LowScale
local white = Config.White
local pi = math.pi

local Arm = {}

function Arm.HideAll(self: Cinematic)
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

function Arm.Particles(self: Cinematic, payload: Payload)
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

function Arm.Stars(self: Cinematic)
	local count = if self._low then math.floor(starCap * 0.4) else starCap
	for index, star in self._stars do
		star.Frame.BackgroundColor3 = if index % 3 == 0 then white else Color3.fromRGB(80, 245, 240)
		star.Frame.BackgroundTransparency = 0
		if index > count then
			star.Frame.Visible = false
		end
	end
end

function Arm.TitleText(payload: Payload, tier: Tiers.Tier): string
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

return Arm
