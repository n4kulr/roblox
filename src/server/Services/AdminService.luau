--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lifecycle = require(ReplicatedStorage.Lifecycle)
local Trove = require(ReplicatedStorage.Packages.Trove)

type TroveInstance = typeof(Trove.new())

local allowlist: { [number]: boolean } = {}

local AdminService = {
	Name = "AdminService",
	Console = nil :: any,
} :: Lifecycle.System & { Console: any }
local services: { [string]: any } = {}
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

local function findPlayer(query: string): Player?
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

local function resolveTargets(arg: string?): { Player }
	if arg == nil or arg == "" or string.lower(arg) == "all" then
		return Players:GetPlayers()
	end
	local player = findPlayer(arg)
	if player then
		return { player }
	end
	return {}
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
		return resolveTargets(target)
	end
	if typeof(target) == "Instance" and target:IsA("Player") then
		return { target }
	end
	return {}
end

local function handleChat(player: Player, message: string)
	if not isAdmin(player) then
		return
	end
	local command, arg = string.match(message, "^/(%S+)%s*(.*)$")
	if not command then
		return
	end
	command = string.lower(command)
	local argument = if arg == nil or arg == "" then nil else arg
	if command ~= "readyeggs" and command ~= "hatchall" then
		return
	end
	local targets = resolveTargets(argument)
	if #targets == 0 then
		print(`[Admin] {player.Name}: no player matched`)
		return
	end
	if command == "readyeggs" then
		local count = readyTargets(targets)
		print(`[Admin] {player.Name}: ready {count} egg(s) for {#targets} player(s)`)
		return
	end
	local count = hatchTargets(targets)
	print(`[Admin] {player.Name}: hatched {count} egg(s) for {#targets} player(s)`)
end

local function bindPlayer(player: Player)
	local serviceTrove = trove :: TroveInstance
	serviceTrove:Connect(player.Chatted, function(message: string)
		handleChat(player, message)
	end)
end

local function installConsole()
	local admin = {
		ReadyEggs = function(target: any): number
			return readyTargets(targetsFrom(target))
		end,
		HatchAll = function(target: any): number
			return hatchTargets(targetsFrom(target))
		end,
		IsAdmin = isAdmin,
	}
	AdminService.Console = admin
	local g = _G :: any
	g.ThockAdmin = admin
end

function AdminService.Init(_self: Lifecycle.System, registry: { [string]: any })
	services = registry
	trove = Trove.new()
end

function AdminService.Start(_self: Lifecycle.System)
	local serviceTrove = trove :: TroveInstance
	serviceTrove:Connect(Players.PlayerAdded, bindPlayer)
	for _, player in Players:GetPlayers() do
		bindPlayer(player)
	end
	installConsole()
end

function AdminService.Destroy(_self: Lifecycle.System)
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
