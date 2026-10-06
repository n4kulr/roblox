--!strict

export type LabelProps = {
	Name: string?,
	Text: string?,
	Font: Enum.Font?,
	Color: Color3?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	Centered: boolean?,
	Transparency: number?,
	TextStrokeColor: Color3?,
	TextStrokeTransparency: number?,
	XAlignment: Enum.TextXAlignment?,
	StrokeColor: Color3?,
	StrokeThickness: number?,
	StrokeJoin: Enum.LineJoinMode?,
	Visible: boolean?,
}

export type BillboardProps = {
	Name: string?,
	Adornee: Instance?,
	Size: UDim2?,
	Offset: Vector3?,
	MaxDistance: number?,
	AlwaysOnTop: boolean?,
	LightInfluence: number?,
	Enabled: boolean?,
}

export type SurfaceProps = {
	Name: string?,
	Face: Enum.NormalId?,
	Adornee: Instance?,
	PixelsPerStud: number?,
	LightInfluence: number?,
	AlwaysOnTop: boolean?,
	MaxDistance: number?,
	Enabled: boolean?,
}

local Gui = {
	Font = Enum.Font.FredokaOne,
}

function Gui.Stroke(parent: Instance, thickness: number, color: Color3?, join: Enum.LineJoinMode?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = thickness
	if color then
		stroke.Color = color
	end
	if join then
		stroke.LineJoinMode = join
	end
	stroke.Parent = parent
	return stroke
end

function Gui.Label(parent: Instance?, props: LabelProps): TextLabel
	local label = Instance.new("TextLabel")
	if props.Name then
		label.Name = props.Name
	end
	label.BackgroundTransparency = 1
	if props.Centered then
		label.AnchorPoint = Vector2.new(0.5, 0.5)
		label.Position = UDim2.fromScale(0.5, 0.5)
	end
	if props.AnchorPoint then
		label.AnchorPoint = props.AnchorPoint
	end
	if props.Position then
		label.Position = props.Position
	end
	label.Size = props.Size or UDim2.fromScale(1, 1)
	label.Font = props.Font or Gui.Font
	label.TextScaled = true
	if props.XAlignment then
		label.TextXAlignment = props.XAlignment
	end
	if props.Color then
		label.TextColor3 = props.Color
	end
	if props.Transparency then
		label.TextTransparency = props.Transparency
	end
	if props.TextStrokeColor then
		label.TextStrokeColor3 = props.TextStrokeColor
	end
	if props.TextStrokeTransparency then
		label.TextStrokeTransparency = props.TextStrokeTransparency
	end
	if props.Visible ~= nil then
		label.Visible = props.Visible
	end
	label.Text = props.Text or ""
	if props.StrokeThickness then
		Gui.Stroke(label, props.StrokeThickness, props.StrokeColor, props.StrokeJoin)
	end
	label.Parent = parent
	return label
end

function Gui.Billboard(parent: Instance?, props: BillboardProps): BillboardGui
	local gui = Instance.new("BillboardGui")
	if props.Name then
		gui.Name = props.Name
	end
	if props.Adornee then
		gui.Adornee = props.Adornee
	end
	if props.Size then
		gui.Size = props.Size
	end
	if props.Offset then
		gui.StudsOffset = props.Offset
	end
	if props.AlwaysOnTop ~= nil then
		gui.AlwaysOnTop = props.AlwaysOnTop
	end
	if props.LightInfluence then
		gui.LightInfluence = props.LightInfluence
	end
	if props.MaxDistance then
		gui.MaxDistance = props.MaxDistance
	end
	if props.Enabled ~= nil then
		gui.Enabled = props.Enabled
	end
	gui.Parent = parent
	return gui
end

function Gui.Surface(parent: Instance?, props: SurfaceProps): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	if props.Name then
		gui.Name = props.Name
	end
	if props.Face then
		gui.Face = props.Face
	end
	if props.Adornee then
		gui.Adornee = props.Adornee
	end
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	if props.PixelsPerStud then
		gui.PixelsPerStud = props.PixelsPerStud
	end
	if props.LightInfluence then
		gui.LightInfluence = props.LightInfluence
	end
	if props.AlwaysOnTop ~= nil then
		gui.AlwaysOnTop = props.AlwaysOnTop
	end
	if props.MaxDistance then
		gui.MaxDistance = props.MaxDistance
	end
	if props.Enabled ~= nil then
		gui.Enabled = props.Enabled
	end
	gui.Parent = parent
	return gui
end

return table.freeze(Gui)
