--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lifecycle = require(ReplicatedStorage.Lifecycle)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Commands = require(script.Commands)
local Targets = require(script.Targets)
local Types = require(script.Types)

type TroveInstance = typeof(Trove.new())

local allowlist: { [number]: boolean } = {}
local maxArgumentLength = 200
local deniedMessage = "Not allowed"

local AdminService = {
	Name = "AdminService",
	Console = nil :: any,
} :: Lifecycle.System & { Console: any, IsAdmin: any, Execute: any }
local services: { [string]: any } = {}
local context: Types.Context = { Services = services }
local trove: TroveInstance? = nil

local function isAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if allowlist[player.UserId] then
		return true
	end
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end
	return false
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
	player:SetAttribute("IsAdmin", isAdmin(player))
	local serviceTrove = trove :: TroveInstance
	serviceTrove:Connect(player.Chatted, function(message: string)
		handleChat(player, message)
	end)
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
			return Commands.Execute(context, player, command, argument or "")
		end,
		IsAdmin = isAdmin,
	}
	AdminService.Console = admin
	local g = _G :: any
	g.ThockAdmin = admin
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
	services = registry
	context = { Services = registry }
	trove = Trove.new()
end

function AdminService.Start(_self: Lifecycle.System)
	local serviceTrove = trove :: TroveInstance
	serviceTrove:Connect(Players.PlayerAdded, bindPlayer)
	for _, player in Players:GetPlayers() do
		bindPlayer(player)
	end
	Packets.AdminCommand.OnServerInvoke = function(player: Player, command: string, argument: string): string
		if type(command) ~= "string" or type(argument) ~= "string" then
			return "Bad request"
		end
		local _, result =
			execute(player, string.sub(command, 1, 32), string.sub(argument, 1, maxArgumentLength))
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
	if trove then
		trove:Destroy()
		trove = nil
	end
end

return AdminService
