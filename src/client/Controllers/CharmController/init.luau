--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CharmConfig = require(ReplicatedStorage.Config.Charms)
local Eggs = require(ReplicatedStorage.Config.Eggs)
local Packets = require(ReplicatedStorage.Packets)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Walkers = require(script.Walkers)

type TroveInstance = typeof(Trove.new())

type State = {
	Name: string,
	Hatched: Signal.Signal<string, string, boolean>,
	Hatch: (self: State, index: number, eggId: string) -> (),
	_trove: TroveInstance?,
}

local scanSeconds = 1
local promptHold = 0.6
local promptRange = 12
local folderName = "PlacedEggs"
local promptName = "HatchPrompt"

local CharmController = {
	Name = "CharmController",
	Hatched = Signal.new() :: Signal.Signal<string, string, boolean>,
	_trove = nil :: TroveInstance?,
}
local controllers: { [string]: any } = {}
local walkers = Walkers.New()
local isHatching = false

local function toast(text: string, kind: string)
	local ui = controllers.UIController
	if ui then
		ui:Toast(text, kind)
	end
end

function CharmController.Hatch(_self: State, index: number, eggId: string)
	if isHatching then
		return
	end
	isHatching = true
	task.spawn(function()
		local charmId, isActive = Packets.HatchEgg:Fire(index)
		isHatching = false
		local pet = if type(charmId) == "string" then CharmConfig.ById[charmId] else nil
		if pet then
			CharmController.Hatched:Fire(eggId, pet.Id, isActive == true)
		else
			toast("Not ready yet!", "Bad")
		end
	end)
end

local function syncPrompt(self: State, model: Model, isMine: boolean)
	local body = model:FindFirstChild("EggBody")
	if not body or not body:IsA("BasePart") then
		return
	end
	local existing = body:FindFirstChild(promptName)
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
	created.Parent = body
	created.Triggered:Connect(function()
		local index = model:GetAttribute("Index")
		if type(index) == "number" then
			self:Hatch(index, (egg :: Eggs.Egg).Id)
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
	trove:Connect(RunService.Heartbeat, function(dt: number)
		Walkers.Step(walkers, dt)
	end)
	trove:Add(task.spawn(function()
		while true do
			scanPlots(self)
			local plots = workspace:FindFirstChild("Plots")
			if plots then
				Walkers.Sync(walkers, plots)
			end
			task.wait(scanSeconds)
		end
	end))
end

function CharmController.Destroy(self: State)
	Walkers.Clear(walkers)
	isHatching = false
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return CharmController
