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
	IconScale: number?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Color: Color3?,
	TextColor: Color3?,
	TextSize: number?,
	Radius: number?,
	Lip: number?,
	Pill: boolean?,
	Title: boolean?,
	Immediate: boolean?,
	Tooltip: string?,
	TooltipSide: string?,
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
	SetLocked: (isLocked: boolean) -> (),
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
local pressInfo = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local hoverInfo = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local springInfo = TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

local Controls = {
	ButtonHeight = 52,
	TouchSize = 48,
	CloseSize = 52,
}

function Controls.Tween(target: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local created = TweenService:Create(target, info, goal)
	created:Play()
	return created
end

local function buildTooltip(root: GuiObject, text: string, side: string): Frame
	local tip = Instance.new("Frame")
	tip.Name = "Tooltip"
	tip.BackgroundColor3 = colors.Ink
	tip.BorderSizePixel = 0
	tip.AutomaticSize = Enum.AutomaticSize.X
	tip.Size = UDim2.fromOffset(0, 34)
	tip.ZIndex = 20
	tip.Visible = false
	if side == "Left" then
		tip.AnchorPoint = Vector2.new(1, 0.5)
		tip.Position = UDim2.new(0, -12, 0.5, 0)
	elseif side == "Above" then
		tip.AnchorPoint = Vector2.new(0.5, 1)
		tip.Position = UDim2.new(0.5, 0, 0, -10)
	elseif side == "Below" then
		tip.AnchorPoint = Vector2.new(0.5, 0)
		tip.Position = UDim2.new(0.5, 0, 1, 10)
	else
		tip.AnchorPoint = Vector2.new(0, 0.5)
		tip.Position = UDim2.new(1, 12, 0.5, 0)
	end
	Core.Corner(tip, 10)
	local edge = Core.Stroke(tip, colors.Text, 2)
	edge.Transparency = 0.6
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.Parent = tip
	local label = Core.Label({
		Parent = tip,
		Name = "Text",
		Text = text,
		Size = UDim2.fromOffset(0, 34),
		TextSize = 17,
		Outline = false,
		Align = Enum.TextXAlignment.Center,
	})
	label.AutomaticSize = Enum.AutomaticSize.X
	label.TextTruncate = Enum.TextTruncate.None
	label.ZIndex = 21
	tip.Parent = root
	return tip
end

function Controls.Tooltip(trove: TroveInstance, target: GuiObject, text: string, side: string?): Frame
	local tip = buildTooltip(target, text, side or "Above")
	local hit = Instance.new("TextButton")
	hit.Name = "Hover"
	hit.AutoButtonColor = false
	hit.BackgroundTransparency = 1
	hit.BorderSizePixel = 0
	hit.Text = ""
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 10
	hit.Parent = target
	trove:Connect(hit.MouseEnter, function()
		if UserInputService:GetLastInputType() == Enum.UserInputType.MouseMovement then
			tip.Visible = true
		end
	end)
	trove:Connect(hit.MouseLeave, function()
		tip.Visible = false
	end)
	return tip
end

function Controls.Button(trove: TroveInstance, props: ButtonProps): Button
	local baseColor = props.Color or colors.Green
	local baseTextColor = props.TextColor or colors.Text
	local lipDepth = props.Lip or Theme.LipDepth
	local radius = props.Radius or Theme.Radius.L
	local isPill = props.Pill == true
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

	local function round(target: GuiObject)
		if isPill then
			Core.Round(target)
		else
			Core.Corner(target, radius)
		end
	end

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.BorderSizePixel = 0
	shadow.Position = UDim2.fromOffset(0, lipDepth)
	shadow.Size = UDim2.new(1, 0, 1, -lipDepth)
	round(shadow)
	Core.Stroke(shadow, colors.Ink, Theme.Stroke.Normal)
	shadow.Parent = root

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.BorderSizePixel = 0
	face.Size = UDim2.new(1, 0, 1, -lipDepth)
	round(face)
	local outline = Core.Stroke(face, colors.Ink, Theme.Stroke.Normal)
	Core.Gloss(face, if isPill then 20 else radius)
	face.Parent = root

	local iconInstance: GuiObject? = nil
	local lockBadge: Frame? = nil
	local hasIcon = props.Glyph ~= nil or props.IconAsset ~= nil
	local isLeft = props.IconLeft == true
	local isIconOnly = hasIcon and (props.Text == nil or props.Text == "")
	local stackedIcon = props.IconScale or 0.58
	local faceHeight = if props.Size and props.Size.Y.Scale == 0 then props.Size.Y.Offset - lipDepth else 0
	local leftIcon = if faceHeight > 0 then math.floor(faceHeight * 0.76) else 0
	local leftPad = if isPill then 12 else Theme.Space.S
	if hasIcon then
		local icon = Core.Icon({
			Parent = face,
			Name = "Icon",
			Glyph = props.Glyph,
			Asset = props.IconAsset,
			Color = props.IconColor,
			Size = if isIconOnly
				then UDim2.fromScale(0.66, 0.66)
				elseif isLeft then (if leftIcon > 0
					then UDim2.fromOffset(leftIcon, leftIcon)
					else UDim2.fromScale(0, 0.8))
				else UDim2.fromScale(1, stackedIcon),
			Position = if isIconOnly
				then UDim2.fromScale(0.17, 0.17)
				elseif isLeft then UDim2.new(0, leftPad, 0.5, 0)
				else UDim2.fromScale(0, 0.04),
			AnchorPoint = if isLeft and not isIconOnly then Vector2.new(0, 0.5) else Vector2.zero,
		})
		iconInstance = icon
		if isLeft and not isIconOnly and leftIcon == 0 then
			local ratio = Instance.new("UIAspectRatioConstraint")
			ratio.AspectRatio = 1
			ratio.DominantAxis = Enum.DominantAxis.Height
			ratio.Parent = icon
		end
	end
	local textLeft = if leftIcon > 0 then leftPad + leftIcon + 4 else 0
	local text = Core.Label({
		Parent = face,
		Name = "Text",
		Text = props.Text or "",
		Position = if hasIcon and isLeft
			then (if leftIcon > 0 then UDim2.new(0, textLeft, 0, 2) else UDim2.new(0.2, 0, 0, 2))
			elseif hasIcon then UDim2.fromScale(0, stackedIcon + 0.02)
			else UDim2.fromOffset(6, 2),
		Size = if hasIcon and isLeft
			then (if leftIcon > 0
				then UDim2.new(1, -(textLeft + leftPad), 1, -4)
				else UDim2.new(0.8, -8, 1, -4))
			elseif hasIcon then UDim2.fromScale(1, 0.96 - stackedIcon)
			else UDim2.new(1, -12, 1, -4),
		TextSize = props.TextSize or 24,
		Color = baseTextColor,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
		Title = props.Title,
		StrokeSize = if (props.TextSize or 24) >= 40 then 4 else 3,
	})
	text.Active = false

	local pressScale = Instance.new("UIScale")
	pressScale.Name = "PressScale"
	pressScale.Parent = root
	local tip: Frame? = nil
	if props.Tooltip then
		tip = buildTooltip(root, props.Tooltip, props.TooltipSide or "Right")
	end
	root.Parent = props.Parent

	local function paint()
		local color = if isDisabled then colors.Disabled else baseColor
		Core.Paint(face, color)
		shadow.BackgroundColor3 = Theme.Shade(color, -0.45)
		text.TextColor3 = if isDisabled then colors.TextDim else baseTextColor
	end
	paint()

	local function applyOutline()
		if isGlowing then
			return
		end
		outline.Color = if isSelected then colors.Gold else colors.Ink
		outline.Thickness = if isSelected then 4.5 else Theme.Stroke.Normal
	end

	local function settle()
		local goal = if isDown then 0.92 elseif isHover then 1.05 else 1
		Controls.Tween(pressScale, if isDown then pressInfo elseif isHover then hoverInfo else springInfo, {
			Scale = goal,
		})
		local drop = if isDown and not isDisabled then lipDepth - 1 else 0
		Controls.Tween(
			face,
			if isDown then pressInfo else springInfo,
			{ Position = UDim2.fromOffset(0, drop) }
		)
		local hint = tip
		if hint then
			hint.Visible = isHover and not isDown
			root.ZIndex = if isHover then 8 else 1
		end
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
				glowTween = TweenService:Create(outline, loop, { Thickness = 6 })
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
		SetLocked = function(isLocked: boolean)
			if isLocked and not lockBadge then
				local badge = Instance.new("Frame")
				badge.Name = "LockBadge"
				badge.BorderSizePixel = 0
				badge.AnchorPoint = Vector2.new(1, 0)
				badge.Position = UDim2.new(1, 0, 0, -8)
				badge.Size = UDim2.fromOffset(26, 26)
				badge.ZIndex = 4
				Core.Paint(badge, colors.Track)
				Core.Round(badge)
				Core.Stroke(badge, colors.Ink, 2)
				Core.Icon({
					Parent = badge,
					Name = "Icon",
					Glyph = "Lock",
					Size = UDim2.fromScale(0.72, 0.72),
					Position = UDim2.fromScale(0.14, 0.14),
				})
				badge.Parent = root
				lockBadge = badge
			end
			local current = lockBadge
			if current then
				current.Visible = isLocked
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
		Size = UDim2.fromOffset(Controls.CloseSize, Controls.CloseSize),
		Position = UDim2.new(1, 14, 0, -14),
		AnchorPoint = Vector2.new(1, 0),
		Color = colors.Red,
		Pill = true,
		Lip = 4,
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
	scroll.ScrollBarImageColor3 = Theme.Shade(colors.InsetEdge, -0.3)
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
		Position = UDim2.new(0, 18, 0.5, 0),
		Size = UDim2.new(1, -36, 0, 22),
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
		Gloss = true,
		Pill = true,
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
		Gloss = true,
		Pill = true,
	})
	local state = Core.Label({
		Parent = face,
		Name = "State",
		Text = "OFF",
		Size = UDim2.new(0, 50, 1, 0),
		TextSize = 22,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local knob = Core.Panel({
		Parent = face,
		Name = "Knob",
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.new(0, 4, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Color = colors.Text,
		Pill = true,
	})
	knob.ZIndex = 3
	local pressScale = Instance.new("UIScale")
	pressScale.Parent = button
	button.Parent = props.Parent

	local function show(animate: boolean)
		state.Text = if isOn then "ON" else "OFF"
		state.Position = if isOn then UDim2.fromOffset(8, 0) else UDim2.new(1, -58, 0, 0)
		Core.Paint(face, if isOn then colors.Green else colors.Disabled)
		knob.AnchorPoint = Vector2.new(if isOn then 1 else 0, 0.5)
		local goal = UDim2.new(if isOn then 1 else 0, if isOn then -4 else 4, 0.5, 0)
		if animate then
			Controls.Tween(knob, springInfo, { Position = goal })
		else
			knob.Position = goal
		end
	end
	show(false)

	trove:Connect(button.MouseButton1Down, function()
		Controls.Tween(pressScale, pressInfo, { Scale = 0.94 })
	end)
	trove:Connect(button.MouseLeave, function()
		Controls.Tween(pressScale, springInfo, { Scale = 1 })
	end)
	trove:Connect(button.Activated, function()
		isOn = not isOn
		show(true)
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
				show(true)
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
			button.SetColor(if isSelected then tab.Color else colors.Grey)
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

function Controls.Pulse(target: GuiObject, color: Color3?, peak: number?)
	local top = peak or 1.04
	local settle = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	if top ~= 1 then
		local existing = target:FindFirstChild("PulseScale")
		local scale: UIScale
		if existing and existing:IsA("UIScale") then
			scale = existing
		else
			scale = Instance.new("UIScale")
			scale.Name = "PulseScale"
			scale.Parent = target
		end
		local rise =
			Controls.Tween(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
				Scale = top,
			})
		rise.Completed:Once(function()
			Controls.Tween(scale, settle, { Scale = 1 })
		end)
	end
	local stroke = target:FindFirstChild("Stroke")
	if stroke and stroke:IsA("UIStroke") then
		local base = stroke:GetAttribute("PulseBase")
		if typeof(base) ~= "Color3" then
			base = stroke.Color
			stroke:SetAttribute("PulseBase", base)
		end
		local rest = base :: Color3
		local flash = Controls.Tween(stroke, settle, { Color = color or colors.Good })
		flash.Completed:Once(function()
			Controls.Tween(stroke, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Color = rest,
			})
		end)
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
