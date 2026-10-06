--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Keys = require(ReplicatedStorage.Config.Keys)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Viewport = require(script.Parent.Parent.Parent.UIController.Viewport)
local ResultSlots = require(script.Parent.Parent.ResultSlots)

type TroveInstance = typeof(Trove.new())

export type Payload = {
	Key: Keys.Key,
	KeyId: string?,
	Rarity: Keys.Rarity,
	IsGolden: boolean,
}

export type Role = "Rail" | "Fading" | "Common"

export type FadeEntry = {
	Target: any,
	Property: string,
	Base: number,
}

export type Piece = {
	Frame: Frame,
	Active: boolean,
	X: number,
	Y: number,
	VX: number,
	VY: number,
	Rotation: number,
	Spin: number,
	Age: number,
	Life: number,
}

export type View = {
	Holder: Frame,
	Scale: UIScale,
	GoldFrame: Frame,
	Card: Frame,
	Face: Frame,
	Model: Viewport.Handle,
	ModelKey: string,
	Name: TextLabel,
	Shimmer: Frame,
	ShimmerGradient: UIGradient,
	Row: Frame,
	RarityChip: Frame,
	RarityLabel: TextLabel,
	IncomeChip: Frame,
	IncomeLabel: TextLabel,
	Banner: TextLabel,
	BannerScale: UIScale,
	Burst: Frame,
	BurstEcho: Frame,
	Fades: { FadeEntry },
	Tweens: { Tween },
	Role: Role?,
	Slot: ResultSlots.Slot,
	Width: number,
	Rank: number,
	Age: number,
	Token: number,
	FadeElapsed: number,
	FadeSeconds: number,
	IsFading: boolean,
	Alpha: number,
}

export type ResultCards = {
	_trove: TroveInstance,
	_isLowGraphics: () -> boolean,
	_gui: ScreenGui,
	_root: Frame,
	_scale: UIScale?,
	_views: { View },
	_rail: View?,
	_common: View?,
	_pieces: { Piece },
	_confetti: Frame,
	_flash: Frame,
	_flashTween: Tween?,
	_humanoid: Humanoid?,
	_shakeLeft: number,
	_shakeTotal: number,
	_shakeStrength: number,
	_destroyed: boolean,
	Show: (self: ResultCards, slot: ResultSlots.Slot, payload: Payload, isRare: boolean) -> (),
	Fade: (self: ResultCards, isRare: boolean, isFast: boolean) -> (),
	Hide: (self: ResultCards, isRare: boolean) -> (),
	Run: (self: ResultCards, actions: { ResultSlots.Action }) -> (),
	Step: (self: ResultCards, dt: number) -> (),
	Flash: (self: ResultCards, color: Color3, transparency: number, seconds: number) -> (),
	VisibleCount: (self: ResultCards) -> number,
	ActiveConfetti: (self: ResultCards) -> number,
	Destroy: (self: ResultCards) -> (),
}

return {}
