--!strict

local Theme = require(script.Parent.Theme)

local colors = Theme.Colors

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

local Scrolls = {}

local function styleScroll(scroll: ScrollingFrame)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.ScrollBarThickness = Theme.Space.S
	scroll.ScrollBarImageColor3 = Theme.Shade(colors.InsetEdge, -0.3)
end

function Scrolls.Scroll(props: ScrollProps): ScrollingFrame
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

function Scrolls.GridScroll(props: GridScrollProps): ScrollingFrame
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

return Scrolls
