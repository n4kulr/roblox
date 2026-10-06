--!strict

local IconAtlas = require(script.Parent.Parent.IconAtlas)

export type IconProps = {
	Parent: Instance,
	Name: string?,
	Glyph: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
}

local Icons = {}

function Icons.Icon(props: IconProps): GuiObject
	local image = Instance.new("ImageLabel")
	image.Name = props.Name or "Icon"
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.ScaleType = Enum.ScaleType.Fit
	image.Size = props.Size or UDim2.fromOffset(48, 48)
	image.Position = props.Position or UDim2.new()
	image.AnchorPoint = props.AnchorPoint or Vector2.zero
	image.LayoutOrder = props.LayoutOrder or 0
	if not IconAtlas.Apply(image, props.Glyph or IconAtlas.Fallback) then
		IconAtlas.Apply(image, IconAtlas.Fallback)
	end
	image.Parent = props.Parent
	return image
end

return Icons
