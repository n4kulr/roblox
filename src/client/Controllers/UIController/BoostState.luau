--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Monetization = require(ReplicatedStorage.Config.Monetization)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Boosts = require(ReplicatedStorage.Rules.Boosts)

type TroveInstance = typeof(Trove.new())

export type State = {
	Passes: () -> { [string]: boolean },
	Owns: (passId: string) -> boolean,
	Stored: () -> Boosts.Stored,
	ServerLuck: () -> (number, string),
	Modifiers: (now: number) -> Boosts.Modifiers,
}

local BoostState = {}

local function number(value: any): number
	return if type(value) == "number" then value else 0
end

function BoostState.Track(dataController: any, trove: TroveInstance): State
	local luckUntil = 0
	local clicksUntil = 0

	trove:Add(dataController:Observe({ "Boosts" }, function(value: any)
		luckUntil = if type(value) == "table" then number(value.LuckUntil) else 0
		clicksUntil = if type(value) == "table" then number(value.ClicksUntil) else 0
	end))

	local function passes(): { [string]: boolean }
		local owned: { [string]: boolean } = {}
		for _, pass in Monetization.Passes do
			if Players.LocalPlayer:GetAttribute(`Pass_{pass.Id}`) == true then
				owned[pass.Id] = true
			end
		end
		return owned
	end

	local function serverLuck(): (number, string)
		local by = ReplicatedStorage:GetAttribute("ServerLuckBy")
		return number(ReplicatedStorage:GetAttribute("ServerLuckUntil")),
			if type(by) == "string" then by else ""
	end

	return {
		Passes = passes,
		Owns = function(passId: string): boolean
			return Players.LocalPlayer:GetAttribute(`Pass_{passId}`) == true
		end,
		Stored = function(): Boosts.Stored
			return { LuckUntil = luckUntil, ClicksUntil = clicksUntil }
		end,
		ServerLuck = serverLuck,
		Modifiers = function(now: number): Boosts.Modifiers
			local serverLuckUntil = serverLuck()
			return Boosts.Modifiers(
				{ LuckUntil = luckUntil, ClicksUntil = clicksUntil },
				passes(),
				now,
				serverLuckUntil
			)
		end,
	}
end

return BoostState
