--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local Trove = require(ReplicatedStorage.Packages.Trove)

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	_trove: TroveInstance?,
}

local KeyboardController = {
	Name = "KeyboardController",
	_trove = nil :: TroveInstance?,
}
local controllers: { [string]: any } = {}
local board: { string } = {}
local hasBoard = false

local function findCap(slot: number): BasePart?
	local folder = workspace:FindFirstChild("Plots")
	if not folder then
		return nil
	end
	for _, model in folder:GetChildren() do
		if model:GetAttribute("Owner") == Players.LocalPlayer.UserId then
			local keysFolder = model:FindFirstChild("Keys")
			local cap = if keysFolder then keysFolder:FindFirstChild(`Slot{slot}`) else nil
			return if cap and cap:IsA("BasePart") then cap else nil
		end
	end
	return nil
end

local function onBoardChanged(value: any)
	local previous = board
	local current: { string } = {}
	if type(value) == "table" then
		for slot = 1, GameConfig.BoardSlots do
			local keyId = value[slot]
			if type(keyId) == "string" then
				current[slot] = keyId
			end
		end
	end
	board = current
	if not hasBoard then
		hasBoard = true
		return
	end
	for slot = 1, GameConfig.BoardSlots do
		local keyId = board[slot]
		local key = if type(keyId) == "string" then Keys.ById[keyId] else nil
		if key and previous[slot] ~= keyId then
			local cap = findCap(slot)
			controllers.SoundController:PlaySwitch(
				key.Switch,
				"Press",
				1,
				1,
				if cap then cap.Position else nil,
				"Board"
			)
		end
	end
end

function KeyboardController.Init(self: State, registry: { [string]: any })
	controllers = registry
	self._trove = Trove.new()
end

function KeyboardController.Start(self: State)
	local trove = self._trove :: TroveInstance
	trove:Add(controllers.DataController:Observe({ "Board" }, onBoardChanged))
end

function KeyboardController.Destroy(self: State)
	table.clear(board)
	hasBoard = false
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return KeyboardController
