--!strict

local Easing = {}

function Easing.Clamp01(x: number): number
	return math.clamp(x, 0, 1)
end

function Easing.Seg(t: number, a: number, b: number): number
	if b <= a then
		return if t >= b then 1 else 0
	end
	return Easing.Clamp01((t - a) / (b - a))
end

function Easing.Lerp(a: number, b: number, x: number): number
	return a + (b - a) * x
end

function Easing.OutQuad(x: number): number
	return 1 - (1 - x) * (1 - x)
end

function Easing.OutCubic(x: number): number
	return 1 - (1 - x) ^ 3
end

function Easing.InQuad(x: number): number
	return x * x
end

function Easing.OutBack(x: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

function Easing.Noise(x: number): number
	local s = math.sin(x * 127.1) * 43758.5453
	return s - math.floor(s)
end

return Easing
