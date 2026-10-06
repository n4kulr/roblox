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

return {}
