--!strict

export type SpawnPoint = {
	Part: BasePart,
	Rarities: string,
}

export type Info = {
	Model: Model,
	Zone: BasePart,
	TapKeys: { BasePart },
	Kills: { BasePart },
	Checkpoints: { BasePart },
	Homes: { BasePart },
	Spawns: { SpawnPoint },
	Gates: { BasePart },
	PopUps: { BasePart },
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
	LastKey: BasePart?,
	LastPosition: Vector3?,
	GateToastAt: number,
}

return {}
