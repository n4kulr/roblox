--!strict

local Primitives = require(script.Parent.Primitives)
local Theme = require(script.Parent.Theme)

local colors = Theme.Colors

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
	Flat: boolean?,
	Gloss: boolean?,
	Pill: boolean?,
}

local Surfaces = {}

function Surfaces.Panel(props: PanelProps): Frame
	local radius = props.Radius or Theme.Radius.M
	local frame = Instance.new("Frame")
	frame.Name = props.Name or "Panel"
	frame.BackgroundTransparency = props.Transparency or 0
	frame.BorderSizePixel = 0
	frame.Size = props.Size or UDim2.fromScale(1, 1)
	frame.Position = props.Position or UDim2.new()
	frame.AnchorPoint = props.AnchorPoint or Vector2.zero
	frame.LayoutOrder = props.LayoutOrder or 0
	if props.Flat == true then
		frame.BackgroundColor3 = props.Color or colors.Panel
	else
		Primitives.Paint(frame, props.Color or colors.Panel)
	end
	if props.Pill == true then
		Primitives.Round(frame)
	else
		Primitives.Corner(frame, radius)
	end
	Primitives.Stroke(frame, props.StrokeColor, props.StrokeThickness or Theme.Stroke.Normal)
	if props.Shards == true then
		Primitives.Shards(frame, radius)
	end
	if props.Gloss == true then
		Primitives.Gloss(frame, radius)
	end
	frame.Parent = props.Parent
	return frame
end

return Surfaces
