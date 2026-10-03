--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local Trove = require(ReplicatedStorage.Packages.Trove)

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	_trove: TroveInstance?,
}

local stepSeconds = 0.5
local ambientVolume = 0.15

local KeyboardController = {
	Name = "KeyboardController",
	_trove = nil :: TroveInstance?,
}
local controllers: { [string]: any } = {}
local board: { string } = {}
local cursor = 0

local function step()
	local slots = GameConfig.BoardSlots
	for offset = 1, slots do
		local slot = (cursor + offset - 1) % slots + 1
		local keyId = board[slot]
		local key = if type(keyId) == "string" then Keys.ById[keyId] else nil
		if key then
			cursor = slot
			local sound = Keys.GetRarity(key).Sound
			controllers.SoundController:Play(sound, 1, ambientVolume / sound.Volume)
			return
		end
	end
end

function KeyboardController.Init(self: State, registry: { [string]: any })
	controllers = registry
	self._trove = Trove.new()
end

function KeyboardController.Start(self: State)
	local trove = self._trove :: TroveInstance
	trove:Add(controllers.DataController:Observe({ "Board" }, function(value: any)
		board = if type(value) == "table" then value else {}
	end))
	trove:Add(task.spawn(function()
		while true do
			task.wait(stepSeconds)
			step()
		end
	end))
end

function KeyboardController.Destroy(self: State)
	table.clear(board)
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return KeyboardController
