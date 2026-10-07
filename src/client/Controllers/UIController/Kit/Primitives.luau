--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UiAssets = require(ReplicatedStorage.Config.UiAssets)
local Theme = require(script.Parent.Theme)

local colors = Theme.Colors
local white = Theme.Colors.White

local Primitives = {}

function Primitives.Corner(parent: Instance, radius: number?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or Theme.Radius.M)
	corner.Parent = parent
	return corner
end

function Primitives.Round(parent: Instance): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = parent
	return corner
end

function Primitives.Stroke(parent: Instance, color: Color3?, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Color = color or colors.Ink
	stroke.Thickness = thickness or Theme.Stroke.Normal
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = parent
	return stroke
end

function Primitives.StrokeOf(parent: Instance): UIStroke
	return parent:FindFirstChild("Stroke") :: UIStroke
end

function Primitives.TextStroke(parent: Instance, thickness: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Name = "TextStroke"
	stroke.Color = colors.Ink
	stroke.Thickness = thickness or Theme.Stroke.Thin
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = parent
	return stroke
end

function Primitives.Paint(frame: GuiObject, color: Color3)
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
	gradient.Color = ColorSequence.new(Theme.Shade(color, 0.25), color)
end

function Primitives.Shards(parent: GuiObject, radius: number, transparency: number?)
	if UiAssets.Pattern == "" then
		return
	end
	local image = Instance.new("ImageLabel")
	image.Name = "Shards"
	image.BackgroundTransparency = 1
	image.BorderSizePixel = 0
	image.Size = UDim2.fromScale(1, 1)
	image.Image = UiAssets.Pattern
	image.ScaleType = Enum.ScaleType.Tile
	image.TileSize = UDim2.fromOffset(128, 128)
	image.ImageColor3 = white
	image.ImageTransparency = transparency or 0.88
	Primitives.Corner(image, radius)
	image.Parent = parent
end

function Primitives.Gloss(parent: GuiObject, radius: number)
	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.BackgroundColor3 = white
	gloss.BackgroundTransparency = Theme.Transparency.Soft
	gloss.BorderSizePixel = 0
	gloss.Position = UDim2.fromOffset(4, 4)
	gloss.Size = UDim2.new(1, -8, 0.45, -4)
	gloss.ZIndex = Theme.ZIndex.Behind
	Primitives.Corner(gloss, math.max(radius - 4, 4))
	local fade = Instance.new("UIGradient")
	fade.Rotation = 90
	fade.Transparency = NumberSequence.new(0, 0.4)
	fade.Parent = gloss
	gloss.Parent = parent
end

return Primitives
