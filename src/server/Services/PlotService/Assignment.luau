--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldNames = require(ReplicatedStorage.Config.WorldNames)
local Trove = require(ReplicatedStorage.Packages.Trove)
local PlayerData = require(script.Parent.Parent.Parent.Data.PlayerData)
local Lock = require(script.Parent.Lock)
local Present = require(script.Parent.Present)
local Respawn = require(script.Parent.Respawn)
local Types = require(script.Parent.Types)

type PlotInfo = Types.PlotInfo

local Assignment = {}

local function applyOwner(info: PlotInfo, owner: Player?)
	info.Owner = owner
	local state = info.Defense
	if state then
		Lock.Reset(state)
	end
	Present.Lock(info)
end

local function vacate(info: PlotInfo, previousOwner: Player)
	applyOwner(info, nil)
	info.Model:SetAttribute(WorldNames.Attributes.LastOwner, previousOwner.UserId)
	info.Model:SetAttribute(WorldNames.Attributes.Owner, nil)
	Present.RefreshWalls(info, nil)
	Present.Render(info, nil)
	if info.Sign then
		info.Sign:Set(nil)
	end
end

function Assignment.Release(context: Types.Context, player: Player)
	local playerTrove = context.PlayerTroves[player]
	context.PlayerTroves[player] = nil
	if playerTrove then
		playerTrove:Destroy()
	end
	local info = context.ByPlayer[player]
	context.ByPlayer[player] = nil
	context.LastZap[player] = nil
	context.RespawnPoints[player] = nil
	if info then
		vacate(info, player)
	end
end

function Assignment.ReleaseStale(context: Types.Context)
	for stalePlayer, info in context.ByPlayer do
		if stalePlayer.Parent ~= Players or info.Owner ~= stalePlayer then
			Assignment.Release(context, stalePlayer)
		end
	end
	for _, info in context.Plots do
		local owner = info.Owner
		if owner and owner.Parent ~= Players and context.ByPlayer[owner] then
			Assignment.Release(context, owner)
		end
		owner = info.Owner
		if owner and context.ByPlayer[owner] ~= info then
			vacate(info, owner)
		end
	end
end

function Assignment.Assign(context: Types.Context, player: Player, data: PlayerData.Data)
	if context.ByPlayer[player] then
		return
	end
	Assignment.ReleaseStale(context)
	local free: PlotInfo? = nil
	for _, info in context.Plots do
		if not info.Owner and info.Model:GetAttribute(WorldNames.Attributes.LastOwner) == player.UserId then
			free = info
			break
		end
	end
	if not free then
		for _, info in context.Plots do
			if not info.Owner then
				free = info
				break
			end
		end
	end
	if not free then
		warn(`[PlotService] No free plot for {player.Name}`)
		return
	end
	applyOwner(free, player)
	context.ByPlayer[player] = free
	free.Model:SetAttribute(WorldNames.Attributes.Owner, player.UserId)
	Present.RefreshWalls(free, data)
	Present.Render(free, data)
	if free.Sign then
		free.Sign:Set(player)
	end
	local playerTrove = Trove.new()
	context.PlayerTroves[player] = playerTrove
	playerTrove:Connect(player.CharacterAdded, function(character: Model)
		Respawn.ApplyWalkSpeed(character)
		Respawn.Teleport(context, player, character)
	end)
	if player.Character then
		Respawn.ApplyWalkSpeed(player.Character)
		Respawn.Teleport(context, player, player.Character)
	end
	context.PlotAssigned:Fire(player)
end

return Assignment
