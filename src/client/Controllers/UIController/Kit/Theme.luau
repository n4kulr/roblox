--!strict

local white = Color3.new(1, 1, 1)
local black = Color3.new(0, 0, 0)
local ink = Color3.fromHex("1A1530")
local grey = Color3.fromHex("9AA3B5")
local panel = Color3.fromHex("FFFFFF")
local well = Color3.fromHex("D9E6FB")
local gold = Color3.fromHex("FFC93C")

local colors = {
	White = white,
	Black = black,
	Scrim = black,
	Ink = ink,
	TextInk = ink,
	Panel = panel,
	PanelDeep = Color3.fromHex("E9F1FF"),
	CardTint = Color3.fromHex("F1F6FF"),
	Inset = well,
	InsetEdge = Color3.fromHex("A9BDE6"),
	Track = Color3.fromHex("2A2440"),
	Text = white,
	TextDim = Color3.fromHex("E2E6F8"),
	Subtext = Color3.fromHex("5B5675"),
	Good = Color3.fromHex("76F060"),
	GoodDeep = Color3.fromHex("1FA64A"),
	Gold = gold,
	GoldenBody = Color3.fromHex("FFB820"),
	Amber = Color3.fromHex("FFBE28"),
	Ring = Color3.fromHex("FFF096"),
	Cream = Color3.fromHex("FFF4B2"),
	Green = Color3.fromHex("4BD865"),
	Blue = Color3.fromHex("3FA9FF"),
	Purple = Color3.fromHex("A35BFF"),
	Grey = grey,
	GreyDeep = Color3.fromHex("787C86"),
	Disabled = grey,
	Locked = Color3.fromHex("E3E9F5"),
	Unknown = Color3.fromHex("7A7F8A"),
	Tier3Tint = Color3.fromHex("2E145C"),
	Red = Color3.fromHex("FF4F5E"),
	Orange = Color3.fromHex("FF8A3D"),
	Ember = Color3.fromHex("FF6030"),
	Teal = Color3.fromHex("2CD3C8"),
	TealDeep = Color3.fromHex("00A8A8"),
	Pink = Color3.fromHex("FF5FB8"),
	Silver = Color3.fromHex("BEC6D4"),
	Bronze = Color3.fromHex("CD7F46"),
	PromoTop = Color3.fromHex("6A4BE0"),
	PromoBottom = Color3.fromHex("2E1F7A"),
}

local rainbowColors = {
	Color3.fromRGB(255, 92, 110),
	Color3.fromRGB(255, 190, 70),
	Color3.fromRGB(110, 235, 110),
	Color3.fromRGB(70, 200, 255),
	Color3.fromRGB(170, 110, 255),
}

local function tween(seconds: number, style: Enum.EasingStyle, direction: Enum.EasingDirection): TweenInfo
	return TweenInfo.new(seconds, style, direction)
end

local quad = Enum.EasingStyle.Quad
local back = Enum.EasingStyle.Back
local sine = Enum.EasingStyle.Sine
local out = Enum.EasingDirection.Out
local inward = Enum.EasingDirection.In
local inOut = Enum.EasingDirection.InOut

local Theme = {
	Colors = table.freeze(colors),
	Rainbow = table.freeze(rainbowColors),
	Space = table.freeze({ Xxs = 2, Xs = 4, S = 8, M = 12, L = 16, Xl = 24, Xxl = 32 }),
	Radius = table.freeze({ Xs = 4, S = 8, M = 12, L = 14, Panel = 20, Pill = 999 }),
	Stroke = table.freeze({
		Hairline = 1,
		Thin = 2,
		Normal = 3,
		Heavy = 4,
		Selected = 4.5,
		Outline = 6,
		Frame = 8,
	}),
	Fonts = table.freeze({ Body = Enum.Font.FredokaOne, Title = Enum.Font.FredokaOne }),
	Text = table.freeze({
		Min = 8,
		Micro = 12,
		Tiny = 13,
		Caption = 14,
		Small = 16,
		Note = 17,
		Body = 18,
		Lead = 19,
		Label = 20,
		Strong = 22,
		Title = 24,
		Subhead = 26,
		Heading = 28,
		Banner = 30,
		Big = 32,
		Display = 34,
		Headline = 36,
		Jumbo = 40,
		Giant = 48,
		Hero = 54,
	}),
	Motion = table.freeze({
		Press = tween(0.06, quad, out),
		Fast = tween(0.12, quad, out),
		Base = tween(0.2, quad, out),
		Slow = tween(0.35, quad, out),
		Fade = tween(0.5, quad, out),
		Exit = tween(0.12, quad, inward),
		Leave = tween(0.16, quad, inward),
		Spring = tween(0.16, back, out),
		SpringQuick = tween(0.12, back, out),
		Pop = tween(0.25, back, out),
		PopLarge = tween(0.28, back, out),
		Badge = tween(0.35, back, out),
		Bounce = TweenInfo.new(0.35, quad, out, -1, true),
		Glow = TweenInfo.new(0.45, sine, inOut, -1, true),
		Throb = TweenInfo.new(0.4, sine, inOut, -1, true),
		Beat = TweenInfo.new(0.35, sine, inOut, -1, true),
		Pull = tween(1, back, inward),
		Spin = TweenInfo.new(1, Enum.EasingStyle.Linear, inOut, -1),
	}),
	Transparency = table.freeze({ Scrim = 0.45, Heavy = 0.6, Soft = 0.78, Faint = 0.9 }),
	Layer = table.freeze({ Hud = 1, Prompt = 9, Modal = 10, Toast = 20, Cinematic = 30, Debug = 200 }),
	ZIndex = table.freeze({
		Behind = 0,
		Base = 1,
		Under = 2,
		Fill = 3,
		Mark = 4,
		Badge = 5,
		BadgeText = 6,
		Float = 7,
		Hover = 8,
		Hit = 10,
		Tooltip = 20,
		TooltipText = 21,
		Top = 25,
	}),
	LipDepth = 5,
	PressDrop = 4,
	ScreenMargin = 20,
}

function Theme.Retime(info: TweenInfo, seconds: number, delay: number?): TweenInfo
	return TweenInfo.new(
		seconds,
		info.EasingStyle,
		info.EasingDirection,
		info.RepeatCount,
		info.Reverses,
		delay or info.DelayTime
	)
end

function Theme.Shade(color: Color3, amount: number): Color3
	if amount >= 0 then
		return color:Lerp(white, amount)
	end
	return color:Lerp(black, -amount)
end

function Theme.RainbowSequence(): ColorSequence
	local count = #rainbowColors
	local points = {}
	for index, color in rainbowColors do
		table.insert(points, ColorSequenceKeypoint.new((index - 1) / count, color))
	end
	table.insert(points, ColorSequenceKeypoint.new(1, rainbowColors[1]))
	return ColorSequence.new(points)
end

return Theme
