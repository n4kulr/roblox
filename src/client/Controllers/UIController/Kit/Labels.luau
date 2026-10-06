--!strict

local TweenService = game:GetService("TweenService")
local Primitives = require(script.Parent.Primitives)
local Surfaces = require(script.Parent.Surfaces)
local Theme = require(script.Parent.Theme)

local colors = Theme.Colors

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
	Subtle: boolean?,
	StrokeSize: number?,
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

local Labels = {}

function Labels.Label(props: LabelProps): TextLabel
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
	label.TextColor3 = props.Color or (if props.Subtle == true then colors.Subtext else colors.Text)
	label.TextXAlignment = props.Align or Enum.TextXAlignment.Left
	label.TextYAlignment = props.VerticalAlign or Enum.TextYAlignment.Center
	label.TextWrapped = props.Wrapped == true
	label.RichText = props.RichText == true
	label.Text = props.Text or ""
	if props.Scaled == true then
		label.TextScaled = true
		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MaxTextSize = textSize
		constraint.MinTextSize = Theme.Text.Min
		constraint.Parent = label
	else
		label.TextSize = textSize
		label.TextTruncate = if props.Wrapped == true then Enum.TextTruncate.None else Enum.TextTruncate.AtEnd
	end
	if props.Outline ~= false and props.Subtle ~= true then
		Primitives.TextStroke(
			label,
			props.StrokeSize or (if textSize >= 24 then 3 elseif textSize >= 15 then 2 else 1.5)
		)
	end
	label.Parent = props.Parent
	return label
end

function Labels.Chip(props: ChipProps): TextLabel
	local chip = Surfaces.Panel({
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
	return Labels.Label({
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

function Labels.Badge(parent: Instance, text: string?): Frame
	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.BorderSizePixel = 0
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, 5, 0, -7)
	badge.Size = UDim2.fromOffset(30, 30)
	badge.ZIndex = Theme.ZIndex.Badge
	Primitives.Paint(badge, colors.Red)
	Primitives.Round(badge)
	Primitives.Stroke(badge, colors.Ink, Theme.Stroke.Normal)
	Primitives.Gloss(badge, 15)
	local pop = Instance.new("UIScale")
	pop.Name = "Pop"
	pop.Parent = badge
	local label = Labels.Label({
		Parent = badge,
		Name = "Text",
		Text = text or "!",
		Size = UDim2.fromScale(1, 1),
		TextSize = Theme.Text.Label,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	label.ZIndex = Theme.ZIndex.BadgeText
	badge.Parent = parent
	badge:GetPropertyChangedSignal("Visible"):Connect(function()
		if badge.Visible then
			pop.Scale = 0.2
			local tween = TweenService:Create(pop, Theme.Motion.Badge, { Scale = 1 })
			tween:Play()
		end
	end)
	return badge
end

return Labels
