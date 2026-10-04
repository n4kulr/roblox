--!strict

export type SpawnPoint = {
	Part: BasePart,
	Stage: number,
}

export type Info = {
	Model: Model,
	Zone: BasePart,
	Kills: { BasePart },
	Checkpoints: { BasePart },
	Returns: { BasePart },
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
}

return {}
