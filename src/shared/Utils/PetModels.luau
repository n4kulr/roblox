--!strict

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharmConfig = require(ReplicatedStorage.Config.Charms)
local PetMeshes = require(ReplicatedStorage.Config.PetMeshes)
local WorldNames = require(ReplicatedStorage.Config.WorldNames)
local Parts = require(script.Parent.Parts)

export type Style = {
	Ears: string,
	Tail: string,
	Snout: boolean,
	Beak: boolean,
	Wings: boolean,
	Horns: boolean,
	Mask: boolean,
	BigEyes: boolean,
	Spots: boolean,
	Accent: Color3?,
}

local baseSize = 1.5
local sizeStep = 0.25
local legHeight = 0.16
local eyeColor = Color3.fromRGB(25, 25, 30)
local darkColor = Color3.fromRGB(38, 32, 40)
local white = Color3.new(1, 1, 1)
local gold = Color3.fromRGB(255, 205, 70)
local beakColor = Color3.fromRGB(255, 160, 50)
local legendaryOrder = 5
local epicOrder = 4

local function style(overrides: { [string]: any }): Style
	local result: any = {
		Ears = "Point",
		Tail = "Puff",
		Snout = false,
		Beak = false,
		Wings = false,
		Horns = false,
		Mask = false,
		BigEyes = false,
		Spots = false,
		Accent = nil,
	}
	for key, value in overrides do
		result[key] = value
	end
	return result :: Style
end

local species: { [string]: Style } = {
	Kitty = style({ Ears = "Point", Tail = "Long", Snout = true }),
	Chick = style({ Ears = "Fin", Tail = "Feather", Beak = true, Wings = true, Accent = beakColor }),
	Pup = style({ Ears = "Floppy", Tail = "Long", Snout = true }),
	Bear = style({ Ears = "Round", Tail = "Puff", Snout = true }),
	Frog = style({ Ears = "Fin", Tail = "None", BigEyes = true, Spots = true }),
	Squirrel = style({ Ears = "Point", Tail = "Big", Snout = true }),
	Hamster = style({ Ears = "Round", Tail = "None", Snout = true }),
	Panda = style({ Ears = "Round", Tail = "Puff", Mask = true, Snout = true }),
	Lizard = style({ Ears = "Fin", Tail = "Long", Spots = true }),
	Hare = style({ Ears = "Long", Tail = "Puff", Snout = true }),
	Gecko = style({ Ears = "Fin", Tail = "Long", BigEyes = true, Spots = true }),
	Raccoon = style({ Ears = "Round", Tail = "Ring", Mask = true, Snout = true }),
	Owl = style({
		Ears = "Tuft",
		Tail = "Feather",
		Beak = true,
		Wings = true,
		BigEyes = true,
		Accent = beakColor,
	}),
	Parrot = style({ Ears = "Fin", Tail = "Feather", Beak = true, Wings = true, Accent = beakColor }),
	Fawn = style({ Ears = "Point", Tail = "Puff", Horns = true, Spots = true, Snout = true }),
	Fox = style({ Ears = "Point", Tail = "Big", Snout = true }),
	Gorilla = style({ Ears = "Round", Tail = "None", Mask = true, Snout = true }),
	Ferret = style({ Ears = "Round", Tail = "Long", Mask = true, Snout = true }),
	Lynx = style({ Ears = "Tuft", Tail = "Puff", Snout = true }),
	Bunny = style({ Ears = "Long", Tail = "Puff", Snout = true }),
	Koala = style({ Ears = "Round", Tail = "None", Snout = true }),
	Leopard = style({ Ears = "Round", Tail = "Long", Spots = true, Snout = true }),
	Goose = style({ Ears = "Fin", Tail = "Feather", Beak = true, Wings = true, Accent = beakColor }),
	Wolf = style({ Ears = "Point", Tail = "Big", Snout = true }),
	Shark = style({ Ears = "Fin", Tail = "Fin", Snout = true }),
	Dragon = style({ Ears = "Fin", Tail = "Long", Wings = true, Horns = true, Spots = true, Accent = gold }),
}

local fallback = style({})
local meshTemplates: { [string]: MeshPart } = {}

local PetModels = {
	MaxParts = 36,
	BaseSize = baseSize,
}

function PetModels.SizeOf(rarity: string): number
	local info = CharmConfig.RarityByName[rarity]
	return baseSize + sizeStep * ((if info then info.Order else 1) - 1)
end

function PetModels.LiftOf(size: number): number
	return (0.275 + legHeight) * size
end

function PetModels.StyleOf(charm: CharmConfig.Charm): Style
	local last = string.match(charm.Name, "(%S+)$")
	return species[last or ""] or fallback
end

local function newPart(model: Model, name: string, shape: Enum.PartType, size: Vector3, color: Color3): Part
	return Parts.New({
		Name = name,
		Parent = model,
		Shape = shape,
		Anchored = true,
		Passive = true,
		CastShadow = false,
		Massless = true,
		Size = size,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Smooth = true,
	})
end

local function meshIdOf(charmId: string): string?
	local ids = PetMeshes :: { [string]: string }
	local meshId = ids[charmId]
	if type(meshId) == "string" and meshId ~= "" then
		return meshId
	end
	return nil
end

local function templateOf(meshId: string): MeshPart?
	local cached = meshTemplates[meshId]
	if cached then
		return cached
	end
	local ok, result = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromUri(meshId), {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Precise,
		})
	end)
	if not ok then
		warn(`[PetModels] mesh {meshId} failed to load, using placeholder: {result}`)
		return nil
	end
	local template = result :: MeshPart
	template.Name = "Body"
	template.Anchored = true
	template.CanCollide = false
	template.CanQuery = false
	template.CanTouch = false
	template.Massless = true
	template.CastShadow = false
	template.Material = Enum.Material.SmoothPlastic
	meshTemplates[meshId] = template
	return template
end

local function buildMesh(charm: CharmConfig.Charm, meshId: string): (Model?, number?)
	local template = templateOf(meshId)
	if not template then
		return nil, nil
	end
	local size = PetModels.SizeOf(charm.Rarity)
	local body = template:Clone()
	body.Name = "Body"
	local extent = math.max(body.Size.X, body.Size.Y, body.Size.Z)
	if extent > 1e-3 then
		body.Size = body.Size * (size / extent)
	end
	body.Color = charm.Color
	body.Anchored = true
	body.CanCollide = false
	body.CanQuery = false
	body.CanTouch = false
	body.Massless = true
	body.CastShadow = false
	body.Material = Enum.Material.SmoothPlastic
	body.CFrame = CFrame.new()
	local model = Instance.new("Model")
	model.Name = `Pet_{charm.Id}`
	body.Parent = model
	model.PrimaryPart = body
	local look = PetModels.StyleOf(charm)
	local lift = if look.Wings then size * 1.4 else math.max(body.Size.Y * 0.5, 0.2)
	model:SetAttribute(WorldNames.Attributes.Lift, lift)
	model:SetAttribute("FaceYaw", math.pi)
	return model, size
end

function PetModels.Build(charm: CharmConfig.Charm): (Model, number)
	local meshId = meshIdOf(charm.Id)
	if meshId then
		local meshModel, meshSize = buildMesh(charm, meshId)
		if meshModel and meshSize then
			return meshModel, meshSize
		end
	end
	local s = PetModels.SizeOf(charm.Rarity)
	local look = PetModels.StyleOf(charm)
	local color = charm.Color
	local light = color:Lerp(white, 0.55)
	local accent = look.Accent or color:Lerp(darkColor, 0.45)
	local rarity = CharmConfig.RarityByName[charm.Rarity]
	local order = if rarity then rarity.Order else 1
	local model = Instance.new("Model")
	model.Name = `Pet_{charm.Id}`
	local block, ball = Enum.PartType.Block, Enum.PartType.Ball

	local function add(
		name: string,
		shape: Enum.PartType,
		size: Vector3,
		position: Vector3,
		partColor: Color3,
		rotation: Vector3?
	): Part
		local part = newPart(model, name, shape, size * s, partColor)
		local turn = rotation or Vector3.zero
		part.CFrame = CFrame.new(position * s)
			* CFrame.Angles(math.rad(turn.X), math.rad(turn.Y), math.rad(turn.Z))
		return part
	end

	local body = add("Body", block, Vector3.new(0.7, 0.55, 0.95), Vector3.zero, color)
	add("Head", ball, Vector3.new(0.6, 0.6, 0.6), Vector3.new(0, 0.28, -0.5), color)
	for _, side in { -1, 1 } do
		local tag = if side < 0 then "Left" else "Right"
		add(
			`{tag}Leg`,
			block,
			Vector3.new(0.16, legHeight * 2, 0.18),
			Vector3.new(side * 0.2, -0.275 - legHeight, -0.28),
			light
		)
		add(
			`{tag}HindLeg`,
			block,
			Vector3.new(0.16, legHeight * 2, 0.18),
			Vector3.new(side * 0.2, -0.275 - legHeight, 0.3),
			light
		)
		if look.Ears == "Round" then
			add(`{tag}Ear`, ball, Vector3.new(0.2, 0.2, 0.12), Vector3.new(side * 0.22, 0.56, -0.45), color)
		elseif look.Ears == "Long" then
			add(
				`{tag}Ear`,
				block,
				Vector3.new(0.12, 0.5, 0.1),
				Vector3.new(side * 0.12, 0.85, -0.45),
				color,
				Vector3.new(-10, 0, side * 8)
			)
		elseif look.Ears == "Floppy" then
			add(
				`{tag}Ear`,
				block,
				Vector3.new(0.14, 0.3, 0.1),
				Vector3.new(side * 0.3, 0.42, -0.5),
				accent,
				Vector3.new(0, 0, side * 25)
			)
		elseif look.Ears == "Fin" then
			add(
				`{tag}Ear`,
				block,
				Vector3.new(0.06, 0.18, 0.2),
				Vector3.new(side * 0.3, 0.38, -0.5),
				color,
				Vector3.new(0, 0, side * 40)
			)
		elseif look.Ears == "Tuft" then
			add(
				`{tag}Ear`,
				block,
				Vector3.new(0.16, 0.3, 0.12),
				Vector3.new(side * 0.2, 0.64, -0.5),
				color,
				Vector3.new(0, 0, side * 14)
			)
			add(
				`{tag}EarTip`,
				block,
				Vector3.new(0.06, 0.14, 0.06),
				Vector3.new(side * 0.24, 0.84, -0.5),
				darkColor,
				Vector3.new(0, 0, side * 14)
			)
		else
			add(
				`{tag}Ear`,
				block,
				Vector3.new(0.16, 0.28, 0.12),
				Vector3.new(side * 0.2, 0.62, -0.5),
				color,
				Vector3.new(0, 0, side * 10)
			)
		end
		if look.BigEyes then
			add(
				`{tag}EyeWhite`,
				ball,
				Vector3.new(0.2, 0.2, 0.16),
				Vector3.new(side * 0.15, 0.4, -0.76),
				white
			)
			add(`{tag}Eye`, ball, Vector3.new(0.1, 0.1, 0.1), Vector3.new(side * 0.15, 0.4, -0.84), eyeColor)
		else
			add(`{tag}Eye`, ball, Vector3.new(0.1, 0.1, 0.1), Vector3.new(side * 0.14, 0.34, -0.78), eyeColor)
		end
		if look.Mask then
			add(
				`{tag}Patch`,
				ball,
				Vector3.new(0.17, 0.2, 0.08),
				Vector3.new(side * 0.14, 0.34, -0.74),
				darkColor
			)
		end
		if look.Wings then
			add(
				`{tag}Wing`,
				block,
				Vector3.new(0.05, 0.3, 0.42),
				Vector3.new(side * 0.38, 0.12, 0.08),
				accent,
				Vector3.new(0, 0, side * -18)
			)
		end
		if look.Horns then
			add(
				`{tag}Horn`,
				block,
				Vector3.new(0.06, 0.22, 0.06),
				Vector3.new(side * 0.13, 0.66, -0.52),
				if look.Accent then look.Accent else light,
				Vector3.new(0, 0, side * 12)
			)
		end
	end

	if look.Snout then
		add("Snout", ball, Vector3.new(0.24, 0.18, 0.2), Vector3.new(0, 0.24, -0.8), light)
		add("Nose", ball, Vector3.new(0.08, 0.06, 0.06), Vector3.new(0, 0.28, -0.9), darkColor)
	end
	if look.Beak then
		add("Beak", block, Vector3.new(0.14, 0.09, 0.16), Vector3.new(0, 0.26, -0.84), beakColor)
	end
	if look.Tail == "Puff" then
		add("Tail", ball, Vector3.new(0.22, 0.22, 0.22), Vector3.new(0, 0.1, 0.55), white)
	elseif look.Tail == "Long" then
		add(
			"Tail",
			block,
			Vector3.new(0.1, 0.1, 0.5),
			Vector3.new(0, 0.14, 0.72),
			color,
			Vector3.new(-20, 0, 0)
		)
	elseif look.Tail == "Big" then
		add("Tail", ball, Vector3.new(0.3, 0.38, 0.5), Vector3.new(0, 0.26, 0.64), color)
		add("TailTip", ball, Vector3.new(0.22, 0.26, 0.2), Vector3.new(0, 0.3, 0.86), white)
	elseif look.Tail == "Ring" then
		add(
			"Tail",
			block,
			Vector3.new(0.14, 0.14, 0.56),
			Vector3.new(0, 0.14, 0.74),
			light,
			Vector3.new(-18, 0, 0)
		)
		add(
			"TailBand1",
			block,
			Vector3.new(0.15, 0.15, 0.1),
			Vector3.new(0, 0.12, 0.66),
			darkColor,
			Vector3.new(-18, 0, 0)
		)
		add(
			"TailBand2",
			block,
			Vector3.new(0.15, 0.15, 0.1),
			Vector3.new(0, 0.18, 0.88),
			darkColor,
			Vector3.new(-18, 0, 0)
		)
	elseif look.Tail == "Feather" then
		add(
			"Tail",
			block,
			Vector3.new(0.18, 0.05, 0.5),
			Vector3.new(0, 0.12, 0.74),
			accent,
			Vector3.new(-14, 0, 0)
		)
	elseif look.Tail == "Fin" then
		add(
			"Tail",
			block,
			Vector3.new(0.06, 0.34, 0.26),
			Vector3.new(0, 0.2, 0.62),
			accent,
			Vector3.new(20, 0, 0)
		)
		add(
			"Fin",
			block,
			Vector3.new(0.06, 0.3, 0.3),
			Vector3.new(0, 0.42, -0.05),
			accent,
			Vector3.new(-25, 0, 0)
		)
	end
	if look.Spots then
		add("Spot1", ball, Vector3.new(0.14, 0.05, 0.14), Vector3.new(-0.15, 0.285, 0.1), accent)
		add("Spot2", ball, Vector3.new(0.12, 0.05, 0.12), Vector3.new(0.14, 0.285, 0.3), accent)
		add("Spot3", ball, Vector3.new(0.12, 0.05, 0.12), Vector3.new(0.08, 0.285, -0.18), accent)
	end

	if order >= epicOrder then
		add(
			"Gem",
			ball,
			Vector3.new(0.1, 0.1, 0.06),
			Vector3.new(0, 0.46, -0.78),
			charm.Color:Lerp(white, 0.5)
		)
	end
	if order >= legendaryOrder then
		local crown = add("Crown", block, Vector3.new(0.34, 0.1, 0.34), Vector3.new(0, 0.64, -0.5), gold)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Cylinder
		mesh.Parent = crown
		for index, offset in { -0.11, 0, 0.11 } do
			add(
				`CrownPoint{index}`,
				block,
				Vector3.new(0.07, 0.14, 0.07),
				Vector3.new(offset, 0.74, -0.5),
				gold
			)
		end
	end

	model.PrimaryPart = body
	return model, s
end

return table.freeze(PetModels)
