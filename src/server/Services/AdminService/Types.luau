--!strict

export type Context = {
	Services: { [string]: any },
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
