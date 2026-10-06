--!strict

local Legend = {
	Transparency = 0.1,
	Darken = 0.5,
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
}
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

function Legend.Text(seed: number): string
	return characters[(Legend.Hash(seed) // 7) % #characters + 1]
end

function Legend.ColorFor(color: Color3): Color3
	return color:Lerp(Color3.new(0, 0, 0), Legend.Darken)
end

function Legend.Attach(cap: BasePart, seed: number, color: Color3): SurfaceGui
	local text = Legend.Text(seed)
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
	label.Size = UDim2.fromScale(0.5, 0.5)
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = color
	label.TextTransparency = Legend.Transparency
	label.TextScaled = true
	label.Parent = surface
	surface.Parent = cap
	return surface
end

return Legend
