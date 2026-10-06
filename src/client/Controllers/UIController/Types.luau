--!strict

local Economy = require(script.Parent.Economy)

export type ToastKind = "Good" | "Bad" | "Info" | "Gold"

export type PetState = {
	Owned: () -> { [string]: number },
	Total: () -> number,
	IsLoaded: () -> boolean,
	Subscribe: (listener: () -> ()) -> () -> (),
}

export type Context = {
	Controllers: { [string]: any },
	PlayerGui: PlayerGui,
	Open: (name: string) -> (),
	Close: (name: string) -> (),
	IsOpen: (name: string) -> boolean,
	Toast: (text: string, kind: ToastKind?) -> (),
	Economy: Economy.Tracker?,
	Pets: PetState?,
	SetAnchor: ((name: string, anchor: GuiObject?) -> ())?,
	GetAnchor: ((name: string) -> GuiObject?)?,
}

export type Screen = {
	Modal: boolean,
	StartsOpen: boolean,
	CanOpen: ((self: Screen) -> boolean)?,
	Open: (self: Screen) -> (),
	Close: (self: Screen) -> (),
	Destroy: (self: Screen) -> (),
}

export type ScreenModule = {
	new: (context: Context) -> Screen,
}

return {}
