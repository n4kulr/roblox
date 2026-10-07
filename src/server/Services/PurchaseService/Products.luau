--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Monetization = require(ReplicatedStorage.Config.Monetization)
local WorldNames = require(ReplicatedStorage.Config.WorldNames)
local Boosts = require(ReplicatedStorage.Rules.Boosts)
local Rewards = require(script.Parent.Parent.Parent.Utils.Rewards)
local ServerTypes = require(script.Parent.Parent.Parent.Types)

export type Grant = (player: Player, services: ServerTypes.Registry) -> boolean

local starterPotionSeconds = GameConfig.Boosts.PotionSeconds
local starterKeyRarity = "Epic"

local function makeGrant(product: Monetization.Product): Grant?
	local kind = product.Kind
	if kind == "LuckPotion" then
		return function(player, services)
			return Rewards.ExtendPotion(player, services, "LuckUntil", product.Amount)
		end
	elseif kind == "ClicksPotion" then
		return function(player, services)
			return Rewards.ExtendPotion(player, services, "ClicksUntil", product.Amount)
		end
	elseif kind == "Clicks" then
		return function(player, services)
			return Rewards.AddClicks(player, services, product.Amount)
		end
	elseif kind == "ServerLuck" then
		return function(player, _services)
			local current = ReplicatedStorage:GetAttribute(WorldNames.Attributes.ServerLuckUntil)
			local expiresAt = if type(current) == "number" then current else 0
			ReplicatedStorage:SetAttribute(WorldNames.Attributes.ServerLuckBy, player.DisplayName)
			ReplicatedStorage:SetAttribute(
				"ServerLuckUntil",
				Boosts.Extend(expiresAt, os.time(), product.Amount)
			)
			return true
		end
	elseif kind == "StarterPack" then
		return function(player, services)
			local data = services.DataService:GetData(player)
			if not data or not services.DataService:GetReplica(player) then
				return false
			end
			if data.StarterPackBought then
				return Rewards.AddClicks(player, services, product.Amount)
			end
			if not Rewards.GrantRandomKey(player, services, starterKeyRarity) then
				return false
			end
			Rewards.ExtendPotion(player, services, "LuckUntil", starterPotionSeconds)
			Rewards.AddClicks(player, services, product.Amount)
			services.DataService:Set(player, { "StarterPackBought" }, true)
			return true
		end
	end
	return nil
end

local Products: { [number]: Grant } = {}

for _, product in Monetization.Products do
	if product.AssetId ~= 0 then
		local grant = makeGrant(product)
		if grant then
			Products[product.AssetId] = grant
		end
	end
end

return Products
