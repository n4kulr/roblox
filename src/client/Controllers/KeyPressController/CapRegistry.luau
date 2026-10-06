--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local WorldNames = require(ReplicatedStorage.Config.WorldNames)
local Detection = require(script.Parent.Detection)
local Press = require(script.Parent.Press)
local Types = require(script.Parent.Types)

local Attributes = WorldNames.Attributes
local Folders = WorldNames.Folders

type TroveInstance = typeof(Trove.new())

local CapRegistry = {}

function CapRegistry.new(): Types.Registry
	return { Plots = {}, StandingOn = {}, Cosmetic = nil }
end

function CapRegistry.Clear(registry: Types.Registry)
	registry.Cosmetic = nil
	table.clear(registry.Plots)
	table.clear(registry.StandingOn)
end

local function newCap(part: BasePart): Types.CapState
	return { Part = part, Rest = part.CFrame, LastPress = 0, Tween = nil, Held = false, RaiseToken = nil }
end

local function forgetCap(registry: Types.Registry, cap: Types.CapState)
	Press.ReleaseTween(cap)
	for player, standing in registry.StandingOn do
		if standing == cap then
			registry.StandingOn[player] = nil
		end
	end
end

local function addCap(state: Types.PlotState, child: Instance)
	if not child:IsA("BasePart") then
		return
	end
	local cell = child:GetAttribute(Attributes.Cell)
	if type(cell) ~= "number" then
		return
	end
	local existing = state.Caps[cell]
	if existing then
		Press.ReleaseTween(existing)
	end
	state.Caps[cell] = newCap(child)
end

local function removeCap(registry: Types.Registry, state: Types.PlotState, child: Instance)
	for cell, cap in state.Caps do
		if cap.Part == child then
			state.Caps[cell] = nil
			forgetCap(registry, cap)
		end
	end
end

local function bindKeys(
	registry: Types.Registry,
	state: Types.PlotState,
	folder: Instance,
	trove: TroveInstance
)
	for _, child in folder:GetChildren() do
		addCap(state, child)
	end
	trove:Connect(folder.ChildAdded, function(child: Instance)
		addCap(state, child)
	end)
	trove:Connect(folder.ChildRemoved, function(child: Instance)
		removeCap(registry, state, child)
	end)
end

local function trackPlot(registry: Types.Registry, model: Model, parentTrove: TroveInstance)
	local trove = Trove.new()
	parentTrove:Add(trove)
	local state: Types.PlotState = { Model = model, Base = nil, Columns = nil, Rows = nil, Caps = {} }
	registry.Plots[model] = state
	local function readLayout()
		local columns = model:GetAttribute(Attributes.FloorColumns)
		local rows = model:GetAttribute(Attributes.FloorRows)
		state.Columns = if type(columns) == "number" then columns else nil
		state.Rows = if type(rows) == "number" then rows else nil
	end
	readLayout()
	trove:Connect(model:GetAttributeChangedSignal(Attributes.FloorColumns), readLayout)
	trove:Connect(model:GetAttributeChangedSignal(Attributes.FloorRows), readLayout)
	trove:Add(function()
		registry.Plots[model] = nil
		for _, cap in state.Caps do
			forgetCap(registry, cap)
		end
	end)
	local keysFolder = model:FindFirstChild(Folders.Keys)
	if keysFolder then
		bindKeys(registry, state, keysFolder, trove)
	end
	trove:Connect(model.ChildAdded, function(child: Instance)
		if child.Name == Folders.Keys then
			bindKeys(registry, state, child, trove)
		end
	end)
	trove:Connect(model.Destroying, function()
		trove:Destroy()
	end)
end

function CapRegistry.WatchPlots(registry: Types.Registry, folder: Instance, trove: TroveInstance)
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			trackPlot(registry, child, trove)
		end
	end
	trove:Connect(folder.ChildAdded, function(child: Instance)
		if child:IsA("Model") and not registry.Plots[child] then
			trackPlot(registry, child, trove)
		end
	end)
end

local function clearCosmetic(registry: Types.Registry)
	local state = registry.Cosmetic
	registry.Cosmetic = nil
	if state then
		for _, cap in state.Caps do
			forgetCap(registry, cap)
		end
	end
end

function CapRegistry.BindCosmetic(registry: Types.Registry, model: Instance, parentTrove: TroveInstance)
	local frame = model:GetAttribute(Attributes.Frame) :: CFrame?
	local pitch = model:GetAttribute(Attributes.Pitch)
	local height = model:GetAttribute(Attributes.CapHeight)
	if frame == nil or type(pitch) ~= "number" or type(height) ~= "number" then
		return
	end
	clearCosmetic(registry)
	local state: Types.CosmeticState =
		{ Model = model, Frame = frame, Pitch = pitch, Height = height, Caps = {} }
	registry.Cosmetic = state
	local trove = Trove.new()
	parentTrove:Add(trove)
	local function add(child: Instance)
		local column = child:GetAttribute(Attributes.GridX)
		local row = child:GetAttribute(Attributes.GridZ)
		if child:IsA("BasePart") and type(column) == "number" and type(row) == "number" then
			local key = Detection.GridKey(column, row)
			local existing = state.Caps[key]
			if existing then
				forgetCap(registry, existing)
			end
			state.Caps[key] = newCap(child)
		end
	end
	for _, child in model:GetChildren() do
		add(child)
	end
	trove:Connect(model.ChildAdded, add)
	trove:Connect(model.Destroying, function()
		trove:Destroy()
		if registry.Cosmetic == state then
			clearCosmetic(registry)
		end
	end)
end

return CapRegistry
