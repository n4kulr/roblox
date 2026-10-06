--!strict

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local Tooltips = require(script.Parent.Tooltips)
local Tweens = require(script.Parent.Tweens)
local Sound = require(script.Parent.Sound)
local Icons = require(script.Parent.Icons)
local Labels = require(script.Parent.Labels)
local Primitives = require(script.Parent.Primitives)
local Theme = require(script.Parent.Theme)

type TroveInstance = typeof(Trove.new())
type SoundPlayer = (name: string) -> ()

local colors = Theme.Colors
local motion = Theme.Motion
local pressInfo = motion.Press
local hoverInfo = motion.Fast
local springInfo = motion.Spring

export type ButtonProps = {
	Parent: Instance,
	Name: string?,
	Text: string?,
	Glyph: string?,
	IconLeft: boolean?,
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
	Silent: boolean?,
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

local Buttons = {
	ButtonHeight = 52,
	TouchSize = 48,
	CloseSize = 52,
	InsetCloseSize = 40,
}

function Buttons.Button(trove: TroveInstance, props: ButtonProps): Button
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
	root.Size = props.Size or UDim2.fromOffset(140, Buttons.ButtonHeight)
	root.Position = props.Position or UDim2.new()
	root.AnchorPoint = props.AnchorPoint or Vector2.zero
	root.LayoutOrder = props.LayoutOrder or 0

	local function round(target: GuiObject)
		if isPill then
			Primitives.Round(target)
		else
			Primitives.Corner(target, radius)
		end
	end

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.BorderSizePixel = 0
	shadow.Position = UDim2.fromOffset(0, lipDepth)
	shadow.Size = UDim2.new(1, 0, 1, -lipDepth)
	round(shadow)
	Primitives.Stroke(shadow, colors.Ink, Theme.Stroke.Normal)
	shadow.Parent = root

	local face = Instance.new("Frame")
	face.Name = "Face"
	face.BorderSizePixel = 0
	face.Size = UDim2.new(1, 0, 1, -lipDepth)
	round(face)
	local outline = Primitives.Stroke(face, colors.Ink, Theme.Stroke.Normal)
	Primitives.Gloss(face, if isPill then 20 else radius)
	face.Parent = root

	local iconInstance: GuiObject? = nil
	local lockBadge: Frame? = nil
	local hasIcon = props.Glyph ~= nil
	local isLeft = props.IconLeft == true
	local isIconOnly = hasIcon and (props.Text == nil or props.Text == "")
	local stackedIcon = props.IconScale or 0.58
	local faceHeight = if props.Size and props.Size.Y.Scale == 0 then props.Size.Y.Offset - lipDepth else 0
	local leftIcon = if faceHeight > 0 then math.floor(faceHeight * 0.76) else 0
	local leftPad = if isPill then 12 else Theme.Space.S
	if hasIcon then
		local icon = Icons.Icon({
			Parent = face,
			Name = "Icon",
			Glyph = props.Glyph,
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
	local text = Labels.Label({
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
		tip = Tooltips.Build(root, props.Tooltip, props.TooltipSide or "Right")
	end
	root.Parent = props.Parent

	local function paint()
		local color = if isDisabled then colors.Disabled else baseColor
		Primitives.Paint(face, color)
		shadow.BackgroundColor3 = Theme.Shade(color, -0.45)
		text.TextColor3 = if isDisabled then colors.TextDim else baseTextColor
	end
	paint()

	local function applyOutline()
		if isGlowing then
			return
		end
		outline.Color = if isSelected then colors.Gold else colors.Ink
		outline.Thickness = if isSelected then Theme.Stroke.Selected else Theme.Stroke.Normal
	end

	local function settle()
		local goal = if isDown then 0.92 elseif isHover then 1.05 else 1
		Tweens.Tween(pressScale, if isDown then pressInfo elseif isHover then hoverInfo else springInfo, {
			Scale = goal,
		})
		local drop = if isDown and not isDisabled then lipDepth - 1 else 0
		Tweens.Tween(face, if isDown then pressInfo else springInfo, { Position = UDim2.fromOffset(0, drop) })
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
		local sound = Sound.Resolve(props.Sound, props.Silent)
		if sound then
			sound(Sound.Click)
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
				outline.Color = colors.Ring
				glowTween = TweenService:Create(outline, motion.Glow, { Thickness = Theme.Stroke.Outline })
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
				badge.ZIndex = Theme.ZIndex.Mark
				Primitives.Paint(badge, colors.Track)
				Primitives.Round(badge)
				Primitives.Stroke(badge, colors.Ink, Theme.Stroke.Thin)
				Icons.Icon({
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

function Buttons.CloseButton(
	trove: TroveInstance,
	parent: Instance,
	onClose: () -> (),
	sound: SoundPlayer?,
	isInset: boolean?
): Button
	local size = if isInset == true then Buttons.InsetCloseSize else Buttons.CloseSize
	return Buttons.Button(trove, {
		Parent = parent,
		Name = "Close",
		Glyph = "Close",
		Size = UDim2.fromOffset(size, size),
		Position = if isInset == true then UDim2.new(1, -8, 0, 8) else UDim2.new(1, 14, 0, -14),
		AnchorPoint = Vector2.new(1, 0),
		Color = colors.Red,
		Pill = true,
		Lip = 4,
		Callback = onClose,
		Sound = sound,
	})
end

return Buttons
