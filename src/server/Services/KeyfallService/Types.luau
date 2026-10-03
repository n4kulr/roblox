--!strict

export type Cap = {
	Part: BasePart,
	KeyId: string,
	IsGolden: boolean,
	LandsAt: number,
	ExpiresAt: number,
	PickableAt: number,
	SpawnedAt: number,
	StartY: number,
	EndY: number,
	IsLanded: boolean,
}

export type Carry = {
	Keys: { string },
	Character: Model,
	Visuals: { BasePart },
	Trove: any,
}

export type Hook = {
	Character: Model,
	Trove: any,
}

export type Arena = {
	Center: Vector3,
	Radius: number,
	SurfaceY: number,
	Trove: any,
}

return {}
