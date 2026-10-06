--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local Packets = require(ReplicatedStorage.Packets)
local Roll = require(ReplicatedStorage.Rules.Roll)
local Rules = require(ReplicatedStorage.Rules.Keyfall)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Character = require(script.Parent.Parent.Utils.Character)
local Arena = require(script.Arena)
local Types = require(script.Types)
local Visual = require(script.Visual)
local ServerTypes = require(script.Parent.Parent.Types)

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	_trove: TroveInstance?,
}

local config = GameConfig.Keyfall
local steal = GameConfig.Steal
local goldenId = config.GoldenSpacebarKeyId
local stepSeconds = 0.1
local fallHeight = 40
local fallSeconds = 1.2
local goldenLifetimeSeconds = 60
local dropPickupDelay = 0.6
local verticalReach = 10
local hipHeight = 3
local scatterRadius = 2.5
local eventAnnounce = 1
local eventGrabbed = 2
local eventClaimed = 3
local eventDelivered = 4
local eventVanished = 5

local KeyfallService = {
	Name = "KeyfallService",
	_trove = nil :: TroveInstance?,
}
local services: ServerTypes.Registry = nil :: any
local rng = Random.new()
local arena: Types.Arena? = nil
local capFolder: Folder? = nil
local caps: { Types.Cap } = {}
local carries: { [Player]: Types.Carry } = {}
local hooks: { [Player]: Types.Hook } = {}
local isDead: { [Player]: boolean } = {}
local lastKnock: { [Player]: number } = {}
local nextDropAt = 0
local nextSpacebarAt = 0
local isGoldenActive = false

local function goldenIndex(): number
	local key = Keys.Resolve(goldenId)
	return if key then key.Index else 0
end

local function announce(kind: number, name: string, keyIndex: number)
	Packets.KeyfallEvent:FireAllClients(kind, name, keyIndex)
end

local function vanishKey(keyId: string)
	if keyId == goldenId and isGoldenActive then
		isGoldenActive = false
		announce(eventVanished, "", goldenIndex())
	end
end

local function removeCap(index: number)
	local cap = table.remove(caps, index)
	if cap then
		cap.Part:Destroy()
	end
end

local function addCap(keyId: string, ground: Vector3, falls: boolean): Types.Cap
	local now = os.clock()
	local isGolden = keyId == goldenId
	local height = if isGolden then Visual.GoldenHeight else Visual.CapHeight
	local endY = ground.Y + height / 2
	local startY = if falls then endY + fallHeight else endY
	local part = Visual.Cap(keyId, isGolden, Vector3.new(ground.X, startY, ground.Z), not falls)
	part.Parent = capFolder
	local landsAt = if falls then now + fallSeconds else now
	local lifetime = if isGolden then goldenLifetimeSeconds else config.CapLifetimeSeconds
	local cap: Types.Cap = {
		Part = part,
		KeyId = keyId,
		IsGolden = isGolden,
		SpawnedAt = now,
		LandsAt = landsAt,
		ExpiresAt = landsAt + lifetime,
		PickableAt = if falls then landsAt else now + dropPickupDelay,
		StartY = startY,
		EndY = endY,
		IsLanded = not falls,
	}
	table.insert(caps, cap)
	return cap
end

local function endCarry(player: Player): Types.Carry?
	local carry = carries[player]
	if not carry then
		return nil
	end
	carries[player] = nil
	carry.Trove:Destroy()
	return carry
end

local function refreshCarry(carry: Types.Carry)
	local count = #carry.Keys
	carry.Character:SetAttribute("KeyfallCount", count)
	Visual.SetSpeed(carry.Character, Rules.CarrySpeed(count))
	for _, part in carry.Visuals do
		part:Destroy()
	end
	local root = Character.RootOfModel(carry.Character)
	carry.Visuals = if root then Visual.Stack(carry.Character, root, carry.Keys, goldenId) else {}
end

local function beginCarry(player: Player, character: Model): Types.Carry
	local carry: Types.Carry = {
		Keys = {},
		Character = character,
		Visuals = {},
		Trove = Trove.new(),
	}
	carry.Trove:Add(function()
		for _, part in carry.Visuals do
			part:Destroy()
		end
		table.clear(carry.Visuals)
		character:SetAttribute("KeyfallCount", nil)
		Visual.SetSpeed(character, steal.NormalWalkSpeed)
	end)
	carries[player] = carry
	return carry
end

local function groundBelow(position: Vector3): Vector3
	return Vector3.new(position.X, position.Y - hipHeight, position.Z)
end

local function dropCarry(player: Player, character: Model)
	local carry = carries[player]
	if not carry then
		return
	end
	local root = Character.RootOfModel(character)
	local position = if root then root.CFrame.Position else nil
	endCarry(player)
	for index, keyId in carry.Keys do
		if position then
			local angle = (index - 1) * (math.pi * 2 / math.max(#carry.Keys, 1))
			local offset = if #carry.Keys > 1
				then Vector3.new(math.cos(angle) * scatterRadius, 0, math.sin(angle) * scatterRadius)
				else Vector3.zero
			addCap(keyId, groundBelow(position) + offset, false)
		else
			vanishKey(keyId)
		end
	end
end

local function hookCharacter(player: Player, character: Model)
	local existing = hooks[player]
	if existing and existing.Character == character then
		return
	end
	if existing then
		existing.Trove:Destroy()
	end
	local trove = Trove.new()
	hooks[player] = { Character = character, Trove = trove }
	isDead[player] = nil
	local humanoid = Character.HumanoidOf(character)
	if humanoid then
		trove:Connect(humanoid.Died, function()
			isDead[player] = true
			dropCarry(player, character)
		end)
	end
	trove:Connect(player.CharacterRemoving, function(removing: Model)
		dropCarry(player, removing)
	end)
end

local function deliver(player: Player, carry: Types.Carry)
	local delivered = 0
	local remaining: { string } = {}
	for _, keyId in carry.Keys do
		if services.KeyboardService:AddKey(player, keyId) then
			local data = services.DataService:GetData(player)
			if data then
				services.DataService:Set(player, { "Discovered", keyId }, (data.Discovered[keyId] or 0) + 1)
			end
			delivered += 1
			if keyId == goldenId then
				isGoldenActive = false
				announce(eventClaimed, player.DisplayName, goldenIndex())
			end
		else
			table.insert(remaining, keyId)
		end
	end
	if #remaining == 0 then
		endCarry(player)
	else
		carry.Keys = remaining
		refreshCarry(carry)
	end
	if delivered > 0 then
		Packets.KeyfallEvent:FireClient(player, eventDelivered, "", delivered)
	end
end

local function findPickup(position: Vector3, carryCount: number, isStolen: boolean, now: number): Types.Cap?
	local best: Types.Cap? = nil
	local bestDistance = math.huge
	for _, cap in caps do
		local at = cap.Part.CFrame.Position
		local distance = math.sqrt((at.X - position.X) ^ 2 + (at.Z - position.Z) ^ 2)
		if
			distance < bestDistance
			and math.abs(at.Y - position.Y) <= verticalReach
			and Rules.CanPickup({
				CarryCount = carryCount,
				CarryingStolen = isStolen,
				IsLanded = cap.IsLanded,
				IsReady = now >= cap.PickableAt,
				Distance = distance,
			})
		then
			best = cap
			bestDistance = distance
		end
	end
	return best
end

local function pickUp(player: Player, character: Model, cap: Types.Cap)
	local index = table.find(caps, cap)
	if not index then
		return
	end
	table.remove(caps, index)
	cap.Part:Destroy()
	local carry = carries[player] or beginCarry(player, character)
	table.insert(carry.Keys, cap.KeyId)
	refreshCarry(carry)
	if cap.IsGolden then
		announce(eventGrabbed, player.DisplayName, goldenIndex())
	end
end

local function updatePlayer(player: Player, now: number)
	local character = player.Character
	local root = Character.RootOfModel(character)
	if not character or not root or not services.DataService:GetData(player) then
		return
	end
	hookCharacter(player, character)
	local carry: Types.Carry? = carries[player]
	if carry and carry.Character ~= character then
		endCarry(player)
		carry = nil
	end
	local position = root.CFrame.Position
	if carry and #carry.Keys > 0 then
		local base = services.PlotService:GetBase(player) :: BasePart?
		if base and (position - base.CFrame.Position).Magnitude <= steal.DeliverRadius then
			deliver(player, carry)
			return
		end
	end
	if isDead[player] then
		return
	end
	local cap = findPickup(
		position,
		if carry then #carry.Keys else 0,
		character:GetAttribute("CarryingKey") ~= nil,
		now
	)
	if cap then
		pickUp(player, character, cap)
	end
end

local function updateCaps(now: number)
	for index = #caps, 1, -1 do
		local cap = caps[index]
		if now >= cap.ExpiresAt then
			removeCap(index)
			if cap.IsGolden then
				vanishKey(cap.KeyId)
			end
		elseif not cap.IsLanded then
			local alpha = math.clamp((now - cap.SpawnedAt) / (cap.LandsAt - cap.SpawnedAt), 0, 1)
			local at = cap.Part.CFrame.Position
			local y = cap.StartY + (cap.EndY - cap.StartY) * alpha * alpha
			cap.Part.CFrame = CFrame.new(at.X, y, at.Z)
			if alpha >= 1 then
				cap.IsLanded = true
				cap.Part:SetAttribute("Landed", true)
			end
		end
	end
end

local function liveDropCount(): number
	local count = 0
	for _, cap in caps do
		if not cap.IsGolden then
			count += 1
		end
	end
	return count
end

local function spawnDrop(now: number)
	if now < nextDropAt then
		return
	end
	nextDropAt = now + config.DropIntervalSeconds
	local current = arena
	if not current or liveDropCount() >= config.MaxLiveCaps then
		return
	end
	local key = Roll.Pick(rng, config.DropLuck)
	addCap(key.Id, Rules.RandomPointInDisc(rng, current.Center, current.Radius), true)
end

local function spawnSpacebar(now: number)
	if now < nextSpacebarAt then
		return
	end
	nextSpacebarAt = now + Rules.NextSpacebarDelay(rng)
	local current = arena
	if not current or isGoldenActive then
		return
	end
	isGoldenActive = true
	addCap(goldenId, Rules.RandomPointInDisc(rng, current.Center, current.Radius), true)
	announce(eventAnnounce, "", goldenIndex())
end

local function step()
	local now = os.clock()
	updateCaps(now)
	spawnDrop(now)
	spawnSpacebar(now)
	for _, player in Players:GetPlayers() do
		updatePlayer(player, now)
	end
end

local function knock(player: Player, targetUserId: number): boolean
	if type(targetUserId) ~= "number" then
		return false
	end
	local target = Players:GetPlayerByUserId(targetUserId)
	local carry = if target then carries[target] else nil
	local ownRoot = Character.RootOfModel(player.Character)
	local targetRoot = if target then Character.RootOfModel(target.Character) else nil
	if not target or not ownRoot or not targetRoot then
		return false
	end
	local now = os.clock()
	local isAllowed, reason = Rules.CanKnock({
		CallerUserId = player.UserId,
		TargetUserId = target.UserId,
		Distance = (ownRoot.CFrame.Position - targetRoot.CFrame.Position).Magnitude,
		TargetCarryCount = if carry then #carry.Keys else 0,
		Now = now,
		LastKnockAt = lastKnock[player],
	})
	if reason ~= Rules.Reasons.Cooldown then
		lastKnock[player] = now
	end
	if not isAllowed or not carry then
		return false
	end
	local keyId = table.remove(carry.Keys)
	if keyId == nil then
		return false
	end
	if #carry.Keys == 0 then
		endCarry(target)
	else
		refreshCarry(carry)
	end
	addCap(keyId, groundBelow(targetRoot.CFrame.Position), false)
	return true
end

local function release(player: Player)
	local carry = endCarry(player)
	if carry then
		for _, keyId in carry.Keys do
			vanishKey(keyId)
		end
	end
	local hook = hooks[player]
	if hook then
		hooks[player] = nil
		hook.Trove:Destroy()
	end
	isDead[player] = nil
	lastKnock[player] = nil
end

function KeyfallService.IsCarrying(_self: State, player: Player): boolean
	local carry = carries[player]
	return carry ~= nil and #carry.Keys > 0
end

function KeyfallService.Init(self: State, registry: { [string]: any })
	services = registry :: any
	self._trove = Trove.new()
end

function KeyfallService.Start(self: State)
	local trove = self._trove :: TroveInstance
	if not config.Enabled then
		Packets.Knock.OnServerInvoke = function()
			return false
		end
		return
	end
	local now = os.clock()
	arena = Arena.Resolve()
	local folder = Instance.new("Folder")
	folder.Name = "KeyfallCaps"
	folder.Parent = workspace
	trove:Add(folder)
	capFolder = folder
	nextDropAt = now + config.DropIntervalSeconds
	nextSpacebarAt = now + Rules.NextSpacebarDelay(rng)
	trove:Add(Players.PlayerRemoving:Connect(release))
	Packets.Knock.OnServerInvoke = knock
	trove:Add(task.spawn(function()
		while true do
			task.wait(stepSeconds)
			step()
		end
	end))
end

function KeyfallService.Destroy(self: State)
	Packets.Knock.OnServerInvoke = nil
	for player in table.clone(carries) do
		endCarry(player)
	end
	for player, hook in table.clone(hooks) do
		hooks[player] = nil
		hook.Trove:Destroy()
	end
	table.clear(caps)
	table.clear(isDead)
	table.clear(lastKnock)
	isGoldenActive = false
	capFolder = nil
	local current = arena
	arena = nil
	if current then
		current.Trove:Destroy()
	end
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return KeyfallService
