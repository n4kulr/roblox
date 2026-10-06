--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Packets)
local PlayerData = require(script.Parent.Parent.Parent.Parent.Data.PlayerData)
local Config = require(script.Parent.Parent.Parent.Parent.Config.Admin)
local Types = require(script.Parent.Parent.Types)

local Support = {}

function Support.DataOf(context: Types.Context, player: Player): PlayerData.Data?
	return context.Services.DataService:GetData(player)
end

function Support.Reward(target: Player, kind: string, id: string, count: number)
	Packets.AdminReward:FireClient(target, kind, id, math.clamp(math.floor(count), 0, 65535))
end

function Support.Normalize(context: Types.Context, player: Player)
	context.Services.KeyboardService:Normalize(player)
	context.Services.KeyboardService:NotifyBoardChanged(player)
end

function Support.ClampCount(count: number?): number
	return math.clamp(count or 1, 1, Config.MaxGive)
end

function Support.Noun(count: number, singular: string): string
	return if count == 1 then `1 {singular}` else `{count} {singular}s`
end

return Support
