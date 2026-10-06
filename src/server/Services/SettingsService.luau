--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ServerTypes = require(script.Parent.Parent.Types)

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	_trove: TroveInstance?,
}

local SettingsService = {
	Name = "SettingsService",
	_trove = nil :: TroveInstance?,
}
local services: ServerTypes.Registry = nil :: any

local booleanSettings: { [string]: boolean } = { LowGraphics = true, AutoPlace = true }
local volumeSettings: { [string]: boolean } =
	{ RollVolume = true, BoardVolume = true, OtherVolume = true, MusicVolume = true }

local function setSetting(player: Player, name: string, value: number)
	if
		type(name) ~= "string"
		or type(value) ~= "number"
		or value ~= value
		or math.abs(value) == math.huge
	then
		return
	end
	if booleanSettings[name] then
		services.DataService:Set(player, { "Settings", name }, value ~= 0)
	elseif name == "EffectsMinRarity" then
		services.DataService:Set(player, { "Settings", name }, math.clamp(math.floor(value), 1, 8))
	elseif volumeSettings[name] then
		local volume = math.floor(math.clamp(value, 0, 1) * 100 + 0.5) / 100
		services.DataService:Set(player, { "Settings", name }, volume)
	end
end

function SettingsService.Init(self: State, registry: { [string]: any })
	services = registry :: any
	self._trove = Trove.new()
end

function SettingsService.Start(self: State)
	local trove = self._trove :: TroveInstance
	trove:Add(Packets.SetSetting.OnServerEvent:Connect(setSetting))
end

function SettingsService.Destroy(self: State)
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return SettingsService
