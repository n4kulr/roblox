--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Keys = require(ReplicatedStorage.Config.Keys)
local Gui = require(script.Parent.Gui)

export type LetterProps = {
	Name: string?,
	Text: string,
	Fill: number?,
	Color: Color3?,
	Transparency: number?,
	StrokeColor: Color3?,
	StrokeTransparency: number?,
	Centered: boolean?,
}

local KeyLegend = {
	PixelsPerStud = 40,
	Fill = 0.62,
	TextColor = Color3.new(1, 1, 1),
	StrokeColor = Color3.fromRGB(20, 18, 28),
	StrokeTransparency = 0.2,
	RimThickness = 3,
	RimLighten = 0.45,
	RimTransparency = 0.1,
}

local white = Color3.new(1, 1, 1)

function KeyLegend.LetterOf(key: Keys.Key): string
	return string.upper(string.sub(key.Name, 1, 1))
end

function KeyLegend.RimColor(key: Keys.Key): Color3
	return Keys.GetRarity(key).Color:Lerp(white, KeyLegend.RimLighten)
end

function KeyLegend.Rim(surface: SurfaceGui): (Frame, UIStroke)
	local rim = Instance.new("Frame")
	rim.Name = "Rim"
	rim.BackgroundTransparency = 1
	rim.Size = UDim2.fromScale(1, 1)
	local stroke = Gui.Stroke(rim, KeyLegend.RimThickness)
	stroke.Name = "Stroke"
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	rim.Parent = surface
	return rim, stroke
end

function KeyLegend.Letter(surface: SurfaceGui, props: LetterProps): TextLabel
	local fill = props.Fill or KeyLegend.Fill
	return Gui.Label(surface, {
		Name = props.Name or "Letter",
		Text = props.Text,
		Centered = props.Centered ~= false,
		Size = UDim2.fromScale(fill, fill),
		Color = props.Color or KeyLegend.TextColor,
		Transparency = props.Transparency,
		TextStrokeColor = props.StrokeColor or KeyLegend.StrokeColor,
		TextStrokeTransparency = props.StrokeTransparency or KeyLegend.StrokeTransparency,
	})
end

function KeyLegend.Mount(cap: BasePart, key: Keys.Key, pixelsPerStud: number?): SurfaceGui
	local surface = Gui.Surface(nil, {
		Name = "Top",
		Face = Enum.NormalId.Top,
		Adornee = cap,
		PixelsPerStud = pixelsPerStud or KeyLegend.PixelsPerStud,
		LightInfluence = 0,
		AlwaysOnTop = false,
	})
	local _, stroke = KeyLegend.Rim(surface)
	stroke.Color = KeyLegend.RimColor(key)
	stroke.Transparency = KeyLegend.RimTransparency
	KeyLegend.Letter(surface, { Text = KeyLegend.LetterOf(key) })
	surface.Parent = cap
	return surface
end

return table.freeze(KeyLegend)
