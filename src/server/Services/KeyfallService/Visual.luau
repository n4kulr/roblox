--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Keys = require(ReplicatedStorage.Config.Keys)
local Parts = require(ReplicatedStorage.Utils.Parts)
local Character = require(script.Parent.Parent.Parent.Utils.Character)

local capSize = Vector3.new(2.2, 1.2, 2.2)
local goldenSize = Vector3.new(3.8, 2, 3.8)
local goldenColor = Color3.fromRGB(255, 200, 40)
local stackBase = 4.5
local stackStep = 1.1

local Visual = {
	CapHeight = capSize.Y,
	GoldenHeight = goldenSize.Y,
}

local function paint(part: Part, keyId: string, isGolden: boolean)
	local key = Keys.Resolve(keyId)
	local rarity = if key then Keys.GetRarity(key) else nil
	if isGolden then
		part.Color = goldenColor
		part.Material = Enum.Material.SmoothPlastic
		part.Reflectance = 0.22
	elseif rarity then
		part.Color = rarity.Color
		Keys.ApplyFinish(part, rarity)
	end
end

function Visual.Cap(keyId: string, isGolden: boolean, position: Vector3, isLanded: boolean): Part
	local part = Parts.New({
		Name = if isGolden then "GoldenSpacebar" else "KeyfallCap",
		Size = if isGolden then goldenSize else capSize,
		CFrame = CFrame.new(position),
		Anchored = true,
		Passive = true,
	})
	paint(part, keyId, isGolden)
	part:SetAttribute("KeyId", keyId)
	part:SetAttribute("Landed", isLanded)
	return part
end

function Visual.Stack(character: Model, root: BasePart, keyIds: { string }, goldenId: string): { BasePart }
	local parts: { BasePart } = {}
	for index, keyId in keyIds do
		local part = Parts.New({
			Name = "KeyfallStack",
			Size = Vector3.new(2, 1, 2),
			Passive = true,
			Massless = true,
			CFrame = root.CFrame * CFrame.new(0, stackBase + stackStep * (index - 1), 0),
		})
		paint(part, keyId, keyId == goldenId)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Parent = character
		table.insert(parts, part)
	end
	return parts
end

function Visual.SetSpeed(character: Model, speed: number)
	local humanoid = Character.HumanoidOf(character)
	if humanoid then
		humanoid.WalkSpeed = speed
	end
end

return Visual
