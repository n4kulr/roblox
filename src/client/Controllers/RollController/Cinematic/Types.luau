--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Keys = require(ReplicatedStorage.Config.Keys)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Viewport = require(script.Parent.Parent.Parent.UIController.Viewport)
local Tiers = require(script.Parent.Parent.Tiers)

type TroveInstance = typeof(Trove.new())

export type Payload = {
	Key: Keys.Key,
	KeyId: string?,
	Rarity: Keys.Rarity,
	IsGolden: boolean,
}

export type Entry = {
	Payload: Payload,
	OnDone: (() -> ())?,
}

export type Particle = {
	Frame: Frame,
	Born: number,
	Life: number,
	X: number,
	Y: number,
	VX: number,
	VY: number,
	Rot: number,
	Spin: number,
	Shape: number,
	IsRain: boolean,
	Color: Color3,
	Used: boolean,
}

export type Star = {
	Frame: Frame,
	Angle: number,
	Speed: number,
	Phase: number,
}

export type Crack = {
	Frame: Frame,
	Angle: number,
	Length: number,
}

export type Ring = {
	Frame: Frame,
	Stroke: UIStroke,
}

export type Ray = {
	Holder: Frame,
	Image: ImageLabel?,
	Diameter: number,
}

export type Edge = {
	Frame: Frame,
	Gradient: UIGradient,
	Side: string,
}

export type TitleSet = {
	Main: TextLabel,
	MainStroke: UIStroke,
	MainScale: UIScale,
	MainGradient: UIGradient,
	Red: TextLabel,
	Cyan: TextLabel,
}

export type Cinematic = {
	_trove: TroveInstance,
	_isLowGraphics: () -> boolean,
	_getControllers: () -> { [string]: any },
	_gui: ScreenGui,
	_world: Frame,
	_dim: Frame,
	_edges: { Edge },
	_vignette: { Frame },
	_flash: Frame,
	_hint: TextLabel,
	_glow: Frame,
	_model: Viewport.Handle,
	_title: TitleSet,
	_name: TextLabel,
	_nameScale: UIScale,
	_nameStroke: UIStroke,
	_rays: { Ray },
	_rings: { Ring },
	_cracks: { Crack },
	_stars: { Star },
	_particles: { Particle },
	_active: Entry?,
	_queued: Entry?,
	_tier: Tiers.Tier,
	_t: number,
	_low: boolean,
	_hasImpacted: boolean,
	_humanoid: Humanoid?,
	_modelKey: string,
	_destroyed: boolean,
	CanAccept: (self: Cinematic) -> boolean,
	Play: (self: Cinematic, payload: Payload, onDone: (() -> ())?) -> boolean,
	Step: (self: Cinematic, dt: number) -> (),
	Skip: (self: Cinematic) -> boolean,
	Seek: (self: Cinematic, seconds: number) -> (),
	IsPlaying: (self: Cinematic) -> boolean,
	QueuedCount: (self: Cinematic) -> number,
	Elapsed: (self: Cinematic) -> number,
	TierName: (self: Cinematic) -> string,
	VisibleParticles: (self: Cinematic) -> number,
	Destroy: (self: Cinematic) -> (),
}

export type Scene = {
	Gui: ScreenGui,
	World: Frame,
	Dim: Frame,
	Edges: { Edge },
	Vignette: { Frame },
	Flash: Frame,
	Hint: TextLabel,
	Glow: Frame,
	Model: Viewport.Handle,
	Title: TitleSet,
	Name: TextLabel,
	NameScale: UIScale,
	NameStroke: UIStroke,
	Rays: { Ray },
	Rings: { Ring },
	Cracks: { Crack },
	Stars: { Star },
	Particles: { Particle },
}

return {}
