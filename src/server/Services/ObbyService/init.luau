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
local Gates = require(script.Gates)
local Pickups = require(script.Pickups)
local PopUps = require(script.PopUps)
local Taps = require(script.Taps)
local Types = require(script.Types)

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	_trove: TroveInstance?,
}

local config = GameConfig.Obby
local goodPhase = 11
local badPhase = 9

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
local popUps: { PopUps.State } = {}

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
			LastKey = nil,
			LastPosition = nil,
			GateToastAt = 0,
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

local onTriggered: (state: Types.SpawnState, player: Player) -> ()

local function spawnPickup(state: Types.SpawnState, info: Types.Info)
	local keyId = Pickups.PickKey(rng, state.Point.Rarities)
	local cap, prompt = Pickups.Create(state.Point, keyId, info.Model)
	if cap and prompt then
		state.Pickup = cap
		state.Trove:Add(cap)
		state.Trove:Connect(prompt.Triggered, function(player: Player)
			onTriggered(state, player)
		end)
	end
end

local function takePickup(state: Types.SpawnState): string?
	local cap = state.Pickup
	if not cap then
		return nil
	end
	local keyId = cap:GetAttribute("KeyId")
	state.Pickup = nil
	state.Trove:Clean()
	state.RespawnAt = os.clock() + config.RespawnSeconds
	return if type(keyId) == "string" then keyId else nil
end

function onTriggered(state: Types.SpawnState, player: Player)
	local cap = state.Pickup
	local track = tracks[player]
	if not cap or not track or not track.IsInside or carriers[player] or isStealing(player) then
		return
	end
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not character or not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return
	end
	if
		(cap.CFrame.Position - root.CFrame.Position).Magnitude
		> config.Pickup.Distance + config.Pickup.Slack
	then
		return
	end
	local keyId = takePickup(state)
	local key = if keyId then Keys.ById[keyId] else nil
	if keyId and key then
		startCarry(player, character, root, humanoid, keyId)
		toast(player, `You grabbed {key.Name}! Run home to keep it!`, goodPhase)
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

local function applySpeed(character: Model, speed: number?)
	if character:GetAttribute(WalkSpeed.TapAttribute) ~= speed then
		character:SetAttribute(WalkSpeed.TapAttribute, speed)
		WalkSpeed.Refresh(character)
	end
end

local function clearTaps(character: Model, track: Types.Track)
	track.Taps = 0
	track.LastKey = nil
	track.LastPosition = nil
	character:SetAttribute("ObbyTaps", nil)
	applySpeed(character, nil)
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

local function update(
	player: Player,
	character: Model,
	root: BasePart,
	humanoid: Humanoid,
	track: Types.Track,
	info: Types.Info,
	now: number
)
	local position = root.CFrame.Position
	local isInside = Obby.Contains(info.Zone.CFrame, info.Zone.Size, position, 0)
	track.IsInside = isInside
	if not isInside then
		setCheckpoint(player, track, nil)
		clearTaps(character, track)
		tryDeliver(player, root)
		return
	end
	if isInsideAny(info.Kills, position, config.KillReach) then
		humanoid.Health = 0
		return
	end
	local checkpoint = isInsideAny(info.Checkpoints, position, config.CheckpointReach)
	if checkpoint then
		setCheckpoint(player, track, checkpoint)
	end
	if isInsideAny(info.Homes, position, config.HomeReach) then
		services.PlotService:SendHome(player)
		return
	end
	local gate = Gates.Check(info.Gates, root.CFrame, Obby.SpeedFor(track.Taps))
	if gate then
		if gate.Passed and gate.Destination then
			root.CFrame = gate.Destination
			position = gate.Destination.Position
			track.LastPosition = nil
			track.LastKey = nil
			toast(player, "Speed gate open!", goodPhase)
		elseif now >= track.GateToastAt then
			track.GateToastAt = now + config.Gate.ToastSeconds
			toast(player, `Need {gate.Required} speed!`, badPhase)
		end
	end
	track.Taps += Taps.Advance(info.TapKeys, track, position)
	if character:GetAttribute("ObbyTaps") ~= track.Taps then
		character:SetAttribute("ObbyTaps", track.Taps)
	end
	applySpeed(character, Obby.SpeedFor(track.Taps))
	tryDeliver(player, root)
end

local function step()
	local info = course
	if not info then
		return
	end
	local now = os.clock()
	for _, state in popUps do
		PopUps.Step(state, now)
	end
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
			track.LastKey = nil
			track.LastPosition = nil
		end
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if character and root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
			update(player, character, root, humanoid, track, info, now)
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
	for _, part in info.PopUps do
		table.insert(popUps, PopUps.New(part))
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

function ObbyService.Destroy(self: State)
	for player in table.clone(carriers) do
		endCarry(player)
	end
	for player, track in table.clone(tracks) do
		local character = track.Character
		if character then
			character:SetAttribute("ObbyTaps", nil)
			character:SetAttribute(WalkSpeed.TapAttribute, nil)
			WalkSpeed.Refresh(character)
		end
		if services.PlotService and track.Checkpoint then
			services.PlotService:SetRespawn(player, nil)
		end
	end
	table.clear(tracks)
	for _, state in popUps do
		PopUps.Reset(state)
	end
	table.clear(popUps)
	table.clear(spawnStates)
	course = nil
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return ObbyService
