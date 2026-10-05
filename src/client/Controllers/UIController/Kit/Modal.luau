--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local Controls = require(script.Parent.Controls)
local Core = require(script.Parent.Core)
local Theme = require(script.Parent.Theme)

type TroveInstance = typeof(Trove.new())
type SoundPlayer = (name: string) -> ()

export type ModalProps = {
	Parent: Instance,
	Name: string,
	Title: string,
	Glyph: string,
	IconAsset: string?,
	MaxSize: Vector2,
	HeaderColor: Color3?,
	OnClose: () -> (),
	Sound: SoundPlayer?,
}

export type Modal = {
	Gui: ScreenGui,
	Root: Frame,
	Panel: Frame,
	Body: Frame,
	HeaderRight: Frame,
	Show: () -> (),
	Hide: () -> (),
}

local colors = Theme.Colors
local black = Color3.new(0, 0, 0)
local popInfo = TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local closeInfo = TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local windowTop = 84
local windowBottom = 12
local headerHeight = 58
local frameGap = 10
local closeReserve = 52

local Modal = {
	HeaderHeight = headerHeight,
	WindowTop = windowTop,
}

local function viewportScale(size: Vector2): number
	local shortest = math.min(size.X, size.Y)
	if shortest <= 0 then
		return 1
	end
	return math.clamp(shortest / 850, 0.75, 1.2)
end

function Modal.ScreenGui(
	name: string,
	displayOrder: number,
	parent: Instance,
	trove: TroveInstance
): (ScreenGui, Frame)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = displayOrder
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Name = "ViewportScale"
	scale.Parent = root
	local function update()
		local value = viewportScale(gui.AbsoluteSize)
		scale.Scale = value
		root.Size = UDim2.fromScale(1 / value, 1 / value)
	end
	update()
	trove:Connect(gui:GetPropertyChangedSignal("AbsoluteSize"), update)
	gui.Parent = parent
	update()
	trove:Add(gui)
	return gui, root
end

function Modal.new(trove: TroveInstance, props: ModalProps): Modal
	local gui, root = Modal.ScreenGui(`Thock{props.Name}`, 10, props.Parent, trove)
	gui.Enabled = false
	local token = 0
	local headerColor = props.HeaderColor or colors.Blue

	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.AutoButtonColor = false
	backdrop.BackgroundColor3 = black
	backdrop.BackgroundTransparency = 0.45
	backdrop.BorderSizePixel = 0
	backdrop.Text = ""
	backdrop.Position = UDim2.fromOffset(0, windowTop - 10)
	backdrop.Size = UDim2.new(1, 0, 1, -(windowTop - 10))
	backdrop.Parent = root
	trove:Connect(backdrop.Activated, props.OnClose)

	local area = Instance.new("Frame")
	area.Name = "Area"
	area.BackgroundTransparency = 1
	area.BorderSizePixel = 0
	area.Position = UDim2.fromOffset(0, windowTop)
	area.Size = UDim2.new(1, 0, 1, -(windowTop + windowBottom))
	area.Parent = root

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.BackgroundTransparency = 1
	window.BorderSizePixel = 0
	window.Active = true
	window.Size = UDim2.new(1, -2 * Theme.Space.Xl, 1, 0)
	window.Position = UDim2.fromScale(0.5, 0.5)
	window.AnchorPoint = Vector2.new(0.5, 0.5)
	window.Parent = area
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = props.MaxSize
	constraint.Parent = window
	local pop = Instance.new("UIScale")
	pop.Name = "Pop"
	pop.Parent = window

	local shadow = Instance.new("Frame")
	shadow.Name = "Shadow"
	shadow.BackgroundColor3 = black
	shadow.BackgroundTransparency = 0.6
	shadow.BorderSizePixel = 0
	shadow.Position = UDim2.fromOffset(0, 8)
	shadow.Size = UDim2.fromScale(1, 1)
	Core.Corner(shadow, Theme.Radius.Panel)
	shadow.Parent = window

	local panel = Core.Panel({
		Parent = window,
		Name = "Panel",
		Color = colors.Panel,
		Radius = Theme.Radius.Panel,
		StrokeThickness = Theme.Stroke.Heavy,
		Shards = true,
	})

	local body = Core.Panel({
		Parent = panel,
		Name = "Body",
		Position = UDim2.fromOffset(frameGap, headerHeight + frameGap * 2),
		Size = UDim2.new(1, -2 * frameGap, 1, -(headerHeight + frameGap * 3)),
		Color = colors.Well,
		Radius = Theme.Radius.L,
		Flat = true,
	})
	body.ClipsDescendants = true

	local header = Core.Panel({
		Parent = panel,
		Name = "Header",
		Position = UDim2.fromOffset(frameGap, frameGap),
		Size = UDim2.new(1, -2 * frameGap, 0, headerHeight),
		Color = headerColor,
		Radius = Theme.Radius.L,
		Shards = true,
	})
	Core.Gloss(header, Theme.Radius.L)
	local badge = Core.Panel({
		Parent = header,
		Name = "IconBadge",
		Position = UDim2.fromOffset(-6, -12),
		Size = UDim2.fromOffset(headerHeight + 8, headerHeight + 8),
		Color = Theme.Shade(headerColor, -0.45),
		Radius = Theme.Radius.L,
		StrokeThickness = Theme.Stroke.Heavy,
	})
	Core.Icon({
		Parent = badge,
		Name = "Icon",
		Glyph = props.Glyph,
		Asset = props.IconAsset,
		Size = UDim2.fromScale(0.82, 0.82),
		Position = UDim2.fromScale(0.09, 0.09),
	})
	Core.Label({
		Parent = header,
		Name = "Title",
		Text = props.Title,
		Position = UDim2.fromOffset(headerHeight + 18, 0),
		Size = UDim2.new(0.5, -(headerHeight + 18), 1, 0),
		TextSize = 36,
		Scaled = true,
		Title = true,
	})
	local headerRight = Instance.new("Frame")
	headerRight.Name = "HeaderRight"
	headerRight.BackgroundTransparency = 1
	headerRight.BorderSizePixel = 0
	headerRight.AnchorPoint = Vector2.new(1, 0.5)
	headerRight.Position = UDim2.new(1, -closeReserve, 0.5, 0)
	headerRight.Size = UDim2.new(0.5, -closeReserve, 1, -10)
	local rightList = Instance.new("UIListLayout")
	rightList.FillDirection = Enum.FillDirection.Horizontal
	rightList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	rightList.VerticalAlignment = Enum.VerticalAlignment.Center
	rightList.SortOrder = Enum.SortOrder.LayoutOrder
	rightList.Padding = UDim.new(0, Theme.Space.S)
	rightList.Parent = headerRight
	headerRight.Parent = header
	Controls.CloseButton(trove, panel, props.OnClose, props.Sound)

	return {
		Gui = gui,
		Root = root,
		Panel = panel,
		Body = body,
		HeaderRight = headerRight,
		Show = function()
			token += 1
			pop.Scale = 0.85
			gui.Enabled = true
			Controls.Tween(pop, popInfo, { Scale = 1 })
		end,
		Hide = function()
			if not gui.Enabled then
				return
			end
			token += 1
			local mine = token
			local closing = Controls.Tween(pop, closeInfo, { Scale = 0.85 })
			closing.Completed:Once(function()
				if token == mine then
					gui.Enabled = false
				end
			end)
		end,
	}
end

return Modal
