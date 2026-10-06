--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats = require(ReplicatedStorage.Rules.Stats)
local PlayerData = require(script.Parent.Parent.Parent.Data.PlayerData)
local Caps = require(script.Parent.Caps)
local Lock = require(script.Parent.Lock)
local Types = require(script.Parent.Types)
local Walls = require(script.Parent.Walls)

type PlotInfo = Types.PlotInfo

local Present = {}

function Present.Render(info: PlotInfo, data: PlayerData.Data?)
	Caps.Render(info, data, if data then Stats.Slots(data.Upgrades) else 0)
end

function Present.Lock(info: PlotInfo)
	local state = info.Defense
	if state then
		Lock.Present(info, state, os.time())
	end
end

function Present.RefreshWalls(info: PlotInfo, data: PlayerData.Data?)
	local level = if data then Walls.Level(data.Upgrades.Walls) else 0
	if info.WallLevel == level then
		return
	end
	Walls.Apply(info, level)
	local state = info.Defense
	if state and state.IsActive then
		Lock.ShowLasers(info, state)
		Lock.Present(info, state, os.time())
	end
end

return Present
