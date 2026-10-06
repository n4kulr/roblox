--!strict

local Ragdoll = {
	Attribute = "Ragdolled",
}

function Ragdoll.Set(humanoid: Humanoid, isRagdolled: boolean)
	if isRagdolled then
		humanoid.PlatformStand = true
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	else
		humanoid.PlatformStand = false
		if humanoid.Health > 0 then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end
end

function Ragdoll.Watch(character: Model, trove: any)
	local function refresh()
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			Ragdoll.Set(humanoid, character:GetAttribute(Ragdoll.Attribute) == true)
		end
	end
	trove:Connect(character:GetAttributeChangedSignal(Ragdoll.Attribute), refresh)
	if character:GetAttribute(Ragdoll.Attribute) == true then
		refresh()
	end
end

return Ragdoll
