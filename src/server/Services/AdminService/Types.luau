--!strict

local ServerTypes = require(script.Parent.Parent.Parent.Types)

export type Context = {
	Services: ServerTypes.Registry,
}

export type Command = {
	Name: string,
	Usage: string,
	Summary: string,
	Positional: number,
	OptionalCount: boolean,
	AllowAll: boolean,
	Run: (
		context: Context,
		admin: Player,
		target: Player,
		args: { string },
		count: number?
	) -> (boolean, string),
}

export type Run = (
	context: Context,
	admin: Player,
	target: Player,
	args: { string },
	count: number?
) -> (boolean, string)

export type Builder = {
	Define: (command: Command) -> (),
	Simple: (name: string, usage: string, summary: string, run: Run) -> (),
	WithArgument: (name: string, usage: string, summary: string, run: Run) -> (),
	WithCount: (name: string, usage: string, summary: string, run: Run) -> (),
}

return {}
