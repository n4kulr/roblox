--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Monetization = require(ReplicatedStorage.Config.Monetization)

local Purchases = {}

function Purchases.IsAvailable(item: { AssetId: number }): boolean
	return item.AssetId ~= 0
end

function Purchases.PromptPass(pass: Monetization.Pass): boolean
	if pass.AssetId == 0 then
		return false
	end
	MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, pass.AssetId)
	return true
end

function Purchases.PromptProduct(product: Monetization.Product): boolean
	if product.AssetId == 0 then
		return false
	end
	MarketplaceService:PromptProductPurchase(Players.LocalPlayer, product.AssetId)
	return true
end

return Purchases
