--!strict

local ContentProvider = game:GetService("ContentProvider")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Keys = require(ReplicatedStorage.Config.Keys)
local SwitchSounds = require(ReplicatedStorage.Config.SwitchSounds)
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
local placeholderPress: Keys.SoundLayer =
	table.freeze({ SoundId = Keys.SoundAssets.Thock, PlaybackSpeed = 1, Volume = 0.65 })
local lastTake: { [string]: number } = {}
local uiSounds: { [string]: Keys.SoundLayer } = {
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
	sound.PlaybackRegionsEnabled = false
	sound.TimePosition = 0
	sound:Play()
end

local function pickTake(switch: SwitchSounds.Switch): SwitchSounds.Clip
	local count = #switch.Presses
	local index = random:NextInteger(1, count)
	if count > 1 and index == lastTake[switch.Id] then
		index = index % count + 1
	end
	lastTake[switch.Id] = index
	return switch.Presses[index]
end

local function playClip(
	clip: SwitchSounds.Clip,
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
	sound.SoundId = SwitchSounds.SpriteId
	sound.PlaybackSpeed = pitch
	sound.Volume = volume
	sound.PlaybackRegionsEnabled = true
	sound.PlaybackRegion = NumberRange.new(clip.Start, clip.Start + clip.Length)
	sound.TimePosition = clip.Start
	sound:Play()
end

local function playSwitch(
	switchId: string,
	kind: string,
	pitchMultiplier: number?,
	volumeMultiplier: number?,
	position: Vector3?,
	category: string?
)
	local volume = (volumeMultiplier or 1) * (volumes[category or "Other"] or 1)
	if volume <= 0 then
		return
	end
	local pitch = (pitchMultiplier or 1) * (1 + (random:NextNumber() * 2 - 1) * pitchVariance)
	if SwitchSounds.SpriteId == "" then
		if kind == "Press" then
			playLayer(placeholderPress, flatTone, pitch, volume, position)
		end
		return
	end
	local switch = SwitchSounds.Switches[switchId]
	if not switch then
		return
	end
	if kind == "Press" then
		playClip(pickTake(switch), flatTone, pitch, volume, position)
	elseif switch.Release then
		playClip(switch.Release, flatTone, pitch, volume, position)
	end
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
	if SwitchSounds.SpriteId ~= "" then
		task.spawn(function()
			pcall(ContentProvider.PreloadAsync, ContentProvider, { SwitchSounds.SpriteId })
		end)
	end
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
	if name == "Click" then
		playSwitch("MxBrown", "Press", 1, 0.5, nil, "Other")
		return
	end
	local layer = uiSounds[name]
	local volume = volumes.Other
	if layer and volume > 0 then
		playLayer(layer, flatTone, 1, volume, nil)
	end
end

function SoundController.PlaySwitch(
	_self: State,
	switchId: string,
	kind: "Press" | "Release",
	pitch: number?,
	volume: number?,
	position: Vector3?,
	category: string?
)
	playSwitch(switchId, kind, pitch, volume, position, category)
end

function SoundController.PlayReveal(_self: State, rarity: Keys.Rarity, category: string?)
	local settings = rarity.Reveal
	local volume = volumes[category or "Other"] or 1
	if not settings or volume <= 0 then
		return
	end
	local pitch = 1 + (random:NextNumber() * 2 - 1) * pitchVariance
	for _, layer in settings.Layers do
		local delay = layer.Delay
		if delay and delay > 0 then
			task.delay(delay, playLayer, layer, settings.Tone, pitch, volume, nil)
		else
			playLayer(layer, settings.Tone, pitch, volume, nil)
		end
	end
end

function SoundController.PlayFlair(_self: State, key: Keys.Key, position: Vector3?, category: string?)
	local layers = key.Flair
	local volume = volumes[category or "Other"] or 1
	if not layers or volume <= 0 then
		return
	end
	for _, layer in layers do
		local delay = layer.Delay
		if delay and delay > 0 then
			task.delay(delay, playLayer, layer, flatTone, 1, volume, position)
		else
			playLayer(layer, flatTone, 1, volume, position)
		end
	end
end

function SoundController.PlaySwell(_self: State, rarity: Keys.Rarity, seconds: number, category: string?)
	local scale = volumes[category or "Other"] or 1
	if scale <= 0 then
		return
	end
	local settings = rarity.Reveal
	if not settings then
		return
	end
	local layer = settings.Layers[1]
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
	sound.PlaybackRegionsEnabled = false
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
	table.clear(lastTake)
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
