--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Keys = require(ReplicatedStorage.Config.Keys)
local Packets = require(ReplicatedStorage.Packets)
local Steal = require(ReplicatedStorage.Rules.Steal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local PlayerData = require(script.Parent.Parent.Parent.Data.PlayerData)
local Character = require(script.Parent.Parent.Parent.Utils.Character)
local Ragdoll = require(script.Parent.Parent.Parent.Utils.Ragdoll)
local Config = require(script.Parent.Parent.Parent.Config.Steal)
local Carry = require(script.Parent.Carry)
local Drops = require(script.Parent.Drops)
local Prompts = require(script.Parent.Prompts)
local Types = require(script.Parent.Types)

local Knock = {}

function Knock.EndRagdoll(context: Types.Context, thief: Player)
	local handle = context.Ragdolls[thief]
	if handle then
		context.Ragdolls[thief] = nil
		handle.Trove:Destroy()
	end
end

local function startRagdoll(context: Types.Context, thief: Player)
	local character = thief.Character
	Knock.EndRagdoll(context, thief)
	if not character then
		return
	end
	local restore = Ragdoll.Apply(character)
	if not restore then
		return
	end
	local trove = Trove.new()
	context.Ragdolls[thief] = { Trove = trove }
	trove:Add(restore)
	local connection = thief.CharacterRemoving:Connect(function()
		Knock.EndRagdoll(context, thief)
	end)
	trove:Add(connection)
	local thread = task.delay(Config.RagdollSeconds, function()
		context.Ragdolls[thief] = nil
		restore()
		connection:Disconnect()
		context.KnockReadyAt[thief] = os.clock() + Config.KnockCooldownSeconds
	end)
	trove:Add(function()
		task.cancel(thread)
	end)
end

function Knock.DestroyDrop(context: Types.Context, drop: Types.Drop)
	if context.Drops[drop.Part] == drop then
		context.Drops[drop.Part] = nil
		drop.Trove:Destroy()
	end
end

local function returnDrop(context: Types.Context, drop: Types.Drop)
	Knock.DestroyDrop(context, drop)
	local owner = Players:GetPlayerByUserId(drop.OwnerUserId)
	if not owner or not context.Services.DataService:GetData(owner) then
		return
	end
	context.Services.KeyboardService:RestoreKey(owner, drop.Slot, drop.KeyId)
	local key = Keys.Resolve(drop.KeyId)
	Packets.StealAlert:FireClient(
		owner,
		drop.ThiefName,
		if key then key.Index else 0,
		Steal.AlertPhase.Returned
	)
end

local function spawnDrop(context: Types.Context, carrier: Types.Carrier, thief: Player, root: BasePart)
	local part, prompt =
		Drops.Build(carrier.KeyId, carrier.VictimUserId, carrier.VictimName, root, thief.Character)
	if not part or not prompt then
		return
	end
	local dropTrove = Trove.new()
	local drop: Types.Drop = {
		KeyId = carrier.KeyId,
		OwnerUserId = carrier.VictimUserId,
		Slot = carrier.Slot,
		ThiefName = thief.DisplayName,
		Part = part,
		Prompt = prompt,
		Trove = dropTrove,
	}
	context.Drops[part] = drop
	dropTrove:Add(function()
		Drops.Release(part)
	end)
	dropTrove:Connect(prompt.Triggered, function(player: Player)
		if player.UserId ~= drop.OwnerUserId or context.Drops[part] ~= drop then
			return
		end
		local ownerRoot = Character.RootOf(player)
		if
			not ownerRoot
			or Character.Distance(ownerRoot, part) > Prompts.TakeBackRange + Prompts.TakeBackSlack
		then
			return
		end
		returnDrop(context, drop)
	end)
	dropTrove:Add(task.delay(Config.DropSeconds, function()
		returnDrop(context, drop)
	end))
	part.Parent = workspace
end

function Knock.Strike(context: Types.Context, victim: Player, thief: Player)
	local carrier = context.Carriers[thief]
	if not carrier or carrier.VictimUserId ~= victim.UserId then
		return
	end
	local readyAt = context.KnockReadyAt[thief]
	if readyAt and os.clock() < readyAt then
		return
	end
	local data = context.Services.DataService:GetData(victim)
	local range = Prompts.KnockRange(data ~= nil and data.TheftLessonDone == false)
	local victimRoot = Character.RootOf(victim)
	local thiefRoot = Character.RootOf(thief)
	if
		not victimRoot
		or not thiefRoot
		or Character.Distance(victimRoot, thiefRoot) > range + Prompts.KnockSlack
	then
		return
	end
	Carry.End(context, thief)
	spawnDrop(context, carrier, thief, thiefRoot)
	startRagdoll(context, thief)
	context.KnockReadyAt[thief] = os.clock() + Config.RagdollSeconds + Config.KnockCooldownSeconds
	Packets.StealAlert:FireClient(
		victim,
		`You knocked down {thief.DisplayName}! Grab your key back!`,
		0,
		Steal.AlertPhase.Good
	)
	Packets.StealAlert:FireClient(thief, Config.KnockedMessage, 0, Steal.AlertPhase.Rejected)
end

function Knock.ReleaseDropsOf(context: Types.Context, owner: Player, data: PlayerData.Data)
	for _, drop in table.clone(context.Drops) do
		if drop.OwnerUserId == owner.UserId then
			Knock.DestroyDrop(context, drop)
			Carry.ReturnToDeparting({
				KeyId = drop.KeyId,
				VictimUserId = drop.OwnerUserId,
				VictimName = "",
				Slot = drop.Slot,
				StartedAt = 0,
				KnockPrompt = nil,
				Trove = nil,
			}, data)
		end
	end
end

return Knock
