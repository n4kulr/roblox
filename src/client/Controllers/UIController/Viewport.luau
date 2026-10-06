--!strict

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
}

local defaultDirection = Vector3.new(0, 0.45, 1)
local defaultFov = 30
local framing = 1.12
local ambient = Color3.fromRGB(150, 150, 160)
local lightColor = Color3.fromRGB(255, 250, 240)
local lightDirection = Vector3.new(-0.4, -1, -0.6)

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
	}
end

function Viewport.Clear(handle: Handle)
	local model = handle.Model
	if model then
		model:Destroy()
		handle.Model = nil
	end
end

local function aim(handle: Handle)
	local fov = math.rad(handle.Camera.FieldOfView)
	local distance = handle.Radius * framing / math.sin(fov / 2)
	local focus = handle.Center + Vector3.new(0, handle.Lift, 0)
	handle.Camera.CFrame = CFrame.lookAt(focus + handle.Direction.Unit * distance, focus)
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
	handle.Center = box.Position
	handle.Radius = math.max(math.sqrt(size.X * size.X + size.Z * size.Z) / 2, size.Y / 2, 0.5)
	handle.Yaw, handle.Roll, handle.Pitch, handle.Lift = 0, 0, 0, 0
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
	handle.Camera:Destroy()
	handle.Frame:Destroy()
end

return Viewport
