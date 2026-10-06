--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local Boosts = require(ReplicatedStorage.Rules.Boosts)
local PlayerState = require(script.Parent.PlayerState)

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

	return {
		Passes = PlayerState.OwnedPasses,
		Owns = PlayerState.OwnsPass,
		Stored = function(): Boosts.Stored
			return { LuckUntil = luckUntil, ClicksUntil = clicksUntil }
		end,
		ServerLuck = PlayerState.ServerLuck,
		Modifiers = function(now: number): Boosts.Modifiers
			local serverLuckUntil = PlayerState.ServerLuck()
			return Boosts.Modifiers(
				{ LuckUntil = luckUntil, ClicksUntil = clicksUntil },
				PlayerState.OwnedPasses(),
				now,
				serverLuckUntil
			)
		end,
	}
end

return BoostState
