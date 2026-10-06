--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)

export type Tier = { Seconds: number, Kind: string, Amount: number, Min: number, Rarity: string }
export type Progress = {
	IsLoaded: boolean,
	States: { string },
	Left: { number },
	ReadyCount: number,
	NextLeft: number?,
}

local Playtime = {}

Playtime.Tiers = GameConfig.Playtime :: { Tier }

function Playtime.Read(player: any, now: number): Progress
	local start = player:GetAttribute("PlaytimeStart")
	local mask = player:GetAttribute("PlaytimeClaimed")
	local isLoaded = type(start) == "number"
	local claimed = if type(mask) == "number" then mask else 0
	local elapsed = if type(start) == "number" then math.max(0, now - start) else 0
	local progress: Progress = { IsLoaded = isLoaded, States = {}, Left = {}, ReadyCount = 0, NextLeft = nil }
	for index, tier in Playtime.Tiers do
		local left = math.max(0, tier.Seconds - elapsed)
		local state = "Locked"
		if math.floor(claimed / 2 ^ (index - 1)) % 2 == 1 then
			state = "Claimed"
		elseif isLoaded and left <= 0 then
			state = "Ready"
			progress.ReadyCount += 1
		elseif isLoaded then
			local soonest = progress.NextLeft
			if soonest == nil or left < soonest then
				progress.NextLeft = left
			end
		end
		progress.States[index] = state
		progress.Left[index] = left
	end
	return progress
end

function Playtime.Name(seconds: number): string
	if seconds < 60 then
		return `{seconds} SEC`
	end
	return `{math.floor(seconds / 60)} MIN`
end

return Playtime
