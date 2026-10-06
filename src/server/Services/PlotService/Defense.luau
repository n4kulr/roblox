--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charms = require(ReplicatedStorage.Rules.Charms)
local Alerts = require(script.Parent.Parent.Parent.Utils.Alerts)
local Intruders = require(script.Parent.Intruders)
local Lock = require(script.Parent.Lock)
local Present = require(script.Parent.Present)
local Types = require(script.Parent.Types)

type PlotInfo = Types.PlotInfo

local sweepSeconds = 0.2
local zapMessage = "🔴 The lasers zapped you!"
local zapToastSeconds = 1.5

local Defense = {}

local function zapIntruders(context: Types.Context, info: PlotInfo, owner: Player, index: Intruders.Index)
	for _, entry in Intruders.Near(index, Lock.EntranceCFrame(info).Position, Lock.Reach(info)) do
		local player, root = entry.Player, entry.Root
		if player ~= owner and Lock.InEntrance(info, root.CFrame.Position) then
			Lock.Knock(info, root)
			local last = context.LastZap[player]
			if not last or os.clock() - last >= zapToastSeconds then
				context.LastZap[player] = os.clock()
				Alerts.Bad(player, zapMessage)
			end
		end
	end
end

local function sweep(context: Types.Context)
	local now = os.time()
	local index: Intruders.Index? = nil
	for info in context.ActiveLocks do
		local state = info.Defense
		local owner = info.Owner
		if not state or not owner or not state.IsActive then
			context.ActiveLocks[info] = nil
		elseif now >= state.LockedUntil then
			context.ActiveLocks[info] = nil
			Lock.Finish(state)
			Lock.Present(info, state, now)
			context.LockChanged:Fire(owner)
		else
			local current = index or Intruders.Build(Players:GetPlayers())
			index = current
			zapIntruders(context, info, owner, current)
			Lock.Present(info, state, now)
		end
	end
end

local function track(context: Types.Context, info: PlotInfo)
	context.ActiveLocks[info] = true
	if context.SweepThread then
		return
	end
	context.SweepThread = task.spawn(function()
		while next(context.ActiveLocks) do
			task.wait(sweepSeconds)
			sweep(context)
		end
		context.SweepThread = nil
	end)
end

function Defense.Activate(context: Types.Context, info: PlotInfo, player: Player): boolean
	local state = info.Defense
	if not state or info.Owner ~= player then
		return false
	end
	local now = os.time()
	if Lock.StatusAt(state, now) ~= Lock.Ready then
		return false
	end
	local data = context.Services.DataService:GetData(player)
	Lock.Start(
		info,
		state,
		now,
		Lock.Duration(
			if data then data.Upgrades.LockTime else 0,
			if data then Charms.Effects(data.EquippedCharms).LaserSeconds else 0
		)
	)
	Present.Lock(info)
	track(context, info)
	context.LockChanged:Fire(player)
	return true
end

function Defense.Stop(context: Types.Context)
	if context.SweepThread then
		task.cancel(context.SweepThread)
		context.SweepThread = nil
	end
	table.clear(context.ActiveLocks)
end

return Defense
