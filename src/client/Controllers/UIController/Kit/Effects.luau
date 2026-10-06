--!strict

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local Primitives = require(script.Parent.Primitives)
local Theme = require(script.Parent.Theme)

type TroveInstance = typeof(Trove.new())

local white = Theme.Colors.White
local rainbow = Theme.RainbowSequence()

local Effects = {
	RainbowColors = rainbow,
}

local function loop(
	trove: TroveInstance,
	target: Instance,
	seconds: number,
	style: Enum.EasingStyle,
	reverses: boolean,
	goal: { [string]: any }
): Tween
	local info = TweenInfo.new(seconds, style, Enum.EasingDirection.InOut, -1, reverses)
	local tween = TweenService:Create(target, info, goal)
	tween:Play()
	trove:Add(function()
		tween:Cancel()
	end)
	return tween
end

function Effects.Shimmer(trove: TroveInstance, parent: GuiObject, radius: number, seconds: number?): Frame
	local band = Instance.new("Frame")
	band.Name = "Shimmer"
	band.BackgroundColor3 = white
	band.BackgroundTransparency = 0
	band.BorderSizePixel = 0
	band.Size = UDim2.fromScale(1, 1)
	band.ZIndex = Theme.ZIndex.Fill
	Primitives.Corner(band, radius)
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 25
	gradient.Offset = Vector2.new(-1, 0)
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.38, 1),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(0.62, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = band
	band.Parent = parent
	loop(trove, gradient, seconds or 1.8, Enum.EasingStyle.Linear, false, { Offset = Vector2.new(1, 0) })
	return band
end

function Effects.Rainbow(trove: TroveInstance, target: GuiObject): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Name = "Rainbow"
	gradient.Color = rainbow
	gradient.Rotation = 0
	gradient.Parent = target
	target.BackgroundColor3 = white
	loop(trove, gradient, 4, Enum.EasingStyle.Linear, false, { Rotation = 360 })
	return gradient
end

function Effects.Breathe(trove: TroveInstance, scale: UIScale, amount: number, seconds: number)
	loop(trove, scale, seconds, Enum.EasingStyle.Sine, true, { Scale = 1 + amount })
end

return Effects
