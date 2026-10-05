--!strict

local white = Color3.new(1, 1, 1)
local black = Color3.new(0, 0, 0)

local colors = {
	Ink = Color3.fromRGB(22, 16, 46),
	TextInk = Color3.fromRGB(22, 16, 46),
	Panel = Color3.fromRGB(70, 78, 170),
	PanelDeep = Color3.fromRGB(46, 50, 128),
	Well = Color3.fromRGB(30, 33, 86),
	Slate = Color3.fromRGB(46, 52, 122),
	Cell = Color3.fromRGB(44, 49, 112),
	Track = Color3.fromRGB(24, 26, 68),
	Text = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(206, 212, 246),
	Good = Color3.fromRGB(110, 238, 96),
	Bad = Color3.fromRGB(255, 104, 112),
	Gold = Color3.fromRGB(255, 214, 64),
	Green = Color3.fromRGB(52, 208, 84),
	Blue = Color3.fromRGB(44, 140, 255),
	Purple = Color3.fromRGB(146, 70, 236),
	Grey = Color3.fromRGB(128, 134, 160),
	Red = Color3.fromRGB(240, 60, 90),
	Orange = Color3.fromRGB(255, 142, 28),
	Yellow = Color3.fromRGB(255, 194, 20),
	Teal = Color3.fromRGB(0, 190, 188),
	Pink = Color3.fromRGB(255, 88, 168),
	Disabled = Color3.fromRGB(104, 108, 134),
	Cream = Color3.fromRGB(255, 244, 178),
}

local Theme = {
	Colors = table.freeze(colors),
	Space = table.freeze({ Xs = 4, S = 8, M = 12, L = 16, Xl = 24 }),
	Radius = table.freeze({ S = 6, M = 10, L = 14, Panel = 18 }),
	Stroke = table.freeze({ Thin = 2, Normal = 3, Heavy = 4 }),
	Fonts = table.freeze({ Body = Enum.Font.FredokaOne, Title = Enum.Font.LuckiestGuy }),
	LipDepth = 6,
	PressDrop = 4,
}

function Theme.Shade(color: Color3, amount: number): Color3
	if amount >= 0 then
		return color:Lerp(white, amount)
	end
	return color:Lerp(black, -amount)
end

return Theme
