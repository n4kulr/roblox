--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FloorGrid = require(ReplicatedStorage.Rules.FloorGrid)
local OwnerSign = require(script.Parent.Parent.Parent.Utils.OwnerSign)

export type Defense = {
	Pad: BasePart,
	Prompt: ProximityPrompt,
	IsActive: boolean,
	LockedUntil: number,
	CooldownUntil: number,
	Lasers: Folder?,
	Anchor: BasePart?,
	Label: TextLabel?,
	ShownSeconds: number,
	Status: string,
}

export type PlotInfo = {
	Model: Model,
	Base: BasePart,
	RollKey: BasePart,
	Board: BasePart,
	Caps: { BasePart },
	FloorCaps: { BasePart },
	Layout: FloorGrid.Layout,
	Owner: Player?,
	Placeholder: boolean,
	Walkway: BasePart?,
	Sign: OwnerSign.Display?,
	Walls: Folder?,
	WallLevel: number,
	Defense: Defense?,
}

return {}
