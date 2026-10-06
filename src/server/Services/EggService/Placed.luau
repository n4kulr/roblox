--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Eggs = require(ReplicatedStorage.Config.Eggs)
local FloorGrid = require(ReplicatedStorage.Rules.FloorGrid)
local EggModel = require(ReplicatedStorage.Utils.EggModel)
local Gui = require(ReplicatedStorage.Utils.Gui)
local Parts = require(ReplicatedStorage.Utils.Parts)
local TimeFormat = require(ReplicatedStorage.Utils.TimeFormat)
local Inventory = require(script.Parent.Inventory)

export type Shown = {
	Plot: Instance?,
	Folder: Folder?,
	Models: { [number]: Model },
}

local folderName = "PlacedEggs"
local scale = EggModel.PlacedScale
local labelRise = 1.9
local readyColor = Color3.fromRGB(255, 226, 90)
local ink = Color3.fromRGB(20, 20, 25)

local Placed = {}

Placed.FolderName = folderName
Placed.Scale = scale

function Placed.NewShown(): Shown
	return { Plot = nil, Folder = nil, Models = {} }
end

function Placed.IsPlot(plot: any): boolean
	return plot ~= nil and type(plot.FindFirstChild) == "function"
end

local function newLabel(model: Model, center: CFrame, height: number)
	local anchor = Parts.New({
		Name = "LabelAnchor",
		Parent = model,
		Anchored = true,
		Passive = true,
		Transparency = 1,
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = center * CFrame.new(0, height / 2 + labelRise, 0),
	})
	local gui = Gui.Billboard(anchor, {
		Name = "Countdown",
		Size = UDim2.fromOffset(190, 56),
		AlwaysOnTop = false,
		MaxDistance = 90,
	})
	Gui.Label(gui, { Name = "Text", Color = Color3.new(1, 1, 1), StrokeThickness = 2.5, StrokeColor = ink })
end

local function create(
	folder: Folder,
	base: BasePart,
	index: number,
	entry: Inventory.Placed,
	egg: Eggs.Egg
): Model
	local model = Instance.new("Model")
	model.Name = `PlacedEgg{index}`
	local height = EggModel.HeightOf(scale)
	local floorY = base.Size.Y / 2 + FloorGrid.CapHeight
	local center = base.CFrame * CFrame.new(entry.X, floorY + height / 2, entry.Z)
	local parts = EggModel.Build(model, egg, { Scale = scale, Anchored = true, Origin = center })
	model.PrimaryPart = parts[1]
	model:SetAttribute("EggId", egg.Id)
	model:SetAttribute("X", entry.X)
	model:SetAttribute("Z", entry.Z)
	model:SetAttribute("Phase", index * 1.7)
	model:SetAttribute("Drop", EggModel.PivotDrop(scale))
	model:SetAttribute("BaseCFrame", center * CFrame.new(EggModel.PivotOffset(scale)))
	newLabel(model, center, height)
	model.Parent = folder
	return model
end

local function textOf(egg: Eggs.Egg, readyAt: number, now: number): (string, Color3)
	local left = readyAt - now
	if left <= 0 then
		return "READY! Hold E", readyColor
	end
	return `{egg.Name}\n{TimeFormat.Clock(left)}`, Color3.new(1, 1, 1)
end

function Placed.Clear(shown: Shown)
	for index, model in shown.Models do
		model:Destroy()
		shown.Models[index] = nil
	end
	shown.Plot = nil
	shown.Folder = nil
end

function Placed.Remove(shown: Shown, index: number)
	local top = 0
	for key in shown.Models do
		top = math.max(top, key)
	end
	local removed = shown.Models[index]
	if removed then
		removed:Destroy()
	end
	for key = index, top do
		shown.Models[key] = shown.Models[key + 1]
	end
end

local function folderOf(shown: Shown, plot: Model): Folder
	if shown.Folder and shown.Plot == plot and shown.Folder.Parent ~= nil then
		return shown.Folder
	end
	Placed.Clear(shown)
	local existing = plot:FindFirstChild(folderName)
	local folder: Folder
	if existing and existing:IsA("Folder") then
		folder = existing
		for _, child in folder:GetChildren() do
			child:Destroy()
		end
	else
		folder = Instance.new("Folder")
		folder.Name = folderName
		folder.Parent = plot
	end
	shown.Plot = plot
	shown.Folder = folder
	return folder
end

function Placed.Refresh(shown: Shown, plot: Model, base: BasePart, list: { Inventory.Placed }, now: number)
	local folder = folderOf(shown, plot)
	for index, model in shown.Models do
		local entry = list[index]
		if
			not entry
			or model:GetAttribute("EggId") ~= entry.Id
			or model:GetAttribute("X") ~= entry.X
			or model:GetAttribute("Z") ~= entry.Z
		then
			model:Destroy()
			shown.Models[index] = nil
		end
	end
	for index, entry in list do
		local egg = Eggs.ById[entry.Id]
		if egg then
			local model = shown.Models[index]
			if not model then
				model = create(folder, base, index, entry, egg)
				shown.Models[index] = model
			end
			model.Name = `PlacedEgg{index}`
			model:SetAttribute("Index", index)
			model:SetAttribute("ReadyAt", entry.ReadyAt)
			local label = model:FindFirstChild("Text", true)
			if label and label:IsA("TextLabel") then
				local text, color = textOf(egg, entry.ReadyAt, now)
				label.Text = text
				label.TextColor3 = color
			end
		end
	end
end

return Placed
