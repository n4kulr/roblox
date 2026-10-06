--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Trove = require(ReplicatedStorage.Packages.Trove)

export type Options = {
	Parent: Instance,
	Name: string?,
	Size: UDim2?,
	Position: UDim2?,
	AnchorPoint: Vector2?,
	ZIndex: number?,
	Direction: Vector3?,
	Fov: number?,
}

export type Handle = {
	Frame: ViewportFrame,
	Camera: Camera,
	Model: Model?,
	Direction: Vector3,
	Center: Vector3,
	Radius: number,
	Yaw: number,
	Roll: number,
	Pitch: number,
	Lift: number,
	Zoom: number,
	Streak: Frame?,
	Legend: (() -> ())?,
}

local defaultDirection = Vector3.new(0, 0.45, 1)
local defaultFov = 30
local framing = 1.12
local ambient = Color3.fromRGB(150, 150, 160)
local lightColor = Color3.fromRGB(255, 250, 240)
local lightDirection = Vector3.new(-0.4, -1, -0.6)
local popRise = 0.18
local popSettle = 0.12
local popPeak = 1.12
local glintSweep = 0.5
local glintPeriod = 2.8
local minZoom = 0.02
local legendFacingThreshold = 0.15
local legendTextScale = 0.82
local legendStrokeThickness = 2
local legendMinTextSize = 4
local legendZIndex = 10
local legendAnchorName = "LegendAnchor"
local defaultLegendFont = Enum.Font.FredokaOne
local defaultLegendFill = 0.62
local defaultLegendStrokeColor = Color3.fromRGB(20, 18, 28)
local defaultLegendStrokeTransparency = 0.2

local Viewport = {}

function Viewport.new(options: Options): Handle
	local frame = Instance.new("ViewportFrame")
	frame.Name = options.Name or "Viewport"
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ImageTransparency = 0
	frame.Active = false
	frame.AnchorPoint = options.AnchorPoint or Vector2.zero
	frame.Position = options.Position or UDim2.fromScale(0, 0)
	frame.Size = options.Size or UDim2.fromScale(1, 1)
	frame.ZIndex = options.ZIndex or 1
	frame.Ambient = ambient
	frame.LightColor = lightColor
	frame.LightDirection = lightDirection
	local camera = Instance.new("Camera")
	camera.Name = "ViewCamera"
	camera.FieldOfView = options.Fov or defaultFov
	camera.Parent = frame
	frame.CurrentCamera = camera
	frame.Parent = options.Parent
	return {
		Frame = frame,
		Camera = camera,
		Model = nil,
		Direction = options.Direction or defaultDirection,
		Center = Vector3.zero,
		Radius = 1,
		Yaw = 0,
		Roll = 0,
		Pitch = 0,
		Lift = 0,
		Zoom = 1,
		Streak = nil,
		Legend = nil,
	}
end

local function noop() end

local function attributeOr(model: Model, name: string, fallback: any): any
	local value = model:GetAttribute(name)
	if value == nil then
		return fallback
	end
	return value
end

function Viewport.TrackLegend(frame: ViewportFrame, model: Model, camera: Camera): () -> ()
	local anchor = model:FindFirstChild(legendAnchorName, true)
	local text = model:GetAttribute("LegendText")
	if not anchor or not anchor:IsA("Attachment") or type(text) ~= "string" then
		return noop
	end
	local cap = anchor.Parent
	if not cap or not cap:IsA("BasePart") then
		return noop
	end
	local fill: number = attributeOr(model, "LegendFill", defaultLegendFill)
	local fontName: string = attributeOr(model, "LegendFont", defaultLegendFont.Name)
	local font = defaultLegendFont
	for _, item in Enum.Font:GetEnumItems() do
		if item.Name == fontName then
			font = item
		end
	end

	local trove = Trove.new()
	local label = Instance.new("TextLabel")
	label.Name = "Legend"
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Active = false
	label.ZIndex = legendZIndex
	label.Font = font
	label.Text = text
	label.TextColor3 = attributeOr(model, "LegendColor", Color3.new(1, 1, 1))
	label.TextScaled = false
	label.Visible = false
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Thickness = legendStrokeThickness
	stroke.Color = attributeOr(model, "LegendStrokeColor", defaultLegendStrokeColor)
	stroke.Transparency = attributeOr(model, "LegendStrokeTransparency", defaultLegendStrokeTransparency)
	stroke.Parent = label
	label.Parent = frame
	trove:Add(label)

	local function project(point: Vector3, pixels: Vector2, viewportSize: Vector2): (Vector2, boolean)
		local screen, onScreen = camera:WorldToViewportPoint(point)
		return Vector2.new(screen.X / viewportSize.X * pixels.X, screen.Y / viewportSize.Y * pixels.Y),
			onScreen and screen.Z > 0
	end

	local function update()
		local pixels = frame.AbsoluteSize
		local viewportSize = camera.ViewportSize
		if pixels.X <= 0 or pixels.Y <= 0 or viewportSize.X <= 0 or viewportSize.Y <= 0 then
			label.Visible = false
			return
		end
		local cframe = cap.CFrame
		local center = cframe:PointToWorldSpace(anchor.Position)
		local toCamera = camera.CFrame.Position - center
		if toCamera.Magnitude < 1e-6 or cframe.UpVector:Dot(toCamera.Unit) < legendFacingThreshold then
			label.Visible = false
			return
		end
		local halfWidth = cframe.RightVector * (cap.Size.X / 2)
		local middle, isVisible = project(center, pixels, viewportSize)
		local left = project(center - halfWidth, pixels, viewportSize)
		local right = project(center + halfWidth, pixels, viewportSize)
		if not isVisible then
			label.Visible = false
			return
		end
		local edge = right - left
		local side = math.max(edge.Magnitude * fill * legendTextScale, legendMinTextSize)
		label.Position = UDim2.fromOffset(middle.X, middle.Y)
		label.Size = UDim2.fromOffset(side, side)
		label.TextSize = math.floor(side)
		label.Rotation = math.deg(math.atan2(edge.Y, edge.X))
		label.Visible = true
	end

	trove:Connect(RunService.RenderStepped, update)
	update()
	return function()
		trove:Destroy()
	end
end

function Viewport.Clear(handle: Handle)
	local legend = handle.Legend
	if legend then
		legend()
		handle.Legend = nil
	end
	local streak = handle.Streak
	if streak then
		streak.Visible = false
	end
	local model = handle.Model
	if model then
		model:Destroy()
		handle.Model = nil
	end
end

local function aim(handle: Handle)
	local fov = math.rad(handle.Camera.FieldOfView)
	local distance = handle.Radius * framing / math.sin(fov / 2) / handle.Zoom
	local focus = handle.Center + Vector3.new(0, handle.Lift, 0)
	handle.Camera.CFrame = CFrame.lookAt(focus + handle.Direction.Unit * distance, focus)
end

function Viewport.PopScale(age: number): number
	if age <= 0 then
		return minZoom
	end
	if age < popRise then
		local alpha = age / popRise
		return math.max(minZoom, (1 - (1 - alpha) * (1 - alpha)) * popPeak)
	end
	if age < popRise + popSettle then
		local alpha = (age - popRise) / popSettle
		return popPeak + (1 - popPeak) * (0.5 - 0.5 * math.cos(alpha * math.pi))
	end
	return 1
end

function Viewport.Zoom(handle: Handle, zoom: number)
	handle.Zoom = math.max(minZoom, zoom)
	aim(handle)
end

local function newStreak(handle: Handle, tint: Color3?): Frame
	local line = Instance.new("Frame")
	line.Name = `{handle.Frame.Name}Glint`
	line.BackgroundColor3 = tint or Color3.new(1, 1, 1)
	line.BackgroundTransparency = 0
	line.BorderSizePixel = 0
	line.Active = false
	line.Visible = false
	local gradient = Instance.new("UIGradient")
	gradient.Name = "Sweep"
	gradient.Rotation = 24
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.42, 1),
		NumberSequenceKeypoint.new(0.5, 0.45),
		NumberSequenceKeypoint.new(0.58, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Parent = line
	line.Parent = handle.Frame.Parent
	handle.Streak = line
	return line
end

function Viewport.Glint(handle: Handle, age: number, tint: Color3?)
	local streak = handle.Streak or newStreak(handle, tint)
	local frame = handle.Frame
	streak.AnchorPoint = frame.AnchorPoint
	streak.Position = frame.Position
	streak.Size = frame.Size
	streak.Rotation = frame.Rotation
	streak.ZIndex = frame.ZIndex + 1
	local phase = age % glintPeriod
	if phase < glintSweep and age > 0.4 and frame.Visible then
		local alpha = phase / glintSweep
		local eased = alpha * alpha * (3 - 2 * alpha)
		local gradient = streak:FindFirstChild("Sweep")
		if gradient and gradient:IsA("UIGradient") then
			gradient.Offset = Vector2.new(-1 + 2 * eased, 0)
		end
		streak.Visible = true
	else
		streak.Visible = false
	end
end

function Viewport.Pose(handle: Handle, yaw: number, roll: number?, pitch: number?, lift: number?)
	handle.Yaw = yaw
	handle.Roll = roll or 0
	handle.Pitch = pitch or 0
	handle.Lift = lift or 0
	local model = handle.Model
	if not model then
		return
	end
	local center = handle.Center
	model:PivotTo(
		CFrame.new(0, handle.Lift, 0)
			* CFrame.new(center)
			* CFrame.Angles(math.rad(handle.Pitch), math.rad(handle.Yaw), math.rad(handle.Roll))
			* CFrame.new(-center)
	)
end

function Viewport.Set(handle: Handle, model: Model, direction: Vector3?)
	Viewport.Clear(handle)
	if direction then
		handle.Direction = direction
	end
	model:PivotTo(CFrame.new())
	model.Parent = handle.Frame
	local box, size = model:GetBoundingBox()
	handle.Model = model
	handle.Legend = Viewport.TrackLegend(handle.Frame, model, handle.Camera)
	handle.Center = box.Position
	handle.Radius = math.max(math.sqrt(size.X * size.X + size.Z * size.Z) / 2, size.Y / 2, 0.5)
	handle.Yaw, handle.Roll, handle.Pitch, handle.Lift = 0, 0, 0, 0
	handle.Zoom = 1
	aim(handle)
end

function Viewport.Light(handle: Handle, color: Color3, boost: number?)
	handle.Frame.LightColor = color
	handle.Frame.Ambient = ambient:Lerp(Color3.new(1, 1, 1), math.clamp(boost or 0, 0, 1))
end

function Viewport.ModelName(handle: Handle): string
	local model = handle.Model
	return if model then model.Name else ""
end

function Viewport.Destroy(handle: Handle)
	Viewport.Clear(handle)
	local streak = handle.Streak
	if streak then
		streak:Destroy()
		handle.Streak = nil
	end
	handle.Camera:Destroy()
	handle.Frame:Destroy()
end

return Viewport
