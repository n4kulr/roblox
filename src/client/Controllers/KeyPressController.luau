--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Keys = require(ReplicatedStorage.Config.Keys)
local FloorGrid = require(ReplicatedStorage.Rules.FloorGrid)
local Trove = require(ReplicatedStorage.Packages.Trove)
local WaitFor = require(ReplicatedStorage.Packages.WaitFor)

type TroveInstance = typeof(Trove.new())
type CapState = {
	Part: BasePart,
	Rest: CFrame,
	LastPress: number,
	Tween: Tween?,
	Held: boolean,
	RaiseToken: number?,
}
type PlotState = {
	Model: Model,
	Base: BasePart?,
	Caps: { [number]: CapState },
}
type CosmeticState = {
	Model: Instance,
	Frame: CFrame,
	Pitch: number,
	Height: number,
	Caps: { [number]: CapState },
}
type State = {
	Name: string,
	_trove: TroveInstance?,
}

local viewRange = 60
local lowViewRange = 30
local maxCharacters = 8
local pressDepth = 1.1
local fillerPressDepth = 0.75
local debounceSeconds = 0.12
local releaseDelaySeconds = 0.15
local raiseSeconds = 0.25
local minHeight = -1
local maxHeight = 7
local cosmeticSwitch = "NkCream"
local cosmeticPitch = 0.9
local blankVolume = 0.6
local fillerVolume = 0.7
local capHeight = FloorGrid.CapHeight
local cosmeticModelName = "CosmeticKeys"
local gridOffset = 512
local gridStride = 1024

local KeyPressController = {
	Name = "KeyPressController",
	_trove = nil :: TroveInstance?,
}
local controllers: { [string]: any } = {}
local plotStates: { [Model]: PlotState } = {}
local standingOn: { [Player]: CapState } = {}
local cosmetic: CosmeticState? = nil
local destroyed = false
local isLowGraphics = false

local function isFillerPart(part: BasePart): boolean
	return part:GetAttribute("Filler") == true or part:GetAttribute("Cosmetic") == true
end

local function gridKey(column: number, row: number): number
	return (column + gridOffset) * gridStride + row + gridOffset
end

local function releaseTween(cap: CapState)
	local tween = cap.Tween
	if tween then
		cap.Tween = nil
		tween:Cancel()
		tween:Destroy()
	end
end

local function pressCap(cap: CapState)
	local part = cap.Part
	local authored = part:GetAttribute("PressDepth")
	local depth = if type(authored) == "number"
		then authored
		elseif isFillerPart(part) then fillerPressDepth
		else pressDepth
	releaseTween(cap)
	cap.Held = true
	local down = TweenService:Create(
		part,
		TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = cap.Rest * CFrame.new(0, -depth, 0) }
	)
	cap.Tween = down
	down.Completed:Once(function()
		if cap.Tween == down then
			cap.Tween = nil
		end
		down:Destroy()
	end)
	down:Play()
end

local function isStoodOn(cap: CapState): boolean
	for _, standing in standingOn do
		if standing == cap then
			return true
		end
	end
	return false
end

local function raiseCap(cap: CapState)
	if not cap.Held or isStoodOn(cap) then
		return
	end
	local token = os.clock()
	cap.RaiseToken = token
	task.delay(releaseDelaySeconds, function()
		if cap.RaiseToken ~= token or isStoodOn(cap) or cap.Part.Parent == nil then
			return
		end
		cap.Held = false
		releaseTween(cap)
		local up = TweenService:Create(
			cap.Part,
			TweenInfo.new(raiseSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ CFrame = cap.Rest }
		)
		cap.Tween = up
		up.Completed:Once(function()
			if cap.Tween == up then
				cap.Tween = nil
			end
			up:Destroy()
		end)
		up:Play()
	end)
end

local function capKey(cap: CapState): Keys.Key?
	local keyId = cap.Part:GetAttribute("KeyId")
	return if type(keyId) == "string" then Keys.Resolve(keyId) else nil
end

local function playCap(cap: CapState, player: Player, kind: "Press" | "Release")
	local category = if player == Players.LocalPlayer then "Board" else "Other"
	local key = capKey(cap)
	local isFiller = isFillerPart(cap.Part)
	local switchId = if key then key.Switch else cosmeticSwitch
	local pitch = if key then 1 else cosmeticPitch
	local volume = if key then 1 elseif isFiller then fillerVolume else blankVolume
	controllers.SoundController:PlaySwitch(switchId, kind, pitch, volume, cap.Part.Position, category)
end

local function triggerCap(cap: CapState, player: Player)
	if cap.Part:GetAttribute("Locked") == true then
		return
	end
	cap.RaiseToken = nil
	if cap.Held then
		return
	end
	local now = os.clock()
	if now - cap.LastPress < debounceSeconds then
		return
	end
	cap.LastPress = now
	pressCap(cap)
	playCap(cap, player, "Press")
end

local function addCap(state: PlotState, child: Instance)
	if not child:IsA("BasePart") then
		return
	end
	local cell = child:GetAttribute("Cell")
	if type(cell) ~= "number" then
		return
	end
	local existing = state.Caps[cell]
	if existing then
		releaseTween(existing)
	end
	state.Caps[cell] =
		{ Part = child, Rest = child.CFrame, LastPress = 0, Tween = nil, Held = false, RaiseToken = nil }
end

local function removeCap(state: PlotState, child: Instance)
	for cell, cap in state.Caps do
		if cap.Part == child then
			releaseTween(cap)
			state.Caps[cell] = nil
			for player, standing in standingOn do
				if standing == cap then
					standingOn[player] = nil
				end
			end
		end
	end
end

local function bindKeys(state: PlotState, folder: Instance, trove: TroveInstance)
	for _, child in folder:GetChildren() do
		addCap(state, child)
	end
	trove:Connect(folder.ChildAdded, function(child: Instance)
		addCap(state, child)
	end)
	trove:Connect(folder.ChildRemoved, function(child: Instance)
		removeCap(state, child)
	end)
end

local function trackPlot(model: Model, parentTrove: TroveInstance)
	local trove = Trove.new()
	parentTrove:Add(trove)
	local state: PlotState = { Model = model, Base = nil, Caps = {} }
	plotStates[model] = state
	trove:Add(function()
		plotStates[model] = nil
		for _, cap in state.Caps do
			releaseTween(cap)
			for player, standing in standingOn do
				if standing == cap then
					standingOn[player] = nil
				end
			end
		end
	end)
	local keysFolder = model:FindFirstChild("Keys")
	if keysFolder then
		bindKeys(state, keysFolder, trove)
	end
	trove:Connect(model.ChildAdded, function(child: Instance)
		if child.Name == "Keys" then
			bindKeys(state, child, trove)
		end
	end)
	trove:Connect(model.Destroying, function()
		trove:Destroy()
	end)
end

local function watchPlots(folder: Instance, trove: TroveInstance)
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			trackPlot(child, trove)
		end
	end
	trove:Connect(folder.ChildAdded, function(child: Instance)
		if child:IsA("Model") and not plotStates[child] then
			trackPlot(child, trove)
		end
	end)
end

local function getBase(state: PlotState): BasePart?
	local base = state.Base
	if base and base.Parent then
		return base
	end
	local found = state.Model:FindFirstChild("Base")
	base = if found and found:IsA("BasePart") then found else nil
	state.Base = base
	return base
end

local function findCosmeticCap(position: Vector3): CapState?
	local state = cosmetic
	if not state then
		return nil
	end
	local localPosition = state.Frame:PointToObjectSpace(position)
	local height = localPosition.Y - state.Height
	if height < minHeight or height > maxHeight then
		return nil
	end
	local column = math.floor(localPosition.X / state.Pitch + 0.5)
	local row = math.floor(localPosition.Z / state.Pitch + 0.5)
	return state.Caps[gridKey(column, row)]
end

local function findCap(position: Vector3): CapState?
	for _, state in plotStates do
		local base = getBase(state)
		local columns = state.Model:GetAttribute("FloorColumns")
		local rows = state.Model:GetAttribute("FloorRows")
		if base and type(columns) == "number" and type(rows) == "number" then
			local localPosition = base.CFrame:PointToObjectSpace(position)
			local height = localPosition.Y - (base.Size.Y / 2 + capHeight)
			if height >= minHeight and height <= maxHeight then
				local index = FloorGrid.IndexAt(columns, rows, localPosition.X, localPosition.Z)
				if index then
					return state.Caps[index]
				end
			end
		end
	end
	return findCosmeticCap(position)
end

local function forgetCap(cap: CapState)
	releaseTween(cap)
	for player, standing in standingOn do
		if standing == cap then
			standingOn[player] = nil
		end
	end
end

local function clearCosmetic()
	local state = cosmetic
	cosmetic = nil
	if state then
		for _, cap in state.Caps do
			forgetCap(cap)
		end
	end
end

local function bindCosmetic(model: Instance, parentTrove: TroveInstance)
	local frame = model:GetAttribute("Frame") :: CFrame?
	local pitch = model:GetAttribute("Pitch")
	local height = model:GetAttribute("CapHeight")
	if frame == nil or type(pitch) ~= "number" or type(height) ~= "number" then
		return
	end
	clearCosmetic()
	local state: CosmeticState = { Model = model, Frame = frame, Pitch = pitch, Height = height, Caps = {} }
	cosmetic = state
	local trove = Trove.new()
	parentTrove:Add(trove)
	local function add(child: Instance)
		local column = child:GetAttribute("GridX")
		local row = child:GetAttribute("GridZ")
		if child:IsA("BasePart") and type(column) == "number" and type(row) == "number" then
			local key = gridKey(column, row)
			local existing = state.Caps[key]
			if existing then
				forgetCap(existing)
			end
			state.Caps[key] = {
				Part = child,
				Rest = child.CFrame,
				LastPress = 0,
				Tween = nil,
				Held = false,
				RaiseToken = nil,
			}
		end
	end
	for _, child in model:GetChildren() do
		add(child)
	end
	trove:Connect(model.ChildAdded, add)
	trove:Connect(model.Destroying, function()
		trove:Destroy()
		if cosmetic == state then
			clearCosmetic()
		end
	end)
end

local function getRoot(player: Player): (BasePart?, boolean)
	local character = player.Character
	if not character then
		return nil, false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid then
		return nil, false
	end
	return root, humanoid.FloorMaterial ~= Enum.Material.Air
end

local function update()
	local camera = workspace.CurrentCamera
	if not camera or (next(plotStates) == nil and cosmetic == nil) then
		return
	end
	local cameraPosition = camera.CFrame.Position
	local localPlayer = Players.LocalPlayer
	local seen: { [Player]: boolean } = {}
	local count = 0
	local candidates = if isLowGraphics then { localPlayer } else Players:GetPlayers()
	if not isLowGraphics then
		table.insert(candidates, 1, localPlayer)
	end
	local range = if isLowGraphics then lowViewRange else viewRange
	for _, player in candidates do
		if count >= maxCharacters then
			break
		end
		if seen[player] == nil then
			local root, isGrounded = getRoot(player)
			if root and (root.Position - cameraPosition).Magnitude <= range then
				seen[player] = true
				count += 1
				local cap = if isGrounded then findCap(root.Position) else nil
				local previous = standingOn[player]
				if cap ~= previous then
					if previous and previous.Part.Parent and previous.Part:GetAttribute("Locked") ~= true then
						playCap(previous, player, "Release")
					end
					if cap then
						standingOn[player] = cap
						triggerCap(cap, player)
					else
						standingOn[player] = nil
					end
					if previous then
						raiseCap(previous)
					end
				end
			end
		end
	end
	for player, standing in standingOn do
		if not seen[player] then
			standingOn[player] = nil
			raiseCap(standing)
		end
	end
end

function KeyPressController.Init(self: State, registry: { [string]: any })
	controllers = registry
	self._trove = Trove.new()
end

function KeyPressController.Start(self: State)
	local trove = self._trove :: TroveInstance
	trove:Add(controllers.DataController:Observe({ "Settings", "LowGraphics" }, function(value: any)
		isLowGraphics = value == true
	end))
	trove:Connect(RunService.Heartbeat, update)
	local existing = workspace:FindFirstChild(cosmeticModelName)
	if existing then
		bindCosmetic(existing, trove)
	end
	trove:Connect(workspace.ChildAdded, function(child: Instance)
		if child.Name == cosmeticModelName then
			bindCosmetic(child, trove)
		end
	end)
	local promise = WaitFor.Child(workspace, "Plots", 30)
		:andThen(function(folder: Instance)
			if destroyed then
				return
			end
			local plotsTrove = Trove.new()
			trove:Add(plotsTrove)
			watchPlots(folder, plotsTrove)
		end)
		:catch(function(problem: any)
			warn(`[KeyPressController] workspace.Plots not found: {tostring(problem)}`)
		end)
	trove:Add(function()
		promise:cancel()
	end)
end

function KeyPressController.Destroy(self: State)
	destroyed = true
	isLowGraphics = false
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
	cosmetic = nil
	table.clear(plotStates)
	table.clear(standingOn)
end

return KeyPressController
