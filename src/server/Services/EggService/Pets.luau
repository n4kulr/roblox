--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharmConfig = require(ReplicatedStorage.Config.Charms)
local FloorGrid = require(ReplicatedStorage.Rules.FloorGrid)
local EggPlacement = require(ReplicatedStorage.Utils.EggPlacement)
local PetWander = require(ReplicatedStorage.Utils.PetWander)

export type Shown = {
	Plot: Instance?,
	Folder: Folder?,
	Key: string,
	Models: { Model },
}

local folderName = "Pets"
local baseSize = 1.5
local sizeStep = 0.25
local ink = Color3.fromRGB(20, 20, 25)
local eyeColor = Color3.fromRGB(25, 25, 30)

local Pets = {}

Pets.FolderName = folderName

function Pets.NewShown(): Shown
	return { Plot = nil, Folder = nil, Key = "", Models = {} }
end

local function newPart(model: Model, name: string, shape: Enum.PartType, size: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Shape = shape
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Size = size
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

function Pets.SizeOf(rarity: string): number
	local info = CharmConfig.RarityByName[rarity]
	return baseSize + sizeStep * ((if info then info.Order else 1) - 1)
end

local function build(charm: CharmConfig.Charm): (Model, number)
	local s = Pets.SizeOf(charm.Rarity)
	local color = charm.Color
	local model = Instance.new("Model")
	model.Name = `Pet_{charm.Id}`
	local block, ball = Enum.PartType.Block, Enum.PartType.Ball
	local body = newPart(model, "Body", block, Vector3.new(0.7, 0.55, 0.95) * s, color)
	local head = newPart(model, "Head", ball, Vector3.new(0.6, 0.6, 0.6) * s, color)
	local leftEar = newPart(model, "LeftEar", block, Vector3.new(0.16, 0.28, 0.12) * s, color)
	local rightEar = newPart(model, "RightEar", block, Vector3.new(0.16, 0.28, 0.12) * s, color)
	local leftEye = newPart(model, "LeftEye", ball, Vector3.new(0.1, 0.1, 0.1) * s, eyeColor)
	local rightEye = newPart(model, "RightEye", ball, Vector3.new(0.1, 0.1, 0.1) * s, eyeColor)
	local tail = newPart(model, "Tail", ball, Vector3.new(0.22, 0.22, 0.22) * s, Color3.new(1, 1, 1))
	body.CFrame = CFrame.new()
	head.CFrame = CFrame.new(0, 0.28 * s, -0.5 * s)
	leftEar.CFrame = CFrame.new(-0.2 * s, 0.62 * s, -0.5 * s)
	rightEar.CFrame = CFrame.new(0.2 * s, 0.62 * s, -0.5 * s)
	leftEye.CFrame = CFrame.new(-0.14 * s, 0.34 * s, -0.78 * s)
	rightEye.CFrame = CFrame.new(0.14 * s, 0.34 * s, -0.78 * s)
	tail.CFrame = CFrame.new(0, 0.1 * s, 0.55 * s)
	model.PrimaryPart = body
	local gui = Instance.new("BillboardGui")
	gui.Name = "Name"
	gui.Adornee = body
	gui.Size = UDim2.fromOffset(120, 22)
	gui.StudsOffset = Vector3.new(0, 0.9 * s + 0.6, 0)
	gui.MaxDistance = 40
	gui.AlwaysOnTop = false
	gui.Parent = body
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = charm.Name
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = ink
	stroke.Parent = label
	return model, s
end

function Pets.Clear(shown: Shown)
	for index, model in shown.Models do
		model:Destroy()
		shown.Models[index] = nil
	end
	if shown.Folder then
		shown.Folder:Destroy()
	end
	shown.Plot = nil
	shown.Folder = nil
	shown.Key = ""
end

local function folderOf(shown: Shown, plot: Model): Folder
	if shown.Folder and shown.Plot == plot and shown.Folder.Parent ~= nil then
		return shown.Folder
	end
	Pets.Clear(shown)
	local existing = plot:FindFirstChild(folderName)
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = folderName
	folder.Parent = plot
	shown.Plot = plot
	shown.Folder = folder
	return folder
end

function Pets.Refresh(
	shown: Shown,
	plot: Model,
	base: BasePart,
	rollKey: BasePart?,
	ownerId: number,
	active: { string }
)
	local folder = folderOf(shown, plot)
	local key = table.concat(active, ",")
	if key == shown.Key and #shown.Models == #active then
		return
	end
	for index, model in shown.Models do
		model:Destroy()
		shown.Models[index] = nil
	end
	shown.Key = key
	local avoid = if rollKey then EggPlacement.RectOf(base.CFrame, rollKey) else nil
	local floorY = base.Size.Y / 2 + FloorGrid.CapHeight
	for index, id in active do
		local charm = CharmConfig.ById[id]
		if charm then
			local model, size = build(charm)
			local seed = ownerId * 31 + index * 7919
			local walker = PetWander.New(seed, base.Size.X / 2, base.Size.Z / 2, avoid)
			local lift = 0.275 * size
			model:SetAttribute("Owner", ownerId)
			model:SetAttribute("PetId", id)
			model:SetAttribute("Seed", seed)
			model:SetAttribute("Lift", lift)
			model:PivotTo(
				base.CFrame
					* CFrame.new(walker.X, floorY + lift, walker.Z)
					* CFrame.Angles(0, walker.Heading, 0)
			)
			model.Parent = folder
			shown.Models[index] = model
		end
	end
end

return Pets
