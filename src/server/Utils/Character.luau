--!strict

local Character = {}

function Character.RootOfModel(character: Model?): BasePart?
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

function Character.RootOf(player: Player): BasePart?
	return Character.RootOfModel(player.Character)
end

function Character.HumanoidOf(character: Model?): Humanoid?
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

return Character
