--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local MeshTemplates = require(script.Parent.Parent.Utils.MeshTemplates)

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	Changed: Signal.Signal<string>,
	_trove: TroveInstance?,
}

local MeshService = {
	Name = "MeshService",
	WaitSeconds = 6,
	Changed = Signal.new() :: Signal.Signal<string>,
	_trove = nil :: TroveInstance?,
}

function MeshService.Init(self: State, _services: { [string]: any })
	self._trove = Trove.new()
end

function MeshService.Start(self: State)
	local trove = self._trove :: TroveInstance
	MeshTemplates.Load()
	trove:Connect(MeshTemplates.Changed, function(name: string)
		MeshTemplates.Replicate()
		MeshService.Changed:Fire(name)
	end)
end

function MeshService.Get(_self: State, name: MeshTemplates.Name): MeshPart?
	return MeshTemplates.Get(name)
end

function MeshService.Wait(_self: State, timeout: number?)
	MeshTemplates.Wait(timeout or MeshService.WaitSeconds)
	MeshTemplates.Replicate()
end

function MeshService.Destroy(self: State)
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
	MeshTemplates.Destroy()
end

return MeshService
