--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Obby = require(ReplicatedStorage.Rules.Obby)

local config = GameConfig.Obby

local lavaColor = Color3.fromRGB(96, 22, 30)
local plinthColor = Color3.fromRGB(240, 228, 196)
local railColor = Color3.fromRGB(35, 36, 42)
local postColor = Color3.fromRGB(140, 96, 64)
local finishColor = Color3.fromRGB(255, 214, 51)
local signColor = Color3.fromRGB(70, 74, 86)
local capTopHeight = 0.7
local railHeight = 7
local barrierHeight = 60
local lavaDepth = 2

local Course = {}

Course.ModelName = "Obby"

local function lighten(color: Color3, amount: number): Color3
	return Color3.new(
		color.R + (1 - color.R) * amount,
		color.G + (1 - color.G) * amount,
		color.B + (1 - color.B) * amount
	)
end

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

local function addLabel(gui: SurfaceGui, name: string, text: string, y: number, height: number)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = UDim2.fromScale(0, y)
	label.Size = UDim2.fromScale(1, height)
	label.FontFace = Font.fromEnum(Enum.Font.FredokaOne)
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
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

local function buildArea(model: Model, origin: CFrame, layout: Obby.Layout, area: Obby.Area)
	local width = layout.Width
	local top = layout.Top
	local length = area.D1 - area.D0
	local middle = (area.D0 + area.D1) / 2
	local isFinish = area.Kind == "Finish"
	local nextStage = config.Stages[area.Index + 1]
	local accent = if isFinish then finishColor elseif nextStage then nextStage.Color else plinthColor
	local bottom = layout.LavaTop - lavaDepth
	local thickness = top - bottom
	local role = if isFinish then "Finish" else "Checkpoint"
	local name = if area.Kind == "Start" then "Start" elseif isFinish then "Finish" else `Safe{area.Index}`
	local plinth = newPart(
		model,
		name,
		Vector3.new(width, thickness, length),
		origin * CFrame.new(0, bottom + thickness / 2, -middle),
		plinthColor,
		role
	)
	plinth:SetAttribute("Safe", area.Index)
	local mat = newPart(
		model,
		`{name}Mat`,
		Vector3.new(width - 6, 0.2, length - 4),
		origin * CFrame.new(0, top - 0.05, -middle),
		accent
	)
	mat.CanCollide = false
	for side, x in { -1, 1 } do
		newPart(
			model,
			`{name}Post{side}`,
			Vector3.new(1, 9, 1),
			origin * CFrame.new(x * (width / 2 - 0.5), top + 4.5, -middle),
			postColor
		)
	end
	local banner = newPart(
		model,
		`{name}Sign`,
		Vector3.new(width - 3, 3, 0.6),
		origin * CFrame.new(0, top + 8.2, -middle),
		signColor
	)
	if area.Kind == "Start" then
		addSign(banner, Enum.NormalId.Back, "TAP OBBY", "STAGE 1 AHEAD")
	elseif isFinish then
		addSign(banner, Enum.NormalId.Back, "FINISH", nil)
	else
		addSign(banner, Enum.NormalId.Back, "SAFE ZONE", `STAGE {area.Index + 1} NEXT`)
	end
	if area.Kind ~= "Start" then
		local pad = newPart(
			model,
			`{name}Home`,
			Vector3.new(6, 0.3, 6),
			origin * CFrame.new(width / 2 - 5, top, -(area.D0 + 4)),
			darken(accent, 0.15),
			"Return"
		)
		pad.CanCollide = false
		addSign(pad, Enum.NormalId.Top, "HOME", nil)
	end
end

local function buildPlatform(model: Model, origin: CFrame, layout: Obby.Layout, platform: Obby.Platform)
	local stage = config.Stages[platform.Stage]
	local length = platform.D1 - platform.D0
	local middle = (platform.D0 + platform.D1) / 2
	local top = layout.Top
	local bodyHeight = top - layout.LavaTop - capTopHeight
	local name = `Stage{platform.Stage}Cap{platform.Index}`
	local body = newPart(
		model,
		`{name}Body`,
		Vector3.new(platform.Width, bodyHeight + 0.5, length),
		origin * CFrame.new(platform.X, layout.LavaTop - 0.5 + (bodyHeight + 0.5) / 2, -middle),
		darken(stage.Color, 0.25)
	)
	body:SetAttribute("Stage", platform.Stage)
	local inset = if platform.Shape == "Beam" then 0.8 else 0.84
	local cap = newPart(
		model,
		`{name}Top`,
		Vector3.new(platform.Width * inset, capTopHeight, math.max(length * inset, 1)),
		origin * CFrame.new(platform.X, top - capTopHeight / 2, -middle),
		stage.Color
	)
	cap:SetAttribute("Stage", platform.Stage)
	if platform.Shape == "Keycap" then
		local dish = newPart(
			model,
			`{name}Dish`,
			Vector3.new(platform.Width * 0.5, 0.1, length * 0.5),
			origin * CFrame.new(platform.X, top + 0.02, -middle),
			lighten(stage.Color, 0.4)
		)
		dish.CanCollide = false
	end
end

local function buildRamp(model: Model, origin: CFrame, layout: Obby.Layout)
	local run = config.RampLength
	local rise = layout.Top
	local ramp = newPart(
		model,
		"Ramp",
		Vector3.new(layout.Width, 1, math.sqrt(run * run + rise * rise)),
		origin
			* CFrame.new(0, rise / 2, -run / 2)
			* CFrame.Angles(math.atan2(rise, run), 0, 0)
			* CFrame.new(0, -0.5, 0),
		plinthColor
	)
	ramp.CanCollide = true
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
	buildRamp(model, origin, layout)
	for _, area in layout.Areas do
		buildArea(model, origin, layout, area)
	end
	for _, span in layout.Stages do
		local length = span.D1 - span.D0
		local lava = newPart(
			model,
			`Lava{span.Index}`,
			Vector3.new(layout.Width, lavaDepth, length),
			origin * CFrame.new(0, layout.LavaTop - lavaDepth / 2, -(span.D0 + span.D1) / 2),
			lavaColor,
			"Kill"
		)
		lava:SetAttribute("Stage", span.Index)
	end
	for _, platform in layout.Platforms do
		buildPlatform(model, origin, layout, platform)
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
		marker:SetAttribute("Stage", point.Stage)
		hide(marker, false)
	end
	buildWalls(model, origin, layout)
	local zone = newPart(
		model,
		"Zone",
		Vector3.new(layout.Width + 3, config.ZoneHeight, layout.Length),
		origin * CFrame.new(0, config.ZoneHeight / 2 - 10, -layout.Length / 2),
		finishColor,
		"Zone"
	)
	hide(zone, false)
	model.PrimaryPart = zone
	return model
end

return Course
