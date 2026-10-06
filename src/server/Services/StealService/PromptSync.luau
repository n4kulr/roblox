--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local Charms = require(ReplicatedStorage.Rules.Charms)
local Steal = require(ReplicatedStorage.Rules.Steal)
local Stats = require(ReplicatedStorage.Rules.Stats)
local Trove = require(ReplicatedStorage.Packages.Trove)
local PlayerData = require(script.Parent.Parent.Parent.Data.PlayerData)
local Alerts = require(script.Parent.Parent.Parent.Utils.Alerts)
local Character = require(script.Parent.Parent.Parent.Utils.Character)
local Carry = require(script.Parent.Carry)
local Locks = require(script.Parent.Locks)
local Prompts = require(script.Parent.Prompts)
local Types = require(script.Parent.Types)

local config = GameConfig.Steal

local PromptSync = {}

function PromptSync.BoardKey(data: PlayerData.Data, slot: number): string
	if slot > Stats.Slots(data.Upgrades) then
		return ""
	end
	local keyId = data.Board[slot]
	return if type(keyId) == "string" and Keys.Resolve(keyId) ~= nil then keyId else ""
end

local function destroyRecord(context: Types.Context, owner: Player, slot: number)
	local records = context.Prompts[owner]
	local record = if records then records[slot] else nil
	if records and record then
		records[slot] = nil
		record.Trove:Destroy()
	end
end

function PromptSync.Clear(context: Types.Context, owner: Player)
	local records = context.Prompts[owner]
	if records then
		for slot in table.clone(records) do
			destroyRecord(context, owner, slot)
		end
	end
	context.Prompts[owner] = nil
end

function PromptSync.Check(
	context: Types.Context,
	thief: Player,
	owner: Player,
	slot: number,
	cap: BasePart,
	expectedKeyId: string
): (boolean, string)
	local services = context.Services
	local thiefData = services.DataService:GetData(thief)
	local victimData = services.DataService:GetData(owner)
	local thiefRoot = Character.RootOf(thief)
	local lockedAt =
		math.max(context.LockedUntil[owner.UserId] or 0, services.PlotService:GetLockedUntil(owner))
	local lock = context.Locks[owner.UserId]
	local keyfall = services.KeyfallService
	local obby = services.ObbyService
	return Steal.CanSteal({
		ThiefUserId = thief.UserId,
		VictimUserId = owner.UserId,
		HasThiefData = thiefData ~= nil,
		HasVictimData = victimData ~= nil,
		ThiefCarrying = context.Carriers[thief] ~= nil
			or (keyfall ~= nil and keyfall:IsCarrying(thief) == true)
			or (obby ~= nil and obby:IsCarrying(thief) == true),
		ActiveThiefUserId = if lock then lock.Thief.UserId else 0,
		VictimPlaySeconds = if victimData
			then victimData.PlaySeconds + services.PlaytimeService:GetPendingSeconds(owner)
			else 0,
		VictimLockedUntil = lockedAt,
		Now = os.time(),
		ThiefRate = services.KeyboardService:GetRate(thief),
		VictimRate = services.KeyboardService:GetRate(owner),
		ExpectedKeyId = expectedKeyId,
		SlotKeyId = if victimData then PromptSync.BoardKey(victimData, slot) else "",
		Distance = if thiefRoot then Character.Distance(thiefRoot, cap) else math.huge,
	})
end

local function onHoldBegan(
	context: Types.Context,
	owner: Player,
	slot: number,
	cap: BasePart,
	record: Types.PromptRecord,
	thief: Player
)
	local data = context.Services.DataService:GetData(owner)
	local current = if data then PromptSync.BoardKey(data, slot) else ""
	record.Holding[thief] = current
	record.HoldStarted[thief] = os.clock()
	local isAllowed = PromptSync.Check(context, thief, owner, slot, cap, current)
	local key = Keys.Resolve(current)
	if isAllowed and key then
		if not context.Locks[owner.UserId] then
			context.Locks[owner.UserId] = { Thief = thief, Slot = slot }
			context.SyncPrompts(owner)
		end
		Alerts.Send(owner, thief.DisplayName, key.Index, Alerts.Phase.Grab)
	end
end

local function onTriggered(
	context: Types.Context,
	owner: Player,
	slot: number,
	cap: BasePart,
	record: Types.PromptRecord,
	thief: Player
)
	local services = context.Services
	local data = services.DataService:GetData(owner)
	local current = if data then PromptSync.BoardKey(data, slot) else ""
	local held = record.Holding[thief] or current
	local startedAt = record.HoldStarted[thief]
	record.Holding[thief] = nil
	record.HoldStarted[thief] = nil
	local isAllowed, reason = PromptSync.Check(context, thief, owner, slot, cap, held)
	if isAllowed then
		local thiefData = services.DataService:GetData(thief)
		local speed = Charms.Effects(if thiefData then thiefData.EquippedCharms else nil).StealSpeed
		local required =
			Steal.HoldSeconds(Steal.RarityIndex(held), data ~= nil and data.TheftLessonDone == false, speed)
		if not startedAt or os.clock() - startedAt < required - config.HoldToleranceSeconds then
			isAllowed = false
			reason = Steal.Reasons.TooFast
		end
	end
	if not isAllowed then
		Locks.Release(context, owner.UserId, thief)
		Alerts.Bad(thief, reason)
		return
	end
	context.Locks[owner.UserId] = { Thief = thief, Slot = 0 }
	if not services.KeyboardService:TakeFromSlot(owner, slot, current) then
		Locks.Release(context, owner.UserId, thief)
		Alerts.Bad(thief, Steal.Reasons.Gone)
		return
	end
	Carry.Begin(context, thief, owner, slot, current)
	if not context.Carriers[thief] then
		Locks.Release(context, owner.UserId, thief)
		services.KeyboardService:RestoreKey(owner, slot, current)
	end
end

local function createRecord(
	context: Types.Context,
	owner: Player,
	slot: number,
	cap: BasePart
): Types.PromptRecord
	local recordTrove = Trove.new()
	local prompt = Prompts.Create(cap, owner.UserId, slot)
	recordTrove:Add(prompt)
	local record: Types.PromptRecord =
		{ Prompt = prompt, Trove = recordTrove, Holding = {}, HoldStarted = {} }
	recordTrove:Connect(prompt.PromptButtonHoldBegan, function(thief: Player)
		onHoldBegan(context, owner, slot, cap, record, thief)
	end)
	recordTrove:Connect(prompt.PromptButtonHoldEnded, function(thief: Player)
		record.Holding[thief] = nil
		record.HoldStarted[thief] = nil
		Locks.Release(context, owner.UserId, thief)
	end)
	recordTrove:Connect(prompt.Triggered, function(thief: Player)
		onTriggered(context, owner, slot, cap, record, thief)
	end)
	return record
end

function PromptSync.Sync(context: Types.Context, owner: Player)
	local services = context.Services
	local data = services.DataService:GetData(owner)
	local caps = services.PlotService:GetCaps(owner)
	if not data or not caps then
		PromptSync.Clear(context, owner)
		return
	end
	local records = context.Prompts[owner]
	if not records then
		records = {}
		context.Prompts[owner] = records
	end
	local lessonPending = data.TheftLessonDone == false
	local lock = context.Locks[owner.UserId]
	local isBaseLocked = services.PlotService:IsLocked(owner) == true
	for slot = 1, GameConfig.BoardSlots do
		local cap = caps[slot]
		local keyId = PromptSync.BoardKey(data, slot)
		local record: Types.PromptRecord? = records[slot]
		if cap and keyId ~= "" then
			if record and record.Prompt.Parent ~= cap then
				destroyRecord(context, owner, slot)
				record = nil
			end
			local active = record or createRecord(context, owner, slot, cap)
			records[slot] = active
			Prompts.Update(
				active.Prompt,
				keyId,
				lessonPending,
				not isBaseLocked and (lock == nil or lock.Slot == slot)
			)
		elseif record then
			destroyRecord(context, owner, slot)
		end
	end
end

return PromptSync
