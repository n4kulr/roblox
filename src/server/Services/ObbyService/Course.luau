--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local Obby = require(ReplicatedStorage.Rules.Obby)

local config = GameConfig.Obby

local deckColor = Color3.fromRGB(24, 25, 31)
local padColor = Color3.fromRGB(58, 61, 74)
local lavaColor = Color3.fromRGB(96, 22, 30)
local railColor = Color3.fromRGB(32, 33, 40)
local signColor = Color3.fromRGB(46, 49, 60)
local gateColor = Color3.fromRGB(226, 72, 84)
local pedestalColor = Color3.fromRGB(255, 214, 51)
local homeColor = Color3.fromRGB(79, 158, 214)
local deckTop = 0.1
local railHeight = 7
local barrierHeight = 60
local lavaDepth = 2
local bannerHeight = 12

local Course = {}

Course.ModelName = "Obby"

local function newPart(
	parent: Instance,
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	role: string?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if role then
		part:SetAttribute("ObbyRole", role)
	end
	part.Parent = parent
	return part
end

local function hide(part: Part, collide: boolean)
	part.Transparency = 1
	part.CanCollide = collide
	part.CanTouch = false
	part.CanQuery = false
end

local function addLabel(
	gui: SurfaceGui,
	name: string,
	text: string,
	y: number,
	height: number,
	color: Color3,
	stroked: boolean
)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0, y)
	label.Size = UDim2.fromScale(1, height)
	label.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	label.Text = text
	label.TextColor3 = color
	label.TextScaled = true
	label.Parent = gui
	if stroked then
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(20, 20, 25)
		stroke.Thickness = 2
		stroke.Parent = label
	end
end

local function addSign(part: Part, faces: { Enum.NormalId }, title: string, subtitle: string?)
	for _, face in faces do
		local gui = Instance.new("SurfaceGui")
		gui.Name = "SignGui"
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.Parent = part
		if subtitle then
			addLabel(gui, "Title", title, 0.05, 0.55, Color3.new(1, 1, 1), true)
			addLabel(gui, "Subtitle", subtitle, 0.62, 0.33, Color3.new(1, 1, 1), true)
		else
			addLabel(gui, "Title", title, 0.1, 0.8, Color3.new(1, 1, 1), true)
		end
	end
end

local function buildKey(model: Model, origin: CFrame, layout: Obby.Layout, cell: Obby.Cell)
	local height = config.Key.Height
	local isPopUp = cell.Kind == "PopUp"
	local rise = config.PopUp.RiseHeight
	local fullHeight = if isPopUp then height + rise else height
	local color = if isPopUp then Keys.RarityByName[config.Key.PopUpRarity].Color else config.Key.Color
	local name = if isPopUp then `PopUp_{cell.Letter}` else `Key_{cell.Section}_{cell.Row}_{cell.Col}`
	local part = newPart(
		model,
		name,
		Vector3.new(cell.Width, fullHeight, cell.Length),
		origin * CFrame.new(cell.X, height - fullHeight / 2, -cell.D),
		color,
		if isPopUp then "PopUpKey" else "TapKey"
	)
	part:SetAttribute("Letter", cell.Letter)
	if isPopUp then
		part:SetAttribute("RiseHeight", rise)
		part:SetAttribute("UpSeconds", config.PopUp.UpSeconds)
		part:SetAttribute("PeriodSeconds", config.PopUp.PeriodSeconds)
		part:SetAttribute("PhaseSeconds", cell.Phase)
	end
end

local function buildPad(
	model: Model,
	origin: CFrame,
	layout: Obby.Layout,
	name: string,
	d0: number,
	d1: number,
	role: string?
): Part
	local thickness = layout.Top + 1
	return newPart(
		model,
		name,
		Vector3.new(layout.Width, thickness, d1 - d0),
		origin * CFrame.new(0, layout.Top - thickness / 2, -(d0 + d1) / 2),
		padColor,
		role
	)
end

local function buildHome(model: Model, origin: CFrame, layout: Obby.Layout, name: string, d: number)
	local pad = newPart(
		model,
		name,
		Vector3.new(8, 0.3, 8),
		origin * CFrame.new(layout.Width / 2 - 8, layout.Top + 0.15, -d),
		homeColor,
		"Home"
	)
	pad.CanCollide = false
	addSign(pad, { Enum.NormalId.Top }, "HOME", nil)
end

local function buildBanner(
	model: Model,
	origin: CFrame,
	layout: Obby.Layout,
	name: string,
	d: number,
	title: string,
	subtitle: string?
)
	local banner = newPart(
		model,
		name,
		Vector3.new(layout.Width - 3, 5, 0.6),
		origin * CFrame.new(0, layout.Top + bannerHeight, -d),
		signColor
	)
	addSign(banner, { Enum.NormalId.Back }, title, subtitle)
	for side, x in { -1, 1 } do
		newPart(
			model,
			`{name}Post{side}`,
			Vector3.new(1, bannerHeight + 2.5, 1),
			origin * CFrame.new(x * (layout.Width / 2 - 0.5), layout.Top + (bannerHeight + 2.5) / 2 - 2.5, -d),
			railColor
		)
	end
end

local function buildWalls(model: Model, origin: CFrame, layout: Obby.Layout)
	local length = layout.Length
	local offset = layout.Width / 2 + 0.75
	for side, x in { -1, 1 } do
		newPart(
			model,
			`SideWall{side}`,
			Vector3.new(1.5, railHeight, length),
			origin * CFrame.new(x * offset, railHeight / 2, -length / 2),
			railColor
		)
		local barrier = newPart(
			model,
			`SideBarrier{side}`,
			Vector3.new(1.5, barrierHeight, length),
			origin * CFrame.new(x * offset, barrierHeight / 2, -length / 2),
			railColor
		)
		hide(barrier, true)
	end
	newPart(
		model,
		"EndWall",
		Vector3.new(layout.Width + 3, railHeight, 1.5),
		origin * CFrame.new(0, railHeight / 2, -(length + 0.75)),
		railColor
	)
	local endBarrier = newPart(
		model,
		"EndBarrier",
		Vector3.new(layout.Width + 3, barrierHeight, 1.5),
		origin * CFrame.new(0, barrierHeight / 2, -(length + 0.75)),
		railColor
	)
	hide(endBarrier, true)
end

local function buildGate(model: Model, origin: CFrame, layout: Obby.Layout)
	local gate = newPart(
		model,
		"SpeedGate",
		Vector3.new(layout.Width, config.Gate.Height, config.Gate.Thickness),
		origin * CFrame.new(0, config.Gate.Height / 2, -layout.GateD),
		gateColor,
		"SpeedGate"
	)
	gate.Transparency = 0.45
	gate.CanQuery = false
	gate:SetAttribute("RequiredSpeed", config.Gate.RequiredSpeed)
	addSign(
		gate,
		{ Enum.NormalId.Back, Enum.NormalId.Front },
		`NEED {config.Gate.RequiredSpeed} SPEED`,
		"TAP KEYS TO GO FASTER"
	)
end

function Course.Build(origin: CFrame, name: string): Model
	local layout = Obby.Layout()
	local model = Instance.new("Model")
	model.Name = name
	local run = layout.Runs
	local areas: { [string]: Obby.Area } = {}
	for _, area in layout.Areas do
		areas[area.Name] = area
	end

	local start = areas.Start
	local rampRun = config.Level1.RampLength
	local rampLength = math.sqrt(rampRun * rampRun + layout.Top * layout.Top)
	newPart(
		model,
		"Ramp",
		Vector3.new(layout.Width, 1, rampLength),
		origin
			* CFrame.new(0, layout.Top / 2, -rampRun / 2)
			* CFrame.Angles(math.atan2(layout.Top, rampRun), 0, 0)
			* CFrame.new(0, -0.5, 0),
		padColor
	)
	buildPad(model, origin, layout, "Start", start.D0 + rampRun, start.D1, "Checkpoint")
	buildPad(model, origin, layout, "Safe1", areas.Safe1.D0, areas.Safe1.D1, "Checkpoint")
	buildPad(model, origin, layout, "Approach", areas.Approach.D0, areas.Approach.D1, nil)
	buildPad(model, origin, layout, "End", areas.End.D0, areas.End.D1, "Checkpoint")

	local deckLength = run[1].D1 - run[1].D0
	newPart(
		model,
		"DeckA",
		Vector3.new(layout.Width, 1, deckLength),
		origin * CFrame.new(0, deckTop - 0.5, -(run[1].D0 + run[1].D1) / 2),
		deckColor
	)
	local lava = newPart(
		model,
		"Lava",
		Vector3.new(layout.Width, lavaDepth, run[2].D1 - run[2].D0),
		origin * CFrame.new(0, config.LavaTop - lavaDepth / 2, -(run[2].D0 + run[2].D1) / 2),
		lavaColor,
		"Kill"
	)
	lava.CanCollide = false

	for _, cell in layout.Cells do
		buildKey(model, origin, layout, cell)
	end
	for index, pedestal in layout.Pedestals do
		local marker = newPart(
			model,
			`KeySpawn{index}`,
			Vector3.new(3, 0.3, 3),
			origin * CFrame.new(pedestal.X, layout.Top + 0.15, -pedestal.D),
			pedestalColor,
			"KeySpawn"
		)
		marker.CanCollide = false
		marker:SetAttribute("Rarities", pedestal.Rarities)
	end

	buildBanner(
		model,
		origin,
		layout,
		"StartSign",
		start.D0 + rampRun + 4,
		"THOCK OBBY",
		"TAP KEYS TO GO FASTER"
	)
	buildBanner(model, origin, layout, "Safe1Sign", areas.Safe1.D0 + 4, "SAFE ZONE", "CHECKPOINT")
	buildBanner(model, origin, layout, "EndSign", areas.End.D0 + 4, "LEVEL 1 COMPLETE", "LEVEL 2 COMING SOON")
	buildHome(model, origin, layout, "Safe1Home", areas.Safe1.D0 + 12)
	buildHome(model, origin, layout, "EndHome", areas.End.D0 + 12)
	buildGate(model, origin, layout)
	buildWalls(model, origin, layout)

	local zone = newPart(
		model,
		"Zone",
		Vector3.new(layout.Width + 3, config.ZoneHeight, layout.Length),
		origin * CFrame.new(0, config.ZoneHeight / 2 - 10, -layout.Length / 2),
		pedestalColor,
		"Zone"
	)
	hide(zone, false)
	model.PrimaryPart = zone
	return model
end

return Course
