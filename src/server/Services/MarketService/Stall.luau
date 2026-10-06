--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Eggs = require(ReplicatedStorage.Config.Eggs)
local EggModel = require(ReplicatedStorage.Utils.EggModel)
local Market = require(ReplicatedStorage.Rules.Market)
local Gui = require(ReplicatedStorage.Utils.Gui)
local Parts = require(ReplicatedStorage.Utils.Parts)

local config = GameConfig.Market

local center = Vector3.new(0, 0, -14)
local stripeColors = { Color3.fromRGB(255, 99, 72), Color3.fromRGB(250, 240, 224) }
local woodColor = Color3.fromRGB(140, 96, 64)
local counterColor = Color3.fromRGB(176, 124, 82)
local rugColor = Color3.fromRGB(70, 74, 86)
local signColor = Color3.fromRGB(255, 99, 72)
local eggScale = 0.6
local eggSpacing = 2.2
local counterHeight = 3.5
local counterZ = 3.5
local stripeCount = 8
local stripeWidth = 2

local Stall = {}

Stall.PromptName = "MarketPrompt"
Stall.PlaceholderName = "Market"

local function newPart(
	parent: Instance,
	name: string,
	size: Vector3,
	offset: Vector3,
	color: Color3,
	collide: boolean?,
	tilt: number?
): Part
	return Parts.New({
		Name = name,
		Parent = parent,
		Anchored = true,
		Size = size,
		CFrame = CFrame.new(center + offset) * CFrame.Angles(tilt or 0, 0, 0),
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		CanCollide = collide ~= false,
		Smooth = true,
	})
end

local function buildSign(model: Model)
	local board = newPart(model, "SignBoard", Vector3.new(12, 3, 0.6), Vector3.new(0, 10.2, 5.8), signColor)
	local gui = Gui.Surface(board, { Name = "SignGui", Face = Enum.NormalId.Back, PixelsPerStud = 40 })
	Gui.Label(gui, {
		Name = "Text",
		Text = "EGG MARKET",
		Color = Color3.new(1, 1, 1),
		StrokeThickness = 3,
		StrokeColor = Color3.fromRGB(20, 20, 25),
	})
end

function Stall.Build(name: string): (Model, BasePart)
	local model = Instance.new("Model")
	model.Name = name
	newPart(model, "Floor", Vector3.new(16, 0.2, 12), Vector3.new(0, 0.1, 0), rugColor, false)
	local counter = newPart(
		model,
		"Counter",
		Vector3.new(12, counterHeight, 2.5),
		Vector3.new(0, counterHeight / 2, counterZ),
		counterColor
	)
	local postIndex = 0
	for _, x in { -7.5, 7.5 } do
		for _, z in { -5.5, 5.5 } do
			postIndex += 1
			newPart(model, `Post{postIndex}`, Vector3.new(1, 9, 1), Vector3.new(x, 4.5, z), woodColor)
		end
	end
	for index = 1, stripeCount do
		local x = (index - (stripeCount + 1) / 2) * stripeWidth
		newPart(
			model,
			`Awning{index}`,
			Vector3.new(stripeWidth, 0.4, 13),
			Vector3.new(x, 9.1, 0),
			stripeColors[index % 2 + 1],
			false,
			math.rad(5)
		)
	end
	buildSign(model)
	local eggCount = #Eggs.Catalog
	for index = 1, eggCount do
		local x = (index - (eggCount + 1) / 2) * eggSpacing
		local deco = Instance.new("Model")
		deco.Name = `EggDeco{index}`
		local height = EggModel.HeightOf(eggScale)
		local parts = EggModel.Build(deco, Eggs.Catalog[index], {
			Scale = eggScale,
			Anchored = true,
			BodyName = `Egg{index}`,
			Origin = CFrame.new(center + Vector3.new(x, counterHeight + height / 2 + 0.2, counterZ)),
		})
		parts[1].Parent = model
		deco.Parent = model
	end
	model.PrimaryPart = counter
	return model, counter
end

function Stall.FindAuthored(): (Model?, BasePart?)
	local found = workspace:FindFirstChild("Market")
	if not found or not found:IsA("Model") then
		return nil, nil
	end
	local counter = found:FindFirstChild("Counter", true)
	if counter and counter:IsA("BasePart") then
		return found, counter
	end
	return nil, nil
end

function Stall.EnsurePrompt(counter: BasePart): ProximityPrompt
	local existing = counter:FindFirstChild(Stall.PromptName)
	if existing and existing:IsA("ProximityPrompt") then
		return existing
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = Stall.PromptName
	prompt.ActionText = "Open Egg Market"
	prompt.ObjectText = "Shop"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = config.PromptRange
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter
	return prompt
end

function Stall.Paint(model: Model, slot: number)
	local offers = Market.Offers(slot)
	for index = 1, #Eggs.Catalog do
		local display = model:FindFirstChild(`Egg{index}`, true)
		local offer = offers[index]
		if display and display:IsA("BasePart") then
			local inStock = offer ~= nil and offer.Stock > 0
			display.Transparency = if inStock then 0 else 1
			local deco = model:FindFirstChild(`EggDeco{index}`)
			if deco then
				for _, part in deco:GetChildren() do
					if part:IsA("BasePart") then
						part.Transparency = if inStock then 0 else 1
					end
				end
			end
			if inStock and offer then
				display.Color = Eggs.ById[offer.EggId].Color
			end
		end
	end
end

return Stall
