--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldNames = require(ReplicatedStorage.Config.WorldNames)
local Lifecycle = require(ReplicatedStorage.Lifecycle)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Config = require(script.Parent.Parent.Config.Admin)
local Access = require(script.Access)
local Commands = require(script.Commands)
local Targets = require(script.Targets)
local Types = require(script.Types)
local ServerTypes = require(script.Parent.Parent.Types)

type TroveInstance = typeof(Trove.new())

local verdicts: { [Player]: boolean } = {}
local deniedMessage = "Not allowed"
local adminAttribute = WorldNames.Attributes.IsAdmin
local developerAttribute = WorldNames.Attributes.IsDeveloper

local AdminService = {
	Name = "AdminService",
	Console = nil :: any,
} :: Lifecycle.System & { Console: any, IsAdmin: any, Execute: any }
local services: ServerTypes.Registry = nil :: any
local context: Types.Context = { Services = services }
local trove: TroveInstance? = nil

local function rankInGroup(player: Player, groupId: number): number
	local ok, rank = pcall(function()
		return player:GetRankInGroup(groupId)
	end)
	return if ok and type(rank) == "number" then rank else 0
end

local function isAdmin(player: Player): boolean
	local known = verdicts[player]
	if known ~= nil then
		return known
	end
	local verdict = Access.Check(player, {
		IsStudio = RunService:IsStudio(),
		CreatorType = game.CreatorType,
		CreatorId = game.CreatorId,
		RankInGroup = rankInGroup,
	})
	verdicts[player] = verdict
	return verdict
end

local function execute(player: Player, command: string, argument: string): (boolean, string)
	if not isAdmin(player) then
		return false, deniedMessage
	end
	return Commands.Execute(context, player, command, argument)
end

local function handleChat(player: Player, message: string)
	local command, argument = string.match(message, "^/(%S+)%s*(.*)$")
	if not command or not Commands.Has(command) or not isAdmin(player) then
		return
	end
	local ok, result = execute(player, command, argument or "")
	local prefix = `[Admin] {player.Name} /{string.lower(command)}`
	if ok then
		print(`{prefix}: {result}`)
	else
		warn(`{prefix} failed: {result}`)
	end
end

local function bindPlayer(player: Player)
	local serviceTrove = trove :: TroveInstance
	serviceTrove:Connect(player.Chatted, function(message: string)
		handleChat(player, message)
	end)
	local admin = isAdmin(player)
	player:SetAttribute(adminAttribute, admin)
	player:SetAttribute(developerAttribute, admin)
end

local function readyTargets(targets: { Player }): number
	local total = 0
	for _, player in targets do
		total += services.EggService:ReadyEggs(player)
	end
	return total
end

local function hatchTargets(targets: { Player }): number
	local total = 0
	for _, player in targets do
		total += #services.EggService:HatchAll(player)
	end
	return total
end

local function targetsFrom(target: any): { Player }
	if target == nil then
		return Players:GetPlayers()
	end
	if type(target) == "string" then
		local found = Targets.Resolve(Players:GetPlayers()[1], target, true)
		return found
	end
	if typeof(target) == "Instance" and target:IsA("Player") then
		return { target }
	end
	return {}
end

local function installConsole()
	local admin = {
		ReadyEggs = function(target: any): number
			return readyTargets(targetsFrom(target))
		end,
		HatchAll = function(target: any): number
			return hatchTargets(targetsFrom(target))
		end,
		Run = function(player: Player, command: string, argument: string?): (boolean, string)
			return execute(player, command, argument or "")
		end,
		IsAdmin = isAdmin,
	}
	AdminService.Console = admin
	if RunService:IsStudio() then
		local g = _G :: any
		g.ThockAdmin = admin
	end
end

function AdminService.IsAdmin(_self: any, player: Player): boolean
	return isAdmin(player)
end

function AdminService.Execute(
	_self: any,
	player: Player,
	command: string,
	argument: string
): (boolean, string)
	return execute(player, command, argument)
end

function AdminService.Init(_self: Lifecycle.System, registry: { [string]: any })
	services = registry :: any
	context = { Services = registry :: any }
	trove = Trove.new()
end

function AdminService.Start(_self: Lifecycle.System)
	local serviceTrove = trove :: TroveInstance
	serviceTrove:Connect(Players.PlayerAdded, bindPlayer)
	serviceTrove:Connect(Players.PlayerRemoving, function(player: Player)
		verdicts[player] = nil
	end)
	for _, player in Players:GetPlayers() do
		bindPlayer(player)
	end
	Packets.AdminCommand.OnServerInvoke = function(player: Player, command: string, argument: string): string
		if type(command) ~= "string" or type(argument) ~= "string" then
			return "Bad request"
		end
		local _, result = execute(
			player,
			string.sub(command, 1, Config.MaxCommandLength),
			string.sub(argument, 1, Config.MaxArgumentLength)
		)
		return result
	end
	installConsole()
end

function AdminService.Destroy(_self: Lifecycle.System)
	Packets.AdminCommand.OnServerInvoke = nil
	AdminService.Console = nil
	local g = _G :: any
	if g.ThockAdmin then
		g.ThockAdmin = nil
	end
	table.clear(verdicts)
	if trove then
		trove:Destroy()
		trove = nil
	end
end

return AdminService
