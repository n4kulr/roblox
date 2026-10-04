--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Obby = require(ReplicatedStorage.Rules.Obby)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local KeyVisual = require(script.Parent.Parent.Utils.KeyVisual)
local WalkSpeed = require(script.Parent.Parent.Utils.WalkSpeed)
local Course = require(script.Course)
local Finder = require(script.Finder)
local Pickups = require(script.Pickups)
local Types = require(script.Types)

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	_trove: TroveInstance?,
}

local config = GameConfig.Obby
local infoPhase = 10
local goodPhase = 11
local badPhase = 9
local tapsAttribute = "ObbyTaps"

local ObbyService = {
	Name = "ObbyService",
	_trove = nil :: TroveInstance?,
}
local services: { [string]: any } = {}
local rng = Random.new()
local course: Types.Info? = nil
local spawnStates: { Types.SpawnState } = {}
local carriers: { [Player]: Types.Carrier } = {}
local tracks: { [Player]: Types.Track } = {}

local function toast(player: Player, text: string, phase: number)
	Packets.StealAlert:FireClient(player, text, 0, phase)
end

local function isStealing(player: Player): boolean
	local steal = services.StealService
	local keyfall = services.KeyfallService
	return (steal ~= nil and steal:IsCarrying(player) == true)
		or (keyfall ~= nil and keyfall:IsCarrying(player) == true)
end

local function trackOf(player: Player): Types.Track
	local track = tracks[player]
	if not track then
		track = {
			Character = nil,
			IsInside = false,
			Checkpoint = nil,
			Taps = 0,
			Pressed = {},
		}
		tracks[player] = track
	end
	return track
end

local function endCarry(player: Player): Types.Carrier?
	local carrier = carriers[player]
	if not carrier then
		return nil
	end
	carriers[player] = nil
	carrier.Trove:Destroy()
	return carrier
end

local function loseCarry(player: Player)
	if endCarry(player) then
		toast(player, "You lost the key!", badPhase)
	end
end

local function startCarry(player: Player, character: Model, root: BasePart, humanoid: Humanoid, keyId: string)
	local carryTrove = Trove.new()
	carriers[player] = { KeyId = keyId, Trove = carryTrove }
	local visual = KeyVisual.Attach(character, root, keyId, "ObbyKeyCarried")
	if visual then
		carryTrove:Add(visual)
	end
	character:SetAttribute("CarryingKey", keyId)
	carryTrove:Add(function()
		character:SetAttribute("CarryingKey", nil)
	end)
	carryTrove:Connect(humanoid.Died, function()
		loseCarry(player)
	end)
	carryTrove:Connect(player.CharacterRemoving, function()
		loseCarry(player)
	end)
end

local function spawnPickup(state: Types.SpawnState, info: Types.Info)
	local keyId = Pickups.PickKey(rng, state.Point.Section)
	local cap = Pickups.Create(state.Point, keyId, info.Model)
	if not cap then
		return
	end
	state.Pickup = cap
	state.Trove:Add(cap)
	local prompt = cap:FindFirstChild(Pickups.PromptName)
	if prompt and prompt:IsA("ProximityPrompt") then
		state.Trove:Connect(prompt.Triggered, function(player: Player)
			if carriers[player] or isStealing(player) then
				return
			end
			if state.Pickup ~= cap then
				return
			end
			local character = player.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
			if
				not character
				or not root
				or not root:IsA("BasePart")
				or not humanoid
				or humanoid.Health <= 0
			then
				return
			end
			local taken = cap:GetAttribute("KeyId")
			state.Pickup = nil
			state.Trove:Clean()
			state.RespawnAt = os.clock() + config.RespawnSeconds
			local key = if type(taken) == "string" then Keys.ById[taken] else nil
			if type(taken) == "string" and key then
				startCarry(player, character, root, humanoid, taken)
				toast(player, `You took {key.Name}! Run home to keep it!`, goodPhase)
			end
		end)
	end
end

local function tryDeliver(player: Player, root: BasePart)
	local carrier = carriers[player]
	local base = services.PlotService:GetBase(player) :: BasePart?
	if not carrier or not base then
		return
	end
	if (root.CFrame.Position - base.CFrame.Position).Magnitude > GameConfig.Steal.DeliverRadius then
		return
	end
	endCarry(player)
	local data = services.DataService:GetData(player) :: PlayerData.Data?
	local key = Keys.ById[carrier.KeyId]
	if not data or not key or not services.KeyboardService:AddKey(player, carrier.KeyId) then
		return
	end
	services.DataService:Set(player, { "Discovered", key.Id }, (data.Discovered[key.Id] or 0) + 1)
	services.DataService:RequestSave(player)
	toast(player, `{key.Name} added to your keys!`, goodPhase)
end

local function applySpeed(character: Model, taps: number, inside: boolean)
	local speed = if inside then Obby.SpeedFor(taps) else nil
	if character:GetAttribute(WalkSpeed.TapAttribute) ~= speed then
		character:SetAttribute(WalkSpeed.TapAttribute, speed)
		WalkSpeed.Refresh(character)
	end
	local shown = if inside then taps else nil
	if character:GetAttribute(tapsAttribute) ~= shown then
		character:SetAttribute(tapsAttribute, shown)
	end
end

local function setCheckpoint(player: Player, track: Types.Track, part: BasePart?)
	if track.Checkpoint == part then
		return
	end
	track.Checkpoint = part
	local cframe = if part then part.CFrame * CFrame.new(0, part.Size.Y / 2 + 4, 0) else nil
	services.PlotService:SetRespawn(player, cframe)
end

local function isInsideAny(parts: { BasePart }, position: Vector3, reach: number): BasePart?
	for _, part in parts do
		if Obby.Contains(part.CFrame, part.Size, position, reach) then
			return part
		end
	end
	return nil
end

local function pressKey(tap: Types.TapPart)
	local part = tap.Part
	part.CFrame = tap.Rest * CFrame.new(0, -config.PressDepth, 0)
	task.delay(config.PressSeconds, function()
		if part.Parent then
			part.CFrame = tap.Rest
		end
	end)
end

local function tryTap(player: Player, track: Types.Track, root: BasePart, info: Types.Info)
	local now = os.clock()
	local position = root.CFrame.Position
	for _, tap in info.Taps do
		local part = tap.Part
		if part.CanCollide and Obby.Contains(part.CFrame, part.Size, position, config.TapReach) then
			local last = track.Pressed[part]
			if last and now - last < config.TapCooldown then
				continue
			end
			track.Pressed[part] = now
			track.Taps += 1
			pressKey(tap)
			applySpeed(root.Parent :: Model, track.Taps, true)
			if track.Taps == 1 or track.Taps % 10 == 0 then
				toast(player, `Speed {Obby.SpeedFor(track.Taps)}  (+{track.Taps} taps)`, infoPhase)
			end
			return
		end
	end
end

local function updatePopups(info: Types.Info, now: number)
	for _, popup in info.Popups do
		local cycle = popup.UpSeconds + popup.DownSeconds
		if cycle <= 0 then
			continue
		end
		local t = (now + popup.Phase) % cycle
		local shouldUp = t < popup.UpSeconds
		if shouldUp ~= popup.IsUp then
			popup.IsUp = shouldUp
			popup.Part.CFrame = if shouldUp then popup.Up else popup.Down
			popup.Part.CanCollide = shouldUp
		end
	end
end

local function enforceGates(player: Player, track: Types.Track, root: BasePart, info: Types.Info)
	local speed = Obby.SpeedFor(track.Taps)
	local position = root.CFrame.Position
	for _, gate in info.Gates do
		if speed >= gate.SpeedNeeded then
			continue
		end
		if Obby.Contains(gate.Part.CFrame, gate.Part.Size + Vector3.new(0, 8, 6), position, 2) then
			local behind = gate.Part.CFrame
				* CFrame.new(0, -gate.Part.Size.Y / 2 + 4, gate.Part.Size.Z / 2 + 6)
			root.CFrame = CFrame.new(behind.Position) * (root.CFrame - root.CFrame.Position)
			toast(player, `Need {gate.SpeedNeeded} speed!`, badPhase)
			return
		end
	end
end

local function update(
	player: Player,
	character: Model,
	root: BasePart,
	humanoid: Humanoid,
	track: Types.Track,
	info: Types.Info
)
	local position = root.CFrame.Position
	local isInside = Obby.Contains(info.Zone.CFrame, info.Zone.Size, position, 0)
	if isInside ~= track.IsInside then
		track.IsInside = isInside
		if isInside then
			toast(player, "Tap keys to gain speed!", infoPhase)
		else
			track.Taps = 0
			table.clear(track.Pressed)
			setCheckpoint(player, track, nil)
		end
	end
	applySpeed(character, track.Taps, isInside)
	if isInside then
		if isInsideAny(info.Kills, position, config.KillReach) then
			humanoid.Health = 0
			return
		end
		local checkpoint = isInsideAny(info.Checkpoints, position, config.CheckpointReach)
		if checkpoint then
			setCheckpoint(player, track, checkpoint)
		end
		if isInsideAny(info.Returns, position, config.ReturnReach) then
			services.PlotService:SendHome(player)
		end
		tryTap(player, track, root, info)
		enforceGates(player, track, root, info)
	end
	tryDeliver(player, root)
end

local function step()
	local info = course
	if not info then
		return
	end
	local now = os.clock()
	updatePopups(info, now)
	for _, state in spawnStates do
		if not state.Pickup and now >= state.RespawnAt then
			spawnPickup(state, info)
		end
	end
	for _, player in Players:GetPlayers() do
		local track = trackOf(player)
		local character = player.Character
		if character ~= track.Character then
			track.Character = character
			track.IsInside = false
		end
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if character and root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
			update(player, character, root, humanoid, track, info)
		end
	end
end

local function bindCourse(trove: TroveInstance): Types.Info
	local authored = Finder.FindAuthored(Course.ModelName)
	if authored then
		return authored
	end
	local existing = workspace:FindFirstChild(Course.ModelName)
	local name = if existing then "ObbyPlaceholder" else Course.ModelName
	if existing then
		warn("[ObbyService] workspace.Obby needs a BasePart with ObbyRole Zone; building a placeholder")
	end
	local model = Course.Build(Obby.Entrance(Finder.MarketPosition()), name)
	model.Parent = workspace
	trove:Add(model)
	return Finder.Collect(model) :: Types.Info
end

local function forget(player: Player)
	endCarry(player)
	tracks[player] = nil
end

function ObbyService.Init(self: State, registry: { [string]: any })
	services = registry
	self._trove = Trove.new()
end

function ObbyService.Start(self: State)
	local trove = self._trove :: TroveInstance
	local info = bindCourse(trove)
	course = info
	for _, point in info.Spawns do
		local state: Types.SpawnState = { Point = point, Pickup = nil, Trove = Trove.new(), RespawnAt = 0 }
		table.insert(spawnStates, state)
		trove:Add(state.Trove)
		spawnPickup(state, info)
	end
	trove:Connect(Players.PlayerRemoving, forget)
	trove:Add(task.spawn(function()
		while true do
			task.wait(config.TickSeconds)
			step()
		end
	end))
end

function ObbyService.IsCarrying(_self: State, player: Player): boolean
	return carriers[player] ~= nil
end

function ObbyService.GetTaps(_self: State, player: Player): number
	local track = tracks[player]
	return if track then track.Taps else 0
end

function ObbyService.Destroy(self: State)
	for player in table.clone(carriers) do
		endCarry(player)
	end
	for player, track in table.clone(tracks) do
		local character = track.Character
		if character then
			character:SetAttribute(WalkSpeed.TapAttribute, nil)
			character:SetAttribute(tapsAttribute, nil)
			WalkSpeed.Refresh(character)
		end
		if services.PlotService and track.Checkpoint then
			services.PlotService:SetRespawn(player, nil)
		end
	end
	table.clear(tracks)
	table.clear(spawnStates)
	course = nil
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return ObbyService
