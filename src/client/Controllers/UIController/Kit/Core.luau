--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiAssets = require(ReplicatedStorage.Config.UiAssets)
local Glyphs = require(script.Parent.Parent.Glyphs)
local Theme = require(script.Parent.Theme)

local colors = Theme.Colors
local white = Color3.new(1, 1, 1)

export type PanelProps = {
	Parent: Instance,
	Name: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Color: Color3?,
	Transparency: number?,
	LayoutOrder: number?,
	Radius: number?,
	StrokeColor: Color3?,
	StrokeThickness: number?,
	Shards: boolean?,
	Bevel: boolean?,
	Flat: boolean?,
}

export type LabelProps = {
	Parent: Instance,
	Name: string?,
	Text: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	TextSize: number?,
	Color: Color3?,
	Align: Enum.TextXAlignment?,
	VerticalAlign: Enum.TextYAlignment?,
	Wrapped: boolean?,
	Scaled: boolean?,
	Outline: boolean?,
	RichText: boolean?,
	Title: boolean?,
}

export type IconProps = {
	Parent: Instance,
	Name: string?,
	Glyph: string?,
	Color: Color3?,
	Asset: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
}

export type ChipProps = {
	Parent: Instance,
	Name: string?,
	Text: string,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Color: Color3?,
	TextSize: number?,
}

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

export type PlateProps = {
	Parent: Instance,
	Name: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Color: Color3?,
	Transparency: number?,
	Radius: number?,
}

export type PillProps = {
	Parent: Instance,
	Name: string?,
	Glyph: string,
	Text: string,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Color: Color3?,
	TextColor: Color3?,
	TextSize: number?,
	IconColor: Color3?,
}

export type Pill = {
	Instance: Frame,
	Label: TextLabel,
	SetText: (text: string) -> (),
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

local Core = {}

function Core.Corner(parent: Instance, radius: number?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Theme.Radius.M)
	corner.Parent = parent
	return corner
end

function Core.Stroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Color = color or colors.Ink
	stroke.Thickness = thickness or Theme.Stroke.Normal
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function Core.StrokeOf(parent: Instance): UIStroke
	return parent:FindFirstChild("Stroke") :: UIStroke
end

function Core.TextStroke(parent: Instance, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Name = "TextStroke"
	stroke.Color = colors.TextInk
	stroke.Thickness = thickness or 2.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = parent
	return stroke
end

function Core.Paint(frame: GuiObject, color: Color3)
	frame.BackgroundColor3 = white
	local existing = frame:FindFirstChild("Paint")
	local gradient: UIGradient
	if existing and existing:IsA("UIGradient") then
		gradient = existing
	else
		gradient = Instance.new("UIGradient")
		gradient.Name = "Paint"
		gradient.Rotation = 90
		gradient.Parent = frame
	end
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Theme.Shade(color, 0.18)),
		ColorSequenceKeypoint.new(0.55, color),
		ColorSequenceKeypoint.new(1, Theme.Shade(color, -0.22)),
	})
end

function Core.Shards(parent: GuiObject, radius: number, transparency: number?)
	if UiAssets.Pattern == "" then
		return
	end
	local image = Instance.new("ImageLabel")
	image.Name = "Shards"
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.Size = UDim2.fromScale(1, 1)
	image.Image = UiAssets.Pattern
	image.ScaleType = Enum.ScaleType.Tile
	image.TileSize = UDim2.fromOffset(128, 128)
	image.ImageColor3 = white
	image.ImageTransparency = transparency or 0.82
	Core.Corner(image, radius)
	image.Parent = parent
end

local function addGloss(parent: GuiObject, radius: number)
	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.BackgroundColor3 = white
	gloss.BackgroundTransparency = 0.82
	gloss.BorderSizePixel = 0
	gloss.Position = UDim2.fromOffset(6, 4)
	gloss.Size = UDim2.new(1, -12, 0.3, 0)
	gloss.ZIndex = 0
	Core.Corner(gloss, math.max(radius - 3, 3))
	gloss.Parent = parent
end

function Core.Gloss(parent: GuiObject, radius: number)
	addGloss(parent, radius)
end

function Core.Panel(props: PanelProps): Frame
	local radius = props.Radius or Theme.Radius.M
	local frame = Instance.new("Frame")
	frame.Name = props.Name or "Panel"
	frame.BackgroundTransparency = props.Transparency or 0
	frame.BorderSizePixel = 0
	frame.Size = props.Size or UDim2.fromScale(1, 1)
	frame.Position = props.Position or UDim2.new()
	frame.AnchorPoint = props.AnchorPoint or Vector2.zero
	frame.LayoutOrder = props.LayoutOrder or 0
	if props.Flat == true then
		frame.BackgroundColor3 = props.Color or colors.Cell
	else
		Core.Paint(frame, props.Color or colors.Cell)
	end
	Core.Corner(frame, radius)
	Core.Stroke(frame, props.StrokeColor, props.StrokeThickness or Theme.Stroke.Normal)
	if props.Shards == true then
		Core.Shards(frame, radius)
	end
	frame.Parent = props.Parent
	return frame
end

function Core.Plate(props: PlateProps): Frame
	local plate = Instance.new("Frame")
	plate.Name = props.Name or "Plate"
	plate.BackgroundColor3 = props.Color or colors.Ink
	plate.BackgroundTransparency = props.Transparency or 0.55
	plate.BorderSizePixel = 0
	plate.Size = props.Size or UDim2.fromScale(1, 1)
	plate.Position = props.Position or UDim2.new()
	plate.AnchorPoint = props.AnchorPoint or Vector2.zero
	plate.LayoutOrder = props.LayoutOrder or 0
	Core.Corner(plate, props.Radius or Theme.Radius.M)
	local edge = Instance.new("UIStroke")
	edge.Name = "Edge"
	edge.Color = white
	edge.Transparency = 0.86
	edge.Thickness = 2
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = plate
	plate.Parent = props.Parent
	return plate
end

function Core.Label(props: LabelProps): TextLabel
	local textSize = props.TextSize or 20
	local label = Instance.new("TextLabel")
	label.Name = props.Name or "Label"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Size = props.Size or UDim2.new(1, 0, 0, 28)
	label.Position = props.Position or UDim2.new()
	label.AnchorPoint = props.AnchorPoint or Vector2.zero
	label.LayoutOrder = props.LayoutOrder or 0
	label.Font = if props.Title == true then Theme.Fonts.Title else Theme.Fonts.Body
	label.TextColor3 = props.Color or colors.Text
	label.TextXAlignment = props.Align or Enum.TextXAlignment.Left
	label.TextYAlignment = props.VerticalAlign or Enum.TextYAlignment.Center
	label.TextWrapped = props.Wrapped == true
	label.RichText = props.RichText == true
	label.Text = props.Text or ""
	if props.Scaled == true then
		label.TextScaled = true
		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MaxTextSize = textSize
		constraint.MinTextSize = 8
		constraint.Parent = label
	else
		label.TextSize = textSize
		label.TextTruncate = if props.Wrapped == true then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd
	end
	if props.Outline ~= false then
		Core.TextStroke(label, if textSize >= 26 then 3 elseif textSize >= 17 then 2.5 else 2)
	end
	label.Parent = props.Parent
	return label
end

function Core.Icon(props: IconProps): GuiObject
	local asset = props.Asset
	if asset and asset ~= "" then
		local image = Instance.new("ImageLabel")
		image.Name = props.Name or "Icon"
		image.BackgroundTransparency = 1
		image.BorderSizePixel = 0
		image.Image = asset
		image.ScaleType = Enum.ScaleType.Fit
		image.Size = props.Size or UDim2.fromOffset(48, 48)
		image.Position = props.Position or UDim2.new()
		image.AnchorPoint = props.AnchorPoint or Vector2.zero
		image.LayoutOrder = props.LayoutOrder or 0
		image.Parent = props.Parent
		return image
	end
	return Glyphs.Build(props.Glyph or "Star", {
		Parent = props.Parent,
		Name = props.Name or "Icon",
		Size = props.Size or UDim2.fromOffset(48, 48),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		Color = props.Color,
	})
end

function Core.Chip(props: ChipProps): TextLabel
	local chip = Core.Panel({
		Parent = props.Parent,
		Name = props.Name or "Chip",
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		Color = props.Color or colors.Red,
		Radius = Theme.Radius.S,
		StrokeThickness = Theme.Stroke.Thin,
	})
	return Core.Label({
		Parent = chip,
		Name = "Text",
		Text = props.Text,
		Size = UDim2.new(1, -Theme.Space.S, 1, 0),
		Position = UDim2.fromOffset(Theme.Space.Xs, 0),
		TextSize = props.TextSize or 16,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
end

function Core.Badge(parent: Instance, text: string?): Frame
	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.BorderSizePixel = 0
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, 8, 0, -8)
	badge.Size = UDim2.fromOffset(28, 28)
	badge.ZIndex = 5
	Core.Paint(badge, colors.Red)
	Core.Corner(badge, 14)
	Core.Stroke(badge, colors.Ink, 3)
	local label = Core.Label({
		Parent = badge,
		Name = "Text",
		Text = text or "!",
		Size = UDim2.fromScale(1, 1),
		TextSize = 20,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	label.ZIndex = 6
	badge.Parent = parent
	return badge
end

function Core.Keycap(props: KeycapProps): Keycap
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
	Core.Corner(base, 9)
	Core.Stroke(base, colors.Ink, 3)
	base.Parent = holder
	local top = Instance.new("Frame")
	top.Name = "Top"
	top.BorderSizePixel = 0
	top.Position = UDim2.fromScale(0.08, 0)
	top.Size = UDim2.fromScale(0.84, 0.74)
	Core.Corner(top, 7)
	Core.Stroke(top, colors.Ink, 2)
	top.Parent = holder
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = white
	shine.BackgroundTransparency = 0.6
	shine.BorderSizePixel = 0
	shine.Position = UDim2.fromScale(0.1, 0.08)
	shine.Size = UDim2.fromScale(0.5, 0.1)
	Core.Corner(shine, 3)
	shine.Parent = top
	local glyph = Core.Label({
		Parent = top,
		Name = "Glyph",
		Text = props.Glyph or "",
		Size = UDim2.fromScale(1, 1),
		TextSize = 34,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local function paint(color: Color3)
		base.BackgroundColor3 = Theme.Shade(color, -0.32)
		Core.Paint(top, color)
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

function Core.Burst(props: BurstProps): Frame
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
			Core.Corner(glow, props.Diameter)
			glow.Parent = holder
		end
	end
	holder.Parent = props.Parent
	return holder
end

function Core.Bar(props: BarProps): Bar
	local value = math.clamp(props.Value or 0, 0, 1)
	local track = Core.Panel({
		Parent = props.Parent,
		Name = props.Name or "Bar",
		Size = props.Size or UDim2.new(1, 0, 0, 28),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		Color = colors.Track,
		Radius = 14,
		StrokeThickness = Theme.Stroke.Normal,
		Flat = true,
	})
	track.ClipsDescendants = true
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(value, 1)
	Core.Paint(fill, props.Color or colors.Green)
	Core.Corner(fill, 14)
	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.BackgroundColor3 = white
	gloss.BackgroundTransparency = 0.78
	gloss.BorderSizePixel = 0
	gloss.Position = UDim2.new(0, 6, 0, 3)
	gloss.Size = UDim2.new(1, -12, 0.3, 0)
	Core.Corner(gloss, 6)
	gloss.Parent = fill
	fill.Parent = track
	local label = Core.Label({
		Parent = track,
		Name = "Text",
		Text = props.Text or "",
		Size = UDim2.fromScale(1, 1),
		TextSize = props.TextSize or 18,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	label.ZIndex = 3
	return {
		Instance = track,
		Fill = fill,
		Label = label,
		Stroke = Core.StrokeOf(track),
		SetValue = function(alpha: number)
			fill.Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
		end,
		SetText = function(text: string)
			label.Text = text
		end,
		SetColor = function(color: Color3)
			Core.Paint(fill, color)
		end,
	}
end

function Core.Pill(props: PillProps): Pill
	local height = 40
	local pill = Instance.new("Frame")
	pill.Name = props.Name or "Pill"
	pill.BackgroundColor3 = props.Color or colors.Track
	pill.BorderSizePixel = 0
	pill.Size = props.Size or UDim2.fromOffset(150, height)
	pill.Position = props.Position or UDim2.new()
	pill.AnchorPoint = props.AnchorPoint or Vector2.zero
	pill.LayoutOrder = props.LayoutOrder or 0
	Core.Corner(pill, 20)
	Core.Stroke(pill, colors.Ink, Theme.Stroke.Normal)
	local disc = Instance.new("Frame")
	disc.Name = "Disc"
	disc.BackgroundColor3 = colors.Well
	disc.BorderSizePixel = 0
	disc.AnchorPoint = Vector2.new(0, 0.5)
	disc.Position = UDim2.new(0, -6, 0.5, 0)
	disc.Size = UDim2.fromOffset(height + 8, height + 8)
	Core.Corner(disc, (height + 8) / 2)
	Core.Stroke(disc, colors.Ink, Theme.Stroke.Normal)
	disc.Parent = pill
	Core.Icon({
		Parent = disc,
		Name = "Icon",
		Glyph = props.Glyph,
		Color = props.IconColor,
		Size = UDim2.fromScale(0.78, 0.78),
		Position = UDim2.fromScale(0.11, 0.11),
	})
	local label = Core.Label({
		Parent = pill,
		Name = "Value",
		Text = props.Text,
		Position = UDim2.fromOffset(height + 8, 0),
		Size = UDim2.new(1, -(height + 8 + Theme.Space.M), 1, 0),
		TextSize = props.TextSize or 24,
		Color = props.TextColor,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	pill.Parent = props.Parent
	return {
		Instance = pill,
		Label = label,
		SetText = function(text: string)
			label.Text = text
		end,
	}
end

function Core.Section(props: SectionProps): Frame
	local color = props.Color or colors.Gold
	local row = Instance.new("Frame")
	row.Name = props.Name or "Section"
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.Size = props.Size or UDim2.new(1, 0, 0, 36)
	row.LayoutOrder = props.LayoutOrder or 0
	local line = Instance.new("Frame")
	line.Name = "Line"
	line.BackgroundColor3 = white
	line.BorderSizePixel = 0
	line.AnchorPoint = Vector2.new(1, 0.5)
	line.Position = UDim2.fromScale(1, 0.5)
	line.Size = UDim2.new(0.6, 0, 0, 4)
	Core.Corner(line, 2)
	local fade = Instance.new("UIGradient")
	fade.Color = ColorSequence.new(color)
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.3),
		NumberSequenceKeypoint.new(1, 0.3),
	})
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
	if props.Glyph then
		Core.Icon({
			Parent = left,
			Name = "Icon",
			Glyph = props.Glyph,
			Size = UDim2.fromOffset(30, 30),
			LayoutOrder = 1,
		})
	end
	local label = Core.Label({
		Parent = left,
		Name = "Text",
		Text = props.Text,
		Size = UDim2.fromOffset(0, 32),
		TextSize = 26,
		Color = color,
		LayoutOrder = 2,
		Title = true,
	})
	label.AutomaticSize = Enum.AutomaticSize.X
	label.TextTruncate = Enum.TextTruncate.None
	left.Parent = row
	row.Parent = props.Parent
	return row
end

return Core
