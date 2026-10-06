--!strict

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Eggs = require(ReplicatedStorage.Config.Eggs)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local FloorGrid = require(ReplicatedStorage.Rules.FloorGrid)
local BaseBounds = require(ReplicatedStorage.Utils.BaseBounds)
local EggModel = require(ReplicatedStorage.Utils.EggModel)
local EggPlacement = require(ReplicatedStorage.Utils.EggPlacement)
local Guide = require(script.Guide)
local Wobble = require(script.Wobble)
local WorldNames = require(ReplicatedStorage.Config.WorldNames)
local Attributes = WorldNames.Attributes
local Folders = WorldNames.Folders
local Parts = WorldNames.Parts

type TroveInstance = typeof(Trove.new())

type State = {
	Name: string,
	_trove: TroveInstance?,
}

type Plot = {
	Model: Model,
	Base: BasePart,
	RollKey: EggPlacement.Rect?,
}

local eggAttribute = Attributes.EggId
local nearMargin = 14
local farLimit = 60
local scanSeconds = 0.5
local validColor = Color3.fromRGB(90, 235, 120)
local invalidColor = Color3.fromRGB(255, 80, 80)
local messages: { [string]: string } = {
	Invalid = "Place eggs on your base!",
	Bounds = "Place eggs on your base!",
	RollKey = "Not on the Roll Key!",
	Spacing = "Too close to another egg!",
}

local EggController = {
	Name = "EggController",
	_trove = nil :: TroveInstance?,
}
local controllers: { [string]: any } = {}
local ghostFolder: Folder? = nil
local ghostModel: Model? = nil
local ghostParts: { BasePart } = {}
local ghostEggId = ""
local ghostColor: Color3? = nil
local heldTool: Tool? = nil
local toolTrove: TroveInstance? = nil
local pointer: Vector2? = nil
local isTouch = false
local isPlacing = false
local ownPlot: Plot? = nil
local models: { Model } = {}
local scanAt = 0
local heldId = ""
local guide: Guide.Guide? = nil

local function toast(text: string, kind: string)
	local ui = controllers.UIController
	if ui then
		ui:Toast(text, kind)
	end
end

local function findOwnPlot(): Plot?
	local current = ownPlot
	local userId = Players.LocalPlayer.UserId
	if current and current.Model.Parent ~= nil and current.Model:GetAttribute(Attributes.Owner) == userId then
		return current
	end
	ownPlot = nil
	local plots = workspace:FindFirstChild(Folders.Plots)
	if not plots then
		return nil
	end
	for _, plot in plots:GetChildren() do
		local base = plot:FindFirstChild(Parts.Base)
		if plot:GetAttribute(Attributes.Owner) == userId and base and base:IsA("BasePart") then
			local rollKey = plot:FindFirstChild(Parts.RollKey)
			ownPlot = {
				Model = plot :: Model,
				Base = base,
				RollKey = if rollKey and rollKey:IsA("BasePart")
					then EggPlacement.RectOf(base.CFrame, rollKey)
					else nil,
			}
			return ownPlot
		end
	end
	return nil
end

local function placedList(): { EggPlacement.Spot }
	local data = controllers.DataController
	local list = if data then data:Get({ "PlacedEggs" }) else nil
	local spots: { EggPlacement.Spot } = {}
	if type(list) == "table" then
		for _, entry in list do
			if type(entry) == "table" and type(entry.X) == "number" and type(entry.Z) == "number" then
				table.insert(spots, { X = entry.X, Z = entry.Z })
			end
		end
	end
	return spots
end

local function pointerHit(plot: Plot): (number?, number?)
	local camera = workspace.CurrentCamera
	if not camera then
		return nil, nil
	end
	local touched = pointer
	local point = if touched and isTouch then touched else UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(point.X, point.Y)
	local base = plot.Base.CFrame
	local origin = base:PointToObjectSpace(ray.Origin)
	local direction = base:VectorToObjectSpace(ray.Direction)
	local planeY = plot.Base.Size.Y / 2 + FloorGrid.CapHeight
	if direction.Y >= -1e-4 then
		return nil, nil
	end
	local t = (planeY - origin.Y) / direction.Y
	if t < 0 then
		return nil, nil
	end
	return origin.X + direction.X * t, origin.Z + direction.Z * t
end

local function isNearBase(plot: Plot): boolean
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return root ~= nil
		and root:IsA("BasePart")
		and BaseBounds.Contains(plot.Base.CFrame, plot.Base.Size, root.Position, nearMargin)
end

local function evaluate(plot: Plot, x: number, z: number): string
	if #placedList() >= Eggs.PlacedCap then
		return "Full"
	end
	return EggPlacement.Check(plot.Base.Size, plot.RollKey, placedList(), x, z)
end

local function clearGhost()
	if ghostModel then
		ghostModel:Destroy()
	end
	ghostModel = nil
	table.clear(ghostParts)
	ghostEggId = ""
	ghostColor = nil
end

local function ensureGhost(eggId: string): boolean
	if ghostModel and ghostEggId == eggId then
		return true
	end
	clearGhost()
	local egg = Eggs.ById[eggId]
	local folder = ghostFolder
	if not egg or not folder then
		return false
	end
	local model = Instance.new("Model")
	model.Name = "EggGhost"
	local parts = EggModel.Build(model, egg, {
		Scale = EggModel.PlacedScale,
		Anchored = true,
		Ghost = validColor,
	})
	model.PrimaryPart = parts[1]
	model.Parent = folder
	ghostModel = model
	ghostParts = parts
	ghostEggId = eggId
	ghostColor = validColor
	return true
end

local function updateGhost(tool: Tool)
	local eggId = tool:GetAttribute(eggAttribute)
	local plot = findOwnPlot()
	if type(eggId) ~= "string" or not plot or not isNearBase(plot) then
		clearGhost()
		return
	end
	local x, z = pointerHit(plot)
	if
		not x
		or not z
		or math.abs(x) > plot.Base.Size.X / 2 + farLimit
		or math.abs(z) > plot.Base.Size.Z / 2 + farLimit
		or not ensureGhost(eggId)
	then
		clearGhost()
		return
	end
	local color = if evaluate(plot, x, z) == "Ok" then validColor else invalidColor
	if color ~= ghostColor then
		ghostColor = color
		EggModel.Tint(ghostParts, color)
	end
	local height = EggModel.HeightOf(EggModel.PlacedScale)
	local floorY = plot.Base.Size.Y / 2 + FloorGrid.CapHeight
	local center = plot.Base.CFrame * CFrame.new(x, floorY + height / 2, z)
	local model = ghostModel :: Model
	model:PivotTo(center * CFrame.new(EggModel.PivotOffset(EggModel.PlacedScale)))
end

local function place(tool: Tool)
	local eggId = tool:GetAttribute(eggAttribute)
	local plot = findOwnPlot()
	if isPlacing or type(eggId) ~= "string" then
		return
	end
	if not plot or not isNearBase(plot) then
		toast(messages.Invalid, "Bad")
		return
	end
	local x, z = pointerHit(plot)
	if not x or not z then
		toast(messages.Invalid, "Bad")
		return
	end
	local verdict = evaluate(plot, x, z)
	if verdict == "Full" then
		toast(`Your base holds {Eggs.PlacedCap} eggs! Hatch one first.`, "Bad")
		return
	end
	if verdict ~= "Ok" then
		toast(messages[verdict] or messages.Invalid, "Bad")
		return
	end
	isPlacing = true
	task.spawn(function()
		local placed = Packets.PlaceEgg:Fire(eggId, x, z)
		isPlacing = false
		if placed == true then
			toast(Eggs.Guide.PlacedToast, "Good")
		else
			toast("Couldn't place that egg!", "Bad")
		end
	end)
end

local function heldEgg(): Tool?
	local character = Players.LocalPlayer.Character
	if not character then
		return nil
	end
	for _, child in character:GetChildren() do
		if child:IsA("Tool") and type(child:GetAttribute(eggAttribute)) == "string" then
			return child
		end
	end
	return nil
end

local function dropGuide()
	local current = guide
	guide = nil
	if current then
		current:Destroy()
	end
end

local function syncGuide(clock: number)
	if heldId == "" then
		dropGuide()
		return
	end
	local plot = findOwnPlot()
	local playerGui = Players.LocalPlayer:FindFirstChild("PlayerGui")
	if not guide and plot and playerGui then
		guide = Guide.new(plot.Base, playerGui)
	end
	local current = guide
	if current then
		local character = Players.LocalPlayer.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		current:Update(clock, if root and root:IsA("BasePart") then root else nil, workspace.CurrentCamera)
	end
end

local function bindTool(trove: TroveInstance, tool: Tool?)
	if tool == heldTool then
		return
	end
	if toolTrove then
		toolTrove:Destroy()
		toolTrove = nil
	end
	heldTool = tool
	clearGhost()
	if tool then
		local bound = Trove.new()
		bound:Connect(tool.Activated, function()
			place(tool)
		end)
		toolTrove = bound
		trove:Add(bound)
	end
end

function EggController.Init(self: State, registry: { [string]: any })
	controllers = registry
	self._trove = Trove.new()
end

function EggController.Start(self: State)
	local trove = self._trove :: TroveInstance
	local folder = Instance.new("Folder")
	folder.Name = "EggGhosts"
	folder.Parent = workspace
	trove:Add(folder)
	ghostFolder = folder
	local data = controllers.DataController
	if data then
		trove:Add(data:Observe({ "HeldEgg" }, function(value: any)
			heldId = if type(value) == "string" and Eggs.ById[value] ~= nil then value else ""
			if heldId == "" then
				dropGuide()
			end
		end))
	end
	trove:Connect(UserInputService.InputChanged, function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			isTouch = true
			pointer = Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset()
		elseif input.UserInputType == Enum.UserInputType.MouseMovement then
			isTouch = false
		end
	end)
	trove:Connect(UserInputService.InputBegan, function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			isTouch = true
			pointer = Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset()
		end
	end)
	trove:Connect(RunService.RenderStepped, function(_dt: number)
		local clock = os.clock()
		if clock >= scanAt then
			scanAt = clock + scanSeconds
			models = Wobble.Collect()
		end
		Wobble.Step(models, os.time(), clock)
		syncGuide(clock)
		local tool = heldEgg()
		bindTool(trove, tool)
		if tool then
			updateGhost(tool)
		end
	end)
end

function EggController.Destroy(self: State)
	dropGuide()
	heldId = ""
	if toolTrove then
		toolTrove:Destroy()
		toolTrove = nil
	end
	heldTool = nil
	ghostModel = nil
	ghostFolder = nil
	table.clear(ghostParts)
	table.clear(models)
	ownPlot = nil
	pointer = nil
	isTouch = false
	isPlacing = false
	scanAt = 0
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return EggController
