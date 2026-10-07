--!strict

local Players = game:GetService("Players")

local grabAnimationId = "rbxassetid://507768375"
local crouchDrop = 0.7
local leanRadians = math.rad(28)
local fade = 0.1

local HoldAnim = {}

local track: AnimationTrack? = nil
local hip: number? = nil
local waist: Motor6D? = nil
local waistC0: CFrame? = nil

local function humanoidOf(): Humanoid?
	local character = Players.LocalPlayer.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	return if humanoid and humanoid:IsA("Humanoid") then humanoid else nil
end

local function characterOf(): Model?
	return Players.LocalPlayer.Character
end

local function animatorOf(humanoid: Humanoid): Animator?
	local existing = humanoid:FindFirstChildOfClass("Animator")
	if existing then
		return existing
	end
	local created = Instance.new("Animator")
	created.Parent = humanoid
	return created
end

local function waistOf(character: Model): Motor6D?
	local upper = character:FindFirstChild("UpperTorso")
	if not upper then
		return nil
	end
	local joint = upper:FindFirstChild("Waist")
	return if joint and joint:IsA("Motor6D") then joint else nil
end

function HoldAnim.Stop()
	local current = track
	track = nil
	if current then
		current:Stop(fade)
		current:Destroy()
	end
	local humanoid = humanoidOf()
	local base = hip
	hip = nil
	if humanoid and base ~= nil then
		humanoid.HipHeight = base
	end
	local joint = waist
	local baseC0 = waistC0
	waist = nil
	waistC0 = nil
	if joint and baseC0 then
		joint.C0 = baseC0
	end
end

function HoldAnim.Start()
	HoldAnim.Stop()
	local humanoid = humanoidOf()
	local character = characterOf()
	if not humanoid or not character then
		return
	end
	local animator = animatorOf(humanoid)
	if not animator then
		return
	end
	local baseHip = humanoid.HipHeight
	hip = baseHip
	humanoid.HipHeight = math.max(baseHip - crouchDrop, 0)
	local joint = waistOf(character)
	if joint then
		waist = joint
		waistC0 = joint.C0
		joint.C0 = joint.C0 * CFrame.Angles(leanRadians, 0, 0)
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = grabAnimationId
	local loaded = animator:LoadAnimation(animation)
	animation:Destroy()
	loaded.Priority = Enum.AnimationPriority.Action
	loaded.Looped = true
	loaded:Play(fade)
	track = loaded
end

return HoldAnim
