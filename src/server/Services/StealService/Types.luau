--!strict

export type Carrier = {
	KeyId: string,
	VictimUserId: number,
	VictimName: string,
	Slot: number,
	StartedAt: number,
	KnockPrompt: ProximityPrompt?,
	Trove: any,
}

export type PromptRecord = {
	Prompt: ProximityPrompt,
	Trove: any,
	Holding: { [Player]: string },
}

export type Lock = {
	Thief: Player,
	Slot: number,
}

export type Drop = {
	KeyId: string,
	OwnerUserId: number,
	Slot: number,
	ThiefName: string,
	Part: BasePart,
	Prompt: ProximityPrompt,
	Trove: any,
}

return {}
