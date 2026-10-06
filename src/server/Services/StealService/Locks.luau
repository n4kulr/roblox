--!strict

local Players = game:GetService("Players")
local Types = require(script.Parent.Types)

local Locks = {}

function Locks.Release(context: Types.Context, victimUserId: number, thief: Player)
	local lock = context.Locks[victimUserId]
	if not lock or lock.Thief ~= thief or context.Carriers[thief] then
		return
	end
	context.Locks[victimUserId] = nil
	local victim = Players:GetPlayerByUserId(victimUserId)
	if victim and context.Prompts[victim] then
		context.SyncPrompts(victim)
	end
end

return Locks
