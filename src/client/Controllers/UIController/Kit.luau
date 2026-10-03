--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Keys = require(ReplicatedStorage.Config.Keys)
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
	Bold: boolean?,
	Align: Enum.TextXAlignment?,
	VerticalAlign: Enum.TextYAlignment?,
	Wrapped: boolean?,
	RichText: boolean?,
}

export type ButtonProps = {
	Parent: Instance,
	Name: string?,
	Text: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Color: Color3?,
	TextColor: Color3?,
	TextSize: number?,
	Callback: (() -> ())?,
	Sound: SoundPlayer?,
}

export type Button = {
	Instance: TextButton,
	SetDisabled: (disabled: boolean) -> (),
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
	OnClose: () -> (),
	Sound: SoundPlayer?,
}

export type Modal = {
	Gui: ScreenGui,
	Root: Frame,
	Panel: Frame,
	Show: () -> (),
	Hide: () -> (),
}

local theme = {
	Background = Color3.fromRGB(22, 23, 28),
	Panel = Color3.fromRGB(34, 36, 44),
	Raised = Color3.fromRGB(48, 51, 61),
	Stroke = Color3.fromRGB(74, 78, 94),
	Text = Color3.fromRGB(240, 240, 245),
	TextDim = Color3.fromRGB(162, 166, 180),
	TextDark = Color3.fromRGB(20, 20, 24),
	Accent = Keys.RarityByName.Rare.Color,
	Good = Keys.RarityByName.Uncommon.Color,
	Bad = Color3.fromRGB(255, 90, 100),
	Gold = Keys.RarityByName.Legendary.Color,
	Disabled = Color3.fromRGB(56, 58, 68),
}

local Kit = {
	Theme = table.freeze(theme),
	HeaderHeight = 56,
	ButtonHeight = 60,
}

local quick = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function tween(target: Instance, info: TweenInfo, goal: { [string]: any })
	TweenService:Create(target, info, goal):Play()
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
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = parent
	return corner
end

function Kit.Stroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Color = color or theme.Stroke
	stroke.Thickness = thickness or 1.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
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
	local scale = Instance.new("UIScale")
	scale.Name = "ViewportScale"
	scale.Parent = gui
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Parent = gui
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
	frame.BackgroundColor3 = props.Color or theme.Panel
	frame.BackgroundTransparency = props.Transparency or 0
	frame.BorderSizePixel = 0
	frame.Size = props.Size or UDim2.fromScale(1, 1)
	frame.Position = props.Position or UDim2.new()
	frame.AnchorPoint = props.AnchorPoint or Vector2.zero
	frame.LayoutOrder = props.LayoutOrder or 0
	Kit.Corner(frame, props.Radius)
	Kit.Stroke(frame, props.StrokeColor)
	frame.Parent = props.Parent
	return frame
end

function Kit.Label(props: LabelProps): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = props.Name or "Label"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Size = props.Size or UDim2.new(1, 0, 0, 24)
	label.Position = props.Position or UDim2.new()
	label.AnchorPoint = props.AnchorPoint or Vector2.zero
	label.LayoutOrder = props.LayoutOrder or 0
	label.Font = if props.Bold == false then Enum.Font.Gotham else Enum.Font.GothamBold
	label.TextSize = props.TextSize or 18
	label.TextColor3 = props.Color or theme.Text
	label.TextXAlignment = props.Align or Enum.TextXAlignment.Left
	label.TextYAlignment = props.VerticalAlign or Enum.TextYAlignment.Center
	label.TextWrapped = props.Wrapped == true
	label.TextTruncate = if props.Wrapped == true then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd
	label.RichText = props.RichText == true
	label.Text = props.Text or ""
	label.Parent = props.Parent
	return label
end

function Kit.Button(trove: TroveInstance, props: ButtonProps): Button
	local baseColor = props.Color or theme.Raised
	local baseTextColor = props.TextColor or theme.Text
	local isDisabled = false
	local lastActivated = 0
	local button = Instance.new("TextButton")
	button.Name = props.Name or "Button"
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.BackgroundColor3 = baseColor
	button.Size = props.Size or UDim2.fromOffset(140, Kit.ButtonHeight)
	button.Position = props.Position or UDim2.new()
	button.AnchorPoint = props.AnchorPoint or Vector2.zero
	button.LayoutOrder = props.LayoutOrder or 0
	button.Font = Enum.Font.GothamBold
	button.TextSize = props.TextSize or 20
	button.TextColor3 = baseTextColor
	button.Text = props.Text or ""
	Kit.Corner(button, 10)
	Kit.Stroke(button, theme.Stroke, 1.5)
	local pressScale = Instance.new("UIScale")
	pressScale.Name = "PressScale"
	pressScale.Parent = button
	button.Parent = props.Parent

	local function apply()
		button.BackgroundColor3 = if isDisabled then theme.Disabled else baseColor
		button.TextColor3 = if isDisabled then theme.TextDim else baseTextColor
	end
	local function release()
		tween(pressScale, quick, { Scale = 1 })
	end
	trove:Connect(button.MouseButton1Down, function()
		if not isDisabled then
			tween(pressScale, quick, { Scale = 0.93 })
		end
	end)
	trove:Connect(button.MouseButton1Up, release)
	trove:Connect(button.MouseLeave, release)
	trove:Connect(button.Activated, function()
		if isDisabled then
			return
		end
		local now = os.clock()
		if now - lastActivated < 0.12 then
			return
		end
		lastActivated = now
		local sound = props.Sound
		if sound then
			sound("Click")
		end
		local callback = props.Callback
		if callback then
			callback()
		end
	end)

	return {
		Instance = button,
		SetDisabled = function(disabled: boolean)
			if disabled == isDisabled then
				return
			end
			isDisabled = disabled
			if disabled then
				release()
			end
			apply()
		end,
		SetText = function(text: string)
			button.Text = text
		end,
		SetColor = function(color: Color3)
			baseColor = color
			apply()
		end,
	}
end

function Kit.IconButton(trove: TroveInstance, props: ButtonProps): Button
	local iconProps: ButtonProps = {
		Parent = props.Parent,
		Name = props.Name,
		Text = props.Text,
		Size = props.Size or UDim2.fromOffset(Kit.ButtonHeight, Kit.ButtonHeight),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		Color = props.Color,
		TextColor = props.TextColor,
		TextSize = props.TextSize or 26,
		Callback = props.Callback,
		Sound = props.Sound,
	}
	return Kit.Button(trove, iconProps)
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
	scroll.ScrollBarImageColor3 = theme.Stroke
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, props.Padding or 8)
	list.Parent = scroll
	local padding = Instance.new("UIPadding")
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 4)
	padding.Parent = scroll
	scroll.Parent = props.Parent
	return scroll
end

function Kit.Grid(parent: Instance, name: string, cellSize: UDim2, cellPadding: UDim2, columns: number): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.CellSize = cellSize
	grid.CellPadding = cellPadding
	grid.FillDirectionMaxCells = columns
	grid.StartCorner = Enum.StartCorner.TopLeft
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.VerticalAlignment = Enum.VerticalAlignment.Center
	grid.Parent = frame
	frame.Parent = parent
	return frame
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
	hit.Size = props.Size or UDim2.new(1, 0, 0, 44)
	hit.Position = props.Position or UDim2.new()
	hit.AnchorPoint = props.AnchorPoint or Vector2.zero
	hit.LayoutOrder = props.LayoutOrder or 0
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = theme.Disabled
	track.BorderSizePixel = 0
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0, 16, 0.5, 0)
	track.Size = UDim2.new(1, -32, 0, 10)
	Kit.Corner(track, 5)
	track.Parent = hit
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = props.Color or theme.Accent
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(value, 1)
	Kit.Corner(fill, 5)
	fill.Parent = track
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.BackgroundColor3 = theme.Text
	knob.BorderSizePixel = 0
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(28, 28)
	knob.Position = UDim2.fromScale(value, 0.5)
	Kit.Corner(knob, 14)
	Kit.Stroke(knob, theme.Stroke, 1.5)
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
	button.Size = UDim2.fromOffset(96, 52)
	button.Position = props.Position or UDim2.new()
	button.AnchorPoint = props.AnchorPoint or Vector2.zero
	button.LayoutOrder = props.LayoutOrder or 0
	Kit.Corner(button, 26)
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.BackgroundColor3 = theme.Text
	knob.BorderSizePixel = 0
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(40, 40)
	Kit.Corner(knob, 20)
	knob.Parent = button
	button.Parent = props.Parent

	local function show(animate: boolean)
		local color = if isOn then theme.Good else theme.Disabled
		local position = if isOn then UDim2.new(1, -26, 0.5, 0) else UDim2.new(0, 26, 0.5, 0)
		if animate then
			tween(button, quick, { BackgroundColor3 = color })
			tween(knob, quick, { Position = position })
		else
			button.BackgroundColor3 = color
			knob.Position = position
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
	local reverse = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true)
	tween(scale, reverse, { Scale = 1.04 })
	local stroke = target:FindFirstChildOfClass("UIStroke")
	if stroke then
		tween(stroke, reverse, { Color = color or theme.Good, Thickness = 4 })
	end
end

function Kit.Shake(target: GuiObject)
	task.spawn(function()
		for _, rotation in { 3, -3, 2, -2, 0 } do
			if not target.Parent then
				return
			end
			target.Rotation = rotation
			task.wait(0.04)
		end
	end)
end

function Kit.Modal(trove: TroveInstance, props: ModalProps): Modal
	local gui, root = Kit.ScreenGui(`Thock{props.Name}`, 10, props.Parent, trove)
	gui.Enabled = false
	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.AutoButtonColor = false
	backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
	backdrop.BackgroundTransparency = 0.45
	backdrop.BorderSizePixel = 0
	backdrop.Text = ""
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Parent = root
	trove:Connect(backdrop.Activated, props.OnClose)

	local panel = Kit.Panel({
		Parent = root,
		Name = "Panel",
		Size = UDim2.fromScale(0.94, 0.94),
		Position = UDim2.fromScale(0.5, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
	})
	panel.Active = true
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = props.MaxSize
	constraint.Parent = panel
	local pop = Instance.new("UIScale")
	pop.Name = "Pop"
	pop.Parent = panel

	Kit.Label({
		Parent = panel,
		Name = "Title",
		Text = props.Title,
		Position = UDim2.fromOffset(18, 0),
		Size = UDim2.new(1, -90, 0, Kit.HeaderHeight),
		TextSize = 28,
	})
	Kit.IconButton(trove, {
		Parent = panel,
		Name = "Close",
		Text = "X",
		Size = UDim2.fromOffset(52, 52),
		Position = UDim2.new(1, -8, 0, 4),
		AnchorPoint = Vector2.new(1, 0),
		Color = theme.Raised,
		Callback = props.OnClose,
		Sound = props.Sound,
	})

	return {
		Gui = gui,
		Root = root,
		Panel = panel,
		Show = function()
			pop.Scale = 0.92
			gui.Enabled = true
			tween(pop, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		end,
		Hide = function()
			gui.Enabled = false
		end,
	}
end

return Kit
