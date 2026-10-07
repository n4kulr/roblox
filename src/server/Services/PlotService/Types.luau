--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FloorGrid = require(ReplicatedStorage.Rules.FloorGrid)
local Signal = require(ReplicatedStorage.Packages.Signal)
local OwnerSign = require(script.Parent.Parent.Parent.Utils.OwnerSign)
local ServerTypes = require(script.Parent.Parent.Parent.Types)

export type Defense = {
	IsActive: boolean,
	LockedUntil: number,
	CooldownUntil: number,
	Lasers: Folder?,
	Anchor: BasePart?,
	Label: TextLabel?,
	ShownSeconds: number,
	Status: string,
	PublishedLocked: number,
	PublishedCooldown: number,
}

export type CapVisual = {
	State: string,
	Billboard: BillboardGui?,
	Amount: TextLabel?,
	Surface: SurfaceGui,
	Rim: GuiObject,
	Stroke: UIStroke,
	Plus: TextLabel?,
	Letter: TextLabel?,
	Lock: ImageLabel?,
	Decor: Model?,
	Skin: BasePart?,
}

export type Frame = {
	Left: number,
	Right: number,
	Front: number,
	Back: number,
	GateLeft: number,
	GateRight: number,
}

export type PlotInfo = {
	Model: Model,
	Base: BasePart,
	RollKey: BasePart,
	Board: BasePart,
	Caps: { BasePart },
	FloorCaps: { BasePart },
	Visuals: { [BasePart]: CapVisual },
	Layout: FloorGrid.Layout,
	Owner: Player?,
	Placeholder: boolean,
	Walkway: BasePart?,
	Sign: OwnerSign.Display?,
	GlassWalls: Folder?,
	GlassParts: { [string]: BasePart },
	FenceRise: number,
	Frame: Frame?,
	WallHeight: number,
	WallLevel: number,
	Defense: Defense?,
}

export type Context = {
	Services: ServerTypes.Registry,
	Plots: { PlotInfo },
	ByPlayer: { [Player]: PlotInfo },
	PlayerTroves: { [Player]: any },
	ActiveLocks: { [PlotInfo]: boolean },
	LastZap: { [Player]: number },
	RespawnPoints: { [Player]: CFrame },
	SweepThread: thread?,
	HasWarnedSlots: boolean,
	LockChanged: Signal.Signal<Player>,
	PlotAssigned: Signal.Signal<Player>,
}

return {}
