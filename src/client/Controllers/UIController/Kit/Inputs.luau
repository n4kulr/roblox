--!strict

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local Tweens = require(script.Parent.Tweens)
local Sound = require(script.Parent.Sound)
local Labels = require(script.Parent.Labels)
local Primitives = require(script.Parent.Primitives)
local Surfaces = require(script.Parent.Surfaces)
local Widgets = require(script.Parent.Widgets)
local Theme = require(script.Parent.Theme)

type TroveInstance = typeof(Trove.new())
type SoundPlayer = (name: string) -> ()

local motion = Theme.Motion
local colors = Theme.Colors
local pressInfo = motion.Press
local springInfo = motion.Spring

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
	Silent: boolean?,
}

export type Toggle = {
	Instance: TextButton,
	SetValue: (value: boolean) -> (),
}

local Inputs = {}

function Inputs.Slider(trove: TroveInstance, props: SliderProps): Slider
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
	local bar = Widgets.Bar({
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
	local knob = Surfaces.Panel({
		Parent = track,
		Name = "Knob",
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.fromScale(value, 0.5),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Color = colors.Text,
		Gloss = true,
		Pill = true,
	})
	knob.ZIndex = Theme.ZIndex.Badge
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

function Inputs.Toggle(trove: TroveInstance, props: ToggleProps): Toggle
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
	local face = Surfaces.Panel({
		Parent = button,
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		Color = colors.Disabled,
		Gloss = true,
		Pill = true,
	})
	local state = Labels.Label({
		Parent = face,
		Name = "State",
		Text = "OFF",
		Size = UDim2.new(0, 50, 1, 0),
		TextSize = Theme.Text.Strong,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local knob = Surfaces.Panel({
		Parent = face,
		Name = "Knob",
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.new(0, 4, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Color = colors.Text,
		Pill = true,
	})
	knob.ZIndex = Theme.ZIndex.Fill
	local pressScale = Instance.new("UIScale")
	pressScale.Parent = button
	button.Parent = props.Parent

	local function show(animate: boolean)
		state.Text = if isOn then "ON" else "OFF"
		state.Position = if isOn then UDim2.fromOffset(8, 0) else UDim2.new(1, -58, 0, 0)
		Primitives.Paint(face, if isOn then colors.Green else colors.Disabled)
		knob.AnchorPoint = Vector2.new(if isOn then 1 else 0, 0.5)
		local goal = UDim2.new(if isOn then 1 else 0, if isOn then -4 else 4, 0.5, 0)
		if animate then
			Tweens.Tween(knob, springInfo, { Position = goal })
		else
			knob.Position = goal
		end
	end
	show(false)

	trove:Connect(button.MouseButton1Down, function()
		Tweens.Tween(pressScale, pressInfo, { Scale = 0.94 })
	end)
	trove:Connect(button.MouseLeave, function()
		Tweens.Tween(pressScale, springInfo, { Scale = 1 })
	end)
	trove:Connect(button.Activated, function()
		isOn = not isOn
		show(true)
		Tweens.Tween(pressScale, springInfo, { Scale = 1 })
		local sound = Sound.Resolve(props.Sound, props.Silent)
		if sound then
			sound(Sound.Click)
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

return Inputs
