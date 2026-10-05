--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local Core = require(script.Parent.Core)
local Effects = require(script.Parent.Effects)
local Theme = require(script.Parent.Theme)

type TroveInstance = typeof(Trove.new())

export type PlateProps = {
	Parent: Instance,
	Name: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Color: Color3,
	Glyph: string?,
	IconAsset: string?,
	Radius: number?,
	Burst: boolean?,
}

export type CardProps = {
	Parent: Instance,
	Name: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	LayoutOrder: number?,
	Radius: number?,
	Tint: Color3?,
}

export type RowProps = {
	Parent: Instance,
	Name: string,
	Height: number?,
	LayoutOrder: number?,
	Color: Color3,
	Glyph: string?,
	IconAsset: string?,
	Title: string,
	TitleSize: number?,
	Subtitle: string?,
	RightWidth: number?,
	PlateSize: number?,
}

export type Row = {
	Frame: Frame,
	Plate: Frame,
	Title: TextLabel,
	Subtitle: TextLabel?,
	Left: number,
	Right: number,
	Width: UDim,
}

local colors = Theme.Colors
local cardTint = Color3.fromHex("F1F6FF")

local Cards = {}

function Cards.Plate(props: PlateProps): Frame
	local radius = props.Radius or Theme.Radius.M
	local plate = Instance.new("Frame")
	plate.Name = props.Name or "IconTile"
	plate.BorderSizePixel = 0
	plate.Size = props.Size or UDim2.fromOffset(64, 64)
	plate.Position = props.Position or UDim2.new()
	plate.AnchorPoint = props.AnchorPoint or Vector2.zero
	plate.LayoutOrder = props.LayoutOrder or 0
	Core.Paint(plate, props.Color)
	Core.Corner(plate, radius)
	Core.Stroke(plate, colors.Ink, Theme.Stroke.Normal)
	if props.Burst == true then
		Core.Burst({ Parent = plate, Diameter = 80, Color = Theme.Shade(props.Color, 0.5) })
	end
	Core.Gloss(plate, radius)
	Core.Icon({
		Parent = plate,
		Name = "Icon",
		Glyph = props.Glyph,
		Asset = props.IconAsset,
		Size = UDim2.fromScale(0.72, 0.72),
		Position = UDim2.fromScale(0.14, 0.14),
	})
	plate.Parent = props.Parent
	return plate
end

function Cards.Card(props: CardProps): Frame
	return Core.Panel({
		Parent = props.Parent,
		Name = props.Name or "Card",
		Size = props.Size or UDim2.new(1, 0, 0, 96),
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		LayoutOrder = props.LayoutOrder,
		Color = props.Tint or cardTint,
		Radius = props.Radius or Theme.Radius.L,
		StrokeThickness = Theme.Stroke.Normal,
	})
end

function Cards.Row(props: RowProps): Row
	local height = props.Height or 96
	local plateSize = props.PlateSize or height - 2 * Theme.Space.M
	local card = Cards.Card({
		Parent = props.Parent,
		Name = props.Name,
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = props.LayoutOrder,
	})
	Cards.Plate({
		Parent = card,
		Name = "IconTile",
		Position = UDim2.fromOffset(Theme.Space.M, (height - plateSize) / 2),
		Size = UDim2.fromOffset(plateSize, plateSize),
		Color = props.Color,
		Glyph = props.Glyph,
		IconAsset = props.IconAsset,
		Burst = true,
	})
	local left = plateSize + Theme.Space.M * 2
	local right = (props.RightWidth or 0) + Theme.Space.M * 2
	local hasSubtitle = props.Subtitle ~= nil
	local title = Core.Label({
		Parent = card,
		Name = "Name",
		Text = props.Title,
		Position = UDim2.fromOffset(left, if hasSubtitle then 8 else (height - 32) / 2),
		Size = UDim2.new(1, -(left + right), 0, 30),
		TextSize = props.TitleSize or 26,
		Scaled = true,
		Title = true,
	})
	local subtitle: TextLabel? = nil
	if props.Subtitle then
		subtitle = Core.Label({
			Parent = card,
			Name = "Subtitle",
			Text = props.Subtitle,
			Position = UDim2.fromOffset(left, 40),
			Size = UDim2.new(1, -(left + right), 0, 20),
			TextSize = 17,
			Subtle = true,
			Scaled = true,
		})
	end
	return {
		Frame = card,
		Plate = card:FindFirstChild("IconTile") :: Frame,
		Title = title,
		Subtitle = subtitle,
		Left = left,
		Right = right,
		Width = UDim.new(1, -(left + right)),
	}
end

function Cards.RarityPaint(
	trove: TroveInstance,
	target: GuiObject,
	rarityName: string,
	color: Color3,
	radius: number
)
	if rarityName == "Secret" then
		Effects.Rainbow(trove, target)
		return
	end
	Core.Paint(target, color)
	if rarityName == "Legendary" or rarityName == "Mythic" then
		Effects.Shimmer(trove, target, radius, if rarityName == "Mythic" then 1.4 else 2)
	end
end

return Cards
