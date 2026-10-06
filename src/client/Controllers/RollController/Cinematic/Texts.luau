--!strict

local Tiers = require(script.Parent.Parent.Tiers)
local Easing = require(script.Parent.Easing)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)
local Build = require(script.Parent.Build)

type Cinematic = Types.Cinematic
local seg = Easing.Seg
local lerp = Easing.Lerp
local outBack = Easing.OutBack
local noise = Easing.Noise
local titleY = Config.TitleY

local Texts = {}

function Texts.Render(self: Cinematic, t: number, fade: number)
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
		title.Main.Position = Build.Center(offsetX, titleY)
		title.Main.TextTransparency = soften(math.max(alpha, flicker))
		title.MainStroke.Transparency = soften(math.max(alpha, flicker))
		title.MainScale.Scale = scale
		title.Main.Rotation = rotation
		title.MainGradient.Rotation = if tier.Rainbow then (t * 90) % 360 else 90
		local ghost = tier.Chroma
		title.Red.Visible = ghost
		title.Cyan.Visible = ghost
		if ghost then
			title.Red.Position = Build.Center(offsetX - chroma, titleY)
			title.Cyan.Position = Build.Center(offsetX + chroma, titleY)
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

return Texts
