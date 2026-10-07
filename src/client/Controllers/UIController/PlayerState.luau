--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Monetization = require(ReplicatedStorage.Config.Monetization)

local developerAttribute = "IsDeveloper"
local marketAttribute = "OpenMarket"
local passPrefix = "Pass_"
local serverLuckUntilAttribute = "ServerLuckUntil"
local serverLuckByAttribute = "ServerLuckBy"
local plotOwnerAttribute = "Owner"

local PlayerState = {}

local function number(value: any): number
	return if type(value) == "number" then value else 0
end

function PlayerState.IsDeveloper(): boolean
	local player = Players.LocalPlayer
	return player ~= nil and player:GetAttribute(developerAttribute) == true
end

function PlayerState.DeveloperChanged(): RBXScriptSignal?
	local player = Players.LocalPlayer
	if not player then
		return nil
	end
	return player:GetAttributeChangedSignal(developerAttribute)
end

function PlayerState.OwnsPass(passId: string): boolean
	return Players.LocalPlayer:GetAttribute(`{passPrefix}{passId}`) == true
end

function PlayerState.OwnedPasses(): { [string]: boolean }
	local owned: { [string]: boolean } = {}
	for _, pass in Monetization.Passes do
		if PlayerState.OwnsPass(pass.Id) then
			owned[pass.Id] = true
		end
	end
	return owned
end

function PlayerState.ServerLuck(): (number, string)
	local by = ReplicatedStorage:GetAttribute(serverLuckByAttribute)
	return number(ReplicatedStorage:GetAttribute(serverLuckUntilAttribute)),
		if type(by) == "string" then by else ""
end

function PlayerState.ServerLuckChanged(): RBXScriptSignal
	return ReplicatedStorage:GetAttributeChangedSignal(serverLuckUntilAttribute)
end

function PlayerState.IsMarketRequested(): boolean
	return Players.LocalPlayer:GetAttribute(marketAttribute) ~= nil
end

function PlayerState.MarketRequested(): RBXScriptSignal
	return Players.LocalPlayer:GetAttributeChangedSignal(marketAttribute)
end

function PlayerState.OwnPlot(): Model?
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	local userId = Players.LocalPlayer.UserId
	for _, child in plots:GetChildren() do
		if child:IsA("Model") and child:GetAttribute(plotOwnerAttribute) == userId then
			return child
		end
	end
	return nil
end

return PlayerState
