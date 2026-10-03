--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Packets)
local Rebirth = require(ReplicatedStorage.Rules.Rebirth)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)

local RebirthService = { Name = "RebirthService" }
local services: { [string]: any } = {}

local function rebirth(player: Player): boolean
	local data = services.DataService:GetData(player) :: PlayerData.Data?
	local replica = services.DataService:GetReplica(player)
	if not data or not replica then
		return false
	end
	services.KeyboardService:Settle(player)
	if data.Cash < Rebirth.Cost(data.Rebirths) then
		return false
	end
	replica:SetValues({}, { Cash = 0, IncomeAt = os.time(), Rebirths = data.Rebirths + 1 })
	replica:SetValues({ "Upgrades" }, { Luck = 0, Speed = 0, Slots = 0 })
	services.KeyboardService:Normalize(player)
	services.KeyboardService.BoardChanged:Fire(player)
	services.DataService:RequestSave(player)
	return true
end

function RebirthService.Init(_self: any, registry: { [string]: any })
	services = registry
end

function RebirthService.Start(_self: any)
	Packets.Rebirth.OnServerInvoke = rebirth
end

function RebirthService.Destroy(_self: any)
	Packets.Rebirth.OnServerInvoke = nil
end

return RebirthService
