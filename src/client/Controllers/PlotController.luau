--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldNames = require(ReplicatedStorage.Config.WorldNames)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local WaitFor = require(ReplicatedStorage.Packages.WaitFor)

local Attributes = WorldNames.Attributes
local Folders = WorldNames.Folders
local Parts = WorldNames.Parts

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	Changed: Signal.Signal<Model?>,
	_trove: TroveInstance?,
}

local plotWaitSeconds = 30

local PlotController = {
	Name = "PlotController",
	Changed = Signal.new() :: Signal.Signal<Model?>,
	_trove = nil :: TroveInstance?,
}
local own: Model? = nil
local base: BasePart? = nil
local rollKey: BasePart? = nil

local function setOwn(model: Model?)
	if model == own then
		return
	end
	own = model
	base = nil
	rollKey = nil
	PlotController.Changed:Fire(model)
end

local function findOwn(folder: Instance): Model?
	local userId = Players.LocalPlayer.UserId
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and child:GetAttribute(Attributes.Owner) == userId then
			return child
		end
	end
	return nil
end

local function watchPlots(folder: Instance, trove: TroveInstance)
	local function refresh()
		setOwn(findOwn(folder))
	end
	local function watch(child: Instance)
		if child:IsA("Model") then
			trove:Connect(child:GetAttributeChangedSignal(Attributes.Owner), refresh)
		end
	end
	for _, child in folder:GetChildren() do
		watch(child)
	end
	trove:Connect(folder.ChildAdded, function(child: Instance)
		watch(child)
		refresh()
	end)
	trove:Connect(folder.ChildRemoved, refresh)
	refresh()
end

local function childPart(name: string, cached: BasePart?): BasePart?
	local model = own
	if not model then
		return nil
	end
	if cached and cached.Parent == model then
		return cached
	end
	local found = model:FindFirstChild(name)
	return if found and found:IsA("BasePart") then found else nil
end

function PlotController.GetPlot(_self: State): Model?
	return own
end

function PlotController.GetBase(_self: State): BasePart?
	base = childPart(Parts.Base, base)
	return base
end

function PlotController.GetRollKey(_self: State): BasePart?
	rollKey = childPart(Parts.RollKey, rollKey)
	return rollKey
end

function PlotController.Observe(_self: State, callback: (plot: Model?) -> ()): Signal.Connection
	local connection = PlotController.Changed:Connect(callback)
	callback(own)
	return connection
end

function PlotController.Init(self: State, _registry: { [string]: any })
	self._trove = Trove.new()
	own = nil
	base = nil
	rollKey = nil
end

function PlotController.Start(self: State)
	local trove = self._trove :: TroveInstance
	local promise = WaitFor.Child(workspace, Folders.Plots, plotWaitSeconds)
		:andThen(function(folder: Instance)
			local plotsTrove = Trove.new()
			trove:Add(plotsTrove)
			watchPlots(folder, plotsTrove)
		end)
		:catch(function(problem: any)
			warn(`[PlotController] workspace.Plots not found: {tostring(problem)}`)
		end)
	trove:Add(function()
		promise:cancel()
	end)
end

function PlotController.Destroy(self: State)
	PlotController.Changed:DisconnectAll()
	own = nil
	base = nil
	rollKey = nil
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return PlotController
