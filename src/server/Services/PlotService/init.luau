--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local Packets = require(ReplicatedStorage.Packets)
local FloorGrid = require(ReplicatedStorage.Rules.FloorGrid)
local Stats = require(ReplicatedStorage.Rules.Stats)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local MeshTemplates = require(script.Parent.Parent.Utils.MeshTemplates)
local OwnerSign = require(script.Parent.Parent.Utils.OwnerSign)
local WalkSpeed = require(script.Parent.Parent.Utils.WalkSpeed)
local Lock = require(script.Lock)
local Types = require(script.Types)
local Walls = require(script.Walls)

type TroveInstance = typeof(Trove.new())
type PlotInfo = Types.PlotInfo
type State = {
	Name: string,
	LockChanged: Signal.Signal<Player>,
	_trove: TroveInstance?,
}

local PlotService = {
	Name = "PlotService",
	LockChanged = Signal.new() :: Signal.Signal<Player>,
	_trove = nil :: TroveInstance?,
}
local services: { [string]: any } = {}
local plots: { PlotInfo } = {}
local plotByPlayer: { [Player]: PlotInfo } = {}
local playerTroves: { [Player]: TroveInstance } = {}
local buildThread: thread? = nil
local meshTimeout = 6
local sweepSeconds = 0.2
local zapAlertPhase = 9
local zapMessage = "🔴 The lasers zapped you!"
local zapToastSeconds = 1.5
local lastZap: { [Player]: number } = {}
local hasWarnedSlots = false

local function newPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

local function buildPlaceholderPlots(folder: Folder)
	local count = GameConfig.PlotCount
	for index = 1, count do
		local angle = (index - 1) / count * math.pi * 2
		local position = Vector3.new(math.cos(angle) * 80, 0.5, math.sin(angle) * 80)
		local origin = CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
		local model = Instance.new("Model")
		model.Name = `Plot{index}`
		local base = newPart(model, "Base", Vector3.new(44, 1, 44), origin, Color3.fromRGB(70, 74, 86))
		newPart(
			model,
			"RollKey",
			Vector3.new(8, 3, 8),
			origin * CFrame.new(0, 2, -10),
			Color3.fromRGB(215, 215, 220)
		)
		newPart(
			model,
			"Board",
			Vector3.new(31, 1.5, 9.6),
			origin * CFrame.new(0, 1.25, 12),
			Color3.fromRGB(35, 36, 42)
		)
		model.PrimaryPart = base
		model.Parent = folder
	end
end

local function findPart(model: Model, name: string): BasePart?
	local child = model:FindFirstChild(name)
	return if child and child:IsA("BasePart") then child else nil
end

local emptyCapColor = Color3.fromRGB(40, 41, 48)
local emptyCapTransparency = 0.6
local lockedCapColor = Color3.fromRGB(60, 60, 64)
local lockedCapTransparency = 0.85
local fillerCapColor = Color3.fromRGB(222, 218, 208)
local capHeight = FloorGrid.CapHeight
local walkwayThickness = 0.2

local function applyFiller(cap: BasePart)
	cap.Color = fillerCapColor
	cap.Material = Enum.Material.SmoothPlastic
	cap.Reflectance = 0
	cap.Transparency = 0
end

local function newCap(info: PlotInfo, cell: FloorGrid.Cell): BasePart
	local template = MeshTemplates.Get("Keycap")
	local cap: BasePart = if template then template:Clone() else Instance.new("Part")
	local capSize = FloorGrid.CapSize()
	cap.Anchored = true
	cap.CanCollide = false
	cap.CanQuery = false
	cap.CanTouch = false
	cap.CastShadow = false
	cap.Size = Vector3.new(capSize, capHeight, capSize)
	cap.CFrame = info.Base.CFrame * CFrame.new(cell.X, info.Base.Size.Y / 2 + capHeight / 2, cell.Z)
	cap:SetAttribute("Cell", cell.Index)
	applyFiller(cap)
	local slot = cell.Slot
	if slot then
		cap.Name = `Slot{slot}`
		cap:SetAttribute("Slot", slot)
	else
		cap.Name = `Floor{cell.Index}`
		cap:SetAttribute("Filler", true)
	end
	return cap
end

local function createCaps(info: PlotInfo, trove: TroveInstance)
	local existing = info.Model:FindFirstChild("Keys")
	if existing then
		existing:Destroy()
	end
	local layout = info.Layout
	local folder = Instance.new("Folder")
	folder.Name = "Keys"
	table.clear(info.Caps)
	table.clear(info.FloorCaps)
	for _, cell in layout.Cells do
		local cap = newCap(info, cell)
		cap.Parent = folder
		table.insert(info.FloorCaps, cap)
		local slot = cell.Slot
		if slot then
			info.Caps[slot] = cap
		end
	end
	if #info.Caps < GameConfig.BoardSlots and not hasWarnedSlots then
		hasWarnedSlots = true
		warn(
			`[PlotService] {info.Model:GetFullName()} only fits {#info.Caps} of {GameConfig.BoardSlots} slot keys`
		)
	end
	local baseSize = info.Base.Size
	local walkway = Instance.new("Part")
	walkway.Name = "Walkway"
	walkway.Anchored = true
	walkway.CanCollide = true
	walkway.CanQuery = true
	walkway.CanTouch = false
	walkway.Transparency = 1
	walkway.Size = Vector3.new(baseSize.X, walkwayThickness, baseSize.Z)
	walkway.CFrame = info.Base.CFrame * CFrame.new(0, baseSize.Y / 2 + capHeight - walkwayThickness / 2, 0)
	info.Walkway = walkway
	walkway.Parent = folder
	info.Model:SetAttribute("FloorCell", FloorGrid.CellSize)
	info.Model:SetAttribute("FloorGap", FloorGrid.CellGap)
	info.Model:SetAttribute("FloorColumns", layout.Columns)
	info.Model:SetAttribute("FloorRows", layout.Rows)
	folder.Parent = info.Model
	trove:Add(folder)
end

local function swapPart(old: BasePart, new: BasePart)
	new.Color = old.Color
	new.Material = old.Material
	new.Transparency = old.Transparency
	new.Parent = old.Parent
	old:Destroy()
end

local function skinRollKey(info: PlotInfo)
	local template = MeshTemplates.Get("RollKey")
	local old = info.RollKey
	if not template or old:IsA("MeshPart") then
		return
	end
	local key = template:Clone()
	key.Name = "RollKey"
	key.Anchored = true
	key.Size = old.Size
	key.CFrame = old.CFrame
	swapPart(old, key)
	info.RollKey = key
end

local function render(info: PlotInfo, data: PlayerData.Data?)
	local unlocked = if data then Stats.Slots(data.Upgrades) else 0
	for slot, cap in info.Caps do
		local key = if data and slot <= unlocked then Keys.ById[data.Board[slot]] else nil
		if key then
			local rarity = Keys.GetRarity(key)
			cap.Color = rarity.Color
			Keys.ApplyFinish(cap, rarity)
			cap.Transparency = 0
			cap:SetAttribute("KeyId", key.Id)
			cap:SetAttribute("Locked", nil)
		elseif data and slot > unlocked then
			cap.Color = lockedCapColor
			cap.Material = Enum.Material.SmoothPlastic
			cap.Reflectance = 0
			cap.Transparency = lockedCapTransparency
			cap:SetAttribute("KeyId", nil)
			cap:SetAttribute("Locked", true)
		elseif data then
			cap.Color = emptyCapColor
			cap.Material = Enum.Material.SmoothPlastic
			cap.Reflectance = 0
			cap.Transparency = emptyCapTransparency
			cap:SetAttribute("KeyId", nil)
			cap:SetAttribute("Locked", nil)
		else
			applyFiller(cap)
			cap:SetAttribute("KeyId", nil)
			cap:SetAttribute("Locked", nil)
		end
	end
end

local function homeCFrame(info: PlotInfo): CFrame
	return info.Base.CFrame * CFrame.new(0, info.Base.Size.Y / 2 + capHeight + 3, 0)
end

local function teleport(player: Player, character: Model)
	task.spawn(function()
		local root = character:WaitForChild("HumanoidRootPart", 10)
		local info = plotByPlayer[player]
		if not root or not info or character.Parent == nil then
			return
		end
		character:PivotTo(homeCFrame(info))
	end)
end

local function applyWalkSpeed(character: Model)
	task.spawn(function()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			WalkSpeed.Refresh(character)
		end
	end)
end

local function presentLock(info: PlotInfo)
	local state = info.Defense
	if state then
		Lock.Present(info, state, os.time())
	end
end

local function applyOwner(info: PlotInfo, owner: Player?)
	info.Owner = owner
	local state = info.Defense
	if state then
		Lock.Reset(state)
	end
	presentLock(info)
end

local function wallLevelOf(data: PlayerData.Data?): number
	return if data then Walls.Level(data.Upgrades.Walls) else 0
end

local function refreshWalls(info: PlotInfo, data: PlayerData.Data?)
	local level = wallLevelOf(data)
	if info.WallLevel == level then
		return
	end
	Walls.Apply(info, level)
	local state = info.Defense
	if state and state.IsActive then
		Lock.ShowLasers(info, state)
		Lock.Present(info, state, os.time())
	end
end

local function release(player: Player)
	local playerTrove = playerTroves[player]
	playerTroves[player] = nil
	if playerTrove then
		playerTrove:Destroy()
	end
	local info = plotByPlayer[player]
	plotByPlayer[player] = nil
	lastZap[player] = nil
	if info then
		applyOwner(info, nil)
		info.Model:SetAttribute("Owner", nil)
		refreshWalls(info, nil)
		render(info, nil)
		if info.Sign then
			info.Sign:Set(nil)
		end
	end
end

local function assign(player: Player, data: PlayerData.Data)
	if plotByPlayer[player] then
		return
	end
	local free: PlotInfo? = nil
	for _, info in plots do
		if not info.Owner then
			free = info
			break
		end
	end
	if not free then
		warn(`[PlotService] No free plot for {player.Name}`)
		return
	end
	applyOwner(free, player)
	plotByPlayer[player] = free
	free.Model:SetAttribute("Owner", player.UserId)
	refreshWalls(free, data)
	render(free, data)
	if free.Sign then
		free.Sign:Set(player)
	end
	local playerTrove = Trove.new()
	playerTroves[player] = playerTrove
	playerTrove:Connect(player.CharacterAdded, function(character: Model)
		applyWalkSpeed(character)
		teleport(player, character)
	end)
	if player.Character then
		applyWalkSpeed(player.Character)
		teleport(player, player.Character)
	end
end

local function collectPlots(folder: Instance, trove: TroveInstance, isPlaceholder: boolean)
	local models: { Model } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			table.insert(models, child)
		end
	end
	table.sort(models, function(a: Model, b: Model)
		return a.Name < b.Name
	end)
	for _, model in models do
		local base = findPart(model, "Base")
		local rollKey = findPart(model, "RollKey")
		local board = findPart(model, "Board")
		if base and rollKey and board then
			local useMeshes = isPlaceholder or model:GetAttribute("UseMeshes") == true
			model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			local info: PlotInfo = {
				Model = model,
				Base = base,
				RollKey = rollKey,
				Board = board,
				Caps = {},
				FloorCaps = {},
				Layout = nil :: any,
				Owner = nil,
				Placeholder = useMeshes,
				Walkway = nil,
				Sign = nil,
				GlassWalls = nil,
				GlassParts = {},
				FenceRise = 0,
				Frame = nil,
				WallHeight = 0,
				WallLevel = 0,
				Defense = nil,
			}
			if useMeshes then
				skinRollKey(info)
			end
			board.Transparency = 1
			board.CanCollide = false
			info.Layout = FloorGrid.ForPlot(base, info.RollKey, board)
			createCaps(info, trove)
			Walls.Build(info, 0)
			info.Defense = Lock.Build()
			presentLock(info)
			info.Sign = OwnerSign.new(model, base, trove)
			table.insert(plots, info)
		else
			warn(
				`[PlotService] {model:GetFullName()} needs BasePart children Base, RollKey and Board; skipped`
			)
		end
	end
end

local function activateLock(info: PlotInfo, player: Player): boolean
	local state = info.Defense
	if not state or info.Owner ~= player then
		return false
	end
	local now = os.time()
	if Lock.StatusAt(state, now) ~= Lock.Ready then
		return false
	end
	local data = services.DataService:GetData(player) :: PlayerData.Data?
	Lock.Start(info, state, now, Lock.Duration(if data then data.Upgrades.LockTime else 0))
	Lock.Present(info, state, now)
	PlotService.LockChanged:Fire(player)
	return true
end

local function zapIntruders(info: PlotInfo, owner: Player)
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if
			player ~= owner
			and root
			and root:IsA("BasePart")
			and Lock.IsInside(info, root.CFrame.Position)
		then
			Lock.Knock(info, root)
			local last = lastZap[player]
			if not last or os.clock() - last >= zapToastSeconds then
				lastZap[player] = os.clock()
				Packets.StealAlert:FireClient(player, zapMessage, 0, zapAlertPhase)
			end
		end
	end
end

local function sweep()
	local now = os.time()
	for _, info in plots do
		local state = info.Defense
		local owner = info.Owner
		if state and owner then
			if state.IsActive and now >= state.LockedUntil then
				Lock.Finish(state)
				Lock.Present(info, state, now)
				PlotService.LockChanged:Fire(owner)
			elseif state.IsActive then
				zapIntruders(info, owner)
			end
			Lock.Present(info, state, now)
		end
	end
end

function PlotService.Init(self: State, registry: { [string]: any })
	services = registry
	self._trove = Trove.new()
end

local function buildPlots(trove: TroveInstance)
	local folder = workspace:FindFirstChild("Plots")
	local isPlaceholder = false
	if not folder then
		isPlaceholder = true
		warn("[PlotService] workspace.Plots not found; building placeholder plots")
		local placeholder = Instance.new("Folder")
		placeholder.Name = "Plots"
		buildPlaceholderPlots(placeholder)
		placeholder.Parent = workspace
		trove:Add(placeholder)
		folder = placeholder
	end
	collectPlots(folder :: Instance, trove, isPlaceholder)
end

local function loadPlayer(player: Player)
	local data = services.DataService:GetData(player) :: PlayerData.Data?
	if data then
		assign(player, data)
		services.KeyboardService.BoardChanged:Fire(player)
	end
end

function PlotService.Start(self: State)
	local trove = self._trove :: TroveInstance
	Packets.LockBase.OnServerInvoke = function(player: Player)
		local info = plotByPlayer[player]
		return info ~= nil and activateLock(info, player)
	end
	local isReady = false
	local waiting: { Player } = {}
	services.DataService.PlayerLoaded:Connect(function(player: Player, data: PlayerData.Data)
		if isReady then
			assign(player, data)
		elseif not table.find(waiting, player) then
			table.insert(waiting, player)
		end
	end)
	services.DataService.PlayerReleasing:Connect(function(player: Player, _data: PlayerData.Data)
		local index = table.find(waiting, player)
		if index then
			table.remove(waiting, index)
		end
		release(player)
	end)
	services.KeyboardService.BoardChanged:Connect(function(player: Player)
		local info = plotByPlayer[player]
		local data = services.DataService:GetData(player) :: PlayerData.Data?
		if info and data then
			refreshWalls(info, data)
			render(info, data)
		end
	end)
	for _, player in Players:GetPlayers() do
		if not table.find(waiting, player) then
			table.insert(waiting, player)
		end
	end
	buildThread = task.spawn(function()
		MeshTemplates.Load()
		MeshTemplates.Wait(meshTimeout)
		buildPlots(trove)
		trove:Connect(MeshTemplates.Changed, function(name: string)
			warn(`[PlotService] {name} mesh arrived after plots were built; ignored`)
		end)
		isReady = true
		for _, player in waiting do
			loadPlayer(player)
		end
		table.clear(waiting)
	end)
	trove:Add(task.spawn(function()
		while true do
			task.wait(sweepSeconds)
			sweep()
		end
	end))
end

function PlotService.GetPlot(_self: State, player: Player): Model?
	local info = plotByPlayer[player]
	return if info then info.Model else nil
end

function PlotService.GetCaps(_self: State, player: Player): { BasePart }?
	local info = plotByPlayer[player]
	return if info then info.Caps else nil
end

function PlotService.GetFloorCaps(_self: State, player: Player): { BasePart }?
	local info = plotByPlayer[player]
	return if info then info.FloorCaps else nil
end

function PlotService.GetBase(_self: State, player: Player): BasePart?
	local info = plotByPlayer[player]
	return if info then info.Base else nil
end

function PlotService.SendHome(_self: State, player: Player): boolean
	local info = plotByPlayer[player]
	local character = player.Character
	if not info or not character then
		return false
	end
	character:PivotTo(homeCFrame(info))
	return true
end

function PlotService.Lock(_self: State, player: Player): boolean
	local info = plotByPlayer[player]
	return info ~= nil and activateLock(info, player)
end

function PlotService.IsLocked(_self: State, player: Player): boolean
	local info = plotByPlayer[player]
	local state = if info then info.Defense else nil
	return state ~= nil and state.IsActive and os.time() < state.LockedUntil
end

function PlotService.GetLockedUntil(_self: State, player: Player): number
	local info = plotByPlayer[player]
	local state = if info then info.Defense else nil
	return if state and state.IsActive then state.LockedUntil else 0
end

function PlotService.GetLockCooldownUntil(_self: State, player: Player): number
	local info = plotByPlayer[player]
	local state = if info then info.Defense else nil
	return if state then state.CooldownUntil else 0
end

function PlotService.GetWallHeight(_self: State, player: Player): number?
	local info = plotByPlayer[player]
	return if info then info.WallHeight else nil
end

function PlotService.Destroy(self: State)
	Packets.LockBase.OnServerInvoke = nil
	if buildThread and coroutine.status(buildThread) == "suspended" then
		task.cancel(buildThread)
	end
	buildThread = nil
	MeshTemplates.Destroy()
	for _, info in plots do
		Walls.Clear(info)
		if info.Defense then
			Lock.Reset(info.Defense)
		end
	end
	table.clear(lastZap)
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return PlotService
