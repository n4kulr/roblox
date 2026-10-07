--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldNames = require(ReplicatedStorage.Config.WorldNames)
local Packets = require(ReplicatedStorage.Packets)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local ServerTypes = require(script.Parent.Parent.Types)
local Assignment = require(script.Assignment)
local Build = require(script.Build)
local Defense = require(script.Defense)
local Lock = require(script.Lock)
local Placeholder = require(script.Placeholder)
local Present = require(script.Present)
local Respawn = require(script.Respawn)
local Types = require(script.Types)
local Walls = require(script.Walls)

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	LockChanged: Signal.Signal<Player>,
	PlotAssigned: Signal.Signal<Player>,
	_trove: TroveInstance?,
}

local staleSweepSeconds = 10

local PlotService = {
	Name = "PlotService",
	LockChanged = Signal.new() :: Signal.Signal<Player>,
	PlotAssigned = Signal.new() :: Signal.Signal<Player>,
	_trove = nil :: TroveInstance?,
}
local services: ServerTypes.Registry = nil :: any
local buildThread: thread? = nil
local context: Types.Context = {
	Services = nil :: any,
	Plots = {},
	ByPlayer = {},
	PlayerTroves = {},
	ActiveLocks = {},
	LastZap = {},
	RespawnPoints = {},
	SweepThread = nil,
	HasWarnedSlots = false,
	LockChanged = PlotService.LockChanged,
	PlotAssigned = PlotService.PlotAssigned,
}

local function lockOf(player: Player): Types.Defense?
	local info = context.ByPlayer[player]
	return if info then info.Defense else nil
end

local function buildPlots(trove: TroveInstance)
	local folder = workspace:FindFirstChild(WorldNames.Folders.Plots)
	local isPlaceholder = false
	if not folder then
		isPlaceholder = true
		warn("[PlotService] workspace.Plots not found; building placeholder plots")
		local placeholder = Instance.new("Folder")
		placeholder.Name = WorldNames.Folders.Plots
		Placeholder.Build(placeholder)
		placeholder.Parent = workspace
		trove:Add(placeholder)
		folder = placeholder
	end
	Build.Collect(context, folder :: Instance, trove, isPlaceholder)
end

local function loadPlayer(player: Player)
	local data = services.DataService:GetData(player)
	if data then
		Assignment.Assign(context, player, data)
		services.KeyboardService:NotifyBoardChanged(player)
	end
end

function PlotService.Init(self: State, registry: { [string]: any })
	services = registry :: any
	context.Services = services
	self._trove = Trove.new()
end

function PlotService.Start(self: State)
	local trove = self._trove :: TroveInstance
	Packets.LockBase.OnServerInvoke = function(player: Player)
		local info = context.ByPlayer[player]
		return info ~= nil and Defense.Activate(context, info, player)
	end
	local isReady = false
	local waiting: { Player } = {}
	services.DataService.PlayerLoaded:Connect(function(player: Player, data: PlayerData.Data)
		if isReady then
			Assignment.Assign(context, player, data)
		elseif not table.find(waiting, player) then
			table.insert(waiting, player)
		end
	end)
	services.DataService.PlayerReleasing:Connect(function(player: Player, _data: PlayerData.Data)
		local index = table.find(waiting, player)
		if index then
			table.remove(waiting, index)
		end
		Assignment.Release(context, player)
	end)
	trove:Connect(Players.PlayerRemoving, function(player: Player)
		task.defer(function()
			if context.ByPlayer[player] then
				Assignment.Release(context, player)
			end
		end)
	end)
	trove:Add(task.spawn(function()
		while true do
			task.wait(staleSweepSeconds)
			Assignment.ReleaseStale(context)
		end
	end))
	trove:Add(services.KeyboardService.BoardChanged:Connect(function(player: Player)
		local info = context.ByPlayer[player]
		local data = services.DataService:GetData(player)
		if info and data then
			Present.RefreshWalls(info, data)
			Present.Render(info, data)
		end
	end))
	for _, player in Players:GetPlayers() do
		if not table.find(waiting, player) then
			table.insert(waiting, player)
		end
	end
	buildThread = task.spawn(function()
		services.MeshService:Wait()
		buildPlots(trove)
		trove:Add(services.MeshService.Changed:Connect(function(name: string)
			warn(`[PlotService] {name} mesh arrived after plots were built; ignored`)
		end))
		isReady = true
		for _, player in waiting do
			loadPlayer(player)
		end
		table.clear(waiting)
	end)
end

function PlotService.GetPlot(_self: State, player: Player): Model?
	local info = context.ByPlayer[player]
	return if info then info.Model else nil
end

function PlotService.GetCaps(_self: State, player: Player): { BasePart }?
	local info = context.ByPlayer[player]
	return if info then info.Caps else nil
end

function PlotService.GetFloorCaps(_self: State, player: Player): { BasePart }?
	local info = context.ByPlayer[player]
	return if info then info.FloorCaps else nil
end

function PlotService.GetRollKey(_self: State, player: Player): BasePart?
	local info = context.ByPlayer[player]
	return if info then info.RollKey else nil
end

function PlotService.GetBase(_self: State, player: Player): BasePart?
	local info = context.ByPlayer[player]
	return if info then info.Base else nil
end

function PlotService.SetRespawn(_self: State, player: Player, cframe: CFrame?)
	if cframe then
		context.RespawnPoints[player] = cframe
	else
		context.RespawnPoints[player] = nil
	end
end

function PlotService.SendHome(_self: State, player: Player): boolean
	local info = context.ByPlayer[player]
	local character = player.Character
	if not info or not character then
		return false
	end
	character:PivotTo(Respawn.HomeCFrame(info))
	return true
end

function PlotService.Lock(_self: State, player: Player): boolean
	local info = context.ByPlayer[player]
	return info ~= nil and Defense.Activate(context, info, player)
end

function PlotService.IsLocked(_self: State, player: Player): boolean
	local state = lockOf(player)
	return state ~= nil and state.IsActive and os.time() < state.LockedUntil
end

function PlotService.GetLockedUntil(_self: State, player: Player): number
	local state = lockOf(player)
	return if state and state.IsActive then state.LockedUntil else 0
end

function PlotService.GetLockCooldownUntil(_self: State, player: Player): number
	local state = lockOf(player)
	return if state then state.CooldownUntil else 0
end

function PlotService.GetWallHeight(_self: State, player: Player): number?
	local info = context.ByPlayer[player]
	return if info then info.WallHeight else nil
end

function PlotService.Destroy(self: State)
	Packets.LockBase.OnServerInvoke = nil
	if buildThread and coroutine.status(buildThread) == "suspended" then
		task.cancel(buildThread)
	end
	buildThread = nil
	Defense.Stop(context)
	for _, info in context.Plots do
		Walls.Clear(info)
		if info.Defense then
			Lock.Reset(info.Defense)
		end
	end
	table.clear(context.LastZap)
	table.clear(context.RespawnPoints)
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return PlotService
