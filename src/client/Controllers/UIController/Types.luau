--!strict

export type Context = {
	Controllers: { [string]: any },
	PlayerGui: PlayerGui,
	Open: (name: string) -> (),
	Close: (name: string) -> (),
	IsOpen: (name: string) -> boolean,
	Toast: (text: string, kind: string?) -> (),
}

export type Screen = {
	Modal: boolean,
	StartsOpen: boolean,
	Open: (self: Screen) -> (),
	Close: (self: Screen) -> (),
	Destroy: (self: Screen) -> (),
}

export type ScreenModule = {
	new: (context: Context) -> Screen,
}

return {}
