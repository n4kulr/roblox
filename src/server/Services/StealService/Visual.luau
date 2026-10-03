--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Keys = require(ReplicatedStorage.Config.Keys)

local Visual = {}

function Visual.Attach(character: Model, root: BasePart, keyId: string): Part?
	local key = Keys.ById[keyId]
	if not key then
		return nil
	end
	local rarity = Keys.GetRarity(key)
	local part = Instance.new("Part")
	part.Name = "StolenKey"
	part.Size = Vector3.new(2.4, 1.2, 2.4)
	part.Color = rarity.Color
	part.Material = if rarity.IsNeon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CFrame = root.CFrame * CFrame.new(0, 4.5, 0)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
	part.Parent = character
	return part
end

function Visual.SetSpeed(character: Model, speed: number)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

return Visual
