--!strict

local Amount = require(script.Parent.Amount)
local Targets = require(script.Parent.Targets)
local Types = require(script.Parent.Types)
local Danger = require(script.Danger)
local Items = require(script.Items)
local Money = require(script.Money)
local Progress = require(script.Progress)
local Support = require(script.Support)

type Context = Types.Context
type Command = Types.Command

local Commands = {}
local registry: { [string]: Command } = {}
local ordered: { Command } = {}

local function define(command: Command)
	registry[command.Name] = command
	table.insert(ordered, command)
end

local function declare(positional: number, hasCount: boolean): (string, string, string, Types.Run) -> ()
	return function(name: string, usage: string, summary: string, run: Types.Run)
		define({
			Name = name,
			Usage = usage,
			Summary = summary,
			Positional = positional,
			OptionalCount = hasCount,
			AllowAll = true,
			Run = run,
		})
	end
end

local builder: Types.Builder = {
	Define = define,
	Simple = declare(0, false),
	WithArgument = declare(1, false),
	WithCount = declare(1, true),
}

Money.Register(builder)
Progress.Register(builder)
Items.Register(builder)
Danger.Register(builder)

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
		if Support.DataOf(context, target) then
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
