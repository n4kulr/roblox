--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Keys = require(ReplicatedStorage.Config.Keys)
local FloorGrid = require(ReplicatedStorage.Rules.FloorGrid)
local Trove = require(ReplicatedStorage.Packages.Trove)
local MeshTemplates = require(script.Parent.Parent.Utils.MeshTemplates)
local Caps = require(script.Parent.PlotService.Caps)
local Legend = require(script.Parent.PlotService.Legend)

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	_trove: TroveInstance?,
}
export type Cell = {
	I: number,
	J: number,
	X: number,
	Z: number,
}
export type Plan = {
	Frame: CFrame,
	Diameter: number,
	Cells: { Cell },
}

local partName = "keyboardstuff"
local modelName = "CosmeticKeys"
local inset = 0.5
local walkwayThickness = 0.2
local accentChance = 15
local accentBlend = 0.45
local gridOffset = 512
local gridStride = 1024
local meshTimeout = 6
local capHeight = FloorGrid.CapHeight

local CosmeticService = {
	Name = "CosmeticService",
	_trove = nil :: TroveInstance?,
}

local accents: { Color3 } = {}
for _, rarity in Keys.Rarities do
	if
		rarity.Name == "Uncommon"
		or rarity.Name == "Rare"
		or rarity.Name == "Epic"
		or rarity.Name == "Legendary"
	then
		table.insert(accents, rarity.Color:Lerp(Caps.FillerColor, accentBlend))
	end
end

local function findPart(): BasePart?
	for _, descendant in workspace:GetDescendants() do
		if descendant:IsA("BasePart") and string.lower(descendant.Name) == partName then
			return descendant
		end
	end
	return nil
end

function CosmeticService.Plan(part: BasePart): Plan?
	local cframe = part.CFrame
	local size = part.Size
	local vectors = { cframe.RightVector, cframe.UpVector, cframe.LookVector }
	local sizes = { size.X, size.Y, size.Z }
	local top = 1
	for index = 2, 3 do
		if math.abs(vectors[index].Y) > math.abs(vectors[top].Y) then
			top = index
		end
	end
	local up = vectors[top]
	if up.Y < 0 then
		up = -up
	end
	local first = if top == 1 then 2 else 1
	local second = if top == 3 then 2 else 3
	local diameter = math.min(sizes[first], sizes[second])
	local right = vectors[first]
	local center = cframe.Position + up * (sizes[top] / 2)
	local frame = CFrame.fromMatrix(center, right, up, right:Cross(up))
	local radius = diameter / 2 - inset
	local pitch = FloorGrid.CellSize
	local half = FloorGrid.CapSize() / 2
	local cells: { Cell } = {}
	local reach = math.floor(radius / pitch) + 1
	for i = -reach, reach do
		for j = -reach, reach do
			local x = i * pitch
			local z = j * pitch
			local cornerX = math.abs(x) + half
			local cornerZ = math.abs(z) + half
			if math.sqrt(cornerX * cornerX + cornerZ * cornerZ) <= radius then
				table.insert(cells, { I = i, J = j, X = x, Z = z })
			end
		end
	end
	if #cells == 0 then
		return nil
	end
	return { Frame = frame, Diameter = diameter, Cells = cells }
end

local function buildCap(plan: Plan, cell: Cell): BasePart
	local cap = Caps.Blank(plan.Frame * CFrame.new(cell.X, capHeight / 2 - Caps.FillerSink, cell.Z))
	cap.Name = `Cosmetic{cell.I}_{cell.J}`
	cap:SetAttribute("Cosmetic", true)
	cap:SetAttribute("GridX", cell.I)
	cap:SetAttribute("GridZ", cell.J)
	local seed = Legend.SeedOf(modelName, (cell.I + gridOffset) * gridStride + cell.J + gridOffset)
	if #accents > 0 and Legend.Hash(seed + 7919) % 100 < accentChance then
		cap.Color = accents[Legend.Hash(seed + 104729) % #accents + 1]
	end
	Legend.Attach(cap, seed)
	return cap
end

function CosmeticService.Build(part: BasePart): Model?
	local plan = CosmeticService.Plan(part)
	if not plan then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = modelName
	for _, cell in plan.Cells do
		buildCap(plan, cell).Parent = model
	end
	local walkway = Instance.new("Part")
	walkway.Name = "Walkway"
	walkway.Shape = Enum.PartType.Cylinder
	walkway.Anchored = true
	walkway.CanCollide = true
	walkway.CanQuery = true
	walkway.CanTouch = false
	walkway.Transparency = 1
	walkway.Size = Vector3.new(walkwayThickness, plan.Diameter, plan.Diameter)
	walkway.CFrame = plan.Frame
		* CFrame.new(0, capHeight - walkwayThickness / 2, 0)
		* CFrame.Angles(0, 0, math.pi / 2)
	walkway.Parent = model
	model:SetAttribute("Frame", plan.Frame)
	model:SetAttribute("Pitch", FloorGrid.CellSize)
	model:SetAttribute("CapHeight", capHeight)
	return model
end

function CosmeticService.Init(self: State, _services: { [string]: any })
	self._trove = Trove.new()
end

function CosmeticService.Start(self: State)
	local trove = self._trove :: TroveInstance
	local thread = task.spawn(function()
		MeshTemplates.Wait(meshTimeout)
		local part = findPart()
		if not part then
			return
		end
		local model = CosmeticService.Build(part)
		if model then
			model.Parent = workspace
			trove:Add(model)
		end
	end)
	trove:Add(function()
		if coroutine.status(thread) == "suspended" then
			task.cancel(thread)
		end
	end)
end

function CosmeticService.Destroy(self: State)
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return CosmeticService
