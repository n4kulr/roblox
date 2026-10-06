--!strict

local Players = game:GetService("Players")

local Targets = {}

local function find(query: string): Player?
	local lowered = string.lower(query)
	for _, player in Players:GetPlayers() do
		if string.lower(player.Name) == lowered or string.lower(player.DisplayName) == lowered then
			return player
		end
	end
	for _, player in Players:GetPlayers() do
		if
			string.find(string.lower(player.Name), lowered, 1, true)
			or string.find(string.lower(player.DisplayName), lowered, 1, true)
		then
			return player
		end
	end
	return nil
end

function Targets.Resolve(admin: Player, query: string?, allowAll: boolean): ({ Player }, string?)
	if query == nil or query == "" then
		return { admin }, nil
	end
	local lowered = string.lower(query)
	if lowered == "me" or lowered == "self" then
		return { admin }, nil
	end
	if lowered == "all" then
		if not allowAll then
			return {}, "This command cannot target all players"
		end
		return Players:GetPlayers(), nil
	end
	local player = find(query)
	if player then
		return { player }, nil
	end
	return {}, `No player matches "{query}"`
end

return Targets
