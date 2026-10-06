--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local ServerTypes = require(script.Parent.Parent.Types)

type TroveInstance = typeof(Trove.new())
type Entry = { Name: string, Value: number }
type Board = { StoreName: string, Field: string }
type State = {
	Name: string,
	_trove: TroveInstance?,
}

local boards: { Board } = {
	{ StoreName = "TotalEarned_v1", Field = "TotalEarned" },
	{ StoreName = "Rolls_v1", Field = "Rolls" },
	{ StoreName = "Rebirths_v1", Field = "Rebirths" },
}

local statsInterval = 1
local statsFolderName = "leaderstats"

local LeaderboardService = {
	Name = "LeaderboardService",
	_trove = nil :: TroveInstance?,
}
local services: ServerTypes.Registry = nil :: any
local cache: { [number]: { Entry } } = {}
local isRemote: { [number]: boolean } = {}
local names: { [number]: string } = {}
local statValues: { [Player]: { Clicks: any, Rolls: any, Rebirths: any } } = {}

local function fieldValue(data: PlayerData.Data, field: string): number
	local value = (data :: any)[field]
	return if type(value) == "number" then math.clamp(math.floor(value), 0, GameConfig.MaxCash) else 0
end

local function fallbackEntries(board: Board): { Entry }
	local entries: { Entry } = {}
	for _, player in Players:GetPlayers() do
		local data = services.DataService:GetData(player)
		if data then
			table.insert(entries, { Name = player.Name, Value = fieldValue(data, board.Field) })
		end
	end
	table.sort(entries, function(a: Entry, b: Entry): boolean
		if a.Value ~= b.Value then
			return a.Value > b.Value
		end
		return a.Name < b.Name
	end)
	while #entries > GameConfig.Leaderboards.Size do
		table.remove(entries)
	end
	return entries
end

local function nameOf(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and type(name) == "string" then
		names[userId] = name
		return name
	end
	return `Player{userId}`
end

local function fetchRemote(board: Board): { Entry }?
	local ok, entries = pcall(function()
		local store = DataStoreService:GetOrderedDataStore(board.StoreName)
		local pages = store:GetSortedAsync(false, GameConfig.Leaderboards.Size)
		local out: { Entry } = {}
		for _, item in pages:GetCurrentPage() do
			local userId = tonumber(item.key)
			if userId and type(item.value) == "number" then
				table.insert(out, { Name = nameOf(userId), Value = item.value })
			end
		end
		return out
	end)
	return if ok then entries else nil
end

local function refreshBoard(index: number)
	local board = boards[index]
	local remote = fetchRemote(board)
	if remote then
		cache[index] = remote
		isRemote[index] = true
	end
end

local function refreshAll()
	for index = 1, #boards do
		refreshBoard(index)
	end
end

local function submit(player: Player, data: PlayerData.Data)
	for _, board in boards do
		local value = fieldValue(data, board.Field)
		pcall(function()
			DataStoreService:GetOrderedDataStore(board.StoreName):SetAsync(tostring(player.UserId), value)
		end)
	end
end

local function submitAll()
	for _, player in Players:GetPlayers() do
		local data = services.DataService:GetData(player)
		if data then
			submit(player, data)
		end
	end
end

local function updateStats(player: Player)
	local data = services.DataService:GetData(player)
	local values = statValues[player]
	if data and values then
		values.Clicks.Value = data.Cash
		values.Rolls.Value = data.Rolls
		values.Rebirths.Value = data.Rebirths
	end
end

local function createStats(player: Player)
	local existing = statValues[player]
	if existing then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = statsFolderName
	local clicks = Instance.new("NumberValue")
	clicks.Name = "Clicks"
	clicks.Parent = folder
	local rolls = Instance.new("NumberValue")
	rolls.Name = "Rolls"
	rolls.Parent = folder
	local rebirths = Instance.new("NumberValue")
	rebirths.Name = "Rebirths"
	rebirths.Parent = folder
	statValues[player] = { Clicks = clicks, Rolls = rolls, Rebirths = rebirths }
	folder.Parent = player
	updateStats(player)
end

function LeaderboardService.Init(self: State, registry: { [string]: any })
	services = registry :: any
	self._trove = Trove.new()
end

function LeaderboardService.Start(self: State)
	local trove = self._trove :: TroveInstance
	services.DataService.PlayerLoaded:Connect(createStats)
	services.DataService.PlayerReleasing:Connect(function(player: Player, data: PlayerData.Data)
		statValues[player] = nil
		task.spawn(submit, player, data)
	end)
	trove:Add(task.spawn(function()
		while true do
			task.wait(statsInterval)
			for player in statValues do
				updateStats(player)
			end
		end
	end))
	trove:Add(task.spawn(function()
		while true do
			refreshAll()
			task.wait(GameConfig.Leaderboards.RefreshSeconds)
		end
	end))
	trove:Add(task.spawn(function()
		while true do
			task.wait(GameConfig.Leaderboards.SubmitSeconds)
			submitAll()
		end
	end))
	Packets.GetLeaderboard.OnServerInvoke = function(_player: Player, board: number): { Entry }
		if type(board) ~= "number" or boards[board] == nil then
			return {}
		end
		return if isRemote[board] then cache[board] else fallbackEntries(boards[board])
	end
end

function LeaderboardService.Destroy(self: State)
	Packets.GetLeaderboard.OnServerInvoke = nil
	table.clear(cache)
	table.clear(isRemote)
	table.clear(names)
	table.clear(statValues)
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return LeaderboardService
