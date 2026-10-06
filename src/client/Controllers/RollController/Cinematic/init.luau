--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local KeyTiers = require(ReplicatedStorage.Config.KeyTiers)
local Trove = require(ReplicatedStorage.Packages.Trove)
local KeyModels = require(ReplicatedStorage.Utils.KeyModels)
local Kit = require(script.Parent.Parent.UIController.Kit)
local Viewport = require(script.Parent.Parent.UIController.Viewport)
local CameraShake = require(script.Parent.CameraShake)
local Tiers = require(script.Parent.Tiers)
local Arm = require(script.Arm)
local Build = require(script.Build)
local Config = require(script.Config)
local Render = require(script.Render)
local Types = require(script.Types)

type TroveInstance = typeof(Trove.new())
export type Payload = Types.Payload
export type Cinematic = Types.Cinematic
type Entry = Types.Entry

local staticYaw = Config.StaticYaw
local white = Config.White
local rainbow = Config.Rainbow

local Cinematic = {}
Cinematic.__index = Cinematic
Cinematic.ShouldPlay = Tiers.ShouldPlay
Cinematic.RankOf = Tiers.RankOf
Cinematic.TierFor = Tiers.For
function Cinematic.new(
	playerGui: Instance,
	trove: TroveInstance,
	isLowGraphics: () -> boolean,
	getControllers: () -> { [string]: any }
): Cinematic
	local scene = Build.Scene(playerGui, trove)
	local self: Cinematic = setmetatable({
		_trove = trove,
		_isLowGraphics = isLowGraphics,
		_getControllers = getControllers,
		_gui = scene.Gui,
		_world = scene.World,
		_dim = scene.Dim,
		_edges = scene.Edges,
		_vignette = scene.Vignette,
		_flash = scene.Flash,
		_hint = scene.Hint,
		_glow = scene.Glow,
		_model = scene.Model,
		_title = scene.Title,
		_name = scene.Name,
		_nameScale = scene.NameScale,
		_nameStroke = scene.NameStroke,
		_rays = scene.Rays,
		_rings = scene.Rings,
		_cracks = scene.Cracks,
		_stars = scene.Stars,
		_particles = scene.Particles,
		_active = nil,
		_queued = nil,
		_tier = Tiers.Get("Legendary"),
		_t = 0,
		_low = false,
		_hasImpacted = false,
		_humanoid = nil,
		_modelKey = "",
		_destroyed = false,
	}, Cinematic) :: any

	trove:Connect(UserInputService.InputBegan, function(input: InputObject)
		local inputType = input.UserInputType
		if inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch then
			self:Skip()
		end
	end)
	trove:Add(function()
		self:Destroy()
	end)
	return self
end

local setDucked: (self: Cinematic, isDucked: boolean) -> ()

local function startEntry(self: Cinematic, entry: Entry)
	local payload = entry.Payload
	local rank = Tiers.RankOf(payload.Rarity)
	local tier = Tiers.For(rank)
	self._active = entry
	self._tier = tier
	self._t = 0
	self._hasImpacted = false
	self._low = self._isLowGraphics()
	Arm.HideAll(self)
	local base = payload.Rarity.Color
	local fullId = payload.KeyId or payload.Key.Id
	if self._modelKey ~= fullId or self._model.Model == nil then
		Viewport.Set(self._model, KeyModels.Build(fullId))
		self._modelKey = fullId
	end
	Viewport.Pose(self._model, staticYaw)
	local text = Arm.TitleText(payload, tier)
	local title = self._title
	title.Main.Text = text
	title.Red.Text = text
	title.Cyan.Text = text
	title.Main.TextColor3 = Kit.Shade(base, 0.7)
	title.MainGradient.Color = if tier.Rainbow
		then rainbow
		else ColorSequence.new(white, Kit.Shade(base, if tier.Name == "Mini" then 0 else 0.05))
	local _, variantTier = KeyTiers.Parse(fullId)
	self._name.Text = if variantTier > 0
		then `{KeyTiers.Get(variantTier).Name} {payload.Key.Name}`
		else payload.Key.Name
	self._glow.BackgroundColor3 = Kit.Shade(base, 0.2)
	Arm.Particles(self, payload)
	Arm.Stars(self)
	local player = Players.LocalPlayer
	local character = if player then player.Character else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	self._humanoid = humanoid
	self._gui.Enabled = true
	setDucked(self, true)
	if tier.Swell then
		local sounds = self._getControllers().SoundController
		if sounds then
			sounds:PlaySwell(payload.Rarity, tier.ImpactAt, "Roll")
		end
	end
end

setDucked = function(self: Cinematic, isDucked: boolean)
	local music = self._getControllers().MusicController
	if music then
		music:SetDucked(isDucked)
	end
end

local function restoreCamera(self: Cinematic)
	local humanoid = self._humanoid
	if humanoid then
		CameraShake.Clear(humanoid, self)
	end
	self._humanoid = nil
end

local function finish(self: Cinematic)
	local entry = self._active
	if not entry then
		return
	end
	self._active = nil
	restoreCamera(self)
	Arm.HideAll(self)
	self._world.Position = UDim2.fromScale(0, 0)
	self._dim.Visible = false
	for _, strip in self._vignette do
		strip.Visible = false
	end
	self._gui.Enabled = false
	setDucked(self, false)
	local queued = self._queued
	self._queued = nil
	local done = entry.OnDone
	if done then
		done()
	end
	if queued and not self._destroyed and not self._active then
		startEntry(self, queued)
		Render.Frame(self, 0)
	end
end

function Cinematic.Play(self: Cinematic, payload: Payload, onDone: (() -> ())?): boolean
	if self._destroyed then
		return false
	end
	local entry: Entry = { Payload = payload, OnDone = onDone }
	if not self._active then
		startEntry(self, entry)
		Render.Frame(self, 0)
		return true
	end
	if not self._queued then
		self._queued = entry
		return true
	end
	return false
end

function Cinematic.CanAccept(self: Cinematic): boolean
	return not self._destroyed and (self._active == nil or self._queued == nil)
end

function Cinematic.Step(self: Cinematic, dt: number)
	local entry = self._active
	if self._destroyed or not entry then
		return
	end
	local tier = self._tier
	self._t += dt
	if not self._hasImpacted and self._t >= tier.ImpactAt then
		self._hasImpacted = true
		local sounds = self._getControllers().SoundController
		if sounds then
			sounds:PlayReveal(entry.Payload.Rarity, "Roll")
		end
	end
	if self._t >= tier.Duration then
		finish(self)
		return
	end
	Render.Frame(self, self._t)
end

function Cinematic.Skip(self: Cinematic): boolean
	if self._destroyed or not self._active or self._t < Tiers.SkipDelay then
		return false
	end
	finish(self)
	return true
end

function Cinematic.Seek(self: Cinematic, seconds: number)
	if self._destroyed or not self._active then
		return
	end
	self._t = math.clamp(seconds, 0, self._tier.Duration)
	Render.Frame(self, self._t)
end

function Cinematic.IsPlaying(self: Cinematic): boolean
	return self._active ~= nil
end

function Cinematic.QueuedCount(self: Cinematic): number
	return if self._queued then 1 else 0
end

function Cinematic.Elapsed(self: Cinematic): number
	return self._t
end

function Cinematic.TierName(self: Cinematic): string
	return self._tier.Name
end

function Cinematic.VisibleParticles(self: Cinematic): number
	local count = 0
	for _, piece in self._particles do
		if piece.Frame.Visible then
			count += 1
		end
	end
	return count
end

function Cinematic.Destroy(self: Cinematic)
	if self._destroyed then
		return
	end
	self._destroyed = true
	if self._active then
		setDucked(self, false)
	end
	restoreCamera(self)
	self._active = nil
	self._queued = nil
	Viewport.Clear(self._model)
	self._modelKey = ""
end

return Cinematic
