--!strict

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Trove = require(game:GetService("ReplicatedStorage").Packages.Trove)

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

export type ButtonProps = {
	Parent: Instance,
	Name: string?,
	Text: string?,
	Icon: string?,
	IconSize: number?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Color: Color3?,
	TextColor: Color3?,
	TextSize: number?,
	Radius: number?,
	Lip: number?,
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
	Show: () -> (),
	Hide: () -> (),
}

local theme = {
	Ink = Color3.fromRGB(22, 18, 38),
	Panel = Color3.fromRGB(64, 54, 128),
	Deep = Color3.fromRGB(44, 36, 98),
	Raised = Color3.fromRGB(90, 80, 168),
	Text = Color3.fromRGB(255, 255, 255),
	TextDim = Color3.fromRGB(208, 202, 238),
	Good = Color3.fromRGB(96, 224, 84),
	Bad = Color3.fromRGB(255, 96, 96),
	Gold = Color3.fromRGB(255, 210, 64),
	Green = Color3.fromRGB(64, 200, 72),
	Blue = Color3.fromRGB(58, 142, 255),
	Purple = Color3.fromRGB(150, 92, 240),
	Grey = Color3.fromRGB(128, 132, 152),
	Red = Color3.fromRGB(238, 66, 66),
	Orange = Color3.fromRGB(255, 142, 32),
	Yellow = Color3.fromRGB(255, 200, 40),
	Disabled = Color3.fromRGB(112, 114, 132),
}

local Kit = {
	Theme = table.freeze(theme),
	Font = Enum.Font.FredokaOne,
	HeaderHeight = 64,
	ButtonHeight = 56,
	TouchSize = 48,
}

local pressInfo = TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local springInfo = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local quick = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local popInfo = TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local closeInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local white = Color3.new(1, 1, 1)
local black = Color3.new(0, 0, 0)

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
	corner.CornerRadius = UDim.new(0, radius or 12)
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

function Kit.TextStroke(parent: Instance, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Name = "TextStroke"
	stroke.Color = theme.Ink
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
	gradient.Color = ColorSequence.new(Kit.Shade(color, 0.28), Kit.Shade(color, -0.16))
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
	local frame = Instance.new("Frame")
	frame.Name = props.Name or "Panel"
	frame.BackgroundTransparency = props.Transparency or 0
	frame.BorderSizePixel = 0
	frame.Size = props.Size or UDim2.fromScale(1, 1)
	frame.Position = props.Position or UDim2.new()
	frame.AnchorPoint = props.AnchorPoint or Vector2.zero
	frame.LayoutOrder = props.LayoutOrder or 0
	Kit.Paint(frame, props.Color or theme.Panel)
	Kit.Corner(frame, props.Radius or 14)
	Kit.Stroke(frame, props.StrokeColor, props.StrokeThickness or 3)
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
		Kit.TextStroke(label, if textSize >= 26 then 3 else 2)
	end
	label.Parent = props.Parent
	return label
end

function Kit.Button(trove: TroveInstance, props: ButtonProps): Button
	local baseColor = props.Color or theme.Green
	local baseTextColor = props.TextColor or theme.Text
	local lip = props.Lip or 5
	local radius = props.Radius or 12
	local isDisabled = false
	local isDown = false
	local isHover = false
	local glowTween: Tween? = nil

	local root = Instance.new("TextButton")
	root.Name = props.Name or "Button"
	root.AutoButtonColor = false
	root.BorderSizePixel = 0
	root.BackgroundTransparency = 1
	root.Text = ""
	root.Size = props.Size or UDim2.fromOffset(140, Kit.ButtonHeight + lip)
	root.Position = props.Position or UDim2.new()
	root.AnchorPoint = props.AnchorPoint or Vector2.zero
	root.LayoutOrder = props.LayoutOrder or 0

	local lipFrame = Instance.new("Frame")
	lipFrame.Name = "Lip"
	lipFrame.BorderSizePixel = 0
	lipFrame.Position = UDim2.new(0, 0, 0, lip)
	lipFrame.Size = UDim2.new(1, 0, 1, -lip)
	Kit.Corner(lipFrame, radius)
	Kit.Stroke(lipFrame, theme.Ink, 3)
	lipFrame.Parent = root

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.BorderSizePixel = 0
	face.Size = UDim2.new(1, 0, 1, -lip)
	Kit.Corner(face, radius)
	local faceStroke = Kit.Stroke(face, theme.Ink, 3)
	face.Parent = root

	local hasIcon = props.Icon ~= nil
	if hasIcon then
		Kit.Label({
			Parent = face,
			Name = "Icon",
			Text = props.Icon,
			Position = UDim2.fromScale(0, 0.04),
			Size = UDim2.fromScale(1, 0.56),
			TextSize = props.IconSize or 34,
			Align = Enum.TextXAlignment.Center,
			Scaled = true,
			Outline = false,
		})
	end
	local text = Kit.Label({
		Parent = face,
		Name = "Text",
		Text = props.Text or "",
		Position = if hasIcon then UDim2.fromScale(0, 0.58) else UDim2.fromOffset(6, 2),
		Size = if hasIcon then UDim2.fromScale(1, 0.36) else UDim2.new(1, -12, 1, -4),
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
		lipFrame.BackgroundColor3 = Kit.Shade(color, -0.45)
		text.TextColor3 = if isDisabled then theme.TextDim else baseTextColor
	end
	paint()

	local function settle()
		local goal = if isDown then 0.92 elseif isHover then 1.06 else 1
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
			if isOn then
				faceStroke.Color = Color3.fromRGB(200, 255, 190)
				local loop = TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
				glowTween = TweenService:Create(faceStroke, loop, { Thickness = 6 })
				if glowTween then
					glowTween:Play()
				end
			else
				faceStroke.Color = theme.Ink
				faceStroke.Thickness = 3
			end
		end,
	}
end

function Kit.IconButton(trove: TroveInstance, props: ButtonProps): Button
	local size = props.Size or UDim2.fromOffset(Kit.ButtonHeight + 5, Kit.ButtonHeight + 5)
	return Kit.Button(trove, {
		Parent = props.Parent,
		Name = props.Name,
		Text = props.Text,
		Size = size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		Color = props.Color,
		TextColor = props.TextColor,
		TextSize = props.TextSize or 28,
		Radius = props.Radius or 14,
		Callback = props.Callback,
		Sound = props.Sound,
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
	grid.CellPadding = props.CellPadding or UDim2.fromOffset(10, 12)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = scroll
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 12)
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
	hit.Size = props.Size or UDim2.new(1, 0, 0, 52)
	hit.Position = props.Position or UDim2.new()
	hit.AnchorPoint = props.AnchorPoint or Vector2.zero
	hit.LayoutOrder = props.LayoutOrder or 0
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BorderSizePixel = 0
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0, 20, 0.5, 0)
	track.Size = UDim2.new(1, -40, 0, 20)
	Kit.Paint(track, theme.Deep)
	Kit.Corner(track, 10)
	Kit.Stroke(track, theme.Ink, 3)
	track.Parent = hit
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(value, 1)
	Kit.Paint(fill, props.Color or theme.Green)
	Kit.Corner(fill, 10)
	fill.Parent = track
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.BackgroundColor3 = theme.Text
	knob.BorderSizePixel = 0
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(36, 36)
	knob.Position = UDim2.fromScale(value, 0.5)
	Kit.Corner(knob, 18)
	Kit.Stroke(knob, theme.Ink, 3)
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
	button.Size = UDim2.fromOffset(104, 52)
	button.Position = props.Position or UDim2.new()
	button.AnchorPoint = props.AnchorPoint or Vector2.zero
	button.LayoutOrder = props.LayoutOrder or 0
	Kit.Corner(button, 26)
	Kit.Stroke(button, theme.Ink, 3)
	local state = Kit.Label({
		Parent = button,
		Name = "State",
		Text = "OFF",
		Size = UDim2.new(0, 56, 1, 0),
		TextSize = 22,
		Align = Enum.TextXAlignment.Center,
	})
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.BackgroundColor3 = theme.Text
	knob.BorderSizePixel = 0
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(38, 38)
	Kit.Corner(knob, 19)
	Kit.Stroke(knob, theme.Ink, 3)
	knob.Parent = button
	local pressScale = Instance.new("UIScale")
	pressScale.Parent = button
	button.Parent = props.Parent

	local function show(animate: boolean)
		local color = if isOn then theme.Green else theme.Disabled
		local position = if isOn then UDim2.new(1, -28, 0.5, 0) else UDim2.new(0, 28, 0.5, 0)
		state.Text = if isOn then "ON" else "OFF"
		state.Position = if isOn then UDim2.new() else UDim2.new(1, -56, 0, 0)
		Kit.Paint(button, color)
		if animate then
			Kit.Tween(knob, quick, { Position = position })
		else
			knob.Position = position
		end
	end
	show(false)

	trove:Connect(button.MouseButton1Down, function()
		Kit.Tween(pressScale, pressInfo, { Scale = 0.92 })
	end)
	trove:Connect(button.MouseLeave, function()
		Kit.Tween(pressScale, springInfo, { Scale = 1 })
	end)
	trove:Connect(button.Activated, function()
		isOn = not isOn
		show(true)
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
				show(true)
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
	Kit.Tween(scale, reverse, { Scale = 1.06 })
	local stroke = target:FindFirstChild("Stroke")
	if stroke and stroke:IsA("UIStroke") then
		Kit.Tween(stroke, reverse, { Color = color or theme.Good })
	end
end

function Kit.Shake(target: GuiObject)
	task.spawn(function()
		for _, rotation in { 4, -4, 3, -3, 0 } do
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
	local headerColor = props.HeaderColor or theme.Blue
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.AutoButtonColor = false
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.5
	backdrop.BorderSizePixel = 0
	backdrop.Text = ""
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Parent = root
	trove:Connect(backdrop.Activated, props.OnClose)

	local panel = Kit.Panel({
		Parent = root,
		Name = "Panel",
		Size = UDim2.fromScale(0.92, 0.9),
		Position = UDim2.fromScale(0.5, 0.52),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Radius = 16,
		StrokeThickness = 4,
	})
	panel.Active = true
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = props.MaxSize
	constraint.Parent = panel
	local pop = Instance.new("UIScale")
	pop.Name = "Pop"
	pop.Parent = panel

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BorderSizePixel = 0
	header.Size = UDim2.new(1, 0, 0, Kit.HeaderHeight)
	Kit.Paint(header, headerColor)
	Kit.Corner(header, 16)
	header.Parent = panel
	local filler = Instance.new("Frame")
	filler.Name = "Filler"
	filler.BorderSizePixel = 0
	filler.Position = UDim2.new(0, 0, 1, -16)
	filler.Size = UDim2.new(1, 0, 0, 16)
	filler.BackgroundColor3 = Kit.Shade(headerColor, -0.16)
	filler.Parent = header
	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.BorderSizePixel = 0
	divider.BackgroundColor3 = theme.Ink
	divider.Position = UDim2.new(0, 0, 1, 0)
	divider.Size = UDim2.new(1, 0, 0, 3)
	divider.Parent = header
	Kit.Label({
		Parent = header,
		Name = "Title",
		Text = props.Title,
		Position = UDim2.fromOffset(16, 0),
		Size = UDim2.new(1, -80, 1, 0),
		TextSize = 36,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.BackgroundTransparency = 1
	body.BorderSizePixel = 0
	body.Position = UDim2.fromOffset(0, Kit.HeaderHeight + 3)
	body.Size = UDim2.new(1, 0, 1, -(Kit.HeaderHeight + 3))
	body.Parent = panel
	Kit.IconButton(trove, {
		Parent = panel,
		Name = "Close",
		Text = "X",
		Size = UDim2.fromOffset(52, 57),
		Position = UDim2.new(1, -2, 0, 4),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = theme.Red,
		Radius = 26,
		Callback = props.OnClose,
		Sound = props.Sound,
	})

	return {
		Gui = gui,
		Root = root,
		Panel = panel,
		Body = body,
		Show = function()
			token += 1
			pop.Scale = 0.8
			gui.Enabled = true
			Kit.Tween(pop, popInfo, { Scale = 1 })
		end,
		Hide = function()
			if not gui.Enabled then
				return
			end
			token += 1
			local mine = token
			local closing = Kit.Tween(pop, closeInfo, { Scale = 0.8 })
			closing.Completed:Once(function()
				if token == mine then
					gui.Enabled = false
				end
			end)
		end,
	}
end

return Kit
