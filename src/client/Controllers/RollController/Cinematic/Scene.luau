--!strict

local Kit = require(script.Parent.Parent.Parent.UIController.Kit)
local Viewport = require(script.Parent.Parent.Parent.UIController.Viewport)
local CameraShake = require(script.Parent.Parent.CameraShake)
local Easing = require(script.Parent.Easing)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)
local Build = require(script.Parent.Build)

type Payload = Types.Payload
type Entry = Types.Entry
type Cinematic = Types.Cinematic
local clamp01 = Easing.Clamp01
local seg = Easing.Seg
local lerp = Easing.Lerp
local outQuad = Easing.OutQuad
local outCubic = Easing.OutCubic
local inQuad = Easing.InQuad
local outBack = Easing.OutBack
local noise = Easing.Noise
local capSize = Config.CapSize
local staticYaw = Config.StaticYaw
local spinSpeed = Config.SpinSpeed
local chargeSpin = Config.ChargeSpin
local bobHeight = Config.BobHeight
local capY = Config.CapY
local white = Config.White

local Scene = {}

function Scene.Backdrop(self: Cinematic, t: number, fade: number)
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

function Scene.Cap(self: Cinematic, t: number, fade: number, charge: number, pulse: number)
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
	cap.Position = Build.Center(jitterX, capY + yOffset + jitterY)
	cap.Rotation = rotation
	local handle = self._model
	if self._low then
		Viewport.Pose(handle, staticYaw)
	else
		Viewport.Glint(handle, if post >= 0 then post + 0.5 else 0)
		local spin = staticYaw + t * spinSpeed
		if tier.Charge and t < ti then
			spin += chargeSpin * charge * charge * t
		end
		Viewport.Pose(
			handle,
			spin % 360,
			0,
			0,
			math.sin(t * 3.2) * bobHeight * handle.Radius * (if post >= 0 then 1 else 0.3)
		)
	end
	local base = if self._active then self._active.Payload.Rarity.Color else white
	if tier.Rainbow and post >= 0 then
		Viewport.Light(handle, Color3.fromHSV((t * 0.6) % 1, 0.45, 1), 0.2)
	else
		Viewport.Light(handle, Kit.Shade(base, 0.7), pulse * 0.6)
	end
end

function Scene.Glow(self: Cinematic, t: number, fade: number, charge: number, pulse: number)
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
	glow.Position = Build.Center(0, capY)
	glow.BackgroundTransparency = 1 - (1 - lerp(0.9, 0.5, amount)) * fade
end

function Scene.Flash(self: Cinematic, t: number, pulse: number, charge: number)
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

function Scene.Shake(self: Cinematic, t: number)
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
		CameraShake.Set(
			humanoid,
			self,
			Vector3.new((noise(t * 47) - 0.5) * 2 * studs, (noise(t * 47 + 9) - 0.5) * 2 * studs, 0)
		)
	end
end

return Scene
