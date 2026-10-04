--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Obby = require(ReplicatedStorage.Rules.Obby)

local config = GameConfig.Obby

local lavaColor = Color3.fromRGB(96, 22, 30)
local plinthColor = Color3.fromRGB(236, 224, 196)
local railColor = Color3.fromRGB(35, 36, 42)
local postColor = Color3.fromRGB(140, 96, 64)
local finishColor = Color3.fromRGB(255, 214, 51)
local signColor = Color3.fromRGB(70, 74, 86)
local keyBody = Color3.fromRGB(48, 50, 58)
local keyTop = Color3.fromRGB(232, 228, 220)
local keyLegend = Color3.fromRGB(40, 42, 48)
local gateColor = Color3.fromRGB(255, 120, 90)
local railHeight = 8
local barrierHeight = 70
local lavaDepth = 2

local Course = {}

Course.ModelName = "Obby"

local function darken(color: Color3, amount: number): Color3
	return Color3.new(color.R * (1 - amount), color.G * (1 - amount), color.B * (1 - amount))
end

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
	part.CanCollide = true
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
	color: Color3?
)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0, y)
	label.Size = UDim2.fromScale(1, height)
	label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	label.Text = text
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(20, 20, 25)
	stroke.Thickness = 2
	stroke.Parent = label
end

local function addSign(part: Part, face: Enum.NormalId, title: string, subtitle: string?)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = part
	if subtitle then
		addLabel(gui, "Title", title, 0.05, 0.55)
		addLabel(gui, "Subtitle", subtitle, 0.62, 0.33)
	else
		addLabel(gui, "Title", title, 0.1, 0.8)
	end
end

local function addLetter(part: Part, letter: string)
	if letter == "" or letter == " " then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "LetterGui"
	gui.Face = Enum.NormalId.Top
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50
	gui.Parent = part
	addLabel(gui, "Letter", letter, 0.15, 0.7, keyLegend)
end

local function buildArea(model: Model, origin: CFrame, layout: Obby.Layout, area: Obby.Area)
	local width = layout.Width
	local top = layout.Top
	local length = area.D1 - area.D0
	local middle = (area.D0 + area.D1) / 2
	local bottom = layout.LavaTop - lavaDepth
	local thickness = top - bottom
	local role = if area.Kind == "Finish"
		then "Finish"
		elseif area.Kind == "Gate" then "Checkpoint"
		else "Checkpoint"
	local name = area.Kind
	if area.Kind == "Safe" then
		name = "Safe"
	end
	local accent = if area.Kind == "Finish"
		then finishColor
		elseif area.Kind == "Gate" then gateColor
		elseif area.Kind == "Start" then Color3.fromRGB(120, 210, 255)
		else plinthColor
	local plinth = newPart(
		model,
		name,
		Vector3.new(width, thickness, length),
		origin * CFrame.new(0, bottom + thickness / 2, -middle),
		plinthColor,
		role
	)
	plinth:SetAttribute("Kind", area.Kind)
	local mat = newPart(
		model,
		`{name}Mat`,
		Vector3.new(width - 8, 0.2, length - 4),
		origin * CFrame.new(0, top - 0.05, -middle),
		accent
	)
	mat.CanCollide = false
	for side, x in { -1, 1 } do
		newPart(
			model,
			`{name}Post{side}`,
			Vector3.new(1.2, 10, 1.2),
			origin * CFrame.new(x * (width / 2 - 1), top + 5, -middle),
			postColor
		)
	end
	local banner = newPart(
		model,
		`{name}Sign`,
		Vector3.new(math.min(width - 8, 48), 3.2, 0.6),
		origin * CFrame.new(0, top + 9, -middle),
		signColor
	)
	addSign(banner, Enum.NormalId.Back, area.Title or name, area.Subtitle)
	if area.Kind == "Gate" then
		local needed = area.SpeedNeeded or config.GateSpeed
		local wall = newPart(
			model,
			"SpeedGate",
			Vector3.new(width - 4, 14, 2),
			origin * CFrame.new(0, top + 7, -middle),
			gateColor,
			"Gate"
		)
		wall.CanCollide = false
		wall:SetAttribute("SpeedNeeded", needed)
		wall:SetAttribute("PushD", area.D0 - 2)
		addSign(wall, Enum.NormalId.Back, `NEED {needed} SPEED`, "TAP KEYS TO GO FASTER")
	end
	if area.HasHome then
		local pad = newPart(
			model,
			`{name}Home`,
			Vector3.new(8, 0.3, 8),
			origin * CFrame.new(width / 2 - 8, top, -(area.D0 + 5)),
			darken(accent, 0.12),
			"Return"
		)
		pad.CanCollide = false
		addSign(pad, Enum.NormalId.Top, "HOME", nil)
	end
end

local function buildKey(model: Model, origin: CFrame, layout: Obby.Layout, key: Obby.TapKey)
	if key.Missing then
		return
	end
	local top = layout.Top
	local bodyHeight = config.KeyHeight
	local stem = config.StemHeight
	local name = `Key{key.Index}`
	local role = if key.Popup then "Popup" else "Tap"
	local body = newPart(
		model,
		`{name}Body`,
		Vector3.new(key.Size * 0.92, bodyHeight, key.Size * 0.92),
		origin * CFrame.new(key.X, top - bodyHeight / 2, -key.D),
		keyBody,
		role
	)
	body:SetAttribute("Letter", key.Letter)
	body:SetAttribute("Section", key.Section)
	if key.Popup then
		body:SetAttribute("PopupUp", config.PopupUpSeconds)
		body:SetAttribute("PopupDown", config.PopupDownSeconds)
		body:SetAttribute("PopupPhase", key.PopupPhase)
		body:SetAttribute("PopupDepth", bodyHeight + stem + 1)
	end
	newPart(
		model,
		`{name}Stem`,
		Vector3.new(key.Size * 0.55, stem, key.Size * 0.55),
		origin * CFrame.new(key.X, top - bodyHeight - stem / 2, -key.D),
		darken(keyBody, 0.2)
	)
	local cap = newPart(
		model,
		`{name}Top`,
		Vector3.new(key.Size * 0.82, 0.55, key.Size * 0.82),
		origin * CFrame.new(key.X, top + 0.1, -key.D),
		keyTop
	)
	cap.CanCollide = false
	addLetter(cap, key.Letter)
end

local function buildWalls(model: Model, origin: CFrame, layout: Obby.Layout)
	local length = layout.Length
	local offset = layout.Width / 2 + 0.75
	for side, x in { -1, 1 } do
		newPart(
			model,
			`Rail{side}`,
			Vector3.new(1.5, railHeight, length),
			origin * CFrame.new(x * offset, railHeight / 2, -length / 2),
			railColor,
			"Wall"
		)
		local barrier = newPart(
			model,
			`Barrier{side}`,
			Vector3.new(1.5, barrierHeight, length),
			origin * CFrame.new(x * offset, barrierHeight / 2, -length / 2),
			railColor,
			"Wall"
		)
		hide(barrier, true)
	end
	newPart(
		model,
		"RailEnd",
		Vector3.new(layout.Width + 3, railHeight, 1.5),
		origin * CFrame.new(0, railHeight / 2, -(length + 0.75)),
		railColor,
		"Wall"
	)
	local endBarrier = newPart(
		model,
		"BarrierEnd",
		Vector3.new(layout.Width + 3, barrierHeight, 1.5),
		origin * CFrame.new(0, barrierHeight / 2, -(length + 0.75)),
		railColor,
		"Wall"
	)
	hide(endBarrier, true)
end

function Course.Build(origin: CFrame, name: string): Model
	local layout = Obby.Layout()
	local model = Instance.new("Model")
	model.Name = name
	for _, area in layout.Areas do
		buildArea(model, origin, layout, area)
	end
	local hazardLength = layout.HazardD1 - layout.HazardD0
	if hazardLength > 0 then
		local lava = newPart(
			model,
			"Lava",
			Vector3.new(layout.Width, lavaDepth, hazardLength),
			origin * CFrame.new(0, layout.LavaTop - lavaDepth / 2, -(layout.HazardD0 + layout.HazardD1) / 2),
			lavaColor,
			"Kill"
		)
		lava:SetAttribute("Section", 2)
	end
	for _, key in layout.Keys do
		buildKey(model, origin, layout, key)
	end
	for index, point in layout.Spawns do
		local marker = newPart(
			model,
			`KeySpawn{index}`,
			Vector3.new(2, 0.2, 2),
			origin * CFrame.new(point.X, layout.Top + 0.1, -point.D),
			finishColor,
			"KeySpawn"
		)
		marker:SetAttribute("Section", point.Section)
		hide(marker, false)
	end
	buildWalls(model, origin, layout)
	local zone = newPart(
		model,
		"Zone",
		Vector3.new(layout.Width + 4, config.ZoneHeight, layout.Length + 4),
		origin * CFrame.new(0, config.ZoneHeight / 2 - 8, -layout.Length / 2),
		finishColor,
		"Zone"
	)
	hide(zone, false)
	model.PrimaryPart = zone
	return model
end

return Course
