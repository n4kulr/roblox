--!strict

local Config = require(script.Parent.Parent.Parent.Config.Admin)

export type Environment = {
	IsStudio: boolean,
	CreatorType: Enum.CreatorType,
	CreatorId: number,
	RankInGroup: (player: Player, groupId: number) -> number,
}

local Access = {}

function Access.Check(player: Player, env: Environment, config: typeof(Config)?): boolean
	local settings = config or Config
	if env.IsStudio then
		return true
	end
	if settings.UserIds[player.UserId] then
		return true
	end
	if env.CreatorType == Enum.CreatorType.User then
		return player.UserId == env.CreatorId
	end
	if env.CreatorType == Enum.CreatorType.Group then
		return env.RankInGroup(player, env.CreatorId) >= settings.GroupRank
	end
	return false
end

return Access
