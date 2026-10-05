--!strict

local white = Color3.new(1, 1, 1)
local black = Color3.new(0, 0, 0)

local colors = {
	Ink = Color3.fromHex("1A1530"),
	TextInk = Color3.fromHex("1A1530"),
	Panel = Color3.fromHex("FFFFFF"),
	PanelDeep = Color3.fromHex("E9F1FF"),
	Well = Color3.fromHex("D9E6FB"),
	Inset = Color3.fromHex("D9E6FB"),
	InsetEdge = Color3.fromHex("A9BDE6"),
	Slate = Color3.fromHex("C4D4F2"),
	Cell = Color3.fromHex("FFFFFF"),
	Track = Color3.fromHex("2A2440"),
	Text = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(226, 230, 248),
	Subtext = Color3.fromHex("5B5675"),
	Good = Color3.fromRGB(118, 240, 96),
	GoodDeep = Color3.fromHex("1FA64A"),
	Bad = Color3.fromRGB(255, 104, 112),
	Gold = Color3.fromHex("FFC93C"),
	Green = Color3.fromHex("4BD865"),
	Blue = Color3.fromHex("3FA9FF"),
	Purple = Color3.fromHex("A35BFF"),
	Grey = Color3.fromHex("9AA3B5"),
	Red = Color3.fromHex("FF4F5E"),
	Orange = Color3.fromHex("FF8A3D"),
	Yellow = Color3.fromHex("FFC93C"),
	Teal = Color3.fromHex("2CD3C8"),
	Pink = Color3.fromHex("FF5FB8"),
	Disabled = Color3.fromHex("9AA3B5"),
	Cream = Color3.fromRGB(255, 244, 178),
}

local Theme = {
	Colors = table.freeze(colors),
	Space = table.freeze({ Xs = 4, S = 8, M = 12, L = 16, Xl = 24 }),
	Radius = table.freeze({ S = 8, M = 12, L = 14, Panel = 20 }),
	Stroke = table.freeze({ Thin = 2, Normal = 3, Heavy = 4 }),
	Fonts = table.freeze({ Body = Enum.Font.FredokaOne, Title = Enum.Font.FredokaOne }),
	LipDepth = 5,
	PressDrop = 4,
	ScreenMargin = 20,
}

function Theme.Shade(color: Color3, amount: number): Color3
	if amount >= 0 then
		return color:Lerp(white, amount)
	end
	return color:Lerp(black, -amount)
end

return Theme
