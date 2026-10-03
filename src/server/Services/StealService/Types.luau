--!strict

export type Carrier = {
	KeyId: string,
	VictimUserId: number,
	VictimName: string,
	Slot: number,
	StartedAt: number,
	Trove: any,
}

export type PromptRecord = {
	Prompt: ProximityPrompt,
	Trove: any,
	Holding: { [Player]: string },
}

return {}
