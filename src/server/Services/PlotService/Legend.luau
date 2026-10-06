--!strict

local Legend = {
	Color = Color3.fromRGB(210, 206, 198),
	Transparency = 0.12,
	PixelsPerStud = 40,
	MaxDistance = 70,
}

local characters = {
	"A",
	"B",
	"C",
	"D",
	"E",
	"F",
	"G",
	"H",
	"I",
	"J",
	"K",
	"L",
	"M",
	"N",
	"O",
	"P",
	"Q",
	"R",
	"S",
	"T",
	"U",
	"V",
	"W",
	"X",
	"Y",
	"Z",
	"0",
	"1",
	"2",
	"3",
	"4",
	"5",
	"6",
	"7",
	"8",
	"9",
	";",
	"'",
	"/",
	"[",
	"]",
}
local modifiers = { "ESC", "TAB", "ALT", "FN" }
local modifierChance = 12
local modulus = 4294967296

function Legend.Hash(seed: number): number
	local value = (seed * 2654435761 + 40503) % modulus
	value = ((value // 65536) * 31 + value) % modulus
	value = (value * 1103515245 + 12345) % modulus
	return value // 16
end

function Legend.SeedOf(name: string, index: number): number
	local value = index
	for position = 1, #name do
		value = (value * 131 + string.byte(name, position)) % modulus
	end
	return value
end

function Legend.Text(seed: number): (string, boolean)
	local value = Legend.Hash(seed)
	if value % modifierChance == 0 then
		return modifiers[(value // modifierChance) % #modifiers + 1], true
	end
	return characters[(value // 7) % #characters + 1], false
end

function Legend.Attach(cap: BasePart, seed: number): SurfaceGui
	local text, isModifier = Legend.Text(seed)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "Legend"
	surface.Face = Enum.NormalId.Top
	surface.Adornee = cap
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = Legend.PixelsPerStud
	surface.LightInfluence = 1
	surface.AlwaysOnTop = false
	surface.MaxDistance = Legend.MaxDistance
	local label = Instance.new("TextLabel")
	label.Name = "Glyph"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = if isModifier then UDim2.fromScale(0.62, 0.3) else UDim2.fromScale(0.5, 0.5)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = Legend.Color
	label.TextTransparency = Legend.Transparency
	label.TextScaled = true
	label.Parent = surface
	surface.Parent = cap
	return surface
end

return Legend
