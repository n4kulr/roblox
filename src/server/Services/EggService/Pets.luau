--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharmConfig = require(ReplicatedStorage.Config.Charms)
local FloorGrid = require(ReplicatedStorage.Rules.FloorGrid)
local EggPlacement = require(ReplicatedStorage.Utils.EggPlacement)
local PetModels = require(ReplicatedStorage.Utils.PetModels)
local PetWander = require(ReplicatedStorage.Utils.PetWander)

export type Shown = {
	Plot: Instance?,
	Folder: Folder?,
	Key: string,
	Models: { Model },
}

local folderName = "Pets"
local ink = Color3.fromRGB(20, 20, 25)

local Pets = {}

Pets.FolderName = folderName

function Pets.NewShown(): Shown
	return { Plot = nil, Folder = nil, Key = "", Models = {} }
end

function Pets.SizeOf(rarity: string): number
	return PetModels.SizeOf(rarity)
end

local function build(charm: CharmConfig.Charm): (Model, number)
	local model, s = PetModels.Build(charm)
	local body = model.PrimaryPart :: BasePart
	local color = charm.Color
	local gui = Instance.new("BillboardGui")
	gui.Name = "Name"
	gui.Adornee = body
	gui.Size = UDim2.fromOffset(120, 22)
	gui.StudsOffset = Vector3.new(0, 1.1 * s + 0.5, 0)
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
			local lift = PetModels.LiftOf(size)
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
