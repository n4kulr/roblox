--!strict

local Membership = {}

Membership.CacheSeconds = 60

export type Cache = { [Player]: number }

function Membership.IsMember(cache: Cache, player: Player, groupId: number, now: number): boolean
	local cachedAt = cache[player]
	if cachedAt and now - cachedAt < Membership.CacheSeconds then
		return true
	end
	cache[player] = nil
	local ok, result = pcall(function()
		return player:IsInGroup(groupId)
	end)
	if ok and result == true then
		cache[player] = now
		return true
	end
	return false
end

return Membership
