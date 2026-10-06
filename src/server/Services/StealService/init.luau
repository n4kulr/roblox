--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Trove = require(ReplicatedStorage.Packages.Trove)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local Character = require(script.Parent.Parent.Utils.Character)
local Config = require(script.Parent.Parent.Config.Steal)
local ServerTypes = require(script.Parent.Parent.Types)
local Carry = require(script.Carry)
local Knock = require(script.Knock)
local Locks = require(script.Locks)
local Prompts = require(script.Prompts)
local PromptSync = require(script.PromptSync)
local Types = require(script.Types)

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	_trove: TroveInstance?,
}

local config = GameConfig.Steal

local StealService = {
	Name = "StealService",
	_trove = nil :: TroveInstance?,
}
local services: ServerTypes.Registry = nil :: any
local context: Types.Context = {
	Services = nil :: any,
	Prompts = {},
	Carriers = {},
	Locks = {},
	LockedUntil = {},
	KnockReadyAt = {},
	Ragdolls = {},
	Drops = {},
	SyncPrompts = nil :: any,
	Knock = nil :: any,
}

context.SyncPrompts = function(owner: Player)
	PromptSync.Sync(context, owner)
end

context.Knock = function(victim: Player, thief: Player)
	Knock.Strike(context, victim, thief)
end

local function step()
	for thief, carrier in table.clone(context.Carriers) do
		if context.Carriers[thief] == carrier then
			local root = Character.RootOf(thief)
			local knockPrompt = carrier.KnockPrompt
			if knockPrompt then
				local readyAt = context.KnockReadyAt[thief]
				local isOpen = readyAt == nil or os.clock() >= readyAt
				if knockPrompt:GetAttribute(Prompts.OpenAttribute) ~= isOpen then
					knockPrompt:SetAttribute(Prompts.OpenAttribute, isOpen)
				end
			end
			if not root then
				Carry.Fail(context, thief)
			else
				local base = services.PlotService:GetBase(thief)
				if base and Character.Distance(root, base) <= config.DeliverRadius then
					Carry.Deliver(context, thief, carrier)
				elseif os.clock() - carrier.StartedAt >= config.CarryTimeoutSeconds then
					Carry.Fail(context, thief)
				end
			end
		end
	end
end

function StealService.Init(self: State, registry: { [string]: any })
	services = registry :: any
	context.Services = services
	self._trove = Trove.new()
end

function StealService.Start(self: State)
	local trove = self._trove :: TroveInstance
	services.DataService.PlayerLoaded:Connect(function(player: Player, _data: PlayerData.Data)
		context.SyncPrompts(player)
	end)
	services.DataService.PlayerReleasing:Connect(function(player: Player, data: PlayerData.Data)
		Carry.ReleaseOf(context, player, data)
		Knock.ReleaseDropsOf(context, player, data)
		context.Locks[player.UserId] = nil
		context.KnockReadyAt[player] = nil
		context.LockedUntil[player.UserId] = nil
		PromptSync.Clear(context, player)
	end)
	trove:Add(services.KeyboardService.BoardChanged:Connect(function(player: Player)
		context.SyncPrompts(player)
	end))
	trove:Add(services.PlotService.LockChanged:Connect(function(player: Player)
		if context.Prompts[player] then
			context.SyncPrompts(player)
		end
	end))
	trove:Add(Players.PlayerRemoving:Connect(function(player: Player)
		Carry.Fail(context, player)
		Knock.EndRagdoll(context, player)
		context.KnockReadyAt[player] = nil
		for victimUserId, lock in table.clone(context.Locks) do
			if lock.Thief == player then
				Locks.Release(context, victimUserId, player)
			end
		end
	end))
	for _, player in Players:GetPlayers() do
		if services.DataService:GetData(player) then
			context.SyncPrompts(player)
		end
	end
	trove:Add(task.spawn(function()
		while true do
			task.wait(Config.StepSeconds)
			step()
		end
	end))
end

function StealService.IsCarrying(_self: State, player: Player): boolean
	return context.Carriers[player] ~= nil
end

function StealService.Destroy(self: State)
	for _, drop in table.clone(context.Drops) do
		Knock.DestroyDrop(context, drop)
	end
	for thief in table.clone(context.Ragdolls) do
		Knock.EndRagdoll(context, thief)
	end
	for thief in table.clone(context.Carriers) do
		Carry.Fail(context, thief)
	end
	for owner in table.clone(context.Prompts) do
		PromptSync.Clear(context, owner)
	end
	table.clear(context.Locks)
	table.clear(context.LockedUntil)
	table.clear(context.KnockReadyAt)
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return StealService
