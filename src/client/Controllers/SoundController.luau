--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Keys = require(ReplicatedStorage.Config.Keys)
local Trove = require(ReplicatedStorage.Packages.Trove)

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	_trove: TroveInstance?,
}

local poolSize = 12
local maxPlaying = 16

local SoundController = {
	Name = "SoundController",
	_trove = nil :: TroveInstance?,
}
local pool: { Sound } = {}
local cursor = 0

local function acquire(): Sound?
	if #pool == 0 then
		return nil
	end
	local playing = 0
	for _, sound in pool do
		if sound.IsPlaying then
			playing += 1
		end
	end
	cursor = cursor % #pool + 1
	if playing >= maxPlaying then
		return nil
	end
	return pool[cursor]
end

function SoundController.Init(self: State, _controllers: { [string]: any })
	self._trove = Trove.new()
end

function SoundController.Start(self: State)
	local trove = self._trove :: TroveInstance
	local folder = Instance.new("Folder")
	folder.Name = "ThockSounds"
	for index = 1, poolSize do
		local sound = Instance.new("Sound")
		sound.Name = `Pooled{index}`
		sound.RollOffMaxDistance = 0
		sound.Parent = folder
		table.insert(pool, sound)
	end
	folder.Parent = SoundService
	trove:Add(folder)
end

function SoundController.Play(
	_self: State,
	settings: Keys.SoundSettings,
	pitchMultiplier: number?,
	volumeMultiplier: number?
)
	local sound = acquire()
	if not sound then
		return
	end
	sound.SoundId = settings.SoundId
	sound.PlaybackSpeed = settings.PlaybackSpeed * (pitchMultiplier or 1)
	sound.Volume = settings.Volume * (volumeMultiplier or 1)
	sound.TimePosition = 0
	sound:Play()
end

function SoundController.PlaySwell(_self: State, settings: Keys.SoundSettings, seconds: number)
	local sound = acquire()
	if not sound then
		return
	end
	sound.SoundId = settings.SoundId
	sound.PlaybackSpeed = settings.PlaybackSpeed * 0.5
	sound.Volume = settings.Volume * 0.5
	sound.Looped = true
	sound.TimePosition = 0
	sound:Play()
	local tween = TweenService:Create(
		sound,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ PlaybackSpeed = settings.PlaybackSpeed * 1.4, Volume = settings.Volume }
	)
	tween.Completed:Once(function()
		sound:Stop()
		sound.Looped = false
		tween:Destroy()
	end)
	tween:Play()
end

function SoundController.Destroy(self: State)
	table.clear(pool)
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return SoundController
