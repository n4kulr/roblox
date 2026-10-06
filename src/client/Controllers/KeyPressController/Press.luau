--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Keys = require(ReplicatedStorage.Config.Keys)
local WorldNames = require(ReplicatedStorage.Config.WorldNames)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Attributes = WorldNames.Attributes

local Press = {}

local function isFillerPart(part: BasePart): boolean
	return part:GetAttribute(Attributes.Filler) == true or part:GetAttribute(Attributes.Cosmetic) == true
end

local function isStoodOn(registry: Types.Registry, cap: Types.CapState): boolean
	for _, standing in registry.StandingOn do
		if standing == cap then
			return true
		end
	end
	return false
end

function Press.ReleaseTween(cap: Types.CapState)
	local tween = cap.Tween
	if tween then
		cap.Tween = nil
		tween:Cancel()
		tween:Destroy()
	end
end

local function press(cap: Types.CapState)
	local part = cap.Part
	local authored = part:GetAttribute(Attributes.PressDepth)
	local depth = if type(authored) == "number"
		then authored
		elseif isFillerPart(part) then Config.FillerPressDepth
		else Config.PressDepth
	Press.ReleaseTween(cap)
	cap.Held = true
	local down = TweenService:Create(
		part,
		TweenInfo.new(Config.PressSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = cap.Rest * CFrame.new(0, -depth, 0) }
	)
	cap.Tween = down
	down.Completed:Once(function()
		if cap.Tween == down then
			cap.Tween = nil
		end
		down:Destroy()
	end)
	down:Play()
end

function Press.Raise(registry: Types.Registry, cap: Types.CapState)
	if not cap.Held or isStoodOn(registry, cap) then
		return
	end
	local token = os.clock()
	cap.RaiseToken = token
	task.delay(Config.ReleaseDelaySeconds, function()
		if cap.RaiseToken ~= token or isStoodOn(registry, cap) or cap.Part.Parent == nil then
			return
		end
		cap.Held = false
		Press.ReleaseTween(cap)
		local up = TweenService:Create(
			cap.Part,
			TweenInfo.new(Config.RaiseSeconds, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ CFrame = cap.Rest }
		)
		cap.Tween = up
		up.Completed:Once(function()
			if cap.Tween == up then
				cap.Tween = nil
			end
			up:Destroy()
		end)
		up:Play()
	end)
end

function Press.Play(
	controllers: { [string]: any },
	cap: Types.CapState,
	player: Player,
	kind: "Press" | "Release"
)
	local category = if player == Players.LocalPlayer then "Board" else "Other"
	local keyId = cap.Part:GetAttribute(Attributes.KeyId)
	local key = if type(keyId) == "string" then Keys.Resolve(keyId) else nil
	local isFiller = isFillerPart(cap.Part)
	local switchId = if key then key.Switch else Config.CosmeticSwitch
	local pitch = if key then 1 else Config.CosmeticPitch
	local volume = if key then 1 elseif isFiller then Config.FillerVolume else Config.BlankVolume
	controllers.SoundController:PlaySwitch(switchId, kind, pitch, volume, cap.Part.Position, category)
end

function Press.Trigger(controllers: { [string]: any }, cap: Types.CapState, player: Player)
	if cap.Part:GetAttribute(Attributes.Locked) == true then
		return
	end
	cap.RaiseToken = nil
	if cap.Held then
		return
	end
	local now = os.clock()
	if now - cap.LastPress < Config.DebounceSeconds then
		return
	end
	cap.LastPress = now
	press(cap)
	Press.Play(controllers, cap, player, "Press")
end

return Press
