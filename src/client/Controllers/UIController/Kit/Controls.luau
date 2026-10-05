--!strict

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local Core = require(script.Parent.Core)
local Theme = require(script.Parent.Theme)

type TroveInstance = typeof(Trove.new())
type SoundPlayer = (name: string) -> ()

export type ButtonProps = {
	Parent: Instance,
	Name: string?,
	Text: string?,
	Glyph: string?,
	IconAsset: string?,
	IconLeft: boolean?,
	IconColor: Color3?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Color: Color3?,
	TextColor: Color3?,
	TextSize: number?,
	Radius: number?,
	Lip: number?,
	Title: boolean?,
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
	SetIconVisible: (isVisible: boolean) -> (),
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

export type Tab = {
	Id: string,
	Text: string,
	Glyph: string?,
	Color: Color3,
}

export type TabBarProps = {
	Parent: Instance,
	Name: string?,
	Tabs: { Tab },
	Selected: string?,
	Size: UDim2?,
	Position: UDim2?,
	LayoutOrder: number?,
	TextSize: number?,
	OnSelect: (id: string) -> (),
	Sound: SoundPlayer?,
}

export type TabBar = {
	Instance: Frame,
	Buttons: { [string]: Button },
	Select: (id: string) -> (),
}

local colors = Theme.Colors
local white = Color3.new(1, 1, 1)
local pressInfo = TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local springInfo = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local knobInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local Controls = {
	ButtonHeight = 52,
	TouchSize = 48,
}

function Controls.Tween(target: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local created = TweenService:Create(target, info, goal)
	created:Play()
	return created
end

function Controls.Button(trove: TroveInstance, props: ButtonProps): Button
	local baseColor = props.Color or colors.Green
	local baseTextColor = props.TextColor or colors.Text
	local lipDepth = props.Lip or Theme.LipDepth
	local radius = props.Radius or Theme.Radius.M
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
	root.Size = props.Size or UDim2.fromOffset(140, Controls.ButtonHeight)
	root.Position = props.Position or UDim2.new()
	root.AnchorPoint = props.AnchorPoint or Vector2.zero
	root.LayoutOrder = props.LayoutOrder or 0

	local lip = Instance.new("Frame")
	lip.Name = "Lip"
	lip.BorderSizePixel = 0
	lip.Size = UDim2.fromScale(1, 1)
	Core.Corner(lip, radius)
	local outline = Core.Stroke(lip, colors.Ink, Theme.Stroke.Normal)
	lip.Parent = root

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.BorderSizePixel = 0
	face.Size = UDim2.new(1, 0, 1, -lipDepth)
	Core.Corner(face, radius)
	Core.Stroke(face, colors.Ink, Theme.Stroke.Thin)
	Core.Gloss(face, radius)
	face.Parent = root

	local iconInstance: GuiObject? = nil
	local hasIcon = props.Glyph ~= nil or props.IconAsset ~= nil
	local isLeft = props.IconLeft == true
	local isIconOnly = hasIcon and (props.Text == nil or props.Text == "")
	if hasIcon then
		local icon = Core.Icon({
			Parent = face,
			Name = "Icon",
			Glyph = props.Glyph,
			Asset = props.IconAsset,
			Color = props.IconColor,
			Size = if isIconOnly
				then UDim2.fromScale(0.66, 0.66)
				elseif isLeft then UDim2.fromScale(0, 0.8)
				else UDim2.fromScale(1, 0.58),
			Position = if isIconOnly
				then UDim2.fromScale(0.17, 0.17)
				elseif isLeft then UDim2.new(0, Theme.Space.S, 0.5, 0)
				else UDim2.fromScale(0, 0.05),
			AnchorPoint = if isLeft and not isIconOnly then Vector2.new(0, 0.5) else Vector2.zero,
		})
		iconInstance = icon
		if isLeft and not isIconOnly then
			local ratio = Instance.new("UIAspectRatioConstraint")
			ratio.AspectRatio = 1
			ratio.DominantAxis = Enum.DominantAxis.Height
			ratio.Parent = icon
		end
	end
	local text = Core.Label({
		Parent = face,
		Name = "Text",
		Text = props.Text or "",
		Position = if hasIcon and isLeft
			then UDim2.new(0.2, 0, 0, 2)
			elseif hasIcon then UDim2.fromScale(0, 0.6)
			else UDim2.fromOffset(6, 2),
		Size = if hasIcon and isLeft
			then UDim2.new(0.8, -8, 1, -4)
			elseif hasIcon then UDim2.fromScale(1, 0.36)
			else UDim2.new(1, -12, 1, -4),
		TextSize = props.TextSize or 24,
		Color = baseTextColor,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
		Title = props.Title,
	})
	text.Active = false

	local pressScale = Instance.new("UIScale")
	pressScale.Name = "PressScale"
	pressScale.Parent = root
	root.Parent = props.Parent

	local function paint()
		local color = if isDisabled then colors.Disabled else baseColor
		Core.Paint(face, color)
		lip.BackgroundColor3 = Theme.Shade(color, -0.42)
		text.TextColor3 = if isDisabled then colors.TextDim else baseTextColor
	end
	paint()

	local function applyOutline()
		if isGlowing then
			return
		end
		outline.Color = if isSelected then white else colors.Ink
		outline.Thickness = if isSelected then 4.5 else Theme.Stroke.Normal
	end

	local function settle()
		local goal = if isDown then 0.97 elseif isHover then 1.05 else 1
		Controls.Tween(pressScale, if isDown then pressInfo else springInfo, { Scale = goal })
		local drop = if isDown and not isDisabled then Theme.PressDrop else 0
		Controls.Tween(
			face,
			if isDown then pressInfo else springInfo,
			{ Position = UDim2.fromOffset(0, drop) }
		)
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
				outline.Color = Color3.fromRGB(255, 240, 150)
				local loop = TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
				glowTween = TweenService:Create(outline, loop, { Thickness = 5.5 })
				if glowTween then
					glowTween:Play()
				end
			else
				applyOutline()
			end
		end,
		SetSelected = function(isOn: boolean)
			isSelected = isOn
			applyOutline()
		end,
		SetIconVisible = function(isVisible: boolean)
			local icon = iconInstance
			if icon then
				icon.Visible = isVisible
			end
		end,
	}
end

function Controls.CloseButton(
	trove: TroveInstance,
	parent: Instance,
	onClose: () -> (),
	sound: SoundPlayer?
): Button
	return Controls.Button(trove, {
		Parent = parent,
		Name = "Close",
		Glyph = "Close",
		Size = UDim2.fromOffset(46, 46),
		Position = UDim2.new(1, 12, 0, -14),
		AnchorPoint = Vector2.new(1, 0),
		Color = colors.Red,
		Radius = 23,
		Callback = onClose,
		Sound = sound,
	})
end

local function styleScroll(scroll: ScrollingFrame)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = colors.Gold
end

function Controls.Scroll(props: ScrollProps): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = props.Name or "Scroll"
	scroll.Size = props.Size or UDim2.fromScale(1, 1)
	scroll.Position = props.Position or UDim2.new()
	scroll.AnchorPoint = props.AnchorPoint or Vector2.zero
	styleScroll(scroll)
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, props.Padding or Theme.Space.M)
	list.Parent = scroll
	local padding = Instance.new("UIPadding")
	padding.PaddingRight = UDim.new(0, Theme.Space.M)
	padding.PaddingTop = UDim.new(0, Theme.Space.S)
	padding.PaddingBottom = UDim.new(0, Theme.Space.M)
	padding.PaddingLeft = UDim.new(0, Theme.Space.S)
	padding.Parent = scroll
	scroll.Parent = props.Parent
	return scroll
end

function Controls.GridScroll(props: GridScrollProps): ScrollingFrame
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = props.Name or "Grid"
	scroll.Size = props.Size or UDim2.fromScale(1, 1)
	scroll.Position = props.Position or UDim2.new()
	styleScroll(scroll)
	local grid = Instance.new("UIGridLayout")
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.CellSize = props.CellSize
	grid.CellPadding = props.CellPadding or UDim2.fromOffset(Theme.Space.M, Theme.Space.M)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	grid.Parent = scroll
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, Theme.Space.S)
	padding.PaddingBottom = UDim.new(0, Theme.Space.M)
	padding.PaddingRight = UDim.new(0, Theme.Space.S)
	padding.Parent = scroll
	scroll.Parent = props.Parent
	return scroll
end

function Controls.Slider(trove: TroveInstance, props: SliderProps): Slider
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
	local bar = Core.Bar({
		Parent = hit,
		Name = "Track",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 16, 0.5, 0),
		Size = UDim2.new(1, -32, 0, 24),
		Color = props.Color or colors.Green,
		Value = value,
	})
	local track = bar.Instance
	track.ClipsDescendants = false
	local knob = Core.Panel({
		Parent = track,
		Name = "Knob",
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.fromScale(value, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = colors.Text,
		Radius = 17,
	})
	knob.ZIndex = 5
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

function Controls.Toggle(trove: TroveInstance, props: ToggleProps): Toggle
	local isOn = props.Value
	local button = Instance.new("TextButton")
	button.Name = props.Name or "Toggle"
	button.AutoButtonColor = false
	button.BorderSizePixel = 0
	button.BackgroundTransparency = 1
	button.Text = ""
	button.Size = UDim2.fromOffset(104, 46)
	button.Position = props.Position or UDim2.new()
	button.AnchorPoint = props.AnchorPoint or Vector2.zero
	button.LayoutOrder = props.LayoutOrder or 0
	local face = Core.Panel({
		Parent = button,
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		Color = colors.Disabled,
		Radius = 23,
	})
	local state = Core.Label({
		Parent = face,
		Name = "State",
		Text = "OFF",
		Size = UDim2.new(0, 48, 1, 0),
		TextSize = 22,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local knob = Core.Panel({
		Parent = face,
		Name = "Knob",
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.new(0, 5, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Color = colors.Text,
		Radius = 18,
	})
	knob.ZIndex = 3
	local pressScale = Instance.new("UIScale")
	pressScale.Parent = button
	button.Parent = props.Parent

	local function show()
		state.Text = if isOn then "ON" else "OFF"
		state.Position = if isOn then UDim2.fromOffset(6, 0) else UDim2.new(1, -54, 0, 0)
		Core.Paint(face, if isOn then colors.Green else colors.Red)
		knob.AnchorPoint = Vector2.new(if isOn then 1 else 0, 0.5)
		knob.Position = UDim2.new(if isOn then 1 else 0, if isOn then -5 else 5, 0.5, 0)
	end
	show()

	trove:Connect(button.MouseButton1Down, function()
		Controls.Tween(pressScale, pressInfo, { Scale = 0.94 })
	end)
	trove:Connect(button.MouseLeave, function()
		Controls.Tween(pressScale, springInfo, { Scale = 1 })
	end)
	trove:Connect(button.Activated, function()
		isOn = not isOn
		show()
		Controls.Tween(pressScale, springInfo, { Scale = 1 })
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

function Controls.TabBar(trove: TroveInstance, props: TabBarProps): TabBar
	local holder = Instance.new("Frame")
	holder.Name = props.Name or "Tabs"
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Size = props.Size or UDim2.new(1, 0, 0, 52)
	holder.Position = props.Position or UDim2.new()
	holder.LayoutOrder = props.LayoutOrder or 0
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, Theme.Space.S)
	list.Parent = holder
	holder.Parent = props.Parent
	local buttons: { [string]: Button } = {}
	local count = #props.Tabs
	local function select(id: string)
		for _, tab in props.Tabs do
			local button = buttons[tab.Id]
			local isSelected = tab.Id == id
			button.SetSelected(isSelected)
			button.SetColor(if isSelected then tab.Color else Theme.Shade(tab.Color, -0.5))
		end
	end
	for index, tab in props.Tabs do
		buttons[tab.Id] = Controls.Button(trove, {
			Parent = holder,
			Name = tab.Id,
			Text = tab.Text,
			Glyph = tab.Glyph,
			IconLeft = tab.Glyph ~= nil,
			Size = UDim2.new(1 / count, -Theme.Space.S, 1, 0),
			LayoutOrder = index,
			Color = tab.Color,
			TextSize = props.TextSize or 22,
			Callback = function()
				select(tab.Id)
				props.OnSelect(tab.Id)
			end,
			Sound = props.Sound,
		})
	end
	if props.Selected then
		select(props.Selected)
	end
	return { Instance = holder, Buttons = buttons, Select = select }
end

function Controls.Pulse(target: GuiObject, color: Color3?)
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
	Controls.Tween(scale, reverse, { Scale = 1.04 })
	local stroke = target:FindFirstChild("Stroke")
	if stroke and stroke:IsA("UIStroke") then
		Controls.Tween(stroke, reverse, { Color = color or colors.Good })
	end
end

function Controls.Shake(target: GuiObject)
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

return Controls
