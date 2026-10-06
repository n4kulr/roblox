--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharmConfig = require(ReplicatedStorage.Config.Charms)
local Eggs = require(ReplicatedStorage.Config.Eggs)
local Keys = require(ReplicatedStorage.Config.Keys)

local Lookup = {}

local function squash(text: string): string
	return string.lower((string.gsub(text, "[%s_%-]", "")))
end

function Lookup.Key(text: string): Keys.Key?
	local wanted = squash(text)
	for _, key in Keys.Catalog do
		if squash(key.Id) == wanted or squash(key.Name) == wanted then
			return key
		end
	end
	return nil
end

function Lookup.Rarity(text: string): string?
	local wanted = squash(text)
	for _, rarity in Keys.Rarities do
		if squash(rarity.Name) == wanted then
			return rarity.Name
		end
	end
	return nil
end

function Lookup.Egg(text: string): Eggs.Egg?
	local wanted = squash(text)
	for _, egg in Eggs.Catalog do
		if squash(egg.Id) == wanted or squash(egg.Name) == wanted then
			return egg
		end
	end
	return nil
end

function Lookup.Pet(text: string): CharmConfig.Charm?
	local wanted = squash(text)
	for _, charm in CharmConfig.Catalog do
		if squash(charm.Id) == wanted or squash(charm.Name) == wanted then
			return charm
		end
	end
	return nil
end

return Lookup
