--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local UiAssets = require(ReplicatedStorage.Config.UiAssets)
local Trove = require(ReplicatedStorage.Packages.Trove)

type TroveInstance = typeof(Trove.new())
type SoundPlayer = (name: string) -> ()

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
	Body: boolean?,
}

export type IconProps = {
	Parent: Instance,
	Name: string?,
	Emoji: string,
	Asset: string?,
	IconName: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
}

export type CaptionProps = {
	Parent: Instance,
	Name: string?,
	Text: string,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Color: Color3?,
	Align: Enum.TextXAlignment?,
}

export type ButtonProps = {
	Parent: Instance,
	Name: string?,
	Text: string?,
	Icon: string?,
	GlyphName: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Color: Color3?,
	TextColor: Color3?,
	TextSize: number?,
	Radius: number?,
	Hero: boolean?,
	Shards: boolean?,
	Immediate: boolean?,
	Callback: (() -> ())?,
	Sound: SoundPlayer?,
}

export type Button = {
	Instance: TextButton,
	Face: Frame,
	Content: Frame,
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
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Color: Color3?,
	TextColor: Color3?,
	TextSize: number?,
	GlyphName: string?,
	AutoWidth: boolean?,
}

export type PlateProps = {
	Parent: Instance,
	Name: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Thickness: number?,
	Lip: boolean?,
	Class: string?,
}

export type KeycapProps = {
	Parent: Instance,
	Name: string?,
	Color: Color3,
	Glyph: string?,
	GlyphName: string?,
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

export type TooltipProps = {
	Parent: Instance,
	Name: string?,
	Text: string,
	GlyphName: string?,
	GlyphColor: Color3?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Large: boolean?,
	Side: string?,
}

export type ModalProps = {
	Parent: Instance,
	Name: string,
	Title: string,
	Icon: string?,
	IconName: string?,
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
	Content: Frame,
	HeaderRight: Frame,
	Show: () -> (),
	Hide: () -> (),
}

local white = Color3.new(1, 1, 1)
local black = Color3.new(0, 0, 0)

local function channel(value: number): number
	if value <= 0.03928 then
		return value / 12.92
	end
	return ((value + 0.055) / 1.055) ^ 2.4
end

local function luminance(color: Color3): number
	return 0.2126 * channel(color.R) + 0.7152 * channel(color.G) + 0.0722 * channel(color.B)
end

local function contrast(first: Color3, second: Color3): number
	local high = luminance(first)
	local low = luminance(second)
	if high < low then
		high, low = low, high
	end
	return (high + 0.05) / (low + 0.05)
end

local function fillSafe(color: Color3): Color3
	local amount = 0
	while contrast(white, color:Lerp(black, amount)) < 4.5 and amount < 0.8 do
		amount += 0.03
	end
	return color:Lerp(black, amount)
end

local function textSafe(color: Color3, background: Color3): Color3
	local amount = 0
	while contrast(color:Lerp(white, amount), background) < 4.5 and amount < 1 do
		amount += 0.05
	end
	return color:Lerp(white, amount)
end

local line = Color3.fromRGB(14, 16, 24)
local surface = Color3.fromRGB(28, 32, 48)
local surface2 = Color3.fromRGB(38, 43, 63)
local surface3 = Color3.fromRGB(49, 55, 79)
local muted = Color3.fromRGB(174, 180, 200)
local green = Color3.fromRGB(60, 203, 90)
local red = Color3.fromRGB(240, 67, 90)
local blue = Color3.fromRGB(58, 141, 255)
local gold = Color3.fromRGB(255, 194, 51)
local purple = Color3.fromRGB(155, 92, 255)
local slate = Color3.fromRGB(107, 116, 148)
local orange = Color3.fromRGB(255, 138, 31)
local teal = Color3.fromRGB(18, 181, 176)
local market = Color3.fromRGB(255, 106, 43)

local theme = {
	Ink = line,
	TextInk = line,
	Line = line,
	Surface = surface,
	Surface2 = surface2,
	Surface3 = surface3,
	Slate = surface,
	Cell = surface2,
	Track = surface3,
	Text = white,
	TextDim = muted,
	Muted = muted,
	Good = textSafe(green, surface2),
	Bad = textSafe(red, surface2),
	Gold = gold,
	Green = green,
	Blue = blue,
	Purple = purple,
	Grey = slate,
	Red = red,
	Orange = orange,
	Yellow = gold,
	Teal = teal,
	Market = market,
	Disabled = Color3.fromRGB(59, 66, 89),
	DisabledLip = Color3.fromRGB(44, 50, 71),
	DisabledText = Color3.fromRGB(142, 149, 173),
}

local Kit = {
	TabBarTop = 24,
	TabBarHeight = 64,
	ClicksGap = 8,
	ClicksHeight = 48,
	ToastGap = 12,
	Margin = 24,
	Theme = table.freeze(theme),
	Font = Enum.Font.FredokaOne,
	BodyFont = Enum.Font.BuilderSansBold,
	HeaderHeight = 64,
	WindowPadding = 24,
	ButtonHeight = 52,
	TouchSize = 48,
}

local pressInfo = TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local popInfo = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local closeInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local slideInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local windowTop = 100
local windowBottom = 16
local shardTransparency = 0.88
local shardTile = 128
local cardRadius = 12
local windowRadius = 16
local chipRadius = 8

local fallbackEmoji: { [string]: string } = {
	upgrades = "🛒",
	keys = "🔑",
	index = "📘",
	settings = "⚙️",
	rebirth = "♻️",
	pass = "🎟️",
	daily = "📅",
	shop = "🛒",
	leaders = "🏆",
	base = "🏠",
	clicks = "⌨️",
	luck = "🍀",
	speed = "⚡",
	income = "💰",
	roll = "🎲",
	auto = "🔁",
	gift = "🎁",
	trade = "🤝",
	close = "✖",
	lock = "🔒",
	check = "✔",
	market = "🏪",
	star = "⭐",
	board = "⌨️",
	tag = "🏷️",
	volume = "🔊",
	people = "👥",
	monitor = "🖥️",
	sparkle = "✨",
	crown = "👑",
	flask = "🧪",
	globe = "🌐",
	warn = "⚠️",
	clock = "⏰",
	wall = "🧱",
	laser = "🔒",
	plus = "+",
	minus = "-",
}

local legacyIconNames: { [string]: string } = {
	["🛒"] = "shop",
	["🔑"] = "keys",
	["📘"] = "index",
	["⚙️"] = "settings",
	["♻️"] = "rebirth",
	["🎟️"] = "pass",
	["📅"] = "daily",
	["🏆"] = "leaders",
	["🤝"] = "trade",
	["🏪"] = "market",
	["🎁"] = "gift",
	["⌨️"] = "clicks",
	["🏠"] = "base",
}

local function collectCells(source: any): { [string]: Vector2 }
	local cells: { [string]: Vector2 } = {}
	for name, value in source do
		local cell: any = value
		if typeof(cell) == "Vector2" then
			cells[name] = cell
		end
	end
	return cells
end

local iconCells = collectCells(UiAssets.Icons)
local glyphCells = collectCells(UiAssets.Glyphs)

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

function Kit.FillColor(color: Color3): Color3
	return fillSafe(color)
end

function Kit.TextSafe(color: Color3, background: Color3?): Color3
	return textSafe(color, background or surface2)
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
	corner.CornerRadius = UDim.new(0, radius or cardRadius)
	corner.Parent = parent
	return corner
end

function Kit.Stroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Color = color or line
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
	stroke.Color = line
	stroke.Thickness = thickness or 2.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = parent
	return stroke
end

function Kit.Paint(frame: GuiObject, color: Color3)
	frame.BackgroundColor3 = color
	local existing = frame:FindFirstChild("Paint")
	if existing then
		existing:Destroy()
	end
end

function Kit.Shards(parent: GuiObject, radius: number, transparency: number?): ImageLabel?
	if UiAssets.Pattern == "" then
		return nil
	end
	local image = Instance.new("ImageLabel")
	image.Name = "Shards"
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.Active = false
	image.Size = UDim2.fromScale(1, 1)
	image.Image = UiAssets.Pattern
	image.ScaleType = Enum.ScaleType.Tile
	image.TileSize = UDim2.fromOffset(shardTile, shardTile)
	image.ImageColor3 = white
	image.ImageTransparency = transparency or shardTransparency
	Kit.Corner(image, radius)
	image.Parent = parent
	return image
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
	local radius = props.Radius or cardRadius
	local frame = Instance.new("Frame")
	frame.Name = props.Name or "Panel"
	frame.BackgroundTransparency = props.Transparency or 0
	frame.BorderSizePixel = 0
	frame.Size = props.Size or UDim2.fromScale(1, 1)
	frame.Position = props.Position or UDim2.new()
	frame.AnchorPoint = props.AnchorPoint or Vector2.zero
	frame.LayoutOrder = props.LayoutOrder or 0
	frame.BackgroundColor3 = props.Color or surface2
	Kit.Corner(frame, radius)
	Kit.Stroke(frame, props.StrokeColor, props.StrokeThickness or 2)
	if props.Shards == true then
		Kit.Shards(frame, radius)
	end
	frame.Parent = props.Parent
	return frame
end

function Kit.Card(props: PanelProps): Frame
	local frame = Kit.Panel(props)
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 16)
	padding.PaddingBottom = UDim.new(0, 16)
	padding.PaddingLeft = UDim.new(0, 16)
	padding.PaddingRight = UDim.new(0, 16)
	padding.Parent = frame
	return frame
end

function Kit.Plate(props: PlateProps): (Frame, Frame)
	local root: Frame
	if props.Class == "TextButton" then
		local button = Instance.new("TextButton")
		button.AutoButtonColor = false
		button.Text = ""
		root = button :: any
	else
		root = Instance.new("Frame")
	end
	root.Name = props.Name or "Plate"
	root.BorderSizePixel = 0
	root.BackgroundColor3 = surface2
	root.Size = props.Size or UDim2.fromOffset(100, 56)
	root.Position = props.Position or UDim2.new()
	root.AnchorPoint = props.AnchorPoint or Vector2.zero
	root.LayoutOrder = props.LayoutOrder or 0
	Kit.Corner(root, cardRadius)
	Kit.Stroke(root, line, props.Thickness or 3)
	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BorderSizePixel = 0
	inner.BackgroundColor3 = surface
	inner.Size = if props.Lip == true then UDim2.new(1, 0, 1, -4) else UDim2.fromScale(1, 1)
	Kit.Corner(inner, cardRadius)
	inner.Parent = root
	root.Parent = props.Parent
	return root, inner
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
	label.Font = if props.Body == true then Kit.BodyFont else Kit.Font
	label.TextColor3 = props.Color or white
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
	if props.Outline == true then
		Kit.TextStroke(label, if textSize >= 26 then 3 elseif textSize >= 17 then 2.5 else 2)
	end
	label.Parent = props.Parent
	return label
end

function Kit.Caption(props: CaptionProps): TextLabel
	return Kit.Label({
		Parent = props.Parent,
		Name = props.Name or "Caption",
		Text = string.upper(props.Text),
		Size = props.Size or UDim2.new(1, 0, 0, 18),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		TextSize = 13,
		Color = props.Color or muted,
		Align = props.Align,
		Body = true,
	})
end

local function emojiLabel(
	parent: Instance,
	name: string,
	text: string,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	order: number?
): TextLabel
	return Kit.Label({
		Parent = parent,
		Name = name,
		Text = text,
		Size = size,
		Position = position,
		AnchorPoint = anchor,
		LayoutOrder = order,
		TextSize = 60,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
end

local function atlasImage(
	parent: Instance,
	name: string,
	atlas: string,
	cell: Vector2,
	cellSize: number,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	order: number?
): ImageLabel
	local image = Instance.new("ImageLabel")
	image.Name = name
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.Image = atlas
	image.ImageRectSize = Vector2.new(cellSize, cellSize)
	image.ImageRectOffset = Vector2.new(cell.X * cellSize, cell.Y * cellSize)
	image.ScaleType = Enum.ScaleType.Fit
	image.Size = size
	image.Position = position or UDim2.new()
	image.AnchorPoint = anchor or Vector2.zero
	image.LayoutOrder = order or 0
	image.Parent = parent
	return image
end

function Kit.HasIcon(name: string): boolean
	local cell: Vector2? = iconCells[name]
	return UiAssets.IconAtlas ~= "" and cell ~= nil
end

function Kit.HasGlyph(name: string): boolean
	local cell: Vector2? = glyphCells[name]
	return UiAssets.GlyphAtlas ~= "" and cell ~= nil
end

local function namedIcon(
	parent: Instance,
	name: string,
	size: UDim2,
	position: UDim2?,
	anchor: Vector2?,
	order: number?,
	instanceName: string?
): GuiObject
	local cell = iconCells[name]
	if UiAssets.IconAtlas ~= "" and cell then
		return atlasImage(
			parent,
			instanceName or "Icon",
			UiAssets.IconAtlas,
			cell,
			UiAssets.IconCell,
			size,
			position,
			anchor,
			order
		)
	end
	return emojiLabel(
		parent,
		instanceName or "Icon",
		fallbackEmoji[name] or "•",
		size,
		position,
		anchor,
		order
	)
end

local function legacyIcon(props: IconProps): GuiObject
	local iconName = props.IconName
	if iconName and iconName ~= "" then
		return namedIcon(
			props.Parent,
			iconName,
			props.Size or UDim2.fromOffset(48, 48),
			props.Position,
			props.AnchorPoint,
			props.LayoutOrder,
			props.Name
		)
	end
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
	return emojiLabel(
		props.Parent,
		props.Name or "Icon",
		props.Emoji,
		props.Size or UDim2.fromOffset(48, 48),
		props.Position,
		props.AnchorPoint,
		props.LayoutOrder
	)
end

function Kit.Icon(first: any, name: string?, size: number?): GuiObject
	if typeof(first) == "Instance" then
		local dimension = size or 48
		return namedIcon(
			first :: Instance,
			name or "",
			UDim2.fromOffset(dimension, dimension),
			nil,
			nil,
			nil,
			nil
		)
	end
	return legacyIcon(first :: IconProps)
end

function Kit.Glyph(parent: Instance, name: string, size: number, color: Color3?): GuiObject
	local cell = glyphCells[name]
	local dimension = UDim2.fromOffset(size, size)
	if UiAssets.GlyphAtlas ~= "" and cell then
		local image = atlasImage(
			parent,
			"Glyph",
			UiAssets.GlyphAtlas,
			cell,
			UiAssets.GlyphCell,
			dimension,
			nil,
			nil,
			nil
		)
		image.ImageColor3 = color or white
		return image
	end
	local label = Kit.Label({
		Parent = parent,
		Name = "Glyph",
		Text = fallbackEmoji[name] or "•",
		Size = dimension,
		TextSize = size,
		Color = color,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	return label
end

function Kit.Chip(props: ChipProps): TextLabel
	local chip = Kit.Panel({
		Parent = props.Parent,
		Name = props.Name or "Chip",
		Size = props.Size or UDim2.fromOffset(0, 24),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		Color = props.Color or surface3,
		Radius = chipRadius,
		StrokeThickness = 2,
	})
	local textColor = props.TextColor or white
	local textSize = props.TextSize or 13
	if props.AutoWidth == true then
		chip.AutomaticSize = Enum.AutomaticSize.X
		local list = Instance.new("UIListLayout")
		list.FillDirection = Enum.FillDirection.Horizontal
		list.HorizontalAlignment = Enum.HorizontalAlignment.Center
		list.VerticalAlignment = Enum.VerticalAlignment.Center
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, 4)
		list.Parent = chip
		local padding = Instance.new("UIPadding")
		padding.PaddingLeft = UDim.new(0, 8)
		padding.PaddingRight = UDim.new(0, 8)
		padding.Parent = chip
		local glyphName = props.GlyphName
		if glyphName then
			local glyph = Kit.Glyph(chip, glyphName, 16, textColor)
			glyph.LayoutOrder = 1
		end
		local label = Kit.Label({
			Parent = chip,
			Name = "Text",
			Text = props.Text,
			Size = UDim2.fromOffset(0, 20),
			LayoutOrder = 2,
			TextSize = textSize,
			Color = textColor,
			Align = Enum.TextXAlignment.Center,
			Body = true,
		})
		label.AutomaticSize = Enum.AutomaticSize.X
		label.TextTruncate = Enum.TextTruncate.None
		return label
	end
	local inset = 4
	local glyphName = props.GlyphName
	if glyphName then
		local glyph = Kit.Glyph(chip, glyphName, 16, textColor)
		glyph.AnchorPoint = Vector2.new(0, 0.5)
		glyph.Position = UDim2.new(0, 6, 0.5, 0)
		inset = 26
	end
	return Kit.Label({
		Parent = chip,
		Name = "Text",
		Text = props.Text,
		Size = UDim2.new(1, -(inset + 4), 1, 0),
		Position = UDim2.fromOffset(inset, 0),
		TextSize = textSize,
		Color = textColor,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
		Body = true,
	})
end

function Kit.Badge(parent: Instance, text: string?): Frame
	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.BorderSizePixel = 0
	badge.BackgroundColor3 = red
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, 6, 0, -6)
	badge.Size = UDim2.fromOffset(20, 20)
	badge.ZIndex = 5
	Kit.Corner(badge, 10)
	Kit.Stroke(badge, line, 2)
	local label = Kit.Label({
		Parent = badge,
		Name = "Text",
		Text = text or "!",
		Size = UDim2.fromScale(1, 1),
		TextSize = 13,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	label.ZIndex = 6
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
	base.Position = UDim2.fromScale(3 / 64, 10 / 64)
	base.Size = UDim2.fromScale(58 / 64, 50 / 64)
	local baseCorner = Kit.Corner(base, 0)
	baseCorner.CornerRadius = UDim.new(0.26, 0)
	Kit.Stroke(base, line, 2.5)
	base.Parent = holder
	local top = Instance.new("Frame")
	top.Name = "Top"
	top.BorderSizePixel = 0
	top.Position = UDim2.fromScale(9 / 64, 4 / 64)
	top.Size = UDim2.fromScale(46 / 64, 44 / 64)
	local topCorner = Kit.Corner(top, 0)
	topCorner.CornerRadius = UDim.new(0.23, 0)
	Kit.Stroke(top, line, 2.5)
	top.Parent = holder
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = white
	shine.BackgroundTransparency = 0.75
	shine.BorderSizePixel = 0
	shine.Position = UDim2.fromScale(0.08, 0.06)
	shine.Size = UDim2.fromScale(0.84, 0.16)
	local shineCorner = Kit.Corner(shine, 0)
	shineCorner.CornerRadius = UDim.new(0.5, 0)
	shine.Parent = top
	local glyphName = props.GlyphName
	local inkGlyph: GuiObject? = nil
	if glyphName and UiAssets.GlyphAtlas ~= "" and glyphCells[glyphName] then
		local ink = Kit.Glyph(top, glyphName, 10, line)
		ink.AnchorPoint = Vector2.new(0.5, 0.5)
		ink.Position = UDim2.fromScale(0.5, 0.5)
		ink.Size = UDim2.fromScale(0.78, 0.78)
		if ink:IsA("ImageLabel") then
			ink.ImageTransparency = 0.15
		end
		inkGlyph = ink
	end
	local letter = Kit.Label({
		Parent = top,
		Name = "Glyph",
		Text = props.Glyph or "",
		Size = UDim2.fromScale(1, 1),
		TextSize = 34,
		Color = line,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	letter.Visible = inkGlyph == nil
	local function paint(color: Color3)
		base.BackgroundColor3 = Kit.Shade(color, -0.38)
		top.BackgroundColor3 = color
	end
	paint(props.Color)
	holder.Parent = props.Parent
	return {
		Instance = holder,
		SetColor = paint,
		SetGlyph = function(text: string, color: Color3?)
			letter.Text = text
			letter.TextColor3 = color or line
			letter.Visible = true
			if inkGlyph then
				inkGlyph.Visible = false
			end
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
		image.ImageTransparency = 0.72
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
	end
	holder.Parent = props.Parent
	return holder
end

function Kit.Bar(props: BarProps): Bar
	local value = math.clamp(props.Value or 0, 0, 1)
	local hasText = props.Text ~= nil and props.Text ~= ""
	local height = if hasText then 26 else 12
	local track = Instance.new("Frame")
	track.Name = props.Name or "Bar"
	track.BorderSizePixel = 0
	track.BackgroundColor3 = surface3
	track.Size = props.Size or UDim2.new(1, 0, 0, height)
	track.Position = props.Position or UDim2.new()
	track.AnchorPoint = props.AnchorPoint or Vector2.zero
	track.LayoutOrder = props.LayoutOrder or 0
	track.ClipsDescendants = true
	Kit.Corner(track, 999)
	Kit.Stroke(track, line, 2)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(value, 1)
	local fillColor = props.Color or green
	fill.BackgroundColor3 = fillColor
	Kit.Corner(fill, 999)
	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.BackgroundColor3 = Kit.Shade(fillColor, 0.25)
	gloss.BorderSizePixel = 0
	gloss.Size = UDim2.fromScale(1, 0.3)
	gloss.Parent = fill
	fill.Parent = track
	local label = Kit.Label({
		Parent = track,
		Name = "Text",
		Text = props.Text or "",
		Size = UDim2.fromScale(1, 1),
		TextSize = props.TextSize or 16,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
		Outline = hasText,
	})
	label.ZIndex = 3
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
			fill.BackgroundColor3 = color
			gloss.BackgroundColor3 = Kit.Shade(color, 0.25)
		end,
	}
end

local function buttonColors(color: Color3): (Color3, Color3)
	if color == gold or color == orange then
		return color, line
	end
	return fillSafe(color), white
end

function Kit.Button(trove: TroveInstance, props: ButtonProps): Button
	local baseColor = props.Color or green
	local textColorOverride = props.TextColor
	local isHero = props.Hero == true
	local isDisabled = false
	local isDown = false
	local isHover = false
	local isGlowing = false
	local isSelected = false
	local glowTween: Tween? = nil
	local size = props.Size or UDim2.fromOffset(140, Kit.ButtonHeight)
	local height = if size.Y.Offset > 0 then size.Y.Offset else Kit.ButtonHeight
	local radius = props.Radius or cardRadius
	local textSize = props.TextSize or (if isHero then 32 elseif height >= 52 then 22 else 16)
	local glyphSize = if isHero then 28 elseif height >= 52 then 24 else 20

	local root = Instance.new("TextButton")
	root.Name = props.Name or "Button"
	root.AutoButtonColor = false
	root.BorderSizePixel = 0
	root.BackgroundTransparency = 1
	root.Text = ""
	root.Size = size
	root.Position = props.Position or UDim2.new()
	root.AnchorPoint = props.AnchorPoint or Vector2.zero
	root.LayoutOrder = props.LayoutOrder or 0

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.BorderSizePixel = 0
	face.Size = UDim2.fromScale(1, 1)
	Kit.Corner(face, radius)
	local faceStroke = Kit.Stroke(face, line, 3)
	face.Parent = root

	local inner = Instance.new("Frame")
	inner.Name = "Inner"
	inner.BorderSizePixel = 0
	inner.Size = UDim2.new(1, 0, 1, -4)
	Kit.Corner(inner, radius)
	inner.Parent = face

	local shards: ImageLabel? = nil
	if isHero or props.Shards == true then
		shards = Kit.Shards(inner, radius)
	end

	local highlight = Instance.new("Frame")
	highlight.Name = "Highlight"
	highlight.BackgroundColor3 = white
	highlight.BackgroundTransparency = 0.8
	highlight.BorderSizePixel = 0
	highlight.Position = UDim2.fromOffset(4, 3)
	highlight.Size = UDim2.new(1, -8, 0.15, 0)
	Kit.Corner(highlight, 99)
	highlight.Parent = inner

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Size = UDim2.fromScale(1, 1)
	local contentList = Instance.new("UIListLayout")
	contentList.FillDirection = Enum.FillDirection.Horizontal
	contentList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	contentList.VerticalAlignment = Enum.VerticalAlignment.Center
	contentList.SortOrder = Enum.SortOrder.LayoutOrder
	contentList.Padding = UDim.new(0, 8)
	contentList.Parent = content
	local contentPadding = Instance.new("UIPadding")
	contentPadding.PaddingLeft = UDim.new(0, if isHero then 24 else 8)
	contentPadding.PaddingRight = UDim.new(0, if isHero then 24 else 8)
	contentPadding.Parent = content
	content.Parent = inner

	local hasText = props.Text ~= nil and props.Text ~= ""
	local glyphName = props.GlyphName
	local glyphObject: GuiObject? = nil
	if glyphName then
		glyphObject = Kit.Glyph(content, glyphName, if hasText then glyphSize else math.floor(height / 2))
	elseif props.Icon then
		glyphObject = Kit.Label({
			Parent = content,
			Name = "Glyph",
			Text = props.Icon,
			Size = UDim2.fromOffset(glyphSize, glyphSize),
			TextSize = glyphSize,
			Align = Enum.TextXAlignment.Center,
			Scaled = true,
			Outline = false,
		})
	end
	if glyphObject then
		glyphObject.LayoutOrder = 1
	end
	local text = Kit.Label({
		Parent = content,
		Name = "Text",
		Text = props.Text or "",
		Size = UDim2.fromOffset(0, height - 8),
		LayoutOrder = 2,
		TextSize = textSize,
		Align = Enum.TextXAlignment.Center,
		Outline = isHero,
	})
	text.AutomaticSize = Enum.AutomaticSize.X
	text.TextTruncate = Enum.TextTruncate.None
	text.Active = false
	text.Visible = hasText
	root.Parent = props.Parent

	local function paint()
		local fill, textColor = buttonColors(baseColor)
		if textColorOverride then
			textColor = textColorOverride
		end
		local lip: Color3
		if isDisabled then
			fill = theme.Disabled
			lip = theme.DisabledLip
			textColor = theme.DisabledText
		else
			if isHover and not isDown then
				fill = Kit.Shade(fill, 0.1)
			end
			lip = Kit.Shade(fill, -0.3)
		end
		face.BackgroundColor3 = lip
		inner.BackgroundColor3 = fill
		text.TextColor3 = textColor
		local stroke = text:FindFirstChild("TextStroke")
		if stroke and stroke:IsA("UIStroke") then
			stroke.Enabled = not isDisabled
		end
		if glyphObject then
			if glyphObject:IsA("ImageLabel") then
				glyphObject.ImageColor3 = textColor
			elseif glyphObject:IsA("TextLabel") then
				glyphObject.TextColor3 = textColor
			end
		end
		highlight.Visible = not isDisabled
		if shards then
			shards.Visible = not isDisabled
		end
		local goal = if isDown and not isDisabled
			then { Position = UDim2.fromOffset(0, 3), Size = UDim2.new(1, 0, 1, -3) }
			else { Position = UDim2.new(), Size = UDim2.new(1, 0, 1, -4) }
		Kit.Tween(inner, pressInfo, goal)
	end
	paint()

	local function applyStroke()
		if isGlowing then
			return
		end
		faceStroke.Color = if isSelected then white else line
		faceStroke.Thickness = if isSelected then 4 else 3
	end

	local function release()
		if isDown then
			isDown = false
			paint()
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
		paint()
		if props.Immediate == true then
			fire()
		end
	end)
	trove:Connect(root.MouseButton1Up, release)
	trove:Connect(root.MouseEnter, function()
		if UserInputService:GetLastInputType() == Enum.UserInputType.MouseMovement then
			isHover = true
			paint()
		end
	end)
	trove:Connect(root.MouseLeave, function()
		isDown = false
		isHover = false
		paint()
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
		Content = content,
		SetDisabled = function(disabled: boolean)
			if disabled == isDisabled then
				return
			end
			isDisabled = disabled
			if disabled then
				isDown = false
			end
			paint()
		end,
		SetText = function(value: string)
			text.Text = value
			text.Visible = value ~= ""
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
				glowTween = TweenService:Create(faceStroke, loop, { Thickness = 6 })
				if glowTween then
					glowTween:Play()
				end
			else
				faceStroke.Thickness = 3
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
		GlyphName = "close",
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.new(1, -13, 0, 13),
		AnchorPoint = Vector2.new(1, 0),
		Color = red,
		Callback = onClose,
		Sound = sound,
	})
end

function Kit.Tooltip(props: TooltipProps): Frame
	local isLarge = props.Large == true
	local isLeft = props.Side == "Left"
	local holder = Instance.new("Frame")
	holder.Name = props.Name or "Tooltip"
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.AutomaticSize = Enum.AutomaticSize.X
	holder.Size = UDim2.fromOffset(0, if isLarge then 48 else 40)
	holder.Position = props.Position or UDim2.new()
	holder.AnchorPoint = props.AnchorPoint or Vector2.zero
	local notch = Instance.new("Frame")
	notch.Name = "Notch"
	notch.BackgroundColor3 = surface
	notch.BorderSizePixel = 0
	notch.Size = UDim2.fromOffset(12, 12)
	notch.Rotation = 45
	notch.AnchorPoint = Vector2.new(0.5, 0.5)
	notch.Position = if isLeft then UDim2.new(0, -3, 0.5, 0) else UDim2.new(0, 26, 1, 3)
	Kit.Stroke(notch, line, 3)
	notch.Parent = holder
	local body = Kit.Panel({
		Parent = holder,
		Name = "Body",
		Size = UDim2.fromScale(0, 1),
		Color = surface,
		StrokeThickness = 3,
	})
	body.AutomaticSize = Enum.AutomaticSize.X
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 8)
	list.Parent = body
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, if isLarge then 16 else 12)
	padding.PaddingRight = UDim.new(0, if isLarge then 16 else 12)
	padding.Parent = body
	local glyphName = props.GlyphName
	if glyphName then
		local glyph = Kit.Glyph(body, glyphName, if isLarge then 20 else 18, props.GlyphColor or green)
		glyph.LayoutOrder = 1
	end
	local label = Kit.Label({
		Parent = body,
		Name = "Text",
		Text = props.Text,
		Size = UDim2.fromOffset(0, 24),
		LayoutOrder = 2,
		TextSize = if isLarge then 16 else 13,
		Body = not isLarge,
	})
	label.AutomaticSize = Enum.AutomaticSize.X
	label.TextTruncate = Enum.TextTruncate.None
	holder.Parent = props.Parent
	return holder
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
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = muted
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, props.Padding or 8)
	list.Parent = scroll
	local padding = Instance.new("UIPadding")
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 4)
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
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = muted
	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.CellSize = props.CellSize
	grid.CellPadding = props.CellPadding or UDim2.fromOffset(8, 8)
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
	hit.Size = props.Size or UDim2.new(1, 0, 0, 32)
	hit.Position = props.Position or UDim2.new()
	hit.AnchorPoint = props.AnchorPoint or Vector2.zero
	hit.LayoutOrder = props.LayoutOrder or 0
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BorderSizePixel = 0
	track.BackgroundColor3 = surface3
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0, 12, 0.5, 0)
	track.Size = UDim2.new(1, -24, 0, 8)
	Kit.Corner(track, 4)
	Kit.Stroke(track, line, 2)
	track.Parent = hit
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = props.Color or green
	fill.Size = UDim2.fromScale(value, 1)
	Kit.Corner(fill, 4)
	fill.Parent = track
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.BorderSizePixel = 0
	knob.BackgroundColor3 = white
	knob.Size = UDim2.fromOffset(24, 24)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(value, 0.5)
	knob.ZIndex = 2
	Kit.Corner(knob, 12)
	Kit.Stroke(knob, line, 3)
	knob.Parent = track
	hit.Parent = props.Parent

	local function show(newValue: number)
		value = math.clamp(newValue, 0, 1)
		fill.Size = UDim2.fromScale(value, 1)
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
	button.Text = ""
	button.Size = UDim2.fromOffset(56, 32)
	button.Position = props.Position or UDim2.new()
	button.AnchorPoint = props.AnchorPoint or Vector2.zero
	button.LayoutOrder = props.LayoutOrder or 0
	Kit.Corner(button, 16)
	Kit.Stroke(button, line, 2)
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.BorderSizePixel = 0
	knob.BackgroundColor3 = white
	knob.Size = UDim2.fromOffset(24, 24)
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.Position = UDim2.new(0, 2, 0.5, 0)
	Kit.Corner(knob, 12)
	Kit.Stroke(knob, line, 2)
	knob.Parent = button
	button.Parent = props.Parent

	local function show(animate: boolean)
		button.BackgroundColor3 = if isOn then fillSafe(green) else surface3
		local goal = if isOn then UDim2.new(1, -26, 0.5, 0) else UDim2.new(0, 2, 0.5, 0)
		if animate then
			Kit.Tween(knob, slideInfo, { Position = goal })
		else
			knob.Position = goal
		end
	end
	show(false)

	trove:Connect(button.Activated, function()
		isOn = not isOn
		show(true)
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
				show(false)
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

function Kit.Modal(trove: TroveInstance, props: ModalProps): Modal
	local gui, root = Kit.ScreenGui(`Thock{props.Name}`, 10, props.Parent, trove)
	gui.Enabled = false
	local token = 0
	local accent = props.HeaderColor or blue
	local headerHeight = Kit.HeaderHeight
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.AutoButtonColor = false
	backdrop.BackgroundColor3 = line
	backdrop.BackgroundTransparency = 0.36
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

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.BackgroundColor3 = line
	shadow.BorderSizePixel = 0
	shadow.Position = UDim2.fromOffset(0, 6)
	shadow.Size = UDim2.fromScale(1, 1)
	Kit.Corner(shadow, windowRadius)
	Kit.Stroke(shadow, line, 3)
	shadow.Parent = window

	local surfaceFrame = Instance.new("Frame")
	surfaceFrame.Name = "Surface"
	surfaceFrame.BackgroundColor3 = surface
	surfaceFrame.BorderSizePixel = 0
	surfaceFrame.Size = UDim2.fromScale(1, 1)
	Kit.Corner(surfaceFrame, windowRadius)
	Kit.Stroke(surfaceFrame, line, 3)
	surfaceFrame.Parent = window

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(0, headerHeight)
	body.Size = UDim2.new(1, 0, 1, -headerHeight)
	body.Parent = window
	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.Size = UDim2.fromScale(1, 1)
	local contentPadding = Instance.new("UIPadding")
	contentPadding.PaddingTop = UDim.new(0, Kit.WindowPadding)
	contentPadding.PaddingBottom = UDim.new(0, Kit.WindowPadding)
	contentPadding.PaddingLeft = UDim.new(0, Kit.WindowPadding)
	contentPadding.PaddingRight = UDim.new(0, Kit.WindowPadding)
	contentPadding.Parent = content
	content.Parent = body

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundColor3 = accent
	header.BorderSizePixel = 0
	header.Size = UDim2.new(1, 0, 0, headerHeight)
	Kit.Corner(header, windowRadius)
	header.Parent = window
	local squareHeader = Instance.new("Frame")
	squareHeader.Name = "Square"
	squareHeader.BackgroundColor3 = accent
	squareHeader.BorderSizePixel = 0
	squareHeader.Position = UDim2.fromOffset(0, headerHeight / 2)
	squareHeader.Size = UDim2.new(1, 0, 0, headerHeight / 2)
	squareHeader.Parent = header
	Kit.Shards(header, windowRadius)
	local band = Instance.new("Frame")
	band.Name = "Highlight"
	band.BackgroundColor3 = white
	band.BackgroundTransparency = 0.82
	band.BorderSizePixel = 0
	band.Position = UDim2.fromOffset(6, 3)
	band.Size = UDim2.new(1, -12, 0, 8)
	Kit.Corner(band, 4)
	band.Parent = header
	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.BackgroundColor3 = line
	rule.BorderSizePixel = 0
	rule.Position = UDim2.new(0, 0, 1, -3)
	rule.Size = UDim2.new(1, 0, 0, 3)
	rule.Parent = header

	local iconName = props.IconName
	local emoji = props.Icon or ""
	if not iconName then
		if emoji == "🛒" and props.IconAsset ~= nil then
			iconName = "upgrades"
		else
			iconName = legacyIconNames[emoji]
		end
	end
	local iconSize = UDim2.fromOffset(72, 72)
	local iconPosition = UDim2.fromOffset(-8, -12)
	local icon: GuiObject
	if iconName and Kit.HasIcon(iconName) then
		icon = Kit.Icon(window, iconName, 72)
		icon.Position = iconPosition
	else
		icon = emojiLabel(
			window,
			"Icon",
			if emoji ~= "" then emoji else (fallbackEmoji[iconName or ""] or "•"),
			iconSize,
			iconPosition,
			nil,
			nil
		)
	end
	icon.Name = "Icon"
	icon.ZIndex = 3
	local title = Kit.Label({
		Parent = header,
		Name = "Title",
		Text = props.Title,
		Position = UDim2.fromOffset(77, 0),
		Size = UDim2.new(0.5, -77, 1, -3),
		TextSize = 32,
		Outline = true,
	})
	title.ZIndex = 2
	local headerRight = Instance.new("Frame")
	headerRight.Name = "HeaderRight"
	headerRight.BackgroundTransparency = 1
	headerRight.BorderSizePixel = 0
	headerRight.AnchorPoint = Vector2.new(1, 0.5)
	headerRight.Position = UDim2.new(1, -(13 + 44 + 8), 0.5, -1)
	headerRight.Size = UDim2.new(0.5, -(13 + 44 + 16), 1, -8)
	headerRight.ZIndex = 2
	local rightList = Instance.new("UIListLayout")
	rightList.FillDirection = Enum.FillDirection.Horizontal
	rightList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	rightList.VerticalAlignment = Enum.VerticalAlignment.Center
	rightList.SortOrder = Enum.SortOrder.LayoutOrder
	rightList.Padding = UDim.new(0, 8)
	rightList.Parent = headerRight
	headerRight.Parent = header
	local closeButton = Kit.CloseButton(trove, header, props.OnClose, props.Sound)
	closeButton.Instance.ZIndex = 3

	return {
		Gui = gui,
		Root = root,
		Panel = window,
		Body = body,
		Content = content,
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
