--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Packets)
local Upgrades = require(ReplicatedStorage.Config.Upgrades)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)

type State = {
	Name: string,
}

local UpgradeService = {
	Name = "UpgradeService",
}
local services: { [string]: any } = {}

local function buyUpgrade(player: Player, upgradeId: string): boolean
	if type(upgradeId) ~= "string" then
		return false
	end
	local upgrade = Upgrades.ById[upgradeId]
	if not upgrade or not services.DataService:GetData(player) then
		return false
	end
	services.KeyboardService:Settle(player)
	local data = services.DataService:GetData(player) :: PlayerData.Data?
	local replica = services.DataService:GetReplica(player)
	if not data or not replica then
		return false
	end
	local level = data.Upgrades[upgrade.Id]
	if type(level) ~= "number" or level >= upgrade.MaxLevel then
		return false
	end
	local cost = Upgrades.Cost(upgrade, level)
	if not cost or data.Cash < cost then
		return false
	end
	local values: { [string]: any } = { Cash = data.Cash - cost }
	if data.Tutorial < 3 then
		values.Tutorial = 3
	end
	replica:SetValues({}, values)
	replica:SetValues({ "Upgrades" }, { [upgrade.Id] = level + 1 })
	if upgrade.Id == "Slots" or upgrade.Id == "Walls" then
		services.KeyboardService.BoardChanged:Fire(player)
	end
	return true
end

function UpgradeService.Init(_self: State, registry: { [string]: any })
	services = registry
end

function UpgradeService.Start(_self: State)
	Packets.BuyUpgrade.OnServerInvoke = buyUpgrade
end

function UpgradeService.Destroy(_self: State)
	Packets.BuyUpgrade.OnServerInvoke = nil
end

return UpgradeService
