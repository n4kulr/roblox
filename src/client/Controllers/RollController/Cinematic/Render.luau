--!strict

local Config = require(script.Parent.Config)
local Easing = require(script.Parent.Easing)
local Effects = require(script.Parent.Effects)
local Scene = require(script.Parent.Scene)
local Texts = require(script.Parent.Texts)
local Types = require(script.Parent.Types)

type Cinematic = Types.Cinematic
local seg = Easing.Seg
local collapseSeconds = Config.CollapseSeconds
local pi = math.pi

local Render = {}

function Render.Frame(self: Cinematic, t: number)
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
	Scene.Backdrop(self, t, fade)
	Effects.Stars(self, t, fade)
	Effects.Rays(self, t, fade, charge)
	Scene.Glow(self, t, fade, charge, pulse)
	Effects.Rings(self, t, fade)
	Effects.Cracks(self, t, fade)
	Scene.Cap(self, t, fade, charge, pulse)
	Effects.Particles(self, t, fade)
	Effects.Edges(self, t, fade)
	Scene.Flash(self, t, pulse, charge)
	Texts.Render(self, t, fade)
	Scene.Shake(self, t)
end

return Render
