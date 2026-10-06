--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CharmConfig = require(ReplicatedStorage.Config.Charms)
local WorldNames = require(ReplicatedStorage.Config.WorldNames)
local Packets = require(ReplicatedStorage.Packets)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Config = require(script.Config)
local Walkers = require(script.Walkers)

local Folders = WorldNames.Folders

type TroveInstance = typeof(Trove.new())

type State = {
	Name: string,
	Hatched: Signal.Signal<string, string, boolean>,
	Hatch: (self: State, index: number, eggId: string) -> (),
	_trove: TroveInstance?,
}

local CharmController = {
	Name = "CharmController",
	Hatched = Signal.new() :: Signal.Signal<string, string, boolean>,
	_trove = nil :: TroveInstance?,
}
local controllers: { [string]: any } = {}
local walkers = Walkers.New()
local isHatching = false

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
			controllers.UIController:Toast(Config.NotReadyToast, "Bad")
		end
	end)
end

function CharmController.Init(self: State, registry: { [string]: any })
	controllers = registry
	self._trove = Trove.new()
end

function CharmController.Start(self: State)
	local trove = self._trove :: TroveInstance
	trove:Connect(RunService.Heartbeat, function(dt: number)
		local camera = workspace.CurrentCamera
		Walkers.Step(walkers, dt, if camera then camera.CFrame.Position else nil)
	end)
	trove:Add(
		controllers.PlotController:WatchItems(
			Folders.Pets,
			function(plot: Model, model: Model, itemTrove: TroveInstance)
				Walkers.Register(walkers, plot, model)
				itemTrove:Add(function()
					Walkers.Remove(walkers, model)
				end)
			end
		)
	)
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
