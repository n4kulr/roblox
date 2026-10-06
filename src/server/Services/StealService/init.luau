--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local Packets = require(ReplicatedStorage.Packets)
local Charms = require(ReplicatedStorage.Rules.Charms)
local Steal = require(ReplicatedStorage.Rules.Steal)
local Stats = require(ReplicatedStorage.Rules.Stats)
local Trove = require(ReplicatedStorage.Packages.Trove)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local Character = require(script.Parent.Parent.Utils.Character)
local KeyVisual = require(script.Parent.Parent.Utils.KeyVisual)
local Ragdoll = require(script.Parent.Parent.Utils.Ragdoll)
local WalkSpeed = require(script.Parent.Parent.Utils.WalkSpeed)
local Drops = require(script.Drops)
local Prompts = require(script.Prompts)
local Types = require(script.Types)
local ServerTypes = require(script.Parent.Parent.Types)

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	_trove: TroveInstance?,
}

local config = GameConfig.Steal
local stepSeconds = 0.2
local playtimeSaveSeconds = 30
local rejectedPhase = 9
local victimLeftReason = "They left — the key went home!"
local ragdollSeconds = 2.5
local knockCooldownSeconds = 3
local dropSeconds = 25
local goodPhase = 11
local knockedMessage = "You got knocked down!"

local StealService = {
	Name = "StealService",
	_trove = nil :: TroveInstance?,
}
local services: ServerTypes.Registry = nil :: any
local prompts: { [Player]: { [number]: Types.PromptRecord } } = {}
local carriers: { [Player]: Types.Carrier } = {}
local locks: { [number]: Types.Lock } = {}
local lockedUntil: { [number]: number } = {}
local knockReadyAt: { [Player]: number } = {}
local ragdolls: { [Player]: any } = {}
local drops: { [BasePart]: Types.Drop } = {}
local playClock: { [Player]: number } = {}

local function distanceBetween(a: BasePart, b: BasePart): number
	return (a.CFrame.Position - b.CFrame.Position).Magnitude
end

local function pendingPlaySeconds(player: Player): number
	local started = playClock[player]
	return if started then math.max(0, math.floor(os.clock() - started)) else 0
end

local function takePlaySeconds(player: Player): number
	local started = playClock[player]
	if not started then
		playClock[player] = os.clock()
		return 0
	end
	local whole = math.max(0, math.floor(os.clock() - started))
	playClock[player] = started + whole
	return whole
end

local function savePlaytime(player: Player)
	local data = services.DataService:GetData(player)
	local whole = takePlaySeconds(player)
	if data and whole > 0 then
		services.DataService:Set(player, { "PlaySeconds" }, data.PlaySeconds + whole)
	end
end

local function boardKey(data: PlayerData.Data, slot: number): string
	if slot > Stats.Slots(data.Upgrades) then
		return ""
	end
	local keyId = data.Board[slot]
	return if type(keyId) == "string" and Keys.Resolve(keyId) ~= nil then keyId else ""
end

local function alert(player: Player, name: string, keyIndex: number, phase: number)
	Packets.StealAlert:FireClient(player, name, keyIndex, phase)
end

local function destroyRecord(owner: Player, slot: number)
	local records = prompts[owner]
	local record = if records then records[slot] else nil
	if records and record then
		records[slot] = nil
		record.Trove:Destroy()
	end
end

local function clearPrompts(owner: Player)
	local records = prompts[owner]
	if records then
		for slot in table.clone(records) do
			destroyRecord(owner, slot)
		end
	end
	prompts[owner] = nil
end

local function isCarryingKeyfall(player: Player): boolean
	local keyfall = services.KeyfallService
	return keyfall ~= nil and keyfall:IsCarrying(player) == true
end

local function isCarryingObby(player: Player): boolean
	local obby = services.ObbyService
	return obby ~= nil and obby:IsCarrying(player) == true
end

local function checkSteal(
	thief: Player,
	owner: Player,
	slot: number,
	cap: BasePart,
	expectedKeyId: string
): (boolean, string)
	local thiefData = services.DataService:GetData(thief)
	local victimData = services.DataService:GetData(owner)
	local thiefRoot = Character.RootOf(thief)
	local lockedAt = math.max(lockedUntil[owner.UserId] or 0, services.PlotService:GetLockedUntil(owner))
	local lock = locks[owner.UserId]
	return Steal.CanSteal({
		ThiefUserId = thief.UserId,
		VictimUserId = owner.UserId,
		HasThiefData = thiefData ~= nil,
		HasVictimData = victimData ~= nil,
		ThiefCarrying = carriers[thief] ~= nil or isCarryingKeyfall(thief) or isCarryingObby(thief),
		ActiveThiefUserId = if lock then lock.Thief.UserId else 0,
		VictimPlaySeconds = if victimData then victimData.PlaySeconds + pendingPlaySeconds(owner) else 0,
		VictimLockedUntil = lockedAt,
		Now = os.time(),
		ThiefRate = services.KeyboardService:GetRate(thief),
		VictimRate = services.KeyboardService:GetRate(owner),
		ExpectedKeyId = expectedKeyId,
		SlotKeyId = if victimData then boardKey(victimData, slot) else "",
		Distance = if thiefRoot then distanceBetween(thiefRoot, cap) else math.huge,
	})
end

local syncPrompts: (owner: Player) -> ()

local function releaseLock(victimUserId: number, thief: Player)
	local lock = locks[victimUserId]
	if not lock or lock.Thief ~= thief or carriers[thief] then
		return
	end
	locks[victimUserId] = nil
	local victim = Players:GetPlayerByUserId(victimUserId)
	if victim and prompts[victim] then
		syncPrompts(victim)
	end
end

local function endCarry(thief: Player): Types.Carrier?
	local carrier = carriers[thief]
	if not carrier then
		return nil
	end
	carriers[thief] = nil
	carrier.Trove:Destroy()
	releaseLock(carrier.VictimUserId, thief)
	return carrier
end

local function returnToVictim(thief: Player, carrier: Types.Carrier)
	local victim = Players:GetPlayerByUserId(carrier.VictimUserId)
	if not victim or not services.DataService:GetData(victim) then
		return
	end
	services.KeyboardService:RestoreKey(victim, carrier.Slot, carrier.KeyId)
	local key = Keys.Resolve(carrier.KeyId)
	alert(victim, thief.DisplayName, if key then key.Index else 0, 3)
end

local function failCarry(thief: Player)
	local carrier = endCarry(thief)
	if carrier then
		returnToVictim(thief, carrier)
	end
end

local function returnToDeparting(carrier: Types.Carrier, data: PlayerData.Data)
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

local function releaseCarriesOf(victim: Player, data: PlayerData.Data)
	for thief, carrier in table.clone(carriers) do
		if carrier.VictimUserId == victim.UserId and carriers[thief] == carrier then
			endCarry(thief)
			returnToDeparting(carrier, data)
			alert(thief, victimLeftReason, 0, rejectedPhase)
		end
	end
end

local function deliver(thief: Player, carrier: Types.Carrier)
	endCarry(thief)
	local key = Keys.Resolve(carrier.KeyId)
	local keyIndex = if key then key.Index else 0
	local added = services.KeyboardService:AddKey(thief, carrier.KeyId, "@" .. carrier.VictimName)
	if not added then
		returnToVictim(thief, carrier)
		return
	end
	lockedUntil[carrier.VictimUserId] = os.time() + config.BaseLockSeconds
	local victim = Players:GetPlayerByUserId(carrier.VictimUserId)
	if victim and services.DataService:GetData(victim) then
		services.DataService:Set(victim, { "TheftLessonDone" }, true)
		alert(victim, thief.DisplayName, keyIndex, 4)
		syncPrompts(victim)
	end
	Packets.StealFeed:FireAllClients(thief.DisplayName, carrier.VictimName, keyIndex)
end

local function startCarry(thief: Player, owner: Player, slot: number, keyId: string)
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
	carriers[thief] = carrier
	local visual = KeyVisual.Attach(character, root, keyId, "StolenKey")
	if visual then
		carryTrove:Add(visual)
	end
	character:SetAttribute("CarryingKey", keyId)
	character:SetAttribute(WalkSpeed.StolenAttribute, owner.UserId)
	WalkSpeed.Refresh(character)
	carryTrove:Add(function()
		character:SetAttribute("CarryingKey", nil)
		character:SetAttribute(WalkSpeed.StolenAttribute, nil)
		WalkSpeed.Refresh(character)
	end)
	local victimData = services.DataService:GetData(owner)
	local knockPrompt = Prompts.CreateKnock(
		root,
		owner.UserId,
		Prompts.KnockRange(victimData ~= nil and victimData.TheftLessonDone == false)
	)
	carryTrove:Add(knockPrompt)
	carrier.KnockPrompt = knockPrompt
	carryTrove:Connect(knockPrompt.Triggered, function(victim: Player)
		StealService:_knock(victim, thief)
	end)
	local humanoid = Character.HumanoidOf(character)
	if humanoid then
		carryTrove:Connect(humanoid.Died, function()
			failCarry(thief)
		end)
	end
	carryTrove:Connect(thief.CharacterRemoving, function()
		failCarry(thief)
	end)
	alert(owner, thief.DisplayName, if key then key.Index else 0, 2)
end

local function onHoldBegan(
	owner: Player,
	slot: number,
	cap: BasePart,
	record: Types.PromptRecord,
	thief: Player
)
	local data = services.DataService:GetData(owner)
	local current = if data then boardKey(data, slot) else ""
	record.Holding[thief] = current
	record.HoldStarted[thief] = os.clock()
	local isAllowed = checkSteal(thief, owner, slot, cap, current)
	local key = Keys.Resolve(current)
	if isAllowed and key then
		if not locks[owner.UserId] then
			locks[owner.UserId] = { Thief = thief, Slot = slot }
			syncPrompts(owner)
		end
		alert(owner, thief.DisplayName, key.Index, 1)
	end
end

local function onTriggered(
	owner: Player,
	slot: number,
	cap: BasePart,
	record: Types.PromptRecord,
	thief: Player
)
	local data = services.DataService:GetData(owner)
	local current = if data then boardKey(data, slot) else ""
	local held = record.Holding[thief] or current
	local startedAt = record.HoldStarted[thief]
	record.Holding[thief] = nil
	record.HoldStarted[thief] = nil
	local isAllowed, reason = checkSteal(thief, owner, slot, cap, held)
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
		releaseLock(owner.UserId, thief)
		alert(thief, reason, 0, rejectedPhase)
		return
	end
	locks[owner.UserId] = { Thief = thief, Slot = 0 }
	if not services.KeyboardService:TakeFromSlot(owner, slot, current) then
		releaseLock(owner.UserId, thief)
		alert(thief, Steal.Reasons.Gone, 0, rejectedPhase)
		return
	end
	startCarry(thief, owner, slot, current)
	if not carriers[thief] then
		releaseLock(owner.UserId, thief)
		services.KeyboardService:RestoreKey(owner, slot, current)
	end
end

local function createRecord(owner: Player, slot: number, cap: BasePart): Types.PromptRecord
	local recordTrove = Trove.new()
	local prompt = Prompts.Create(cap, owner.UserId, slot)
	recordTrove:Add(prompt)
	local record: Types.PromptRecord =
		{ Prompt = prompt, Trove = recordTrove, Holding = {}, HoldStarted = {} }
	recordTrove:Connect(prompt.PromptButtonHoldBegan, function(thief: Player)
		onHoldBegan(owner, slot, cap, record, thief)
	end)
	recordTrove:Connect(prompt.PromptButtonHoldEnded, function(thief: Player)
		record.Holding[thief] = nil
		record.HoldStarted[thief] = nil
		releaseLock(owner.UserId, thief)
	end)
	recordTrove:Connect(prompt.Triggered, function(thief: Player)
		onTriggered(owner, slot, cap, record, thief)
	end)
	return record
end

function syncPrompts(owner: Player)
	local data = services.DataService:GetData(owner)
	local caps = services.PlotService:GetCaps(owner) :: { BasePart }?
	if not data or not caps then
		clearPrompts(owner)
		return
	end
	local records = prompts[owner]
	if not records then
		records = {}
		prompts[owner] = records
	end
	local lessonPending = data.TheftLessonDone == false
	local lock = locks[owner.UserId]
	local isBaseLocked = services.PlotService:IsLocked(owner) == true
	for slot = 1, GameConfig.BoardSlots do
		local cap = caps[slot]
		local keyId = boardKey(data, slot)
		local record: Types.PromptRecord? = records[slot]
		if cap and keyId ~= "" then
			if record and record.Prompt.Parent ~= cap then
				destroyRecord(owner, slot)
				record = nil
			end
			local active = record or createRecord(owner, slot, cap)
			records[slot] = active
			Prompts.Update(
				active.Prompt,
				keyId,
				lessonPending,
				not isBaseLocked and (lock == nil or lock.Slot == slot)
			)
		elseif record then
			destroyRecord(owner, slot)
		end
	end
end

local function endRagdoll(thief: Player)
	local handle = ragdolls[thief]
	if handle then
		ragdolls[thief] = nil
		handle.Trove:Destroy()
	end
end

local function startRagdoll(thief: Player)
	local character = thief.Character
	endRagdoll(thief)
	if not character then
		return
	end
	local restore = Ragdoll.Apply(character)
	if not restore then
		return
	end
	local trove = Trove.new()
	ragdolls[thief] = { Trove = trove }
	trove:Add(restore)
	local connection = thief.CharacterRemoving:Connect(function()
		endRagdoll(thief)
	end)
	trove:Add(connection)
	local thread = task.delay(ragdollSeconds, function()
		ragdolls[thief] = nil
		restore()
		connection:Disconnect()
		knockReadyAt[thief] = os.clock() + knockCooldownSeconds
	end)
	trove:Add(function()
		task.cancel(thread)
	end)
end

local function destroyDrop(drop: Types.Drop)
	if drops[drop.Part] == drop then
		drops[drop.Part] = nil
		drop.Trove:Destroy()
	end
end

local function returnDrop(drop: Types.Drop, thiefName: string)
	destroyDrop(drop)
	local owner = Players:GetPlayerByUserId(drop.OwnerUserId)
	if not owner or not services.DataService:GetData(owner) then
		return
	end
	services.KeyboardService:RestoreKey(owner, drop.Slot, drop.KeyId)
	local key = Keys.Resolve(drop.KeyId)
	alert(owner, thiefName, if key then key.Index else 0, 3)
end

local function spawnDrop(carrier: Types.Carrier, thief: Player, root: BasePart)
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
	drops[part] = drop
	dropTrove:Add(function()
		Drops.Release(part)
	end)
	dropTrove:Connect(prompt.Triggered, function(player: Player)
		if player.UserId ~= drop.OwnerUserId or drops[part] ~= drop then
			return
		end
		local ownerRoot = Character.RootOf(player)
		if
			not ownerRoot
			or distanceBetween(ownerRoot, part) > Prompts.TakeBackRange + Prompts.TakeBackSlack
		then
			return
		end
		returnDrop(drop, drop.ThiefName)
	end)
	dropTrove:Add(task.delay(dropSeconds, function()
		returnDrop(drop, drop.ThiefName)
	end))
	part.Parent = workspace
end

local function knock(victim: Player, thief: Player)
	local carrier = carriers[thief]
	if not carrier or carrier.VictimUserId ~= victim.UserId then
		return
	end
	local readyAt = knockReadyAt[thief]
	if readyAt and os.clock() < readyAt then
		return
	end
	local data = services.DataService:GetData(victim)
	local range = Prompts.KnockRange(data ~= nil and data.TheftLessonDone == false)
	local victimRoot = Character.RootOf(victim)
	local thiefRoot = Character.RootOf(thief)
	if
		not victimRoot
		or not thiefRoot
		or distanceBetween(victimRoot, thiefRoot) > range + Prompts.KnockSlack
	then
		return
	end
	endCarry(thief)
	spawnDrop(carrier, thief, thiefRoot)
	startRagdoll(thief)
	knockReadyAt[thief] = os.clock() + ragdollSeconds + knockCooldownSeconds
	alert(victim, `You knocked down {thief.DisplayName}! Grab your key back!`, 0, goodPhase)
	alert(thief, knockedMessage, 0, rejectedPhase)
end

local function releaseDropsOf(owner: Player, data: PlayerData.Data)
	for _, drop in table.clone(drops) do
		if drop.OwnerUserId == owner.UserId then
			destroyDrop(drop)
			returnToDeparting({
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

local function step()
	for thief, carrier in table.clone(carriers) do
		if carriers[thief] == carrier then
			local root = Character.RootOf(thief)
			local knockPrompt = carrier.KnockPrompt
			if knockPrompt then
				local readyAt = knockReadyAt[thief]
				local isOpen = readyAt == nil or os.clock() >= readyAt
				if knockPrompt:GetAttribute(Prompts.OpenAttribute) ~= isOpen then
					knockPrompt:SetAttribute(Prompts.OpenAttribute, isOpen)
				end
			end
			if not root then
				failCarry(thief)
			else
				local base = services.PlotService:GetBase(thief) :: BasePart?
				if base and distanceBetween(root, base) <= config.DeliverRadius then
					deliver(thief, carrier)
				elseif os.clock() - carrier.StartedAt >= config.CarryTimeoutSeconds then
					failCarry(thief)
				end
			end
		end
	end
end

function StealService.Init(self: State, registry: { [string]: any })
	services = registry :: any
	self._trove = Trove.new()
end

function StealService.Start(self: State)
	local trove = self._trove :: TroveInstance
	services.DataService.PlayerLoaded:Connect(function(player: Player, _data: PlayerData.Data)
		playClock[player] = os.clock()
		syncPrompts(player)
	end)
	services.DataService.PlayerReleasing:Connect(function(player: Player, data: PlayerData.Data)
		releaseCarriesOf(player, data)
		releaseDropsOf(player, data)
		locks[player.UserId] = nil
		data.PlaySeconds += takePlaySeconds(player)
		playClock[player] = nil
		knockReadyAt[player] = nil
		lockedUntil[player.UserId] = nil
		clearPrompts(player)
	end)
	trove:Add(services.KeyboardService.BoardChanged:Connect(function(player: Player)
		syncPrompts(player)
	end))
	trove:Add(services.PlotService.LockChanged:Connect(function(player: Player)
		if prompts[player] then
			syncPrompts(player)
		end
	end))
	trove:Add(Players.PlayerRemoving:Connect(function(player: Player)
		failCarry(player)
		endRagdoll(player)
		knockReadyAt[player] = nil
		for victimUserId, lock in table.clone(locks) do
			if lock.Thief == player then
				releaseLock(victimUserId, player)
			end
		end
	end))
	for _, player in Players:GetPlayers() do
		if services.DataService:GetData(player) then
			playClock[player] = os.clock()
			syncPrompts(player)
		end
	end
	trove:Add(task.spawn(function()
		local sinceSave = 0
		while true do
			task.wait(stepSeconds)
			step()
			sinceSave += stepSeconds
			if sinceSave >= playtimeSaveSeconds then
				sinceSave = 0
				for _, player in Players:GetPlayers() do
					savePlaytime(player)
				end
			end
		end
	end))
end

function StealService._knock(_self: State, victim: Player, thief: Player)
	knock(victim, thief)
end

function StealService.IsCarrying(_self: State, player: Player): boolean
	return carriers[player] ~= nil
end

function StealService.Destroy(self: State)
	for _, drop in table.clone(drops) do
		destroyDrop(drop)
	end
	for thief in table.clone(ragdolls) do
		endRagdoll(thief)
	end
	for thief in table.clone(carriers) do
		failCarry(thief)
	end
	for owner in table.clone(prompts) do
		clearPrompts(owner)
	end
	table.clear(locks)
	table.clear(lockedUntil)
	table.clear(knockReadyAt)
	table.clear(playClock)
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return StealService
