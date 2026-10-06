--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local Kit = require(script.Parent.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Parent.Types)

export type Env = {
	Trove: typeof(Trove.new()),
	Root: Frame,
	Context: Types.Context,
	DataController: any,
	RollController: any,
	Toggle: (target: string) -> (),
}

export type SideMenu = {
	Menu: Frame,
	Upgrades: Kit.Button,
	Rebirth: Kit.Button,
	Daily: Kit.Button,
	Pets: Kit.Button,
	Pass: Kit.Button,
	Gift: Kit.Button,
}

export type Badges = {
	Upgrades: Frame,
	Rebirth: Frame,
	Pass: Frame,
	Daily: Frame,
	DailyText: TextLabel,
	DailyTimer: Frame,
	DailyTimerText: TextLabel,
}

export type Currency = {
	Cash: Kit.CountUp,
	Income: TextLabel,
}

export type StatLabels = {
	Luck: TextLabel,
	Speed: TextLabel,
	Income: TextLabel,
}

return {}
