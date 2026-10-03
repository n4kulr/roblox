--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local Packets = require(ReplicatedStorage.Packets)
local Steal = require(ReplicatedStorage.Rules.Steal)
local Stats = require(ReplicatedStorage.Rules.Stats)
local Trove = require(ReplicatedStorage.Packages.Trove)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local Prompts = require(script.Prompts)
local Types = require(script.Types)
local Visual = require(script.Visual)

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

local StealService = {
	Name = "StealService",
	_trove = nil :: TroveInstance?,
}
local services: { [string]: any } = {}
local prompts: { [Player]: { [number]: Types.PromptRecord } } = {}
local carriers: { [Player]: Types.Carrier } = {}
local locks: { [number]: Types.Lock } = {}
local lockedUntil: { [number]: number } = {}
local lastTag: { [Player]: number } = {}
local playClock: { [Player]: number } = {}

local function getData(player: Player): PlayerData.Data?
	return services.DataService:GetData(player) :: PlayerData.Data?
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

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
	local data = getData(player)
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
	return if type(keyId) == "string" and Keys.ById[keyId] ~= nil then keyId else ""
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

local function checkSteal(
	thief: Player,
	owner: Player,
	slot: number,
	cap: BasePart,
	expectedKeyId: string
): (boolean, string)
	local thiefData = getData(thief)
	local victimData = getData(owner)
	local thiefRoot = rootOf(thief)
	local lockedAt = math.max(lockedUntil[owner.UserId] or 0, services.PlotService:GetLockedUntil(owner))
	local lock = locks[owner.UserId]
	return Steal.CanSteal({
		ThiefUserId = thief.UserId,
		VictimUserId = owner.UserId,
		HasThiefData = thiefData ~= nil,
		HasVictimData = victimData ~= nil,
		ThiefCarrying = carriers[thief] ~= nil or isCarryingKeyfall(thief),
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
	if not victim or not getData(victim) then
		return
	end
	services.KeyboardService:RestoreKey(victim, carrier.Slot, carrier.KeyId)
	local key = Keys.ById[carrier.KeyId]
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
		and (type(current) ~= "string" or Keys.ById[current] == nil)
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
	local key = Keys.ById[carrier.KeyId]
	local keyIndex = if key then key.Index else 0
	local added = services.KeyboardService:AddKey(thief, carrier.KeyId, "@" .. carrier.VictimName)
	if not added then
		returnToVictim(thief, carrier)
		return
	end
	lockedUntil[carrier.VictimUserId] = os.time() + config.BaseLockSeconds
	local victim = Players:GetPlayerByUserId(carrier.VictimUserId)
	if victim and getData(victim) then
		services.DataService:Set(victim, { "TheftLessonDone" }, true)
		alert(victim, thief.DisplayName, keyIndex, 4)
		syncPrompts(victim)
	end
	Packets.StealFeed:FireAllClients(thief.DisplayName, carrier.VictimName, keyIndex)
end

local function startCarry(thief: Player, owner: Player, slot: number, keyId: string)
	local character = thief.Character
	local root = rootOf(thief)
	if not character or not root then
		return
	end
	local key = Keys.ById[keyId]
	local carryTrove = Trove.new()
	local carrier: Types.Carrier = {
		KeyId = keyId,
		VictimUserId = owner.UserId,
		VictimName = owner.DisplayName,
		Slot = slot,
		StartedAt = os.clock(),
		Trove = carryTrove,
	}
	carriers[thief] = carrier
	local visual = Visual.Attach(character, root, keyId)
	if visual then
		carryTrove:Add(visual)
	end
	Visual.SetSpeed(character, config.CarryWalkSpeed)
	character:SetAttribute("CarryingKey", keyId)
	character:SetAttribute("StolenFromUserId", owner.UserId)
	carryTrove:Add(function()
		character:SetAttribute("CarryingKey", nil)
		character:SetAttribute("StolenFromUserId", nil)
		Visual.SetSpeed(character, config.NormalWalkSpeed)
	end)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
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
	local data = getData(owner)
	local current = if data then boardKey(data, slot) else ""
	record.Holding[thief] = current
	local isAllowed = checkSteal(thief, owner, slot, cap, current)
	local key = Keys.ById[current]
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
	local data = getData(owner)
	local current = if data then boardKey(data, slot) else ""
	local held = record.Holding[thief] or current
	record.Holding[thief] = nil
	local isAllowed, reason = checkSteal(thief, owner, slot, cap, held)
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
	local record: Types.PromptRecord = { Prompt = prompt, Trove = recordTrove, Holding = {} }
	recordTrove:Connect(prompt.PromptButtonHoldBegan, function(thief: Player)
		onHoldBegan(owner, slot, cap, record, thief)
	end)
	recordTrove:Connect(prompt.PromptButtonHoldEnded, function(thief: Player)
		record.Holding[thief] = nil
		releaseLock(owner.UserId, thief)
	end)
	recordTrove:Connect(prompt.Triggered, function(thief: Player)
		onTriggered(owner, slot, cap, record, thief)
	end)
	return record
end

function syncPrompts(owner: Player)
	local data = getData(owner)
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
			Prompts.Update(active.Prompt, keyId, lessonPending)
			active.Prompt.Enabled = not isBaseLocked and (lock == nil or lock.Slot == slot)
		elseif record then
			destroyRecord(owner, slot)
		end
	end
end

local function tagThief(player: Player, targetUserId: number): boolean
	if type(targetUserId) ~= "number" then
		return false
	end
	local thief = Players:GetPlayerByUserId(targetUserId)
	local carrier = if thief then carriers[thief] else nil
	if not thief or not carrier or carrier.VictimUserId ~= player.UserId then
		return false
	end
	local now = os.clock()
	local last = lastTag[player]
	if last and now - last < config.TagCooldown then
		return false
	end
	lastTag[player] = now
	local data = getData(player)
	local range = if data and data.TheftLessonDone == false then config.LessonTagRange else config.TagRange
	local ownRoot = rootOf(player)
	local thiefRoot = rootOf(thief)
	if not ownRoot or not thiefRoot or distanceBetween(ownRoot, thiefRoot) > range then
		return false
	end
	failCarry(thief)
	return true
end

local function step()
	for thief, carrier in table.clone(carriers) do
		if carriers[thief] == carrier then
			local root = rootOf(thief)
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
	services = registry
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
		locks[player.UserId] = nil
		data.PlaySeconds += takePlaySeconds(player)
		playClock[player] = nil
		lastTag[player] = nil
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
		for victimUserId, lock in table.clone(locks) do
			if lock.Thief == player then
				releaseLock(victimUserId, player)
			end
		end
	end))
	for _, player in Players:GetPlayers() do
		if getData(player) then
			playClock[player] = os.clock()
			syncPrompts(player)
		end
	end
	Packets.TagThief.OnServerInvoke = tagThief
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

function StealService.Destroy(self: State)
	Packets.TagThief.OnServerInvoke = nil
	for thief in table.clone(carriers) do
		failCarry(thief)
	end
	for owner in table.clone(prompts) do
		clearPrompts(owner)
	end
	table.clear(locks)
	table.clear(lockedUntil)
	table.clear(lastTag)
	table.clear(playClock)
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return StealService
