--!strict

local GuiService = game:GetService("GuiService")
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
local openInfo = Theme.Motion.Pop
local fadeInfo = Theme.Motion.Base
local closeInfo = Theme.Motion.Exit
local dimTransparency = Theme.Transparency.Scrim
local headerHeight = 60
local frameGap = 12
local closeReserve = 44
local badgeSize = 72
local areaTop = 40
local areaBottom = 20
local areaSide = 24

local Modal = {
	HeaderHeight = headerHeight,
	AreaTop = areaTop,
}

local function viewportScale(size: Vector2): number
	local shortest = math.min(size.X, size.Y)
	if shortest <= 0 then
		return 1
	end
	return math.clamp(shortest / 800, 0.5, 1.25)
end

function Modal.ScreenGui(
	name: string,
	displayOrder: number,
	parent: Instance,
	trove: TroveInstance,
	ignoresInset: boolean?
): (ScreenGui, Frame)
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = ignoresInset == true
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
	local gui, root = Modal.ScreenGui(`Thock{props.Name}`, Theme.Layer.Modal, props.Parent, trove, true)
	gui.Enabled = false
	local token = 0
	local headerColor = props.HeaderColor or colors.Blue

	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.AutoButtonColor = false
	backdrop.BackgroundColor3 = colors.Scrim
	backdrop.BackgroundTransparency = dimTransparency
	backdrop.BorderSizePixel = 0
	backdrop.Text = ""
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Parent = root
	trove:Connect(backdrop.Activated, props.OnClose)

	local area = Instance.new("Frame")
	area.Name = "Area"
	area.BackgroundTransparency = 1
	area.BorderSizePixel = 0
	area.Parent = root
	local function layoutArea()
		local scale = root:FindFirstChild("ViewportScale")
		local factor = if scale and scale:IsA("UIScale") and scale.Scale > 0 then scale.Scale else 1
		local top = GuiService:GetGuiInset().Y / factor + areaTop
		area.Position = UDim2.fromOffset(0, top)
		area.Size = UDim2.new(1, 0, 1, -(top + areaBottom))
	end
	layoutArea()
	trove:Connect(gui:GetPropertyChangedSignal("AbsoluteSize"), layoutArea)

	local window = Instance.new("Frame")
	window.Name = "Window"
	window.BackgroundTransparency = 1
	window.BorderSizePixel = 0
	window.Active = true
	window.Size = UDim2.new(1, -2 * areaSide, 1, 0)
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
	shadow.BackgroundColor3 = colors.Scrim
	shadow.BackgroundTransparency = Theme.Transparency.Heavy
	shadow.BorderSizePixel = 0
	shadow.Position = UDim2.fromOffset(0, 8)
	shadow.Size = UDim2.fromScale(1, 1)
	Core.Corner(shadow, Theme.Radius.Panel)
	shadow.Parent = window

	local panel = Core.Panel({
		Parent = window,
		Name = "Panel",
		Color = colors.PanelDeep,
		Radius = Theme.Radius.Panel,
		StrokeThickness = Theme.Stroke.Heavy,
	})
	local paint = panel:FindFirstChild("Paint")
	if paint and paint:IsA("UIGradient") then
		paint.Color = ColorSequence.new(colors.Panel, colors.PanelDeep)
	end

	local body = Core.Panel({
		Parent = panel,
		Name = "Body",
		Position = UDim2.fromOffset(frameGap, headerHeight + frameGap * 2),
		Size = UDim2.new(1, -2 * frameGap, 1, -(headerHeight + frameGap * 3)),
		Color = colors.Inset,
		Radius = Theme.Radius.L,
		StrokeColor = colors.InsetEdge,
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
		Position = UDim2.new(0, -20, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.fromOffset(badgeSize, badgeSize),
		Color = Theme.Shade(headerColor, -0.2),
		Pill = true,
		StrokeThickness = Theme.Stroke.Heavy,
		Gloss = true,
	})
	badge.ZIndex = Theme.ZIndex.Fill
	local badgeIcon = Core.Icon({
		Parent = badge,
		Name = "Icon",
		Glyph = props.Glyph,
		Size = UDim2.fromScale(0.72, 0.72),
		Position = UDim2.fromScale(0.14, 0.14),
	})
	badgeIcon.ZIndex = Theme.ZIndex.Mark
	Core.Label({
		Parent = header,
		Name = "Title",
		Text = props.Title,
		Position = UDim2.fromOffset(badgeSize - 6, 0),
		Size = UDim2.new(0.55, -(badgeSize - 6), 1, 0),
		TextSize = Theme.Text.Display,
		Scaled = true,
		Title = true,
	})
	local headerRight = Instance.new("Frame")
	headerRight.Name = "HeaderRight"
	headerRight.BackgroundTransparency = 1
	headerRight.BorderSizePixel = 0
	headerRight.AnchorPoint = Vector2.new(1, 0.5)
	headerRight.Position = UDim2.new(1, -closeReserve, 0.5, 0)
	headerRight.Size = UDim2.new(0.45, -closeReserve, 1, -12)
	local rightList = Instance.new("UIListLayout")
	rightList.FillDirection = Enum.FillDirection.Horizontal
	rightList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	rightList.VerticalAlignment = Enum.VerticalAlignment.Center
	rightList.SortOrder = Enum.SortOrder.LayoutOrder
	rightList.Padding = UDim.new(0, Theme.Space.S)
	rightList.Parent = headerRight
	headerRight.Parent = header
	Controls.CloseButton(trove, panel, props.OnClose, props.Sound).Instance.ZIndex = Theme.ZIndex.BadgeText

	return {
		Gui = gui,
		Root = root,
		Panel = panel,
		Body = body,
		HeaderRight = headerRight,
		Show = function()
			token += 1
			pop.Scale = 0.7
			backdrop.BackgroundTransparency = 1
			gui.Enabled = true
			Controls.Tween(pop, openInfo, { Scale = 1 })
			Controls.Tween(backdrop, fadeInfo, { BackgroundTransparency = dimTransparency })
		end,
		Hide = function()
			if not gui.Enabled then
				return
			end
			token += 1
			local mine = token
			Controls.Tween(backdrop, closeInfo, { BackgroundTransparency = 1 })
			local closing = Controls.Tween(pop, closeInfo, { Scale = 0.8 })
			closing.Completed:Once(function()
				if token == mine then
					gui.Enabled = false
				end
			end)
		end,
	}
end

return Modal
