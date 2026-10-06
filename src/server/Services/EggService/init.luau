--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharmConfig = require(ReplicatedStorage.Config.Charms)
local Eggs = require(ReplicatedStorage.Config.Eggs)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Charms = require(ReplicatedStorage.Rules.Charms)
local EggPlacement = require(ReplicatedStorage.Utils.EggPlacement)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local Inventory = require(script.Inventory)
local Pets = require(script.Pets)
local Placed = require(script.Placed)
local Tools = require(script.Tools)
local ServerTypes = require(script.Parent.Parent.Types)

type TroveInstance = typeof(Trove.new())

type State = {
	Name: string,
	CanBuy: (self: State, player: Player) -> string,
	ReadyEggs: (self: State, player: Player) -> number,
	Hatch: (self: State, player: Player, index: any) -> string,
	HatchAll: (self: State, player: Player) -> { string },
	_trove: TroveInstance?,
}

local refreshSeconds = 1
local backpackWait = 5

local EggService = {
	Name = "EggService",
	_trove = nil :: TroveInstance?,
}
local services: ServerTypes.Registry = nil :: any
local random: Random? = nil
local shown: { [Player]: Placed.Shown } = {}
local petsShown: { [Player]: Pets.Shown } = {}
local playerTroves: { [Player]: TroveInstance } = {}

local function dataOf(player: Player): PlayerData.Data?
	return services.DataService:GetData(player)
end

local function plotOf(player: Player): (Model?, BasePart?, BasePart?)
	local plotService = services.PlotService
	if not plotService then
		return nil, nil, nil
	end
	local plot = plotService:GetPlot(player)
	local base = plotService:GetBase(player)
	local rollKey = if plotService.GetRollKey then plotService:GetRollKey(player) else nil
	return plot :: Model?, base :: BasePart?, rollKey :: BasePart?
end

local function footprint(base: BasePart, rollKey: BasePart?): EggPlacement.Rect?
	return if rollKey then EggPlacement.RectOf(base.CFrame, rollKey) else nil
end

local function spotsOf(list: { Inventory.Placed }): { EggPlacement.Spot }
	local spots: { EggPlacement.Spot } = {}
	for _, entry in list do
		table.insert(spots, { X = entry.X, Z = entry.Z })
	end
	return spots
end

local function showPlaced(player: Player, now: number)
	local data = dataOf(player)
	local plot, base = plotOf(player)
	local state = shown[player]
	if not data or not plot or not base or not Placed.IsPlot(plot) then
		if state then
			Placed.Clear(state)
		end
		return
	end
	if not state then
		state = Placed.NewShown()
		shown[player] = state
	end
	Placed.Refresh(state, plot, base, data.PlacedEggs, now)
end

local function showPets(player: Player, data: PlayerData.Data)
	local plot, base, rollKey = plotOf(player)
	local state = petsShown[player]
	if not plot or not base or not Placed.IsPlot(plot) then
		if state then
			Pets.Clear(state)
		end
		return
	end
	if not state then
		state = Pets.NewShown()
		petsShown[player] = state
	end
	Pets.Refresh(state, plot, base, rollKey, player.UserId, data.EquippedCharms)
end

local function syncActive(player: Player, data: PlayerData.Data)
	local best = Charms.Best(data.Charms)
	if table.concat(best, ",") ~= table.concat(data.EquippedCharms, ",") then
		services.DataService:Set(player, { "EquippedCharms" }, best)
	end
	player:SetAttribute("EquippedCharms", table.concat(best, ","))
	showPets(player, data)
end

local function syncTools(player: Player)
	local data = dataOf(player)
	if data then
		Tools.Sync(player, data.HeldEgg)
	end
end

local function migrate(player: Player, data: PlayerData.Data)
	local legacy: { number } = {}
	if type(data.Incubators) == "table" then
		for slot = 1, #data.Incubators do
			if Eggs.ById[data.Incubators[slot]] ~= nil then
				table.insert(legacy, slot)
			end
		end
	end
	if #legacy == 0 then
		return
	end
	local _, base, rollKey = plotOf(player)
	if not base then
		return
	end
	local rect = footprint(base, rollKey)
	local list = table.clone(data.PlacedEggs)
	local incubators = table.clone(data.Incubators)
	local readyAt = table.clone(data.IncubatorReadyAt)
	local now = os.time()
	for _, slot in legacy do
		local spot = EggPlacement.FindSpot(base.Size, rect, spotsOf(list))
		if spot then
			local eggId = data.Incubators[slot]
			local ready = data.IncubatorReadyAt[slot]
			table.insert(list, {
				Id = eggId,
				ReadyAt = if type(ready) == "number" and ready > 0
					then ready
					else now + Eggs.ById[eggId].HatchSeconds,
				X = spot.X,
				Z = spot.Z,
			})
			incubators[slot] = ""
			readyAt[slot] = 0
		end
	end
	services.DataService:Set(player, { "PlacedEggs" }, list)
	services.DataService:Set(player, { "Incubators" }, incubators)
	services.DataService:Set(player, { "IncubatorReadyAt" }, readyAt)
	services.DataService:RequestSave(player)
end

function EggService.Sync(_self: State, player: Player)
	syncTools(player)
	showPlaced(player, os.time())
	local data = dataOf(player)
	if data then
		syncActive(player, data)
	end
end

function EggService.CanBuy(_self: State, player: Player): string
	local data = dataOf(player)
	if not data then
		return "NoData"
	end
	if data.HeldEgg ~= "" then
		return "Holding"
	end
	if #data.PlacedEggs >= Eggs.PlacedCap then
		return "Full"
	end
	return "Ok"
end

local function hold(player: Player, eggId: string)
	services.DataService:Set(player, { "HeldEgg" }, eggId)
	syncTools(player)
	Tools.Equip(player)
end

function EggService.AddEgg(self: State, player: Player, eggId: string): boolean
	if Eggs.ById[eggId] == nil or self:CanBuy(player) ~= "Ok" then
		return false
	end
	hold(player, eggId)
	return true
end

function EggService.GrantEgg(_self: State, player: Player, eggId: string): boolean
	local data = dataOf(player)
	if not data or Eggs.ById[eggId] == nil then
		return false
	end
	if data.HeldEgg == "" then
		hold(player, eggId)
		return true
	end
	if Inventory.Count(data.EggInventory, eggId) >= Inventory.MaxCount then
		return false
	end
	services.DataService:Set(player, { "EggInventory" }, Inventory.Added(data.EggInventory, eggId))
	return true
end

local function promoteQueued(player: Player, data: PlayerData.Data)
	local nextId = Inventory.Next(data.EggInventory)
	if data.HeldEgg ~= "" or nextId == nil then
		return
	end
	services.DataService:Set(player, { "EggInventory" }, Inventory.Removed(data.EggInventory, nextId))
	services.DataService:Set(player, { "HeldEgg" }, nextId)
end

function EggService.PlaceEgg(_self: State, player: Player, eggId: any, x: any, z: any): boolean
	local data = dataOf(player)
	if not data or type(eggId) ~= "string" or Eggs.ById[eggId] == nil then
		return false
	end
	if data.HeldEgg ~= eggId or #data.PlacedEggs >= Eggs.PlacedCap then
		return false
	end
	local _, base, rollKey = plotOf(player)
	if not base then
		return false
	end
	local placed = data.PlacedEggs
	if EggPlacement.Check(base.Size, footprint(base, rollKey), spotsOf(placed), x, z) ~= "Ok" then
		return false
	end
	local list = table.clone(placed)
	table.insert(list, { Id = eggId, ReadyAt = os.time() + Eggs.ById[eggId].HatchSeconds, X = x, Z = z })
	services.DataService:Set(player, { "PlacedEggs" }, list)
	services.DataService:Set(player, { "HeldEgg" }, "")
	promoteQueued(player, data)
	services.DataService:RequestSave(player)
	syncTools(player)
	Tools.Equip(player)
	showPlaced(player, os.time())
	return true
end

function EggService.Hatch(_self: State, player: Player, index: any): (string, boolean)
	local data = dataOf(player)
	if
		not data
		or type(index) ~= "number"
		or index ~= index
		or index % 1 ~= 0
		or index < 1
		or index > #data.PlacedEggs
	then
		return "", false
	end
	local entry = data.PlacedEggs[index]
	if Eggs.ById[entry.Id] == nil then
		return "", false
	end
	local now = os.time()
	if now < entry.ReadyAt then
		return "", false
	end
	local rng = random
	if not rng then
		return "", false
	end
	local charmId = Charms.Roll(rng, entry.Id)
	if CharmConfig.ById[charmId] == nil then
		return "", false
	end
	local list = table.clone(data.PlacedEggs)
	table.remove(list, index)
	services.DataService:Set(player, { "PlacedEggs" }, list)
	services.DataService:Set(player, { "Charms", charmId }, (data.Charms[charmId] or 0) + 1)
	syncActive(player, data)
	services.DataService:RequestSave(player)
	local state = shown[player]
	if state then
		Placed.Remove(state, index)
	end
	showPlaced(player, now)
	return charmId, table.find(data.EquippedCharms, charmId) ~= nil
end

function EggService.ReadyEggs(_self: State, player: Player): number
	local data = dataOf(player)
	if not data or #data.PlacedEggs == 0 then
		return 0
	end
	local now = os.time()
	local list = table.clone(data.PlacedEggs)
	local count = 0
	for index, entry in list do
		if entry.ReadyAt > now then
			list[index] = { Id = entry.Id, ReadyAt = now, X = entry.X, Z = entry.Z }
			count += 1
		end
	end
	if count == 0 then
		return 0
	end
	services.DataService:Set(player, { "PlacedEggs" }, list)
	services.DataService:RequestSave(player)
	showPlaced(player, now)
	return count
end

function EggService.HatchAll(self: State, player: Player): { string }
	self:ReadyEggs(player)
	local charms: { string } = {}
	while true do
		local data = dataOf(player)
		if not data or #data.PlacedEggs == 0 then
			break
		end
		local charmId = (self:Hatch(player, 1))
		if charmId == "" then
			break
		end
		table.insert(charms, charmId)
	end
	return charms
end

local function releasePlayer(player: Player)
	local playerTrove = playerTroves[player]
	playerTroves[player] = nil
	if playerTrove then
		playerTrove:Destroy()
	end
	local state = shown[player]
	shown[player] = nil
	if state then
		Placed.Clear(state)
	end
	local petState = petsShown[player]
	petsShown[player] = nil
	if petState then
		Pets.Clear(petState)
	end
end

local function loadPlayer(player: Player, data: PlayerData.Data)
	releasePlayer(player)
	local bag = Inventory.CleanBag(data.EggInventory)
	if not Inventory.Same(bag, data.EggInventory) then
		services.DataService:Set(player, { "EggInventory" }, bag)
	end
	if type(data.HeldEgg) ~= "string" or (data.HeldEgg ~= "" and Eggs.ById[data.HeldEgg] == nil) then
		services.DataService:Set(player, { "HeldEgg" }, "")
	end
	promoteQueued(player, data)
	local placed = Inventory.CleanPlaced(data.PlacedEggs)
	if not Inventory.Same(placed, data.PlacedEggs) then
		services.DataService:Set(player, { "PlacedEggs" }, placed)
	end
	migrate(player, data)
	local playerTrove = Trove.new()
	playerTroves[player] = playerTrove
	playerTrove:Connect(player.CharacterAdded, function(_character: Model)
		task.spawn(function()
			player:WaitForChild("Backpack", backpackWait)
			if playerTroves[player] == playerTrove then
				syncTools(player)
			end
		end)
	end)
	syncTools(player)
	showPlaced(player, os.time())
	syncActive(player, data)
end

function EggService.Init(self: State, registry: { [string]: any })
	services = registry :: any
	self._trove = Trove.new()
end

function EggService.Start(self: State)
	local trove = self._trove :: TroveInstance
	random = Random.new()
	services.DataService.PlayerLoaded:Connect(loadPlayer)
	services.DataService.PlayerReleasing:Connect(function(player: Player, _data: PlayerData.Data)
		releasePlayer(player)
	end)
	if services.PlotService and services.PlotService.PlotAssigned then
		trove:Add(services.PlotService.PlotAssigned:Connect(function(player: Player)
			local data = dataOf(player)
			if data then
				migrate(player, data)
				showPlaced(player, os.time())
				showPets(player, data)
			end
		end))
	end
	for _, player in Players:GetPlayers() do
		local data = dataOf(player)
		if data then
			loadPlayer(player, data)
		end
	end
	Packets.HatchEgg.OnServerInvoke = function(player: Player, index: number)
		return EggService:Hatch(player, index)
	end
	Packets.PlaceEgg.OnServerInvoke = function(player: Player, eggId: string, x: number, z: number)
		return EggService:PlaceEgg(player, eggId, x, z)
	end
	trove:Add(task.spawn(function()
		while true do
			task.wait(refreshSeconds)
			local now = os.time()
			for _, player in Players:GetPlayers() do
				showPlaced(player, now)
				local data = dataOf(player)
				if data then
					showPets(player, data)
				end
			end
		end
	end))
end

function EggService.Destroy(self: State)
	Packets.HatchEgg.OnServerInvoke = nil
	Packets.PlaceEgg.OnServerInvoke = nil
	for player in playerTroves do
		releasePlayer(player)
	end
	for player, state in shown do
		Placed.Clear(state)
		shown[player] = nil
	end
	for player, state in petsShown do
		Pets.Clear(state)
		petsShown[player] = nil
	end
	random = nil
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return EggService
