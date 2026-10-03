--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Monetization = require(ReplicatedStorage.Config.Monetization)
local Trove = require(ReplicatedStorage.Packages.Trove)

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	_trove: TroveInstance?,
}

local PassService = {
	Name = "PassService",
	_trove = nil :: TroveInstance?,
}
local services: { [string]: any } = {}
local retryDelaySeconds = 2

local function attributeName(passId: string): string
	return `Pass_{passId}`
end

local function grant(player: Player, pass: Monetization.Pass)
	if player:GetAttribute(attributeName(pass.Id)) == true then
		return
	end
	local keyboard = services.KeyboardService
	if keyboard then
		keyboard:Settle(player)
	end
	player:SetAttribute(attributeName(pass.Id), true)
end

local function queryOwnership(player: Player, pass: Monetization.Pass): boolean?
	for attempt = 1, 2 do
		local ok, owns = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.AssetId)
		end)
		if ok then
			return owns == true
		end
		if attempt == 1 then
			task.wait(retryDelaySeconds)
		end
	end
	warn(`[PassService] Could not check pass {pass.Id} for {player.Name}`)
	return nil
end

local function refresh(player: Player)
	for _, pass in Monetization.Passes do
		if pass.AssetId ~= 0 and player:GetAttribute(attributeName(pass.Id)) ~= true then
			local owns = queryOwnership(player, pass)
			if player.Parent == nil then
				return
			end
			if owns then
				grant(player, pass)
			end
		end
	end
end

function PassService.Init(self: State, registry: { [string]: any })
	services = registry
	self._trove = Trove.new()
end

function PassService.Start(self: State)
	local trove = self._trove :: TroveInstance
	services.DataService.PlayerLoaded:Connect(function(player: Player)
		task.spawn(refresh, player)
	end)
	trove:Connect(
		MarketplaceService.PromptGamePassPurchaseFinished,
		function(player: Player, assetId: number, wasPurchased: boolean)
			if not wasPurchased then
				return
			end
			for _, pass in Monetization.Passes do
				if pass.AssetId ~= 0 and pass.AssetId == assetId then
					grant(player, pass)
				end
			end
		end
	)
end

function PassService.Owns(_self: State, player: Player, passId: string): boolean
	return player:GetAttribute(attributeName(passId)) == true
end

function PassService.GetPasses(_self: State, player: Player): { [string]: boolean }
	local passes: { [string]: boolean } = {}
	for _, pass in Monetization.Passes do
		if player:GetAttribute(attributeName(pass.Id)) == true then
			passes[pass.Id] = true
		end
	end
	return passes
end

function PassService.Destroy(self: State)
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return PassService
