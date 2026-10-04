--!strict

export type SpawnPoint = {
	Part: BasePart,
	Section: number,
}

export type TapPart = {
	Part: BasePart,
	Rest: CFrame,
	Letter: string,
}

export type PopupPart = {
	Part: BasePart,
	Up: CFrame,
	Down: CFrame,
	UpSeconds: number,
	DownSeconds: number,
	Phase: number,
	IsUp: boolean,
}

export type GatePart = {
	Part: BasePart,
	SpeedNeeded: number,
	PushD: number,
}

export type Info = {
	Model: Model,
	Zone: BasePart,
	Kills: { BasePart },
	Checkpoints: { BasePart },
	Returns: { BasePart },
	Taps: { TapPart },
	Popups: { PopupPart },
	Gates: { GatePart },
	Spawns: { SpawnPoint },
}

export type SpawnState = {
	Point: SpawnPoint,
	Pickup: BasePart?,
	Trove: any,
	RespawnAt: number,
}

export type Carrier = {
	KeyId: string,
	Trove: any,
}

export type Track = {
	Character: Model?,
	IsInside: boolean,
	Checkpoint: BasePart?,
	Taps: number,
	Pressed: { [BasePart]: number },
}

return {}
