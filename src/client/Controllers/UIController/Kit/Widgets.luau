--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiAssets = require(ReplicatedStorage.Config.UiAssets)
local Primitives = require(script.Parent.Primitives)
local Surfaces = require(script.Parent.Surfaces)
local Labels = require(script.Parent.Labels)
local Icons = require(script.Parent.Icons)
local Theme = require(script.Parent.Theme)

local colors = Theme.Colors
local white = Theme.Colors.White

export type KeycapProps = {
	Parent: Instance,
	Name: string?,
	Color: Color3,
	Glyph: string?,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
}

export type Keycap = {
	Instance: Frame,
	SetColor: (color: Color3) -> (),
	SetGlyph: (text: string, color: Color3?) -> (),
}

export type BurstProps = {
	Parent: Instance,
	Diameter: number,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
}

export type BarProps = {
	Parent: Instance,
	Name: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Color: Color3?,
	Value: number?,
	Text: string?,
	TextSize: number?,
}

export type Bar = {
	Instance: Frame,
	Fill: Frame,
	Label: TextLabel,
	Stroke: UIStroke,
	SetValue: (alpha: number) -> (),
	SetText: (text: string) -> (),
	SetColor: (color: Color3) -> (),
}

export type PillProps = {
	Parent: Instance,
	Name: string,
	Glyph: string,
	Text: string,
	Caption: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Color: Color3?,
	DiscColor: Color3?,
	TextColor: Color3?,
	TextSize: number?,
}

export type Pill = {
	Instance: Frame,
	Label: TextLabel,
	Caption: TextLabel?,
	SetText: (text: string) -> (),
	SetCaption: (text: string) -> (),
}

export type SectionProps = {
	Parent: Instance,
	Name: string?,
	Text: string,
	Glyph: string?,
	Color: Color3?,
	LayoutOrder: number?,
	Size: UDim2?,
}

local Widgets = {}

function Widgets.Keycap(props: KeycapProps): Keycap
	local holder = Instance.new("Frame")
	holder.Name = props.Name or "Keycap"
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Size = props.Size
	holder.Position = props.Position or UDim2.new()
	holder.AnchorPoint = props.AnchorPoint or Vector2.zero
	local base = Instance.new("Frame")
	base.Name = "Base"
	base.BorderSizePixel = 0
	base.Position = UDim2.fromScale(0, 0.14)
	base.Size = UDim2.fromScale(1, 0.86)
	Primitives.Corner(base, 9)
	Primitives.Stroke(base, colors.Ink, Theme.Stroke.Normal)
	base.Parent = holder
	local top = Instance.new("Frame")
	top.Name = "Top"
	top.BorderSizePixel = 0
	top.Position = UDim2.fromScale(0.08, 0)
	top.Size = UDim2.fromScale(0.84, 0.74)
	Primitives.Corner(top, 7)
	Primitives.Stroke(top, colors.Ink, Theme.Stroke.Thin)
	top.Parent = holder
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = white
	shine.BackgroundTransparency = Theme.Transparency.Heavy
	shine.BorderSizePixel = 0
	shine.Position = UDim2.fromScale(0.1, 0.08)
	shine.Size = UDim2.fromScale(0.5, 0.1)
	Primitives.Corner(shine, 3)
	shine.Parent = top
	local glyph = Labels.Label({
		Parent = top,
		Name = "Glyph",
		Text = props.Glyph or "",
		Size = UDim2.fromScale(1, 1),
		TextSize = Theme.Text.Display,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local function paint(color: Color3)
		base.BackgroundColor3 = Theme.Shade(color, -0.32)
		Primitives.Paint(top, color)
	end
	paint(props.Color)
	holder.Parent = props.Parent
	return {
		Instance = holder,
		SetColor = paint,
		SetGlyph = function(text: string, color: Color3?)
			glyph.Text = text
			glyph.TextColor3 = color or colors.Text
		end,
	}
end

function Widgets.Burst(props: BurstProps): Frame
	local holder = Instance.new("Frame")
	holder.Name = "Burst"
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Size = UDim2.fromOffset(props.Diameter, props.Diameter)
	holder.Position = props.Position or UDim2.fromScale(0.5, 0.5)
	holder.AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5)
	local tint = props.Color or white
	if UiAssets.Burst ~= "" then
		local image = Instance.new("ImageLabel")
		image.Name = "Image"
		image.BackgroundTransparency = 1
		image.BorderSizePixel = 0
		image.Size = UDim2.fromScale(1, 1)
		image.Image = UiAssets.Burst
		image.ImageColor3 = tint
		image.ImageTransparency = 0.5
		image.Parent = holder
	else
		for index, fraction in { 1, 0.66, 0.36 } do
			local glow = Instance.new("Frame")
			glow.Name = `Glow{index}`
			glow.BackgroundColor3 = tint
			glow.BackgroundTransparency = 0.9 - index * 0.02
			glow.BorderSizePixel = 0
			glow.AnchorPoint = Vector2.new(0.5, 0.5)
			glow.Position = UDim2.fromScale(0.5, 0.5)
			glow.Size = UDim2.fromScale(fraction, fraction)
			Primitives.Corner(glow, props.Diameter)
			glow.Parent = holder
		end
	end
	holder.Parent = props.Parent
	return holder
end

function Widgets.Bar(props: BarProps): Bar
	local value = math.clamp(props.Value or 0, 0, 1)
	local track = Surfaces.Panel({
		Parent = props.Parent,
		Name = props.Name or "Bar",
		Size = props.Size or UDim2.new(1, 0, 0, 26),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		Color = colors.Track,
		StrokeThickness = Theme.Stroke.Thin,
		Flat = true,
		Pill = true,
	})
	track.ClipsDescendants = true
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(value, 1)
	Primitives.Paint(fill, props.Color or colors.Green)
	Primitives.Round(fill)
	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.BackgroundColor3 = white
	gloss.BackgroundTransparency = Theme.Transparency.Soft
	gloss.BorderSizePixel = 0
	gloss.Position = UDim2.new(0, 6, 0, 3)
	gloss.Size = UDim2.new(1, -12, 0.35, 0)
	Primitives.Round(gloss)
	gloss.Parent = fill
	fill.Parent = track
	local label = Labels.Label({
		Parent = track,
		Name = "Text",
		Text = props.Text or "",
		Size = UDim2.fromScale(1, 1),
		TextSize = props.TextSize or 16,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	label.ZIndex = Theme.ZIndex.Fill
	return {
		Instance = track,
		Fill = fill,
		Label = label,
		Stroke = Primitives.StrokeOf(track),
		SetValue = function(alpha: number)
			fill.Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
		end,
		SetText = function(text: string)
			label.Text = text
		end,
		SetColor = function(color: Color3)
			Primitives.Paint(fill, color)
		end,
	}
end

function Widgets.Pill(props: PillProps): Pill
	local height = if props.Caption then 46 else 40
	local disc = height + 10
	local pill = Instance.new("Frame")
	pill.Name = props.Name or "Pill"
	pill.BackgroundColor3 = props.Color or colors.Track
	pill.BorderSizePixel = 0
	pill.Size = props.Size or UDim2.fromOffset(150, height)
	pill.Position = props.Position or UDim2.new()
	pill.AnchorPoint = props.AnchorPoint or Vector2.zero
	pill.LayoutOrder = props.LayoutOrder or 0
	Primitives.Round(pill)
	Primitives.Stroke(pill, colors.Ink, Theme.Stroke.Normal)
	local coin = Instance.new("Frame")
	coin.Name = "Disc"
	coin.BorderSizePixel = 0
	coin.AnchorPoint = Vector2.new(0, 0.5)
	coin.Position = UDim2.new(0, -10, 0.5, 0)
	coin.Size = UDim2.fromOffset(disc, disc)
	Primitives.Paint(coin, props.DiscColor or Theme.Shade(colors.Track, 0.12))
	Primitives.Round(coin)
	Primitives.Stroke(coin, colors.Ink, Theme.Stroke.Normal)
	Primitives.Gloss(coin, disc / 2)
	coin.Parent = pill
	Icons.Icon({
		Parent = coin,
		Name = "Icon",
		Glyph = props.Glyph,
		Size = UDim2.fromScale(0.74, 0.74),
		Position = UDim2.fromScale(0.13, 0.13),
	})
	local textLeft = disc - 2
	local caption: TextLabel? = nil
	if props.Caption then
		caption = Labels.Label({
			Parent = pill,
			Name = "Caption",
			Text = props.Caption,
			Position = UDim2.new(0, textLeft, 0, 3),
			Size = UDim2.new(1, -(textLeft + Theme.Space.M), 0.36, 0),
			TextSize = Theme.Text.Tiny,
			Color = colors.TextDim,
			Align = Enum.TextXAlignment.Center,
			Scaled = true,
		})
	end
	local label = Labels.Label({
		Parent = pill,
		Name = "Value",
		Text = props.Text,
		Position = if props.Caption then UDim2.new(0, textLeft, 0.36, 0) else UDim2.fromOffset(textLeft, 0),
		Size = if props.Caption
			then UDim2.new(1, -(textLeft + Theme.Space.M), 0.58, 0)
			else UDim2.new(1, -(textLeft + Theme.Space.M), 1, 0),
		TextSize = props.TextSize or 24,
		Color = props.TextColor,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	pill.Parent = props.Parent
	return {
		Instance = pill,
		Label = label,
		Caption = caption,
		SetText = function(text: string)
			label.Text = text
		end,
		SetCaption = function(text: string)
			if caption then
				caption.Text = text
			end
		end,
	}
end

function Widgets.Section(props: SectionProps): Frame
	local color = props.Color or colors.Gold
	local row = Instance.new("Frame")
	row.Name = props.Name or "Section"
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.Size = props.Size or UDim2.new(1, 0, 0, 40)
	row.LayoutOrder = props.LayoutOrder or 0
	local line = Instance.new("Frame")
	line.Name = "Line"
	line.BackgroundColor3 = white
	line.BorderSizePixel = 0
	line.AnchorPoint = Vector2.new(1, 0.5)
	line.Position = UDim2.fromScale(1, 0.5)
	line.Size = UDim2.new(0.6, 0, 0, 6)
	Primitives.Round(line)
	Primitives.Stroke(line, colors.Ink, Theme.Stroke.Thin)
	local fade = Instance.new("UIGradient")
	fade.Color = ColorSequence.new(Theme.Shade(color, 0.15), color)
	fade.Parent = line
	line.Parent = row
	local left = Instance.new("Frame")
	left.Name = "Left"
	left.BackgroundTransparency = 1
	left.BorderSizePixel = 0
	left.AutomaticSize = Enum.AutomaticSize.X
	left.Size = UDim2.fromScale(0, 1)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, Theme.Space.S)
	list.Parent = left
	local padding = Instance.new("UIPadding")
	padding.PaddingRight = UDim.new(0, Theme.Space.M)
	padding.PaddingLeft = UDim.new(0, Theme.Space.Xs)
	padding.Parent = left
	if props.Glyph then
		Icons.Icon({
			Parent = left,
			Name = "Icon",
			Glyph = props.Glyph,
			Size = UDim2.fromOffset(32, 32),
			LayoutOrder = 1,
		})
	end
	local label = Labels.Label({
		Parent = left,
		Name = "Text",
		Text = props.Text,
		Size = UDim2.fromOffset(0, 34),
		TextSize = Theme.Text.Subhead,
		LayoutOrder = 2,
		Title = true,
	})
	label.AutomaticSize = Enum.AutomaticSize.X
	label.TextTruncate = Enum.TextTruncate.None
	left.Parent = row
	row.Parent = props.Parent
	return row
end

return Widgets
