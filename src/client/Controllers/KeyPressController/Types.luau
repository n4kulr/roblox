--!strict

export type CapState = {
	Part: BasePart,
	Rest: CFrame,
	LastPress: number,
	Tween: Tween?,
	Held: boolean,
	RaiseToken: number?,
}

export type PlotState = {
	Model: Model,
	Base: BasePart?,
	Columns: number?,
	Rows: number?,
	Caps: { [number]: CapState },
}

export type CosmeticState = {
	Model: Instance,
	Frame: CFrame,
	Pitch: number,
	Height: number,
	Caps: { [number]: CapState },
}

export type Registry = {
	Plots: { [Model]: PlotState },
	StandingOn: { [Player]: CapState },
	Cosmetic: CosmeticState?,
}

return {}
