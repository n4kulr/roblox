--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)

local Chest = {}

Chest.ModelName = "GroupChest"
Chest.PromptName = "ChestPrompt"
Chest.SignName = "ChestSign"
Chest.TitleName = "Title"
Chest.SubtitleName = "Subtitle"
Chest.PromptRange = 12
Chest.HoldSeconds = 0.5

local wood = Color3.fromRGB(150, 92, 48)
local darkWood = Color3.fromRGB(112, 66, 34)
local gold = Color3.fromRGB(255, 201, 60)
local glowColor = Color3.fromRGB(255, 226, 120)
local ink = Color3.fromRGB(26, 21, 48)
local lidAngle = math.rad(-24)
local width = 8
local depth = 5
local bodyHeight = 3.6
local lidThickness = 1.2
local bandX = { -2.6, 2.6 }

local function newPart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	return part
end

local function newLabel(name: string, text: string, color: Color3, position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeColor3 = ink
	label.TextStrokeTransparency = 0
	return label
end

function Chest.GroundAt(position: Vector3): number
	local ok, result = pcall(function()
		local params = RaycastParams.new()
		local hit = workspace:Raycast(position + Vector3.new(0, 60, 0), Vector3.new(0, -260, 0), params)
		return if hit then hit.Position.Y else nil
	end)
	if ok and type(result) == "number" then
		return result
	end
	return GameConfig.Obby.GroundY
end

function Chest.AddPrompt(part: BasePart): ProximityPrompt
	local existing = part:FindFirstChild(Chest.PromptName)
	if existing and existing:IsA("ProximityPrompt") then
		return existing
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = Chest.PromptName
	prompt.ActionText = "Open"
	prompt.ObjectText = "Group Chest"
	prompt.HoldDuration = Chest.HoldSeconds
	prompt.MaxActivationDistance = Chest.PromptRange
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	return prompt
end

function Chest.AddSign(part: BasePart): BillboardGui
	local existing = part:FindFirstChild(Chest.SignName)
	if existing and existing:IsA("BillboardGui") then
		return existing
	end
	local sign = Instance.new("BillboardGui")
	sign.Name = Chest.SignName
	sign.Adornee = part
	sign.Size = UDim2.fromOffset(300, 92)
	sign.StudsOffset = Vector3.new(0, 5.5, 0)
	sign.MaxDistance = 140
	sign.LightInfluence = 0
	local title = newLabel(Chest.TitleName, "GROUP CHEST", gold, UDim2.new(), UDim2.fromScale(1, 0.58))
	title.Parent = sign
	local subtitle = newLabel(
		Chest.SubtitleName,
		"Join the group to claim!",
		Color3.new(1, 1, 1),
		UDim2.fromScale(0, 0.6),
		UDim2.fromScale(1, 0.36)
	)
	subtitle.Parent = sign
	sign.Parent = part
	return sign
end

function Chest.Build(origin: Vector3): Model
	local baseY = Chest.GroundAt(origin) + 0.25
	local bodyTop = baseY + bodyHeight
	local function at(x: number, y: number, z: number): CFrame
		return CFrame.new(origin.X + x, y, origin.Z + z)
	end
	local model = Instance.new("Model")
	model.Name = Chest.ModelName
	local body = newPart(
		"Body",
		Vector3.new(width, bodyHeight, depth),
		at(0, baseY + bodyHeight / 2, 0),
		wood,
		Enum.Material.Wood
	)
	body.CanCollide = true
	body.Parent = model
	newPart(
		"Foot",
		Vector3.new(width + 0.6, 0.5, depth + 0.6),
		at(0, baseY + 0.25, 0),
		gold,
		Enum.Material.Metal
	).Parent =
		model
	local hinge = at(0, bodyTop, -depth / 2) * CFrame.Angles(lidAngle, 0, 0)
	local lidCenter = CFrame.new(0, lidThickness / 2, depth / 2)
	newPart("Lid", Vector3.new(width, lidThickness, depth), hinge * lidCenter, darkWood, Enum.Material.Wood).Parent =
		model
	for index, x in bandX do
		newPart(
			`BodyBand{index}`,
			Vector3.new(0.7, bodyHeight + 0.1, depth + 0.3),
			at(x, baseY + bodyHeight / 2, 0),
			gold,
			Enum.Material.Metal
		).Parent =
			model
		newPart(
			`LidBand{index}`,
			Vector3.new(0.7, lidThickness + 0.1, depth + 0.3),
			hinge * lidCenter * CFrame.new(x, 0, 0),
			gold,
			Enum.Material.Metal
		).Parent =
			model
	end
	newPart(
		"Lock",
		Vector3.new(1.5, 1.7, 0.6),
		at(0, bodyTop - 0.9, depth / 2 + 0.2),
		gold,
		Enum.Material.Metal
	).Parent =
		model
	local glow = newPart(
		"Glow",
		Vector3.new(width - 1.2, 0.3, depth - 1.2),
		at(0, bodyTop - 0.05, 0),
		glowColor,
		Enum.Material.Neon
	)
	glow.Parent = model
	local light = Instance.new("PointLight")
	light.Name = "GlowLight"
	light.Color = glowColor
	light.Brightness = 2.5
	light.Range = 20
	light.Parent = glow
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Name = "Sparkles"
	sparkles.Color = ColorSequence.new(glowColor)
	sparkles.Rate = 6
	sparkles.Lifetime = NumberRange.new(1.2, 2)
	sparkles.Speed = NumberRange.new(2, 4)
	sparkles.SpreadAngle = Vector2.new(25, 25)
	sparkles.LightEmission = 1
	sparkles.Size = NumberSequence.new(0.5, 0)
	sparkles.Parent = glow
	local coin =
		newPart("Coin", Vector3.new(0.4, 2.2, 2.2), at(0, bodyTop + 2.4, 0), gold, Enum.Material.Metal)
	coin.Shape = Enum.PartType.Cylinder
	coin:SetAttribute("SpinSpeed", 110)
	CollectionService:AddTag(coin, "Spinner")
	coin.Parent = model
	model.PrimaryPart = body
	Chest.AddPrompt(body)
	Chest.AddSign(body)
	return model
end

function Chest.AnchorOf(found: Instance): BasePart?
	if found:IsA("BasePart") then
		return found
	end
	if found:IsA("Model") and found.PrimaryPart then
		return found.PrimaryPart
	end
	for _, descendant in found:GetDescendants() do
		if descendant:IsA("BasePart") then
			return descendant
		end
	end
	return nil
end

return Chest
