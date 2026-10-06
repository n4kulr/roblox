--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Eggs = require(ReplicatedStorage.Config.Eggs)
local Packets = require(ReplicatedStorage.Packets)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Orbit = require(script.Orbit)

type TroveInstance = typeof(Trove.new())
type PlayerOrbit = Orbit.Orbit

type State = {
	Name: string,
	Hatched: Signal.Signal<string, string>,
	Hatch: (self: State, slot: number, eggId: string) -> (),
	_trove: TroveInstance?,
}

local scanSeconds = 1
local promptHold = 0.6
local promptRange = 12
local attributeName = "EquippedCharms"
local folderName = "Incubators"
local promptName = "HatchPrompt"

local CharmController = {
	Name = "CharmController",
	Hatched = Signal.new() :: Signal.Signal<string, string>,
	_trove = nil :: TroveInstance?,
}
local controllers: { [string]: any } = {}
local orbits: { [Player]: PlayerOrbit } = {}
local visuals: Folder? = nil
local isHatching = false

local function clearOrbit(player: Player)
	local orbit = orbits[player]
	orbits[player] = nil
	if orbit then
		for _, model in orbit.Models do
			model:Destroy()
		end
	end
end

local function syncOrbit(player: Player)
	local parent = visuals
	if not parent then
		return
	end
	local text = player:GetAttribute(attributeName)
	local current = orbits[player]
	local key = if type(text) == "string" then text else ""
	if current and current.Ids == key then
		return
	end
	clearOrbit(player)
	local ids = Orbit.Parse(key)
	if #ids == 0 then
		return
	end
	local models: { Model } = {}
	for _, id in ids do
		local model = Orbit.BuildCharm(parent, id)
		if model then
			table.insert(models, model)
		end
	end
	orbits[player] = { Ids = key, Models = models }
end

local function stepOrbits()
	local now = os.clock()
	for player, orbit in orbits do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if root and root:IsA("BasePart") then
			for index, model in orbit.Models do
				Orbit.Place(model, root.CFrame, index, #orbit.Models, now)
			end
		end
	end
end

local function toast(text: string, kind: string)
	local ui = controllers.UIController
	if ui then
		ui:Toast(text, kind)
	end
end

function CharmController.Hatch(_self: State, slot: number, eggId: string)
	if isHatching then
		return
	end
	isHatching = true
	task.spawn(function()
		local charmId = Packets.HatchEgg:Fire(slot)
		isHatching = false
		if type(charmId) == "string" and charmId ~= "" then
			CharmController.Hatched:Fire(eggId, charmId)
		else
			toast("Not ready yet!", "Bad")
		end
	end)
end

local function syncPrompt(self: State, model: Model, isMine: boolean)
	local pedestal = model:FindFirstChild("Pedestal")
	if not pedestal or not pedestal:IsA("BasePart") then
		return
	end
	local existing = pedestal:FindFirstChild(promptName)
	local prompt = if existing and existing:IsA("ProximityPrompt") then existing else nil
	local eggId = model:GetAttribute("EggId")
	local readyAt = model:GetAttribute("ReadyAt")
	local egg = if type(eggId) == "string" then Eggs.ById[eggId] else nil
	local isReady = isMine and egg ~= nil and type(readyAt) == "number" and os.time() >= readyAt
	if not isReady then
		if prompt then
			prompt:Destroy()
		end
		return
	end
	if prompt then
		return
	end
	local created = Instance.new("ProximityPrompt")
	created.Name = promptName
	created.ActionText = "Hatch"
	created.ObjectText = (egg :: Eggs.Egg).Name
	created.HoldDuration = promptHold
	created.MaxActivationDistance = promptRange
	created.RequiresLineOfSight = false
	created.KeyboardKeyCode = Enum.KeyCode.E
	created.Parent = pedestal
	local slot = model:GetAttribute("Index")
	created.Triggered:Connect(function()
		if type(slot) == "number" then
			self:Hatch(slot, (egg :: Eggs.Egg).Id)
		end
	end)
end

local function scanPlots(self: State)
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return
	end
	local userId = Players.LocalPlayer.UserId
	for _, plot in plots:GetChildren() do
		local folder = plot:FindFirstChild(folderName)
		if folder then
			local isMine = plot:GetAttribute("Owner") == userId
			for _, model in folder:GetChildren() do
				if model:IsA("Model") then
					syncPrompt(self, model, isMine)
				end
			end
		end
	end
end

function CharmController.Init(self: State, registry: { [string]: any })
	controllers = registry
	self._trove = Trove.new()
end

function CharmController.Start(self: State)
	local trove = self._trove :: TroveInstance
	local folder = Instance.new("Folder")
	folder.Name = "CharmVisuals"
	folder.Parent = workspace
	trove:Add(folder)
	visuals = folder
	local function watch(player: Player)
		syncOrbit(player)
		trove:Connect(player:GetAttributeChangedSignal(attributeName), function()
			syncOrbit(player)
		end)
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	trove:Connect(Players.PlayerAdded, watch)
	trove:Connect(Players.PlayerRemoving, clearOrbit)
	trove:Connect(RunService.Heartbeat, stepOrbits)
	trove:Add(task.spawn(function()
		while true do
			scanPlots(self)
			task.wait(scanSeconds)
		end
	end))
end

function CharmController.Destroy(self: State)
	for player in orbits do
		clearOrbit(player)
	end
	visuals = nil
	isHatching = false
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return CharmController
