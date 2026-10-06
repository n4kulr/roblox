--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Music = require(ReplicatedStorage.Config.Music)
local Trove = require(ReplicatedStorage.Packages.Trove)

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	_trove: TroveInstance?,
}

local MusicController = {
	Name = "MusicController",
	_trove = nil :: TroveInstance?,
}
local controllers: { [string]: any } = {}
local random = Random.new()
local playlist: { Music.Track } = {}
local order: { number } = {}
local cursor = 0
local folder: Folder? = nil
local current: Sound? = nil
local startedAt = 0
local userVolume = 0.5
local isDucked = false
local isPaused = false
local retiring: { Sound } = {}

local function targetVolume(): number
	local duck = if isDucked then Music.DuckMultiplier else 1
	return Music.BaseVolume * math.clamp(userVolume, 0, 1) * duck
end

local function fade(sound: Sound, volume: number, seconds: number, onDone: (() -> ())?)
	local tween = TweenService:Create(
		sound,
		TweenInfo.new(seconds, Enum.EasingStyle.Linear, Enum.EasingDirection.Out),
		{ Volume = volume }
	)
	tween.Completed:Once(function()
		tween:Destroy()
		if onDone then
			onDone()
		end
	end)
	tween:Play()
end

local function shuffle()
	table.clear(order)
	for index = 1, #playlist do
		order[index] = index
	end
	for index = #order, 2, -1 do
		local swap = random:NextInteger(1, index)
		order[index], order[swap] = order[swap], order[index]
	end
	cursor = 0
end

local function retire(sound: Sound)
	table.insert(retiring, sound)
	fade(sound, 0, Music.CrossfadeSeconds, function()
		local at = table.find(retiring, sound)
		if at then
			table.remove(retiring, at)
		end
		sound:Destroy()
	end)
end

local function nextTrack(): Music.Track?
	if #playlist == 0 then
		return nil
	end
	local previous = if cursor > 0 then order[cursor] else nil
	cursor += 1
	if cursor > #order then
		shuffle()
		cursor = 1
		if #order > 1 and order[1] == previous then
			order[1], order[2] = order[2], order[1]
		end
	end
	return playlist[order[cursor]]
end

local function startNext()
	local track = nextTrack()
	local parent = folder
	if not track or not parent then
		return
	end
	local old = current
	local sound = Instance.new("Sound")
	sound.Name = track.Name
	sound.SoundId = track.SoundId
	sound.Looped = false
	sound.Volume = 0
	sound.Parent = parent
	sound:Play()
	current = sound
	startedAt = os.clock()
	fade(sound, targetVolume(), if old then Music.CrossfadeSeconds else Music.VolumeFadeSeconds, nil)
	if old then
		retire(old)
	end
end

local function isFinishing(sound: Sound): boolean
	local length = sound.TimeLength
	if length > 0 then
		return length - sound.TimePosition <= Music.CrossfadeSeconds
	end
	return not sound.IsLoaded and os.clock() - startedAt >= Music.LoadTimeoutSeconds
end

local function tick()
	if isPaused or #playlist == 0 then
		return
	end
	local sound = current
	if not sound or isFinishing(sound) then
		startNext()
	end
end

local function applyVolume(seconds: number)
	local sound = current
	if sound and not isPaused then
		fade(sound, targetVolume(), seconds, nil)
	end
end

local function setPaused(value: boolean)
	if isPaused == value then
		return
	end
	isPaused = value
	local sounds = table.clone(retiring)
	if current then
		table.insert(sounds, current)
	end
	for _, sound in sounds do
		if value then
			sound:Pause()
		else
			sound:Resume()
		end
	end
	if not value then
		applyVolume(Music.VolumeFadeSeconds)
		tick()
	end
end

local function setUserVolume(value: any)
	userVolume = if type(value) == "number" then math.clamp(value, 0, 1) else 0.5
	setPaused(userVolume <= 0)
	applyVolume(Music.VolumeFadeSeconds)
end

function MusicController.Init(self: State, registry: { [string]: any })
	controllers = registry
	self._trove = Trove.new()
end

function MusicController.Start(self: State)
	local trove = self._trove :: TroveInstance
	table.clear(playlist)
	for _, track in Music.Playlist do
		if track.SoundId ~= "" then
			table.insert(playlist, track)
		end
	end
	local home = Instance.new("Folder")
	home.Name = "Music"
	home.Parent = SoundService
	folder = home
	trove:Add(home)
	shuffle()
	trove:Add(controllers.DataController:Observe({ "Settings", "MusicVolume" }, setUserVolume))
	if #playlist == 0 then
		return
	end
	tick()
	local thread = task.spawn(function()
		while true do
			task.wait(Music.PollSeconds)
			tick()
		end
	end)
	trove:Add(function()
		if coroutine.status(thread) == "suspended" then
			task.cancel(thread)
		end
	end)
end

function MusicController.SetDucked(_self: State, ducked: boolean)
	if isDucked == ducked then
		return
	end
	isDucked = ducked
	applyVolume(Music.DuckFadeSeconds)
end

function MusicController.GetCurrentName(_self: State): string?
	local sound = current
	return if sound then sound.Name else nil
end

function MusicController.Destroy(self: State)
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
	table.clear(retiring)
	table.clear(playlist)
	table.clear(order)
	current = nil
	folder = nil
	cursor = 0
	userVolume = 0.5
	isDucked = false
	isPaused = false
end

return MusicController
