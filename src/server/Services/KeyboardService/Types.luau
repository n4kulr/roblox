--!strict

local ServerTypes = require(script.Parent.Parent.Parent.Types)

export type Context = {
	Services: ServerTypes.Registry,
}

return {}
