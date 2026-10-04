--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local UiAssets = require(ReplicatedStorage.Config.UiAssets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Glyphs = require(script.Parent.Glyphs)

type TroveInstance = typeof(Trove.new())
type SoundPlayer = (name: string) -> ()
type ShardLayer = { Rotation: number, Bands: { { number } } }

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
}

export type IconProps = {
	Parent: Instance,
	Name: string?,
	Emoji: string?,
	Glyph: string?,
	Color: Color3?,
	Asset: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
}

export type ButtonProps = {
	Parent: Instance,
	Name: string?,
	Text: string?,
	Icon: string?,
	Glyph: string?,
	IconAsset: string?,
	IconLeft: boolean?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Color: Color3?,
	TextColor: Color3?,
	TextSize: number?,
	Radius: number?,
	Immediate: boolean?,
	Callback: (() -> ())?,
	Sound: SoundPlayer?,
}

export type Button = {
	Instance: TextButton,
	Face: Frame,
	SetDisabled: (disabled: boolean) -> (),
	SetText: (text: string) -> (),
	SetColor: (color: Color3) -> (),
	SetGlow: (isOn: boolean) -> (),
	SetSelected: (isOn: boolean) -> (),
}

export type ChipProps = {
	Parent: Instance,
	Name: string?,
	Text: string,
	Size: UDim2,
	Position: UDim2?,
	AnchorPoint: Vector2?,
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

export type ScrollProps = {
	Parent: Instance,
	Name: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Padding: number?,
}

export type GridScrollProps = {
	Parent: Instance,
	Name: string?,
	Size: UDim2?,
	Position: UDim2?,
	CellSize: UDim2,
	CellPadding: UDim2?,
}

export type SliderProps = {
	Parent: Instance,
	Name: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Value: number,
	Color: Color3?,
	OnChanged: ((value: number) -> ())?,
	OnReleased: ((value: number) -> ())?,
}

export type Slider = {
	Instance: Frame,
	SetValue: (value: number) -> (),
}

export type ToggleProps = {
	Parent: Instance,
	Name: string?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Value: boolean,
	OnChanged: ((value: boolean) -> ())?,
	Sound: SoundPlayer?,
}

export type Toggle = {
	Instance: TextButton,
	SetValue: (value: boolean) -> (),
}

export type ModalProps = {
	Parent: Instance,
	Name: string,
	Title: string,
	Icon: string?,
	Glyph: string?,
	IconAsset: string?,
	MaxSize: Vector2,
	HeaderColor: Color3?,
	OnClose: () -> (),
	Sound: SoundPlayer?,
}

export type Modal = {
	Gui: ScreenGui,
	Root: Frame,
	Panel: Frame,
	Body: Frame,
	HeaderRight: Frame,
	Show: () -> (),
	Hide: () -> (),
}

local theme = {
	Ink = Color3.fromRGB(20, 20, 25),
	TextInk = Color3.fromRGB(15, 15, 20),
	Slate = Color3.fromRGB(45, 52, 64),
	Cell = Color3.fromRGB(36, 42, 52),
	Track = Color3.fromRGB(30, 33, 42),
	Text = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(214, 218, 230),
	Good = Color3.fromRGB(96, 230, 84),
	Bad = Color3.fromRGB(255, 96, 96),
	Gold = Color3.fromRGB(255, 210, 64),
	Green = Color3.fromRGB(60, 203, 60),
	Blue = Color3.fromRGB(30, 144, 255),
	Purple = Color3.fromRGB(142, 45, 226),
	Grey = Color3.fromRGB(122, 127, 138),
	Red = Color3.fromRGB(232, 38, 78),
	Orange = Color3.fromRGB(255, 140, 20),
	Yellow = Color3.fromRGB(255, 179, 0),
	Disabled = Color3.fromRGB(98, 102, 114),
}

local Kit = {
	TabBarTop = 8,
	TabBarHeight = 56,
	ClicksGap = 8,
	ClicksHeight = 40,
	ToastGap = 12,
	Theme = table.freeze(theme),
	Font = Enum.Font.FredokaOne,
	HeaderHeight = 64,
	ButtonHeight = 52,
	TouchSize = 48,
	CardRadius = 8,
}

local pressInfo = TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local springInfo = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local popInfo = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local closeInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local white = Color3.new(1, 1, 1)
local black = Color3.new(0, 0, 0)
local windowTop = 70
local windowBottom = 8
local cornerRadius = 5

local shardLayers: { ShardLayer } = {
	{
		Rotation = -35,
		Bands = {
			{ 0.08, 0.24, 0.8 },
			{ 0.3, 0.36, 0.88 },
			{ 0.5, 0.74, 0.84 },
			{ 0.8, 0.86, 0.9 },
		},
	},
	{
		Rotation = 40,
		Bands = {
			{ 0.2, 0.32, 0.92 },
			{ 0.62, 0.9, 0.93 },
		},
	},
}

local function bandSequence(bands: { { number } }): NumberSequence
	local points = { NumberSequenceKeypoint.new(0, 1) }
	for _, band in bands do
		table.insert(points, NumberSequenceKeypoint.new(band[1], 1))
		table.insert(points, NumberSequenceKeypoint.new(band[1] + 0.002, band[3]))
		table.insert(points, NumberSequenceKeypoint.new(band[2], band[3]))
		table.insert(points, NumberSequenceKeypoint.new(band[2] + 0.002, 1))
	end
	table.insert(points, NumberSequenceKeypoint.new(1, 1))
	return NumberSequence.new(points)
end

function Kit.Tween(target: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local created = TweenService:Create(target, info, goal)
	created:Play()
	return created
end

function Kit.PopInfo(): TweenInfo
	return popInfo
end

function Kit.Shade(color: Color3, amount: number): Color3
	if amount >= 0 then
		return color:Lerp(white, amount)
	end
	return color:Lerp(black, -amount)
end

function Kit.UiSound(controllers: { [string]: any }): SoundPlayer
	return function(name: string)
		local sounds = controllers.SoundController
		if sounds then
			sounds:PlayUi(name)
		end
	end
end

function Kit.Corner(parent: Instance, radius: number?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or cornerRadius)
	corner.Parent = parent
	return corner
end

function Kit.Stroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Color = color or theme.Ink
	stroke.Thickness = thickness or 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function Kit.StrokeOf(parent: Instance): UIStroke
	return parent:FindFirstChild("Stroke") :: UIStroke
end

function Kit.TextStroke(parent: Instance, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Name = "TextStroke"
	stroke.Color = theme.TextInk
	stroke.Thickness = thickness or 2.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = parent
	return stroke
end

function Kit.Paint(frame: GuiObject, color: Color3)
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
	local skirt = Kit.Shade(color, -0.16)
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(0.8, color),
		ColorSequenceKeypoint.new(0.801, skirt),
		ColorSequenceKeypoint.new(1, skirt),
	})
end

function Kit.Shards(parent: GuiObject, radius: number)
	if UiAssets.Pattern ~= "" then
		local image = Instance.new("ImageLabel")
		image.Name = "Shards"
		image.BackgroundTransparency = 1
		image.BorderSizePixel = 0
		image.Size = UDim2.fromScale(1, 1)
		image.Image = UiAssets.Pattern
		image.ScaleType = Enum.ScaleType.Tile
		image.TileSize = UDim2.fromOffset(128, 128)
		image.ImageColor3 = white
		image.ImageTransparency = 0.75
		Kit.Corner(image, radius)
		image.Parent = parent
		return
	end
	for index, layer in shardLayers do
		local band = Instance.new("Frame")
		band.Name = `Shards{index}`
		band.BackgroundColor3 = white
		band.BorderSizePixel = 0
		band.Size = UDim2.fromScale(1, 1)
		Kit.Corner(band, radius)
		local gradient = Instance.new("UIGradient")
		gradient.Rotation = layer.Rotation
		gradient.Transparency = bandSequence(layer.Bands)
		gradient.Parent = band
		band.Parent = parent
	end
end

local function addBevel(parent: GuiObject, radius: number)
	local inner = Instance.new("Frame")
	inner.Name = "Bevel"
	inner.BackgroundTransparency = 1
	inner.BorderSizePixel = 0
	inner.Position = UDim2.fromOffset(2, 2)
	inner.Size = UDim2.new(1, -4, 1, -4)
	Kit.Corner(inner, math.max(radius - 1, 0))
	local edge = Instance.new("UIStroke")
	edge.Name = "Edge"
	edge.Color = white
	edge.Transparency = 0.5
	edge.Thickness = 2
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = inner
	inner.Parent = parent
end

local function viewportScale(size: Vector2): number
	local shortest = math.min(size.X, size.Y)
	if shortest <= 0 then
		return 1
	end
	return math.clamp(shortest / 850, 0.75, 1.2)
end

function Kit.ScreenGui(
	name: string,
	displayOrder: number,
	parent: Instance,
	trove: TroveInstance
): (ScreenGui, Frame)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = displayOrder
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Name = "ViewportScale"
	scale.Parent = root
	local function update()
		local value = viewportScale(gui.AbsoluteSize)
		scale.Scale = value
		root.Size = UDim2.fromScale(1 / value, 1 / value)
	end
	update()
	trove:Connect(gui:GetPropertyChangedSignal("AbsoluteSize"), update)
	gui.Parent = parent
	update()
	trove:Add(gui)
	return gui, root
end

function Kit.Panel(props: PanelProps): Frame
	local radius = props.Radius or cornerRadius
	local frame = Instance.new("Frame")
	frame.Name = props.Name or "Panel"
	frame.BackgroundTransparency = props.Transparency or 0
	frame.BorderSizePixel = 0
	frame.Size = props.Size or UDim2.fromScale(1, 1)
	frame.Position = props.Position or UDim2.new()
	frame.AnchorPoint = props.AnchorPoint or Vector2.zero
	frame.LayoutOrder = props.LayoutOrder or 0
	Kit.Paint(frame, props.Color or theme.Cell)
	Kit.Corner(frame, radius)
	Kit.Stroke(frame, props.StrokeColor, props.StrokeThickness or 3)
	if props.Shards == true then
		Kit.Shards(frame, radius)
	end
	if props.Bevel ~= false then
		addBevel(frame, radius)
	end
	frame.Parent = props.Parent
	return frame
end

function Kit.Label(props: LabelProps): TextLabel
	local textSize = props.TextSize or 20
	local label = Instance.new("TextLabel")
	label.Name = props.Name or "Label"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Size = props.Size or UDim2.new(1, 0, 0, 28)
	label.Position = props.Position or UDim2.new()
	label.AnchorPoint = props.AnchorPoint or Vector2.zero
	label.LayoutOrder = props.LayoutOrder or 0
	label.Font = Kit.Font
	label.TextColor3 = props.Color or theme.Text
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
		Kit.TextStroke(label, if textSize >= 26 then 3 elseif textSize >= 17 then 2.5 else 2)
	end
	label.Parent = props.Parent
	return label
end

function Kit.Icon(props: IconProps): GuiObject
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
	local glyph = props.Glyph
	if glyph and Glyphs.Has(glyph) then
		return Glyphs.Build(glyph, {
			Parent = props.Parent,
			Name = props.Name or "Icon",
			Size = props.Size or UDim2.fromOffset(48, 48),
			Position = props.Position,
			AnchorPoint = props.AnchorPoint,
			LayoutOrder = props.LayoutOrder,
			Color = props.Color,
		})
	end
	return Kit.Label({
		Parent = props.Parent,
		Name = props.Name or "Icon",
		Text = props.Emoji or "",
		Size = props.Size or UDim2.fromOffset(48, 48),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		TextSize = 60,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
		Outline = false,
	})
end

function Kit.Chip(props: ChipProps): TextLabel
	local chip = Kit.Panel({
		Parent = props.Parent,
		Name = props.Name or "Chip",
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		Color = props.Color or theme.Red,
		Radius = 4,
		StrokeThickness = 2.5,
		Bevel = false,
	})
	return Kit.Label({
		Parent = chip,
		Name = "Text",
		Text = props.Text,
		Size = UDim2.new(1, -4, 1, 0),
		Position = UDim2.fromOffset(2, 0),
		TextSize = props.TextSize or 16,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
end

function Kit.Badge(parent: Instance, text: string?): Frame
	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.BorderSizePixel = 0
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, 6, 0, -6)
	badge.Size = UDim2.fromOffset(26, 26)
	Kit.Paint(badge, theme.Red)
	Kit.Corner(badge, 13)
	Kit.Stroke(badge, theme.Ink, 2.5)
	Kit.Label({
		Parent = badge,
		Name = "Text",
		Text = text or "!",
		Size = UDim2.fromScale(1, 1),
		TextSize = 20,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	badge.Parent = parent
	return badge
end

function Kit.Keycap(props: KeycapProps): Keycap
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
	Kit.Corner(base, 8)
	Kit.Stroke(base, theme.Ink, 2.5)
	base.Parent = holder
	local top = Instance.new("Frame")
	top.Name = "Top"
	top.BorderSizePixel = 0
	top.Position = UDim2.fromScale(0.08, 0)
	top.Size = UDim2.fromScale(0.84, 0.74)
	Kit.Corner(top, 6)
	Kit.Stroke(top, theme.Ink, 2)
	top.Parent = holder
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = white
	shine.BackgroundTransparency = 0.7
	shine.BorderSizePixel = 0
	shine.Position = UDim2.fromScale(0.1, 0.08)
	shine.Size = UDim2.fromScale(0.5, 0.12)
	Kit.Corner(shine, 3)
	shine.Parent = top
	local glyph = Kit.Label({
		Parent = top,
		Name = "Glyph",
		Text = props.Glyph or "",
		Size = UDim2.fromScale(1, 1),
		TextSize = 34,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local function paint(color: Color3)
		base.BackgroundColor3 = Kit.Shade(color, -0.3)
		Kit.Paint(top, color)
	end
	paint(props.Color)
	holder.Parent = props.Parent
	return {
		Instance = holder,
		SetColor = paint,
		SetGlyph = function(text: string, color: Color3?)
			glyph.Text = text
			glyph.TextColor3 = color or theme.Text
		end,
	}
end

function Kit.Burst(props: BurstProps): Frame
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
		image.ImageTransparency = 0.45
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
			Kit.Corner(glow, props.Diameter)
			glow.Parent = holder
		end
		for index = 0, 3 do
			local ray = Instance.new("Frame")
			ray.Name = `Ray{index}`
			ray.BackgroundColor3 = tint
			ray.BorderSizePixel = 0
			ray.AnchorPoint = Vector2.new(0.5, 0.5)
			ray.Position = UDim2.fromScale(0.5, 0.5)
			ray.Size = UDim2.fromOffset(props.Diameter * 0.95, 5)
			ray.Rotation = index * 45
			local fade = Instance.new("UIGradient")
			fade.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.78),
				NumberSequenceKeypoint.new(1, 1),
			})
			fade.Parent = ray
			ray.Parent = holder
		end
	end
	holder.Parent = props.Parent
	return holder
end

function Kit.Bar(props: BarProps): Bar
	local value = math.clamp(props.Value or 0, 0, 1)
	local track = Kit.Panel({
		Parent = props.Parent,
		Name = props.Name or "Bar",
		Size = props.Size or UDim2.new(1, 0, 0, 26),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		Color = theme.Track,
		Radius = 4,
		Bevel = false,
	})
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(value, 1)
	Kit.Paint(fill, props.Color or theme.Green)
	Kit.Corner(fill, 4)
	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.BackgroundColor3 = white
	gloss.BackgroundTransparency = 0.8
	gloss.BorderSizePixel = 0
	gloss.Position = UDim2.fromScale(0.02, 0.1)
	gloss.Size = UDim2.fromScale(0.96, 0.32)
	Kit.Corner(gloss, 3)
	gloss.Parent = fill
	fill.Parent = track
	local label = Kit.Label({
		Parent = track,
		Name = "Text",
		Text = props.Text or "",
		Size = UDim2.fromScale(1, 1),
		TextSize = props.TextSize or 18,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	return {
		Instance = track,
		Fill = fill,
		Label = label,
		Stroke = Kit.StrokeOf(track),
		SetValue = function(alpha: number)
			fill.Size = UDim2.fromScale(math.clamp(alpha, 0, 1), 1)
		end,
		SetText = function(text: string)
			label.Text = text
		end,
		SetColor = function(color: Color3)
			Kit.Paint(fill, color)
		end,
	}
end

function Kit.Button(trove: TroveInstance, props: ButtonProps): Button
	local baseColor = props.Color or theme.Green
	local baseTextColor = props.TextColor or theme.Text
	local isDisabled = false
	local isDown = false
	local isHover = false
	local isGlowing = false
	local isSelected = false
	local glowTween: Tween? = nil

	local root = Instance.new("TextButton")
	root.Name = props.Name or "Button"
	root.AutoButtonColor = false
	root.BorderSizePixel = 0
	root.BackgroundTransparency = 1
	root.Text = ""
	root.Size = props.Size or UDim2.fromOffset(140, Kit.ButtonHeight)
	root.Position = props.Position or UDim2.new()
	root.AnchorPoint = props.AnchorPoint or Vector2.zero
	root.LayoutOrder = props.LayoutOrder or 0

	local lipDrop = 5
	local lip = Instance.new("Frame")
	lip.Name = "Lip"
	lip.BorderSizePixel = 0
	lip.Position = UDim2.fromOffset(0, lipDrop)
	lip.Size = UDim2.new(1, 0, 1, -lipDrop)
	lip.Parent = root
	Kit.Corner(lip, props.Radius or cornerRadius)

	local face = Kit.Panel({
		Parent = root,
		Name = "Face",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 1, -lipDrop),
		Color = baseColor,
		Radius = props.Radius,
		StrokeThickness = 2.5,
		Bevel = false,
	})
	local faceStroke = Kit.StrokeOf(face)

	local hasIcon = props.Icon ~= nil or props.IconAsset ~= nil or props.Glyph ~= nil
	local isLeft = props.IconLeft == true
	local isIconOnly = hasIcon and (props.Text == nil or props.Text == "")
	if hasIcon then
		local icon = Kit.Icon({
			Parent = face,
			Name = "Icon",
			Emoji = props.Icon,
			Glyph = props.Glyph,
			Asset = props.IconAsset,
			Size = if isIconOnly
				then UDim2.fromScale(0.7, 0.7)
				elseif isLeft then UDim2.fromScale(0, 0.78)
				else UDim2.fromScale(1, 0.56),
			Position = if isIconOnly
				then UDim2.fromScale(0.15, 0.15)
				elseif isLeft then UDim2.new(0, 8, 0.5, 0)
				else UDim2.fromScale(0, 0.06),
			AnchorPoint = if isLeft and not isIconOnly then Vector2.new(0, 0.5) else Vector2.zero,
		})
		if isLeft and not isIconOnly then
			local ratio = Instance.new("UIAspectRatioConstraint")
			ratio.AspectRatio = 1
			ratio.DominantAxis = Enum.DominantAxis.Height
			ratio.Parent = icon
		end
	end
	local text = Kit.Label({
		Parent = face,
		Name = "Text",
		Text = props.Text or "",
		Position = if hasIcon and isLeft
			then UDim2.new(0.2, 0, 0, 2)
			elseif hasIcon then UDim2.fromScale(0, 0.6)
			else UDim2.fromOffset(6, 2),
		Size = if hasIcon and isLeft
			then UDim2.new(0.8, -8, 1, -4)
			elseif hasIcon then UDim2.fromScale(1, 0.38)
			else UDim2.new(1, -12, 1, -4),
		TextSize = props.TextSize or 24,
		Color = baseTextColor,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	text.Active = false

	local pressScale = Instance.new("UIScale")
	pressScale.Name = "PressScale"
	pressScale.Parent = root
	root.Parent = props.Parent

	local function paint()
		local color = if isDisabled then theme.Disabled else baseColor
		Kit.Paint(face, color)
		lip.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.38)
		text.TextColor3 = if isDisabled then theme.TextDim else baseTextColor
	end
	paint()

	local function applyStroke()
		if isGlowing then
			return
		end
		faceStroke.Color = if isSelected then white else theme.Ink
		faceStroke.Thickness = if isSelected then 4 else 2.5
	end

	local function settle()
		face.Position = UDim2.fromOffset(0, if isDown then lipDrop - 1 else 0)
		local goal = if isDown then 0.96 elseif isHover then 1.04 else 1
		Kit.Tween(pressScale, if isDown then pressInfo else springInfo, { Scale = goal })
	end
	local function release()
		if isDown then
			isDown = false
			settle()
		end
	end
	local function fire()
		if isDisabled then
			return
		end
		local sound = props.Sound
		if sound then
			sound("Click")
		end
		local callback = props.Callback
		if callback then
			callback()
		end
	end

	trove:Connect(root.MouseButton1Down, function()
		if isDisabled then
			return
		end
		isDown = true
		settle()
		if props.Immediate == true then
			fire()
		end
	end)
	trove:Connect(root.MouseButton1Up, release)
	trove:Connect(root.MouseEnter, function()
		if UserInputService:GetLastInputType() == Enum.UserInputType.MouseMovement then
			isHover = true
			settle()
		end
	end)
	trove:Connect(root.MouseLeave, function()
		isDown = false
		isHover = false
		settle()
	end)
	trove:Connect(UserInputService.InputEnded, function(input: InputObject)
		local inputType = input.UserInputType
		if inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch then
			release()
		end
	end)
	trove:Connect(root.Activated, function(input: InputObject)
		local inputType = input.UserInputType
		if props.Immediate == true then
			if inputType ~= Enum.UserInputType.MouseButton1 and inputType ~= Enum.UserInputType.Touch then
				fire()
			end
			return
		end
		fire()
	end)
	trove:Add(function()
		if glowTween then
			glowTween:Cancel()
			glowTween = nil
		end
	end)

	return {
		Instance = root,
		Face = face,
		SetDisabled = function(disabled: boolean)
			if disabled == isDisabled then
				return
			end
			isDisabled = disabled
			if disabled then
				isDown = false
				settle()
			end
			paint()
		end,
		SetText = function(value: string)
			text.Text = value
		end,
		SetColor = function(color: Color3)
			baseColor = color
			paint()
		end,
		SetGlow = function(isOn: boolean)
			if glowTween then
				glowTween:Cancel()
				glowTween = nil
			end
			isGlowing = isOn
			if isOn then
				faceStroke.Color = Color3.fromRGB(255, 240, 150)
				local loop = TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
				glowTween = TweenService:Create(faceStroke, loop, { Thickness = 4.5 })
				if glowTween then
					glowTween:Play()
				end
			else
				applyStroke()
			end
		end,
		SetSelected = function(isOn: boolean)
			isSelected = isOn
			applyStroke()
		end,
	}
end

function Kit.CloseButton(
	trove: TroveInstance,
	parent: Instance,
	onClose: () -> (),
	sound: SoundPlayer?
): Button
	return Kit.Button(trove, {
		Parent = parent,
		Name = "Close",
		Text = "X",
		Size = UDim2.fromOffset(Kit.TouchSize, Kit.TouchSize),
		Position = UDim2.new(1, -6, 0, 6),
		AnchorPoint = Vector2.new(1, 0),
		Color = theme.Red,
		TextSize = 30,
		Callback = onClose,
		Sound = sound,
	})
end

function Kit.Scroll(props: ScrollProps): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = props.Name or "Scroll"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = props.Size or UDim2.fromScale(1, 1)
	scroll.Position = props.Position or UDim2.new()
	scroll.AnchorPoint = props.AnchorPoint or Vector2.zero
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = theme.Gold
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, props.Padding or 10)
	list.Parent = scroll
	local padding = Instance.new("UIPadding")
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 4)
	padding.Parent = scroll
	scroll.Parent = props.Parent
	return scroll
end

function Kit.GridScroll(props: GridScrollProps): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = props.Name or "Grid"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = props.Size or UDim2.fromScale(1, 1)
	scroll.Position = props.Position or UDim2.new()
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = theme.Gold
	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.CellSize = props.CellSize
	grid.CellPadding = props.CellPadding or UDim2.fromOffset(10, 10)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = scroll
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.Parent = scroll
	scroll.Parent = props.Parent
	return scroll
end

function Kit.Slider(trove: TroveInstance, props: SliderProps): Slider
	local value = math.clamp(props.Value, 0, 1)
	local isDragging = false
	local activeInput: InputObject? = nil
	local hit = Instance.new("Frame")
	hit.Name = props.Name or "Slider"
	hit.BackgroundTransparency = 1
	hit.BorderSizePixel = 0
	hit.Active = true
	hit.Size = props.Size or UDim2.new(1, 0, 0, 48)
	hit.Position = props.Position or UDim2.new()
	hit.AnchorPoint = props.AnchorPoint or Vector2.zero
	hit.LayoutOrder = props.LayoutOrder or 0
	local bar = Kit.Bar({
		Parent = hit,
		Name = "Track",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.new(1, -32, 0, 24),
		Color = props.Color or theme.Green,
		Value = value,
	})
	local track = bar.Instance
	local knob = Kit.Panel({
		Parent = track,
		Name = "Knob",
		Size = UDim2.fromOffset(20, 40),
		Position = UDim2.fromScale(value, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = theme.Text,
		Radius = 4,
		Bevel = false,
	})
	hit.Parent = props.Parent

	local function show(newValue: number)
		value = math.clamp(newValue, 0, 1)
		bar.SetValue(value)
		knob.Position = UDim2.fromScale(value, 0.5)
	end
	local function fromX(x: number): number
		local width = track.AbsoluteSize.X
		if width <= 0 then
			return value
		end
		return math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
	end
	local function move(x: number)
		show(fromX(x))
		local callback = props.OnChanged
		if callback then
			callback(value)
		end
	end

	trove:Connect(hit.InputBegan, function(input: InputObject)
		local inputType = input.UserInputType
		if inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch then
			isDragging = true
			activeInput = input
			move(input.Position.X)
		end
	end)
	trove:Connect(UserInputService.InputChanged, function(input: InputObject)
		if not isDragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement or input == activeInput then
			move(input.Position.X)
		end
	end)
	trove:Connect(UserInputService.InputEnded, function(input: InputObject)
		if not isDragging then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input == activeInput then
			isDragging = false
			activeInput = nil
			local callback = props.OnReleased
			if callback then
				callback(value)
			end
		end
	end)

	return {
		Instance = hit,
		SetValue = function(newValue: number)
			if not isDragging then
				show(newValue)
			end
		end,
	}
end

function Kit.Toggle(trove: TroveInstance, props: ToggleProps): Toggle
	local isOn = props.Value
	local button = Instance.new("TextButton")
	button.Name = props.Name or "Toggle"
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Size = UDim2.fromOffset(100, Kit.TouchSize)
	button.Position = props.Position or UDim2.new()
	button.AnchorPoint = props.AnchorPoint or Vector2.zero
	button.LayoutOrder = props.LayoutOrder or 0
	local face = Kit.Panel({
		Parent = button,
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		Color = theme.Disabled,
		Shards = true,
	})
	local state = Kit.Label({
		Parent = face,
		Name = "State",
		Text = "OFF",
		Size = UDim2.fromScale(1, 1),
		TextSize = 28,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local pressScale = Instance.new("UIScale")
	pressScale.Parent = button
	button.Parent = props.Parent

	local function show()
		state.Text = if isOn then "ON" else "OFF"
		Kit.Paint(face, if isOn then theme.Green else theme.Red)
	end
	show()

	trove:Connect(button.MouseButton1Down, function()
		Kit.Tween(pressScale, pressInfo, { Scale = 0.92 })
	end)
	trove:Connect(button.MouseLeave, function()
		Kit.Tween(pressScale, springInfo, { Scale = 1 })
	end)
	trove:Connect(button.Activated, function()
		isOn = not isOn
		show()
		Kit.Tween(pressScale, springInfo, { Scale = 1 })
		local sound = props.Sound
		if sound then
			sound("Click")
		end
		local callback = props.OnChanged
		if callback then
			callback(isOn)
		end
	end)

	return {
		Instance = button,
		SetValue = function(value: boolean)
			if value ~= isOn then
				isOn = value
				show()
			end
		end,
	}
end

function Kit.Pulse(target: GuiObject, color: Color3?)
	local existing = target:FindFirstChild("PulseScale")
	local scale: UIScale
	if existing and existing:IsA("UIScale") then
		scale = existing
	else
		scale = Instance.new("UIScale")
		scale.Name = "PulseScale"
		scale.Parent = target
	end
	local reverse = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, true)
	Kit.Tween(scale, reverse, { Scale = 1.04 })
	local stroke = target:FindFirstChild("Stroke")
	if stroke and stroke:IsA("UIStroke") then
		Kit.Tween(stroke, reverse, { Color = color or theme.Good })
	end
end

function Kit.Shake(target: GuiObject)
	task.spawn(function()
		for _, rotation in { 3, -3, 2, -2, 0 } do
			if not target.Parent then
				return
			end
			target.Rotation = rotation
			task.wait(0.035)
		end
	end)
end

function Kit.PlainTitle(text: string): string
	local emoji, rest = string.match(text, "^(%S+)%s+(.+)$")
	if emoji and rest then
		local code = utf8.codepoint(emoji)
		if code and code >= 0x2190 then
			return rest
		end
	end
	return text
end

function Kit.Modal(trove: TroveInstance, props: ModalProps): Modal
	local gui, root = Kit.ScreenGui(`Thock{props.Name}`, 10, props.Parent, trove)
	gui.Enabled = false
	local token = 0
	local headerColor = props.HeaderColor or theme.Blue
	local headerHeight = Kit.HeaderHeight
	local iconSize = 52
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.AutoButtonColor = false
	backdrop.BackgroundColor3 = black
	backdrop.BackgroundTransparency = 0.45
	backdrop.BorderSizePixel = 0
	backdrop.Text = ""
	backdrop.Position = UDim2.fromOffset(0, windowTop - 6)
	backdrop.Size = UDim2.new(1, 0, 1, -(windowTop - 6))
	backdrop.Parent = root
	trove:Connect(backdrop.Activated, props.OnClose)

	local area = Instance.new("Frame")
	area.Name = "Area"
	area.BackgroundTransparency = 1
	area.BorderSizePixel = 0
	area.Position = UDim2.fromOffset(0, windowTop)
	area.Size = UDim2.new(1, 0, 1, -(windowTop + windowBottom))
	area.Parent = root

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.BackgroundTransparency = 1
	window.BorderSizePixel = 0
	window.Active = true
	window.Size = UDim2.fromScale(0.92, 1)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Parent = area
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = props.MaxSize
	constraint.Parent = window
	local pop = Instance.new("UIScale")
	pop.Name = "Pop"
	pop.Parent = window

	local shell = Kit.Panel({
		Parent = window,
		Name = "Shell",
		Size = UDim2.fromScale(1, 1),
		Color = theme.Ink,
		StrokeThickness = 4,
		Radius = Kit.CardRadius,
		Bevel = false,
	})
	local body = Kit.Panel({
		Parent = shell,
		Name = "Body",
		Position = UDim2.fromOffset(4, headerHeight),
		Size = UDim2.new(1, -8, 1, -(headerHeight + 4)),
		Color = theme.Slate,
		Transparency = 0.04,
		StrokeThickness = 0,
		Radius = Kit.CardRadius - 2,
		Bevel = false,
	})
	local header = Kit.Panel({
		Parent = shell,
		Name = "Header",
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 0, headerHeight - 4),
		Color = headerColor,
		Shards = true,
		Radius = Kit.CardRadius - 2,
		StrokeThickness = 2.5,
	})
	local badge = Kit.Panel({
		Parent = header,
		Name = "IconBadge",
		Position = UDim2.fromOffset(10, (headerHeight - 4 - iconSize) / 2),
		Size = UDim2.fromOffset(iconSize, iconSize),
		Color = theme.Cell,
		Transparency = 0.05,
		Radius = 10,
		StrokeThickness = 2.5,
		Bevel = false,
	})
	Kit.Icon({
		Parent = badge,
		Name = "Icon",
		Glyph = props.Glyph,
		Emoji = props.Icon,
		Asset = props.IconAsset,
		Size = UDim2.fromScale(0.72, 0.72),
		Position = UDim2.fromScale(0.14, 0.14),
	})
	Kit.Label({
		Parent = header,
		Name = "Title",
		Text = props.Title,
		Position = UDim2.fromOffset(iconSize + 22, 0),
		Size = UDim2.new(0.55, -(iconSize + 22), 1, 0),
		TextSize = 34,
		Scaled = true,
	})
	local headerRight = Instance.new("Frame")
	headerRight.Name = "HeaderRight"
	headerRight.BackgroundTransparency = 1
	headerRight.BorderSizePixel = 0
	headerRight.AnchorPoint = Vector2.new(1, 0.5)
	headerRight.Position = UDim2.new(1, -(Kit.TouchSize + 14), 0.5, 0)
	headerRight.Size = UDim2.new(0.45, -(Kit.TouchSize + 20), 1, -8)
	local rightList = Instance.new("UIListLayout")
	rightList.FillDirection = Enum.FillDirection.Horizontal
	rightList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	rightList.VerticalAlignment = Enum.VerticalAlignment.Center
	rightList.SortOrder = Enum.SortOrder.LayoutOrder
	rightList.Padding = UDim.new(0, 8)
	rightList.Parent = headerRight
	headerRight.Parent = header
	Kit.CloseButton(trove, header, props.OnClose, props.Sound)

	return {
		Gui = gui,
		Root = root,
		Panel = window,
		Body = body,
		HeaderRight = headerRight,
		Show = function()
			token += 1
			pop.Scale = 0.85
			gui.Enabled = true
			Kit.Tween(pop, popInfo, { Scale = 1 })
		end,
		Hide = function()
			if not gui.Enabled then
				return
			end
			token += 1
			local mine = token
			local closing = Kit.Tween(pop, closeInfo, { Scale = 0.85 })
			closing.Completed:Once(function()
				if token == mine then
					gui.Enabled = false
				end
			end)
		end,
	}
end

return Kit
