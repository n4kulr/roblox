--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Eggs = require(ReplicatedStorage.Config.Eggs)
local TimeFormat = require(ReplicatedStorage.Utils.TimeFormat)

type Visual = {
	Model: Model,
	Dome: BasePart,
	Egg: { BasePart },
	Label: TextLabel,
	Gui: BillboardGui,
}

local folderName = "Incubators"
local ledgeDepth = 6
local spacing = 8
local pedestalHeight = 1.4
local eggSize = Vector3.new(2.2, 2.9, 2.2)
local metal = Color3.fromRGB(58, 62, 78)
local trim = Color3.fromRGB(255, 200, 60)
local ledgeColor = Color3.fromRGB(70, 74, 86)
local glassColor = Color3.fromRGB(190, 235, 255)
local emptyColor = Color3.fromRGB(120, 126, 142)
local spotOffsets =
	{ Vector3.new(0.5, 0.5, -0.9), Vector3.new(-0.6, -0.2, -0.95), Vector3.new(0.3, -0.9, -0.85) }

local Incubators = {}

Incubators.FolderName = folderName
Incubators.Count = Eggs.Slots

local function newPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	collide: boolean
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.CanCollide = collide
	part.CanQuery = collide
	part.CanTouch = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function sphere(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = newPart(parent, name, size, cframe, color, false)
	part.CanQuery = false
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

local function buildOne(folder: Folder, index: number, origin: CFrame, topY: number)
	local model = Instance.new("Model")
	model.Name = `Incubator{index}`
	model:SetAttribute("Index", index)
	model:SetAttribute("EggId", "")
	model:SetAttribute("ReadyAt", 0)
	local stand = origin * CFrame.new(0, topY + pedestalHeight / 2, 0)
	local pedestal = newPart(
		model,
		"Pedestal",
		Vector3.new(pedestalHeight, 4, 4),
		stand * CFrame.Angles(0, 0, math.rad(90)),
		metal,
		true
	)
	pedestal.Shape = Enum.PartType.Cylinder
	local rim = newPart(
		model,
		"Rim",
		Vector3.new(0.3, 4.4, 4.4),
		origin * CFrame.new(0, topY + pedestalHeight + 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)),
		trim,
		false
	)
	rim.Shape = Enum.PartType.Cylinder
	local center = origin * CFrame.new(0, topY + pedestalHeight + 0.3 + eggSize.Y / 2, 0)
	local egg: { BasePart } = {}
	table.insert(egg, sphere(model, "EggBody", eggSize, center, emptyColor))
	for spotIndex, offset in spotOffsets do
		table.insert(
			egg,
			sphere(
				model,
				`EggSpot{spotIndex}`,
				Vector3.new(0.6, 0.6, 0.2),
				center * CFrame.new(offset * Vector3.new(1, 1, 1)),
				Color3.new(1, 1, 1)
			)
		)
	end
	local dome = sphere(model, "Dome", Vector3.new(4.6, 5.4, 4.6), center, glassColor)
	dome.Transparency = 0.65
	dome.Material = Enum.Material.Glass
	dome.Reflectance = 0.1
	local anchor = newPart(
		model,
		"LabelAnchor",
		Vector3.new(0.2, 0.2, 0.2),
		center * CFrame.new(0, 3.6, 0),
		metal,
		false
	)
	anchor.Transparency = 1
	anchor.CanQuery = false
	local gui = Instance.new("BillboardGui")
	gui.Name = "Countdown"
	gui.Size = UDim2.fromOffset(190, 56)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 90
	gui.Enabled = false
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Text = ""
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2.5
	stroke.Color = Color3.fromRGB(20, 20, 25)
	stroke.Parent = label
	model.PrimaryPart = pedestal
	model.Parent = folder
end

function Incubators.Build(plot: Model, base: BasePart, board: BasePart): Folder
	local existing = plot:FindFirstChild(folderName)
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = folderName
	local baseCFrame = base.CFrame
	local halfZ = base.Size.Z / 2
	local boardZ = baseCFrame:PointToObjectSpace(board.CFrame.Position).Z
	local sign = if boardZ >= 0 then 1 else -1
	local topY = base.Size.Y / 2
	local ledgeWidth = math.min(base.Size.X, spacing * (Eggs.Slots + 1))
	newPart(
		folder,
		"Ledge",
		Vector3.new(ledgeWidth, base.Size.Y, ledgeDepth),
		baseCFrame * CFrame.new(0, 0, sign * (halfZ + ledgeDepth / 2)),
		ledgeColor,
		true
	)
	for index = 1, Eggs.Slots do
		local x = (index - (Eggs.Slots + 1) / 2) * spacing
		buildOne(folder, index, baseCFrame * CFrame.new(x, 0, sign * (halfZ + ledgeDepth / 2)), topY)
	end
	folder.Parent = plot
	return folder
end

function Incubators.Find(plot: Model): Folder?
	if type((plot :: any).FindFirstChild) ~= "function" then
		return nil
	end
	local found = plot:FindFirstChild(folderName)
	return if found and found:IsA("Folder") then found else nil
end

local function visualOf(folder: Folder, index: number): Visual?
	local model = folder:FindFirstChild(`Incubator{index}`)
	if not model or not model:IsA("Model") then
		return nil
	end
	local parts: { BasePart } = {}
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") and string.sub(child.Name, 1, 3) == "Egg" then
			table.insert(parts, child)
		end
	end
	local dome = model:FindFirstChild("Dome")
	local label = model:FindFirstChild("Text", true)
	local gui = model:FindFirstChild("Countdown", true)
	if
		not dome
		or not dome:IsA("BasePart")
		or not label
		or not label:IsA("TextLabel")
		or not gui
		or not gui:IsA("BillboardGui")
	then
		return nil
	end
	return { Model = model, Dome = dome, Egg = parts, Label = label, Gui = gui }
end

function Incubators.Refresh(folder: Folder, eggIds: { string }, readyAt: { number }, now: number)
	for index = 1, Eggs.Slots do
		local visual = visualOf(folder, index)
		if visual then
			local eggId = eggIds[index] or ""
			local egg = Eggs.ById[eggId]
			local ready = readyAt[index] or 0
			visual.Model:SetAttribute("EggId", if egg then eggId else "")
			visual.Model:SetAttribute("ReadyAt", if egg then ready else 0)
			for _, part in visual.Egg do
				part.Transparency = if egg then 0 else 1
				if egg and part.Name == "EggBody" then
					part.Color = egg.Color
				elseif egg then
					part.Color = egg.SpotColor
				end
			end
			visual.Gui.Enabled = egg ~= nil
			if egg then
				local left = ready - now
				visual.Label.Text = if left <= 0
					then "READY! Hold E"
					else `{egg.Name}\n{TimeFormat.Clock(left)}`
				visual.Label.TextColor3 = if left <= 0
					then Color3.fromRGB(255, 226, 90)
					else Color3.new(1, 1, 1)
			end
		end
	end
end

return Incubators
