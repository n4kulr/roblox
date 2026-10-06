--!strict

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Monetization = require(ReplicatedStorage.Config.Monetization)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	Resolved: Signal.Signal<Player>,
	_trove: TroveInstance?,
}

local PassService = {
	Name = "PassService",
	Resolved = Signal.new() :: Signal.Signal<Player>,
	_trove = nil :: TroveInstance?,
}
local services: { [string]: any } = {}
local retryDelaySeconds = 2
local attributePrefix = "Pass_"
local passIdByAttribute: { [string]: string } = {}
for _, pass in Monetization.Passes do
	passIdByAttribute[`{attributePrefix}{pass.Id}`] = pass.Id
end
local ownedByPlayer: { [Player]: { [string]: boolean } } = {}
local listeners: { [Player]: any } = {}

local resolvedPlayers: { [Player]: boolean } = {}

local function forget(player: Player)
	ownedByPlayer[player] = nil
	resolvedPlayers[player] = nil
	local listener = listeners[player]
	listeners[player] = nil
	if listener then
		listener:Disconnect()
	end
end

local function ownedSet(player: Player): { [string]: boolean }
	local owned = ownedByPlayer[player]
	if owned then
		return owned
	end
	local fresh: { [string]: boolean } = {}
	for attribute, passId in passIdByAttribute do
		if player:GetAttribute(attribute) == true then
			fresh[passId] = true
		end
	end
	ownedByPlayer[player] = fresh
	listeners[player] = player.AttributeChanged:Connect(function(attribute: string)
		local passId = passIdByAttribute[attribute]
		if passId then
			if player:GetAttribute(attribute) == true then
				fresh[passId] = true
			else
				fresh[passId] = nil
			end
			local keyboard = services.KeyboardService
			if keyboard then
				keyboard:InvalidateStats(player)
			end
		end
	end)
	return fresh
end

local function attributeName(passId: string): string
	return `{attributePrefix}{passId}`
end

local function grant(player: Player, pass: Monetization.Pass, shouldSettle: boolean)
	if player:GetAttribute(attributeName(pass.Id)) == true then
		return
	end
	local keyboard = services.KeyboardService
	if keyboard and shouldSettle then
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
				grant(player, pass, false)
			end
		end
	end
end

local function resolve(player: Player)
	refresh(player)
	if player.Parent ~= nil then
		resolvedPlayers[player] = true
		PassService.Resolved:Fire(player)
	end
end

function PassService.Init(self: State, registry: { [string]: any })
	services = registry
	self._trove = Trove.new()
end

function PassService.Start(self: State)
	local trove = self._trove :: TroveInstance
	services.DataService.PlayerLoaded:Connect(function(player: Player)
		task.spawn(resolve, player)
	end)
	trove:Connect(Players.PlayerRemoving, forget)
	trove:Connect(
		MarketplaceService.PromptGamePassPurchaseFinished,
		function(player: Player, assetId: number, wasPurchased: boolean)
			if not wasPurchased then
				return
			end
			for _, pass in Monetization.Passes do
				if pass.AssetId ~= 0 and pass.AssetId == assetId then
					grant(player, pass, true)
				end
			end
		end
	)
end

function PassService.IsResolved(_self: State, player: Player): boolean
	return resolvedPlayers[player] == true
end

function PassService.Owns(_self: State, player: Player, passId: string): boolean
	return ownedSet(player)[passId] == true
end

function PassService.GetPasses(_self: State, player: Player): { [string]: boolean }
	return ownedSet(player)
end

function PassService.Destroy(self: State)
	for player in listeners do
		forget(player)
	end
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return PassService
