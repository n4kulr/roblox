--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Packets)
local Upgrades = require(ReplicatedStorage.Config.Upgrades)
local UpgradeCost = require(ReplicatedStorage.Rules.UpgradeCost)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local ServerTypes = require(script.Parent.Parent.Types)

type State = {
	Name: string,
}

local UpgradeService = {
	Name = "UpgradeService",
}
local services: ServerTypes.Registry = nil :: any

local function buyUpgrade(player: Player, upgradeId: string, amount: number): boolean
	if type(upgradeId) ~= "string" or type(amount) ~= "number" or amount % 1 ~= 0 or amount < 0 then
		return false
	end
	local upgrade = Upgrades.ById[upgradeId]
	if not upgrade or not services.DataService:GetData(player) then
		return false
	end
	services.KeyboardService:Settle(player)
	local data = services.DataService:GetData(player)
	local replica = services.DataService:GetReplica(player)
	if not data or not replica then
		return false
	end
	local level = data.Upgrades[upgrade.Id]
	if type(level) ~= "number" or level >= upgrade.MaxLevel then
		return false
	end
	local count = UpgradeCost.Affordable(upgrade, level, data.Cash, amount)
	if count < 1 then
		return false
	end
	local cost = UpgradeCost.Total(upgrade, level, count)
	local values: { [string]: any } = { Cash = data.Cash - cost }
	if data.Tutorial < 3 then
		values.Tutorial = 3
	end
	replica:SetValues({}, values)
	replica:SetValues({ "Upgrades" }, { [upgrade.Id] = level + count })
	if upgrade.Id == "Slots" or upgrade.Id == "Walls" then
		services.KeyboardService:NotifyBoardChanged(player)
	end
	return true
end

function UpgradeService.Init(_self: State, registry: { [string]: any })
	services = registry :: any
end

function UpgradeService.Start(_self: State)
	Packets.BuyUpgrade.OnServerInvoke = buyUpgrade
end

function UpgradeService.Destroy(_self: State)
	Packets.BuyUpgrade.OnServerInvoke = nil
end

return UpgradeService
