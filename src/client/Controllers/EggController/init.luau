--!strict

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Eggs = require(ReplicatedStorage.Config.Eggs)
local WorldNames = require(ReplicatedStorage.Config.WorldNames)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local EggPlacement = require(ReplicatedStorage.Utils.EggPlacement)
local Config = require(script.Config)
local Ghost = require(script.Ghost)
local Guide = require(script.Guide)
local Hatching = require(script.Hatching)
local HeldTool = require(script.HeldTool)
local Placement = require(script.Placement)
local Types = require(script.Types)
local Wobble = require(script.Wobble)

local Folders = WorldNames.Folders

type TroveInstance = typeof(Trove.new())

type State = {
	Name: string,
	_trove: TroveInstance?,
}

local EggController = {
	Name = "EggController",
	_trove = nil :: TroveInstance?,
}
local controllers: { [string]: any } = {}
local ghost: Ghost.Ghost? = nil
local heldTool: Tool? = nil
local toolTrove: TroveInstance? = nil
local pointer: Vector2? = nil
local isTouch = false
local isPlacing = false
local ownPlot: Types.Plot? = nil
local placed: Wobble.Entries = {}
local spots: { EggPlacement.Spot } = {}
local heldId = ""
local guide: Guide.Guide? = nil

local function toast(text: string, kind: string)
	controllers.UIController:Toast(text, kind)
end

local function findOwnPlot(): Types.Plot?
	local plots = controllers.PlotController
	local model = plots:GetPlot()
	local base = plots:GetBase()
	if not model or not base then
		ownPlot = nil
		return nil
	end
	local current = ownPlot
	if current and current.Model == model and current.Base == base then
		return current
	end
	local rollKey = plots:GetRollKey()
	ownPlot = {
		Model = model,
		Base = base,
		RollKey = if rollKey then EggPlacement.RectOf(base.CFrame, rollKey) else nil,
	}
	return ownPlot
end

local function rootOfLocal(): BasePart?
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function pointerPoint(): Vector2
	local touched = pointer
	return if touched and isTouch then touched else UserInputService:GetMouseLocation()
end

local function clearGhost()
	local current = ghost
	if current then
		Ghost.Clear(current)
	end
end

local function updateGhost(tool: Tool)
	local eggId = tool:GetAttribute(WorldNames.Attributes.EggId)
	local plot = findOwnPlot()
	local current = ghost
	if
		type(eggId) ~= "string"
		or not plot
		or not current
		or not Placement.IsNearBase(plot, rootOfLocal())
	then
		clearGhost()
		return
	end
	local x, z = Placement.PointerHit(plot, pointerPoint())
	if not x or not z or Placement.IsFar(plot, x, z) then
		clearGhost()
		return
	end
	local isValid = Placement.Evaluate(plot, spots, x, z) == Config.OkVerdict
	if not Ghost.Show(current, eggId, plot, x, z, isValid) then
		clearGhost()
	end
end

local function place(tool: Tool)
	local eggId = tool:GetAttribute(WorldNames.Attributes.EggId)
	local plot = findOwnPlot()
	if isPlacing or type(eggId) ~= "string" then
		return
	end
	if not plot or not Placement.IsNearBase(plot, rootOfLocal()) then
		toast(Config.Messages.Invalid, "Bad")
		return
	end
	local x, z = Placement.PointerHit(plot, pointerPoint())
	if not x or not z then
		toast(Config.Messages.Invalid, "Bad")
		return
	end
	local verdict = Placement.Evaluate(plot, spots, x, z)
	if verdict == Config.FullVerdict then
		toast(`Your base holds {Eggs.PlacedCap} eggs! Hatch one first.`, "Bad")
		return
	end
	if verdict ~= Config.OkVerdict then
		toast(Config.Messages[verdict] or Config.Messages.Invalid, "Bad")
		return
	end
	isPlacing = true
	task.spawn(function()
		local result = Packets.PlaceEgg:Fire(eggId, x, z)
		isPlacing = false
		if result == true then
			toast(Eggs.Guide.PlacedToast, "Good")
		else
			toast(Config.FailToast, "Bad")
		end
	end)
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
		current:Update(clock, rootOfLocal(), workspace.CurrentCamera)
	end
end

local function bindTool(trove: TroveInstance, tool: Tool?)
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

local function trackInput(trove: TroveInstance)
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
	ghost = Ghost.new(folder)
	trove:Add(controllers.DataController:Observe({ "HeldEgg" }, function(value: any)
		heldId = if type(value) == "string" and Eggs.ById[value] ~= nil then value else ""
		if heldId == "" then
			dropGuide()
		end
	end))
	trove:Add(controllers.DataController:Observe({ "PlacedEggs" }, function(value: any)
		Placement.Spots(value, spots)
	end))
	trackInput(trove)
	HeldTool.Watch(Players.LocalPlayer, trove, function(tool: Tool?)
		bindTool(trove, tool)
	end)
	local hatching: Hatching.Context = {
		GetOwnPlot = function()
			return controllers.PlotController:GetPlot()
		end,
		Hatch = function(index: number, eggId: string)
			controllers.CharmController:Hatch(index, eggId)
		end,
	}
	trove:Add(
		controllers.PlotController:WatchItems(
			Folders.PlacedEggs,
			function(plot: Model, model: Model, itemTrove: TroveInstance)
				placed[model] = Wobble.Track(model, itemTrove)
				itemTrove:Add(function()
					placed[model] = nil
				end)
				Hatching.Bind(hatching, plot, model, itemTrove, controllers.PlotController.Changed)
			end
		)
	)
	trove:Connect(RunService.RenderStepped, function(_dt: number)
		local clock = os.clock()
		local camera = workspace.CurrentCamera
		Wobble.Step(placed, os.time(), clock, if camera then camera.CFrame.Position else nil)
		syncGuide(clock)
		local tool = heldTool
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
	ghost = nil
	table.clear(placed)
	table.clear(spots)
	ownPlot = nil
	pointer = nil
	isTouch = false
	isPlacing = false
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return EggController
