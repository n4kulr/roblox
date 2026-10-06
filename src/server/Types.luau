--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)
local PlayerData = require(script.Parent.Data.PlayerData)
local StatsCache = require(script.Parent.Services.KeyboardService.StatsCache)

export type Path = { string | number }

export type DataService = {
	Name: string,
	PlayerLoaded: Signal.Signal<(Player, PlayerData.Data)>,
	PlayerReleasing: Signal.Signal<(Player, PlayerData.Data)>,
	GetData: (self: any, player: Player) -> PlayerData.Data?,
	GetReplica: (self: any, player: Player) -> any?,
	Set: (self: any, player: Player, path: Path, value: any) -> boolean,
	RequestSave: (self: any, player: Player) -> boolean,
	WaitForSave: (self: any, player: Player, saved: (any) -> boolean) -> boolean,
	AdjustCash: (self: any, player: Player, amount: number) -> boolean,
}

export type PassService = {
	Name: string,
	Resolved: Signal.Signal<Player>,
	IsResolved: (self: any, player: Player) -> boolean,
	Owns: (self: any, player: Player, passId: string) -> boolean,
	GetPasses: (self: any, player: Player) -> { [string]: boolean },
}

export type KeyboardService = {
	Name: string,
	BoardChanged: Signal.Signal<Player>,
	Settle: (self: any, player: Player) -> (),
	Normalize: (self: any, player: Player) -> (),
	NotifyBoardChanged: (self: any, player: Player) -> (),
	InvalidateStats: (self: any, player: Player) -> (),
	GetRate: (self: any, player: Player) -> number,
	GetRollStats: (self: any, player: Player, luckMultiplier: number) -> StatsCache.RollStats?,
	AddKey: (self: any, player: Player, keyId: string, tag: string?) -> boolean,
	TakeFromSlot: (self: any, player: Player, slot: number, keyId: string) -> boolean,
	RestoreKey: (self: any, player: Player, slot: number, keyId: string) -> boolean,
}

export type PlotService = {
	Name: string,
	LockChanged: Signal.Signal<Player>,
	PlotAssigned: Signal.Signal<Player>,
	GetPlot: (self: any, player: Player) -> Model?,
	GetCaps: (self: any, player: Player) -> { BasePart }?,
	GetFloorCaps: (self: any, player: Player) -> { BasePart }?,
	GetRollKey: (self: any, player: Player) -> BasePart?,
	GetBase: (self: any, player: Player) -> BasePart?,
	SetRespawn: (self: any, player: Player, cframe: CFrame?) -> (),
	SendHome: (self: any, player: Player) -> boolean,
	Lock: (self: any, player: Player) -> boolean,
	IsLocked: (self: any, player: Player) -> boolean,
	GetLockedUntil: (self: any, player: Player) -> number,
	GetLockCooldownUntil: (self: any, player: Player) -> number,
	GetWallHeight: (self: any, player: Player) -> number?,
}

export type EggService = {
	Name: string,
	Sync: (self: any, player: Player) -> (),
	CanBuy: (self: any, player: Player) -> string,
	AddEgg: (self: any, player: Player, eggId: string) -> boolean,
	GrantEgg: (self: any, player: Player, eggId: string) -> boolean,
	ReadyEggs: (self: any, player: Player) -> number,
	HatchAll: (self: any, player: Player) -> { string },
}

export type SeasonService = {
	Name: string,
	AddRoll: (self: any, player: Player, isGolden: boolean) -> (),
}

export type RebirthService = {
	Name: string,
	Force: (self: any, player: Player) -> boolean,
}

export type CarryService = {
	Name: string,
	IsCarrying: (self: any, player: Player) -> boolean,
}

export type TradeService = {
	Name: string,
	IsTrading: (self: any, player: Player) -> boolean,
}

export type AdminService = {
	Name: string,
	IsAdmin: (self: any, player: Player) -> boolean,
	Execute: (self: any, player: Player, command: string, argument: string) -> (boolean, string),
}

export type Registry = {
	DataService: DataService,
	PassService: PassService,
	KeyboardService: KeyboardService,
	PlotService: PlotService,
	StealService: CarryService,
	KeyfallService: CarryService,
	EggService: EggService,
	SeasonService: SeasonService,
	RebirthService: RebirthService,
	TradeService: TradeService,
	ObbyService: CarryService?,
	AdminService: AdminService,
}

return {}
