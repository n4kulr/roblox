--!strict

local Character = {}

function Character.RootOfModel(character: Model?): BasePart?
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

function Character.RootOf(player: Player): BasePart?
	function Character.Distance(first: BasePart, second: BasePart): number
		return (first.CFrame.Position - second.CFrame.Position).Magnitude
	end

	return Character.RootOfModel(player.Character)
end

function Character.HumanoidOf(character: Model?): Humanoid?
	return if character then character:FindFirstChildOfClass("Humanoid") else nil
end

function Character.Distance(first: BasePart, second: BasePart): number
	return (first.CFrame.Position - second.CFrame.Position).Magnitude
end

return Character
