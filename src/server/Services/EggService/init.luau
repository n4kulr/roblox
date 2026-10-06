--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharmConfig = require(ReplicatedStorage.Config.Charms)
local Eggs = require(ReplicatedStorage.Config.Eggs)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Charms = require(ReplicatedStorage.Rules.Charms)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local Incubators = require(script.Parent.PlotService.Incubators)

type TroveInstance = typeof(Trove.new())

type State = {
	Name: string,
	_trove: TroveInstance?,
}

local refreshSeconds = 1

local EggService = {
	Name = "EggService",
	_trove = nil :: TroveInstance?,
}
local services: { [string]: any } = {}
local random: Random? = nil
local shownFolders: { [Player]: Folder } = {}

local function isSlot(value: any): boolean
	return type(value) == "number"
		and value == value
		and value % 1 == 0
		and value >= 1
		and value <= Eggs.Slots
end

local function slotPath(field: string, slot: number): any
	local path: { any } = { field, slot }
	return path
end

local function dataOf(player: Player): PlayerData.Data?
	return services.DataService:GetData(player) :: PlayerData.Data?
end

local function publishEquipped(player: Player, data: PlayerData.Data)
	player:SetAttribute("EquippedCharms", table.concat(data.EquippedCharms, ","))
end

local function showIncubators(player: Player, now: number)
	local data = dataOf(player)
	local plotService = services.PlotService
	local plot = if plotService then plotService:GetPlot(player) :: Model? else nil
	local folder = if plot then Incubators.Find(plot) else nil
	local previous = shownFolders[player]
	if previous and previous ~= folder then
		Incubators.Refresh(previous, {}, {}, now)
		shownFolders[player] = nil
	end
	if data and folder then
		shownFolders[player] = folder
		Incubators.Refresh(folder, data.Incubators, data.IncubatorReadyAt, now)
	end
end

function EggService.HasRoom(_self: State, player: Player): boolean
	local data = dataOf(player)
	return data ~= nil and table.find(data.Incubators, "") ~= nil
end

function EggService.PlaceEgg(_self: State, player: Player, eggId: string): number
	local data = dataOf(player)
	local egg = Eggs.ById[eggId]
	if not data or not egg then
		return 0
	end
	local slot = table.find(data.Incubators, "")
	if not slot then
		return 0
	end
	local now = os.time()
	services.DataService:Set(player, slotPath("Incubators", slot), eggId)
	services.DataService:Set(player, slotPath("IncubatorReadyAt", slot), now + egg.HatchSeconds)
	showIncubators(player, now)
	return slot
end

function EggService.Hatch(_self: State, player: Player, slot: number): string
	local data = dataOf(player)
	if not data or not isSlot(slot) then
		return ""
	end
	local eggId = data.Incubators[slot]
	if not eggId or Eggs.ById[eggId] == nil then
		return ""
	end
	local now = os.time()
	if now < (data.IncubatorReadyAt[slot] or 0) then
		return ""
	end
	local rng = random
	if not rng then
		return ""
	end
	local charmId = Charms.Roll(rng, eggId)
	if CharmConfig.ById[charmId] == nil then
		return ""
	end
	services.DataService:Set(player, slotPath("Incubators", slot), "")
	services.DataService:Set(player, slotPath("IncubatorReadyAt", slot), 0)
	services.DataService:Set(player, { "Charms", charmId }, (data.Charms[charmId] or 0) + 1)
	services.DataService:RequestSave(player)
	showIncubators(player, now)
	return charmId
end

function EggService.Equip(_self: State, player: Player, charmId: string, equip: boolean): boolean
	local data = dataOf(player)
	if not data or type(charmId) ~= "string" or type(equip) ~= "boolean" then
		return false
	end
	local list = table.clone(data.EquippedCharms)
	if equip then
		if not Charms.CanEquip(data.Charms, list, charmId) then
			return false
		end
		table.insert(list, charmId)
	else
		local found = table.find(list, charmId)
		if not found then
			return false
		end
		table.remove(list, found)
	end
	services.DataService:Set(player, { "EquippedCharms" }, list)
	services.DataService:RequestSave(player)
	publishEquipped(player, data)
	return true
end

local function loadPlayer(player: Player, data: PlayerData.Data)
	local clean = Charms.Sanitize(data.Charms, data.EquippedCharms)
	if #clean ~= #data.EquippedCharms then
		services.DataService:Set(player, { "EquippedCharms" }, clean)
	end
	publishEquipped(player, data)
end

function EggService.Init(self: State, registry: { [string]: any })
	services = registry
	self._trove = Trove.new()
end

function EggService.Start(self: State)
	local trove = self._trove :: TroveInstance
	random = Random.new()
	services.DataService.PlayerLoaded:Connect(loadPlayer)
	services.DataService.PlayerReleasing:Connect(function(player: Player, _data: PlayerData.Data)
		local folder = shownFolders[player]
		shownFolders[player] = nil
		if folder then
			Incubators.Refresh(folder, {}, {}, os.time())
		end
	end)
	for _, player in Players:GetPlayers() do
		local data = dataOf(player)
		if data then
			loadPlayer(player, data)
		end
	end
	Packets.HatchEgg.OnServerInvoke = function(player: Player, slot: number)
		return EggService:Hatch(player, slot)
	end
	Packets.EquipCharm.OnServerInvoke = function(player: Player, charmId: string, equip: boolean)
		return EggService:Equip(player, charmId, equip)
	end
	trove:Add(task.spawn(function()
		while true do
			task.wait(refreshSeconds)
			local now = os.time()
			for _, player in Players:GetPlayers() do
				showIncubators(player, now)
			end
		end
	end))
end

function EggService.Destroy(self: State)
	Packets.HatchEgg.OnServerInvoke = nil
	Packets.EquipCharm.OnServerInvoke = nil
	table.clear(shownFolders)
	random = nil
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return EggService
