--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharmConfig = require(ReplicatedStorage.Config.Charms)
local Eggs = require(ReplicatedStorage.Config.Eggs)
local Keys = require(ReplicatedStorage.Config.Keys)
local Packets = require(ReplicatedStorage.Packets)
local Upgrades = require(ReplicatedStorage.Config.Upgrades)
local Boosts = require(ReplicatedStorage.Rules.Boosts)
local Charms = require(ReplicatedStorage.Rules.Charms)
local Stats = require(ReplicatedStorage.Rules.Stats)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local PlayerData = require(script.Parent.Parent.Parent.Data.PlayerData)
local Rewards = require(script.Parent.Parent.Parent.Utils.Rewards)
local Amount = require(script.Parent.Amount)
local Targets = require(script.Parent.Targets)
local Types = require(script.Parent.Types)

type Context = Types.Context
type Command = Types.Command
type Run = (
	context: Context,
	admin: Player,
	target: Player,
	args: { string },
	count: number?
) -> (boolean, string)

local maxCash = 9007199254740991
local maxMoneyValue = 1e15
local maxGive = 200
local maxStack = 1000
local maxRolls = 1000000000
local maxRevealed = 3
local protectedFields: { [string]: boolean } = { SchemaVersion = true, Receipts = true, LastSeenAt = true }

local Commands = {}
local registry: { [string]: Command } = {}
local ordered: { Command } = {}

local function dataOf(context: Context, player: Player): PlayerData.Data?
	return context.Services.DataService:GetData(player) :: PlayerData.Data?
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, inner in value do
		copy[key] = deepCopy(inner)
	end
	return copy
end

local function reward(target: Player, kind: string, id: string, count: number)
	Packets.AdminReward:FireClient(target, kind, id, math.clamp(math.floor(count), 0, 65535))
end

local function normalize(context: Context, player: Player)
	context.Services.KeyboardService:Normalize(player)
	context.Services.KeyboardService.BoardChanged:Fire(player)
end

local function addClicks(context: Context, player: Player, requested: number): number
	local services = context.Services
	services.KeyboardService:Settle(player)
	local data = dataOf(context, player)
	if not data then
		return 0
	end
	local amount = math.min(requested, maxCash - data.Cash)
	if amount <= 0 or not Rewards.AddClicks(player, services, amount) then
		return 0
	end
	return amount
end

local function setClicks(context: Context, player: Player, value: number): boolean
	local services = context.Services
	services.KeyboardService:Settle(player)
	local data = dataOf(context, player)
	if not data then
		return false
	end
	local target = math.clamp(math.floor(value), 0, maxCash)
	local gained = target - data.Cash
	services.DataService:Set(player, { "Cash" }, target)
	if gained > 0 then
		services.DataService:Set(player, { "TotalEarned" }, data.TotalEarned + gained)
	end
	services.DataService:RequestSave(player)
	return true
end

local function squash(text: string): string
	return string.lower((string.gsub(text, "[%s_%-]", "")))
end

local function findKey(text: string): Keys.Key?
	local wanted = squash(text)
	for _, key in Keys.Catalog do
		if squash(key.Id) == wanted or squash(key.Name) == wanted then
			return key
		end
	end
	return nil
end

local function findRarity(text: string): string?
	local wanted = squash(text)
	for _, rarity in Keys.Rarities do
		if squash(rarity.Name) == wanted then
			return rarity.Name
		end
	end
	return nil
end

local function findEgg(text: string): Eggs.Egg?
	local wanted = squash(text)
	for _, egg in Eggs.Catalog do
		if squash(egg.Id) == wanted or squash(egg.Name) == wanted then
			return egg
		end
	end
	return nil
end

local function findPet(text: string): CharmConfig.Charm?
	local wanted = squash(text)
	for _, charm in CharmConfig.Catalog do
		if squash(charm.Id) == wanted or squash(charm.Name) == wanted then
			return charm
		end
	end
	return nil
end

local function clampCount(count: number?): number
	return math.clamp(count or 1, 1, maxGive)
end

local function noun(count: number, singular: string): string
	return if count == 1 then `1 {singular}` else `{count} {singular}s`
end

local function define(command: Command)
	registry[command.Name] = command
	table.insert(ordered, command)
end

local function simple(name: string, usage: string, summary: string, run: Run)
	define({
		Name = name,
		Usage = usage,
		Summary = summary,
		Positional = 0,
		OptionalCount = false,
		AllowAll = true,
		Run = run,
	})
end

local function withArgument(name: string, usage: string, summary: string, run: Run)
	define({
		Name = name,
		Usage = usage,
		Summary = summary,
		Positional = 1,
		OptionalCount = false,
		AllowAll = true,
		Run = run,
	})
end

local function withCount(name: string, usage: string, summary: string, run: Run)
	define({
		Name = name,
		Usage = usage,
		Summary = summary,
		Positional = 1,
		OptionalCount = true,
		AllowAll = true,
		Run = run,
	})
end

withArgument(
	"money",
	"money <amount> [player|all]",
	"Add Clicks (1k 2.5m 1b 1t)",
	function(context, _admin, target, args)
		local amount = Amount.Parse(args[1])
		if not amount or amount < 1 then
			return false, "Bad amount"
		end
		local added = addClicks(context, target, amount)
		if added <= 0 then
			return false, "Clicks are already maxed"
		end
		reward(target, "Cash", string.format("%d", added), 1)
		return true, `Added {NumberFormat.Compact(added)} Clicks`
	end
)

withArgument(
	"setmoney",
	"setmoney <amount> [player|all]",
	"Set Clicks to an exact amount",
	function(context, _admin, target, args)
		local amount = Amount.Parse(args[1])
		if not amount then
			return false, "Bad amount"
		end
		if not setClicks(context, target, amount) then
			return false, "Data not loaded"
		end
		return true, `Clicks set to {NumberFormat.Compact(math.min(amount, maxCash))}`
	end
)

simple("resetmoney", "resetmoney [player|all]", "Set Clicks to 0", function(context, _admin, target)
	if not setClicks(context, target, 0) then
		return false, "Data not loaded"
	end
	return true, "Clicks reset to 0"
end)

simple("maxmoney", "maxmoney [player|all]", "Set Clicks to 1 quadrillion", function(context, _admin, target)
	local before = dataOf(context, target)
	local previous = if before then before.Cash else 0
	if not setClicks(context, target, maxMoneyValue) then
		return false, "Data not loaded"
	end
	if maxMoneyValue > previous then
		reward(target, "Cash", string.format("%d", maxMoneyValue - previous), 1)
	end
	return true, `Clicks set to {NumberFormat.Compact(maxMoneyValue)}`
end)

withArgument(
	"income",
	"income <seconds> [player|all]",
	"Grant N seconds of current income",
	function(context, _admin, target, args)
		local seconds = Amount.Parse(args[1])
		if not seconds or seconds < 1 then
			return false, "Bad seconds"
		end
		local rate = context.Services.KeyboardService:GetRate(target)
		local earned = math.floor(rate * seconds)
		if earned < 1 then
			return false, "No income to grant"
		end
		local added = addClicks(context, target, earned)
		if added <= 0 then
			return false, "Clicks are already maxed"
		end
		reward(target, "Cash", string.format("%d", added), 1)
		return true, `Granted {NumberFormat.Compact(added)} Clicks ({seconds}s of income)`
	end
)

withArgument(
	"rolls",
	"rolls <n> [player|all]",
	"Add to the roll counter",
	function(context, _admin, target, args)
		local amount = Amount.Parse(args[1])
		if not amount or amount < 1 then
			return false, "Bad amount"
		end
		local data = dataOf(context, target)
		if not data then
			return false, "Data not loaded"
		end
		local total = math.min(data.Rolls + amount, maxRolls)
		context.Services.DataService:Set(target, { "Rolls" }, total)
		context.Services.DataService:RequestSave(target)
		return true, `Rolls now {NumberFormat.Compact(total)}`
	end
)

simple("golden", "golden [player|all]", "Make the next roll golden", function(context, _admin, target)
	local data = dataOf(context, target)
	if not data then
		return false, "Data not loaded"
	end
	local every = Stats.GoldenEvery(data.Upgrades, Charms.Effects(data.EquippedCharms).GoldenReduction)
	context.Services.DataService:Set(target, { "GoldenProgress" }, math.max(0, every - 1))
	return true, "Next roll will be golden"
end)

withCount(
	"givekey",
	"givekey <keyId|rarity> [count] [player|all]",
	"Give a key by id, or a random key of a rarity",
	function(context, _admin, target, args, count)
		local services = context.Services
		local exact = findKey(args[1])
		local rarity = if exact then nil else findRarity(args[1])
		local pool: { Keys.Key } = if rarity then Keys.ByRarity[rarity] else {}
		if not exact and #pool == 0 then
			return false, `Unknown key or rarity "{args[1]}"`
		end
		local random = Random.new()
		local given: { [string]: number } = {}
		local revealed: { string } = {}
		local total = 0
		for _ = 1, clampCount(count) do
			local key = exact or pool[random:NextInteger(1, #pool)]
			if services.KeyboardService:AddKey(target, key.Id) then
				given[key.Id] = (given[key.Id] or 0) + 1
				total += 1
				if #revealed < maxRevealed then
					table.insert(revealed, key.Id)
				end
			end
		end
		local data = dataOf(context, target)
		local names: { string } = {}
		for keyId, amount in given do
			if data then
				services.DataService:Set(
					target,
					{ "Discovered", keyId },
					(data.Discovered[keyId] or 0) + amount
				)
			end
			table.insert(names, `{amount}x {Keys.ById[keyId].Name}`)
		end
		if #names == 0 then
			return false, "No keys were given"
		end
		table.sort(names)
		services.DataService:RequestSave(target)
		reward(target, "Key", table.concat(revealed, ","), total)
		return true, `Gave {table.concat(names, ", ")}`
	end
)

withCount(
	"giveegg",
	"giveegg <eggId> [count] [player|all]",
	"Give eggs (bypasses the bag cap)",
	function(context, _admin, target, args, count)
		local egg = findEgg(args[1])
		if not egg then
			return false, `Unknown egg "{args[1]}"`
		end
		local data = dataOf(context, target)
		if not data then
			return false, "Data not loaded"
		end
		local bag = table.clone(data.EggInventory)
		local have = bag[egg.Id] or 0
		local added = math.min(clampCount(count), maxStack - have)
		if added < 1 then
			return false, `Already holding the maximum {egg.Name}`
		end
		bag[egg.Id] = have + added
		context.Services.DataService:Set(target, { "EggInventory" }, bag)
		context.Services.EggService:Sync(target)
		context.Services.DataService:RequestSave(target)
		reward(target, "Egg", egg.Id, added)
		return true, `Gave {added}x {egg.Name}`
	end
)

withCount(
	"givepet",
	"givepet <petId> [count] [player|all]",
	"Give pets",
	function(context, _admin, target, args, count)
		local pet = findPet(args[1])
		if not pet then
			return false, `Unknown pet "{args[1]}"`
		end
		local data = dataOf(context, target)
		if not data then
			return false, "Data not loaded"
		end
		local have = data.Charms[pet.Id] or 0
		local added = math.min(clampCount(count), maxStack - have)
		if added < 1 then
			return false, `Already holding the maximum {pet.Name}`
		end
		context.Services.DataService:Set(target, { "Charms", pet.Id }, have + added)
		context.Services.EggService:Sync(target)
		context.Services.DataService:RequestSave(target)
		reward(target, "Pet", pet.Id, added)
		return true, `Gave {added}x {pet.Name}`
	end
)

simple("removepets", "removepets [player|all]", "Remove every pet", function(context, _admin, target)
	local services = context.Services
	local data = dataOf(context, target)
	if not data then
		return false, "Data not loaded"
	end
	local removed = 0
	for _, owned in data.Charms do
		removed += owned
	end
	services.DataService:Set(target, { "Charms" }, {})
	services.DataService:Set(target, { "EquippedCharms" }, {})
	services.EggService:Sync(target)
	services.DataService:RequestSave(target)
	return true, `Removed {noun(removed, "pet")}`
end)

simple("readyeggs", "readyeggs [player|all]", "Finish every placed egg", function(context, _admin, target)
	local count = context.Services.EggService:ReadyEggs(target)
	return true, `Readied {noun(count, "egg")}`
end)

simple("hatchall", "hatchall [player|all]", "Hatch every placed egg", function(context, _admin, target)
	local count = #context.Services.EggService:HatchAll(target)
	return true, `Hatched {noun(count, "egg")}`
end)

local function setAllUpgrades(context: Context, target: Player, toMax: boolean): boolean
	local replica = context.Services.DataService:GetReplica(target)
	if not replica then
		return false
	end
	context.Services.KeyboardService:Settle(target)
	local levels: { [string]: number } = {}
	for _, upgrade in Upgrades.List do
		levels[upgrade.Id] = if toMax then upgrade.MaxLevel else 0
	end
	replica:SetValues({ "Upgrades" }, levels)
	normalize(context, target)
	context.Services.DataService:RequestSave(target)
	return true
end

simple("maxupgrades", "maxupgrades [player|all]", "Max every upgrade", function(context, _admin, target)
	if not setAllUpgrades(context, target, true) then
		return false, "Data not loaded"
	end
	return true, "All upgrades maxed"
end)

simple("resetupgrades", "resetupgrades [player|all]", "Reset every upgrade", function(context, _admin, target)
	if not setAllUpgrades(context, target, false) then
		return false, "Data not loaded"
	end
	return true, "All upgrades reset"
end)

simple(
	"rebirth",
	"rebirth [player|all]",
	"Force a rebirth, ignoring the cost",
	function(context, _admin, target)
		if not context.Services.RebirthService:Force(target) then
			return false, "Rebirth failed"
		end
		local data = dataOf(context, target)
		return true, `Rebirthed (now {if data then data.Rebirths else 0})`
	end
)

local function potion(name: string, label: string, field: string)
	withArgument(
		name,
		`{name} <minutes> [player|all]`,
		`Extend the {label} potion`,
		function(context, _admin, target, args)
			local minutes = Amount.Parse(args[1])
			if not minutes or minutes < 1 then
				return false, "Bad minutes"
			end
			if not Rewards.ExtendPotion(target, context.Services, field, minutes * 60) then
				return false, "Data not loaded"
			end
			local data = dataOf(context, target)
			local boosts: { [string]: number } = if data then data.Boosts :: any else {}
			local left = Boosts.Remaining(boosts[field] or 0, os.time())
			return true, `{label} potion: {math.floor(left / 60)}m left`
		end
	)
end

potion("luckpotion", "Luck", "LuckUntil")
potion("clickspotion", "Clicks", "ClicksUntil")

define({
	Name = "resetdata",
	Usage = "resetdata confirm [player]",
	Summary = "Wipe all data to the template",
	Positional = 1,
	OptionalCount = false,
	AllowAll = false,
	Run = function(context, _admin, target, args)
		if string.lower(args[1]) ~= "confirm" then
			return false, "Type resetdata confirm to wipe data"
		end
		local services = context.Services
		if not dataOf(context, target) then
			return false, "Data not loaded"
		end
		for field, value in PlayerData.Template :: any do
			if not protectedFields[field] then
				services.DataService:Set(target, { field }, deepCopy(value))
			end
		end
		services.DataService:Set(target, { "IncomeAt" }, os.time())
		normalize(context, target)
		services.EggService:Sync(target)
		services.DataService:RequestSave(target)
		return true, "Data reset"
	end,
})

function Commands.Has(name: string): boolean
	local lowered = string.lower(name)
	return registry[lowered] ~= nil or lowered == "help"
end

function Commands.Help(): string
	local lines: { string } = {}
	for _, command in ordered do
		table.insert(lines, `/{command.Usage} - {command.Summary}`)
	end
	table.insert(lines, "/help - This list")
	return table.concat(lines, "\n")
end

local function split(text: string): { string }
	local tokens: { string } = {}
	for token in string.gmatch(text, "%S+") do
		table.insert(tokens, token)
	end
	return tokens
end

function Commands.Execute(context: Context, admin: Player, name: string, argument: string): (boolean, string)
	local lowered = string.lower((string.gsub(name, "^/", "")))
	if lowered == "help" then
		return true, Commands.Help()
	end
	local command = registry[lowered]
	if not command then
		return false, `Unknown command "{name}". Try help`
	end
	local tokens = split(argument)
	local cursor = 1
	local args: { string } = {}
	for _ = 1, command.Positional do
		if tokens[cursor] == nil then
			return false, `Usage: /{command.Usage}`
		end
		table.insert(args, tokens[cursor])
		cursor += 1
	end
	local count: number? = nil
	if command.OptionalCount and tokens[cursor] ~= nil then
		local parsed = Amount.Parse(tokens[cursor])
		if parsed then
			count = parsed
			cursor += 1
		end
	end
	local query = tokens[cursor]
	if query ~= nil then
		cursor += 1
	end
	if tokens[cursor] ~= nil then
		return false, `Usage: /{command.Usage}`
	end
	local targets, problem = Targets.Resolve(admin, query, command.AllowAll)
	if problem then
		return false, problem
	end
	if #targets == 0 then
		return false, "No players to target"
	end
	local succeeded = 0
	local firstMessage = ""
	local firstFailure = ""
	for _, target in targets do
		if dataOf(context, target) then
			local ok, message = command.Run(context, admin, target, args, count)
			if ok then
				succeeded += 1
				if firstMessage == "" then
					firstMessage = message
				end
			elseif firstFailure == "" then
				firstFailure = message
			end
		elseif firstFailure == "" then
			firstFailure = "Data not loaded"
		end
	end
	if succeeded == 0 then
		return false, firstFailure
	end
	if #targets == 1 then
		return true, if targets[1] == admin then firstMessage else `{firstMessage} ({targets[1].Name})`
	end
	return true, `{firstMessage} ({succeeded}/{#targets} players)`
end

return Commands
