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
}
type PlotState = {
	Model: Model,
	Base: BasePart?,
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
local debounceSeconds = 0.12
local minHeight = -1
local maxHeight = 7
local blankVolume = 0.35
local blankSwitch = "MxBlack"
local fillerVolume = 0.55
local fillerSwitch = "CreamTravel"
local capHeight = FloorGrid.CapHeight

local KeyPressController = {
	Name = "KeyPressController",
	_trove = nil :: TroveInstance?,
}
local controllers: { [string]: any } = {}
local plotStates: { [Model]: PlotState } = {}
local standingOn: { [Player]: CapState } = {}
local destroyed = false
local isLowGraphics = false

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
	releaseTween(cap)
	local down = TweenService:Create(
		part,
		TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = cap.Rest * CFrame.new(0, -pressDepth, 0) }
	)
	cap.Tween = down
	down.Completed:Once(function(playbackState: Enum.PlaybackState)
		if playbackState ~= Enum.PlaybackState.Completed or cap.Tween ~= down then
			return
		end
		local up = TweenService:Create(
			part,
			TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ CFrame = cap.Rest }
		)
		cap.Tween = up
		up.Completed:Once(function()
			if cap.Tween == up then
				cap.Tween = nil
			end
			up:Destroy()
		end)
		down:Destroy()
		up:Play()
	end)
	down:Play()
end

local function capKey(cap: CapState): Keys.Key?
	local keyId = cap.Part:GetAttribute("KeyId")
	return if type(keyId) == "string" then Keys.ById[keyId] else nil
end

local function playCap(cap: CapState, player: Player, kind: "Press" | "Release")
	local category = if player == Players.LocalPlayer then "Board" else "Other"
	local key = capKey(cap)
	local isFiller = cap.Part:GetAttribute("Filler") == true
	local switchId = if key then key.Switch elseif isFiller then fillerSwitch else blankSwitch
	local volume = if key then 1 elseif isFiller then fillerVolume else blankVolume
	controllers.SoundController:PlaySwitch(switchId, kind, 1, volume, cap.Part.Position, category)
end

local function triggerCap(cap: CapState, player: Player)
	if cap.Part:GetAttribute("Locked") == true then
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
	state.Caps[cell] = { Part = child, Rest = child.CFrame, LastPress = 0, Tween = nil }
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
	return nil
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
	if not camera or next(plotStates) == nil then
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
				end
			end
		end
	end
	for player in standingOn do
		if not seen[player] then
			standingOn[player] = nil
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
	local promise = WaitFor.Child(workspace, "Plots", 30)
		:andThen(function(folder: Instance)
			if destroyed then
				return
			end
			local plotsTrove = Trove.new()
			trove:Add(plotsTrove)
			watchPlots(folder, plotsTrove)
			plotsTrove:Connect(RunService.Heartbeat, update)
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
	table.clear(plotStates)
	table.clear(standingOn)
end

return KeyPressController
