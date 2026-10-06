--!strict

local ServerTypes = require(script.Parent.Parent.Parent.Types)

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
	HoldStarted: { [Player]: number },
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

export type Context = {
	Services: ServerTypes.Registry,
	Prompts: { [Player]: { [number]: PromptRecord } },
	Carriers: { [Player]: Carrier },
	Locks: { [number]: Lock },
	LockedUntil: { [number]: number },
	KnockReadyAt: { [Player]: number },
	Ragdolls: { [Player]: { Trove: any } },
	Drops: { [BasePart]: Drop },
	SyncPrompts: (owner: Player) -> (),
	Knock: (victim: Player, thief: Player) -> (),
}

return {}
