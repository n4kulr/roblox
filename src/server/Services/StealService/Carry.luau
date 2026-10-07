--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local WorldNames = require(ReplicatedStorage.Config.WorldNames)
local Packets = require(ReplicatedStorage.Packets)
local Stats = require(ReplicatedStorage.Rules.Stats)
local Steal = require(ReplicatedStorage.Rules.Steal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local PlayerData = require(script.Parent.Parent.Parent.Data.PlayerData)
local Character = require(script.Parent.Parent.Parent.Utils.Character)
local KeyVisual = require(script.Parent.Parent.Parent.Utils.KeyVisual)
local WalkSpeed = require(script.Parent.Parent.Parent.Utils.WalkSpeed)
local Config = require(script.Parent.Parent.Parent.Config.Steal)
local Locks = require(script.Parent.Locks)
local Prompts = require(script.Parent.Prompts)
local Types = require(script.Parent.Types)

local config = GameConfig.Steal

local Carry = {}

function Carry.End(context: Types.Context, thief: Player): Types.Carrier?
	local carrier = context.Carriers[thief]
	if not carrier then
		return nil
	end
	context.Carriers[thief] = nil
	carrier.Trove:Destroy()
	Locks.Release(context, carrier.VictimUserId, thief)
	return carrier
end

function Carry.ReturnToVictim(context: Types.Context, thief: Player, carrier: Types.Carrier)
	local victim = Players:GetPlayerByUserId(carrier.VictimUserId)
	if not victim or not context.Services.DataService:GetData(victim) then
		return
	end
	context.Services.KeyboardService:RestoreKey(victim, carrier.Slot, carrier.KeyId)
	local key = Keys.Resolve(carrier.KeyId)
	Packets.StealAlert:FireClient(
		victim,
		thief.DisplayName,
		if key then key.Index else 0,
		Steal.AlertPhase.Returned
	)
end

function Carry.Fail(context: Types.Context, thief: Player)
	local carrier = Carry.End(context, thief)
	if carrier then
		Carry.ReturnToVictim(context, thief, carrier)
	end
end

function Carry.ReturnToDeparting(carrier: Types.Carrier, data: PlayerData.Data)
	local slot = carrier.Slot
	local current = data.Board[slot]
	local isFree = slot >= 1
		and slot <= Stats.Slots(data.Upgrades)
		and (type(current) ~= "string" or Keys.Resolve(current) == nil)
	if isFree then
		data.Board[slot] = carrier.KeyId
		data.BoardTags[slot] = ""
	else
		data.Inventory[carrier.KeyId] = (data.Inventory[carrier.KeyId] or 0) + 1
	end
end

function Carry.ReleaseOf(context: Types.Context, victim: Player, data: PlayerData.Data)
	for thief, carrier in table.clone(context.Carriers) do
		if carrier.VictimUserId == victim.UserId and context.Carriers[thief] == carrier then
			Carry.End(context, thief)
			Carry.ReturnToDeparting(carrier, data)
			Packets.StealAlert:FireClient(thief, Config.VictimLeftMessage, 0, Steal.AlertPhase.Rejected)
		end
	end
end

function Carry.Deliver(context: Types.Context, thief: Player, carrier: Types.Carrier)
	Carry.End(context, thief)
	local services = context.Services
	local key = Keys.Resolve(carrier.KeyId)
	local keyIndex = if key then key.Index else 0
	local added = services.KeyboardService:AddKey(thief, carrier.KeyId, "@" .. carrier.VictimName)
	if not added then
		Carry.ReturnToVictim(context, thief, carrier)
		return
	end
	context.LockedUntil[carrier.VictimUserId] = os.time() + config.BaseLockSeconds
	local victim = Players:GetPlayerByUserId(carrier.VictimUserId)
	if victim and services.DataService:GetData(victim) then
		services.DataService:Set(victim, { "TheftLessonDone" }, true)
		Packets.StealAlert:FireClient(victim, thief.DisplayName, keyIndex, Steal.AlertPhase.GotAway)
		context.SyncPrompts(victim)
	end
	Packets.StealFeed:FireAllClients(thief.DisplayName, carrier.VictimName, keyIndex)
end

function Carry.Begin(context: Types.Context, thief: Player, owner: Player, slot: number, keyId: string)
	local character = thief.Character
	local root = Character.RootOf(thief)
	if not character or not root then
		return
	end
	local key = Keys.Resolve(keyId)
	local carryTrove = Trove.new()
	local carrier: Types.Carrier = {
		KeyId = keyId,
		VictimUserId = owner.UserId,
		VictimName = owner.DisplayName,
		Slot = slot,
		StartedAt = os.clock(),
		KnockPrompt = nil,
		Trove = carryTrove,
	}
	context.Carriers[thief] = carrier
	local visual = KeyVisual.Attach(character, root, keyId, "StolenKey")
	if visual then
		carryTrove:Add(visual)
	end
	character:SetAttribute(WorldNames.Attributes.CarryingKey, keyId)
	character:SetAttribute(WalkSpeed.StolenAttribute, owner.UserId)
	WalkSpeed.Refresh(character)
	carryTrove:Add(function()
		character:SetAttribute(WorldNames.Attributes.CarryingKey, nil)
		character:SetAttribute(WalkSpeed.StolenAttribute, nil)
		WalkSpeed.Refresh(character)
	end)
	local victimData = context.Services.DataService:GetData(owner)
	local knockPrompt = Prompts.CreateKnock(
		root,
		owner.UserId,
		Prompts.KnockRange(victimData ~= nil and victimData.TheftLessonDone == false)
	)
	carryTrove:Add(knockPrompt)
	carrier.KnockPrompt = knockPrompt
	carryTrove:Connect(knockPrompt.Triggered, function(victim: Player)
		context.Knock(victim, thief)
	end)
	local humanoid = Character.HumanoidOf(character)
	if humanoid then
		carryTrove:Connect(humanoid.Died, function()
			Carry.Fail(context, thief)
		end)
	end
	carryTrove:Connect(thief.CharacterRemoving, function()
		Carry.Fail(context, thief)
	end)
	Packets.StealAlert:FireClient(
		owner,
		thief.DisplayName,
		if key then key.Index else 0,
		Steal.AlertPhase.Stolen
	)
end

return Carry
