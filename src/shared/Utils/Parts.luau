--!strict

export type Props = {
	Name: string?,
	Parent: Instance?,
	Shape: Enum.PartType?,
	Size: Vector3?,
	CFrame: CFrame?,
	Color: Color3?,
	Material: Enum.Material?,
	Transparency: number?,
	Reflectance: number?,
	Anchored: boolean?,
	Passive: boolean?,
	CanCollide: boolean?,
	CanQuery: boolean?,
	CanTouch: boolean?,
	CastShadow: boolean?,
	Massless: boolean?,
	Smooth: boolean?,
}

local Parts = {}

function Parts.Passive(part: BasePart)
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
end

function Parts.Smooth(part: Part)
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

function Parts.New(props: Props): Part
	local part = Instance.new("Part")
	if props.Name then
		part.Name = props.Name
	end
	if props.Shape then
		part.Shape = props.Shape
	end
	if props.Anchored ~= nil then
		part.Anchored = props.Anchored
	end
	if props.Passive then
		Parts.Passive(part)
	end
	if props.CanCollide ~= nil then
		part.CanCollide = props.CanCollide
	end
	if props.CanQuery ~= nil then
		part.CanQuery = props.CanQuery
	end
	if props.CanTouch ~= nil then
		part.CanTouch = props.CanTouch
	end
	if props.CastShadow ~= nil then
		part.CastShadow = props.CastShadow
	end
	if props.Massless ~= nil then
		part.Massless = props.Massless
	end
	if props.Size then
		part.Size = props.Size
	end
	if props.CFrame then
		part.CFrame = props.CFrame
	end
	if props.Color then
		part.Color = props.Color
	end
	if props.Material then
		part.Material = props.Material
	end
	if props.Transparency then
		part.Transparency = props.Transparency
	end
	if props.Reflectance then
		part.Reflectance = props.Reflectance
	end
	if props.Smooth then
		Parts.Smooth(part)
	end
	if props.Parent then
		part.Parent = props.Parent
	end
	return part
end

return table.freeze(Parts)
