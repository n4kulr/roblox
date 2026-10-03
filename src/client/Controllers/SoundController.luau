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
type Voice = {
	Sound: Sound,
	Equalizer: EqualizerSoundEffect,
	Attachment: Attachment,
}

local poolSize = 20
local maxPlaying = 16
local pitchVariance = 0.03
local rollOffMaxDistance = 60

local SoundController = {
	Name = "SoundController",
	_trove = nil :: TroveInstance?,
}
local controllers: { [string]: any } = {}
local pool: { Voice } = {}
local cursor = 0
local home: Folder? = nil
local random = Random.new()
local volumes: { [string]: number } = { Roll = 1, Board = 1, Other = 1 }
local settingByCategory: { [string]: string } = {
	Roll = "RollVolume",
	Board = "BoardVolume",
	Other = "OtherVolume",
}
local flatTone: Keys.Tone = table.freeze({ LowGain = 0, MidGain = 0, HighGain = 0 })
local uiSounds: { [string]: Keys.SoundLayer } = {
	Click = table.freeze({ SoundId = Keys.SoundAssets.Thock, PlaybackSpeed = 1.7, Volume = 0.3 }),
	Confirm = table.freeze({ SoundId = Keys.SoundAssets.Chime, PlaybackSpeed = 1.1, Volume = 0.35 }),
	Error = table.freeze({ SoundId = Keys.SoundAssets.Thud, PlaybackSpeed = 0.9, Volume = 0.45 }),
}

local function acquire(): Voice?
	local count = #pool
	if count == 0 then
		return nil
	end
	local playing = 0
	for _, voice in pool do
		if voice.Sound.IsPlaying then
			playing += 1
		end
	end
	if playing >= maxPlaying then
		return nil
	end
	for _ = 1, count do
		cursor = cursor % count + 1
		local voice = pool[cursor]
		if not voice.Sound.IsPlaying then
			return voice
		end
	end
	return nil
end

local function prepare(voice: Voice, tone: Keys.Tone, position: Vector3?)
	local sound = voice.Sound
	voice.Equalizer.LowGain = tone.LowGain
	voice.Equalizer.MidGain = tone.MidGain
	voice.Equalizer.HighGain = tone.HighGain
	if position then
		voice.Attachment.WorldPosition = position
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMaxDistance = rollOffMaxDistance
		sound.Parent = voice.Attachment
	else
		sound.RollOffMaxDistance = 0
		sound.Parent = home
	end
end

local function playLayer(
	layer: Keys.SoundLayer,
	tone: Keys.Tone,
	pitch: number,
	volume: number,
	position: Vector3?
)
	local voice = acquire()
	if not voice then
		return
	end
	prepare(voice, tone, position)
	local sound = voice.Sound
	sound.SoundId = layer.SoundId
	sound.PlaybackSpeed = layer.PlaybackSpeed * pitch
	sound.Volume = layer.Volume * volume
	sound.TimePosition = 0
	sound:Play()
end

function SoundController.Init(self: State, registry: { [string]: any })
	controllers = registry
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
		local equalizer = Instance.new("EqualizerSoundEffect")
		equalizer.Parent = sound
		local attachment = Instance.new("Attachment")
		attachment.Name = `Voice{index}`
		attachment.Parent = workspace.Terrain
		trove:Add(attachment)
		sound.Parent = folder
		table.insert(pool, { Sound = sound, Equalizer = equalizer, Attachment = attachment })
	end
	folder.Parent = SoundService
	home = folder
	trove:Add(folder)
	trove:Add(controllers.DataController:Observe({ "Settings" }, function(settings: any)
		if type(settings) ~= "table" then
			return
		end
		for category, name in settingByCategory do
			local value = settings[name]
			volumes[category] = if type(value) == "number" then math.clamp(value, 0, 1) else 1
		end
	end))
end

function SoundController.PlayUi(_self: State, name: string)
	local layer = uiSounds[name]
	local volume = volumes.Other
	if layer and volume > 0 then
		playLayer(layer, flatTone, 1, volume, nil)
	end
end

function SoundController.PlayKey(
	_self: State,
	rarity: Keys.Rarity,
	pitchMultiplier: number?,
	volumeMultiplier: number?,
	position: Vector3?,
	category: string?
)
	local settings = rarity.Sound
	local pitch = (pitchMultiplier or 1) * (1 + (random:NextNumber() * 2 - 1) * pitchVariance)
	local volume = (volumeMultiplier or 1) * (volumes[category or "Other"] or 1)
	if volume <= 0 then
		return
	end
	for _, layer in settings.Layers do
		local delay = layer.Delay
		if delay and delay > 0 then
			task.delay(delay, playLayer, layer, settings.Tone, pitch, volume, position)
		else
			playLayer(layer, settings.Tone, pitch, volume, position)
		end
	end
end

function SoundController.PlaySwell(_self: State, rarity: Keys.Rarity, seconds: number, category: string?)
	local scale = volumes[category or "Other"] or 1
	if scale <= 0 then
		return
	end
	local settings = rarity.Sound
	local layer = settings.Layers[#settings.Layers]
	local voice = acquire()
	if not voice then
		return
	end
	prepare(voice, settings.Tone, nil)
	local sound = voice.Sound
	sound.SoundId = layer.SoundId
	sound.PlaybackSpeed = layer.PlaybackSpeed * 0.5
	sound.Volume = layer.Volume * 0.5 * scale
	sound.Looped = true
	sound.TimePosition = 0
	sound:Play()
	local tween = TweenService:Create(
		sound,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ PlaybackSpeed = layer.PlaybackSpeed * 1.4, Volume = layer.Volume * scale }
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
	table.clear(controllers)
	volumes.Roll = 1
	volumes.Board = 1
	volumes.Other = 1
	home = nil
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return SoundController
