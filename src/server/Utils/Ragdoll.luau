--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local Character = require(script.Parent.Character)

local Ragdoll = {
	Attribute = "Ragdolled",
}

local upperAngle = 70
local twistAngle = 45

local function disableMotor(trove: any, motor: Motor6D)
	local part0 = motor.Part0
	local part1 = motor.Part1
	if not part0 or not part1 then
		return
	end
	local first = Instance.new("Attachment")
	first.Name = "RagdollFirst"
	first.CFrame = motor.C0
	first.Parent = part0
	trove:Add(first)
	local second = Instance.new("Attachment")
	second.Name = "RagdollSecond"
	second.CFrame = motor.C1
	second.Parent = part1
	trove:Add(second)
	local socket = Instance.new("BallSocketConstraint")
	socket.Name = "RagdollSocket"
	socket.Attachment0 = first
	socket.Attachment1 = second
	socket.LimitsEnabled = true
	socket.UpperAngle = upperAngle
	socket.TwistLimitsEnabled = true
	socket.TwistLowerAngle = -twistAngle
	socket.TwistUpperAngle = twistAngle
	socket.Parent = part0
	trove:Add(socket)
	motor.Enabled = false
	trove:Add(function()
		motor.Enabled = true
	end)
end

function Ragdoll.Apply(character: Model): (() -> ())?
	local humanoid = Character.HumanoidOf(character)
	if not humanoid or character:GetAttribute(Ragdoll.Attribute) == true then
		return nil
	end
	local trove = Trove.new()
	for _, descendant in character:GetDescendants() do
		if descendant:IsA("Motor6D") and descendant.Enabled then
			disableMotor(trove, descendant)
		end
	end
	local neckRequired = humanoid.RequiresNeck
	local wasPlatformStanding = humanoid.PlatformStand
	humanoid.RequiresNeck = false
	humanoid.PlatformStand = true
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	character:SetAttribute(Ragdoll.Attribute, true)
	local isRestored = false
	return function()
		if isRestored then
			return
		end
		isRestored = true
		trove:Destroy()
		character:SetAttribute(Ragdoll.Attribute, nil)
		humanoid.RequiresNeck = neckRequired
		humanoid.PlatformStand = wasPlatformStanding
		if humanoid.Health > 0 then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end
end

return Ragdoll
