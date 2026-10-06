--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local Gui = require(ReplicatedStorage.Utils.Gui)

type TroveInstance = typeof(Trove.new())
type Face = { Face: Enum.NormalId, Normal: Vector3, Axis: string }

export type Display = {
	Set: (self: Display, player: Player?) -> (),
	Guis: { Instance },
}

local OwnerSign = {}
OwnerSign.__index = OwnerSign

local guiName = "OwnerSign"
local emptyText = "🔓 EMPTY BASE"
local pixelsPerStud = 50
local billboardSize = UDim2.fromScale(8, 2.5)
local billboardOffset = Vector3.new(0, 9, 0)
local billboardDistance = 150
local plateColor = Color3.fromRGB(24, 25, 31)
local outlineColor = Color3.fromRGB(10, 10, 14)
local white = Color3.new(1, 1, 1)
local subColor = Color3.fromRGB(200, 205, 220)

local faces: { Face } = {
	{ Face = Enum.NormalId.Front, Normal = Vector3.new(0, 0, -1), Axis = "Z" },
	{ Face = Enum.NormalId.Back, Normal = Vector3.new(0, 0, 1), Axis = "Z" },
	{ Face = Enum.NormalId.Right, Normal = Vector3.new(1, 0, 0), Axis = "X" },
	{ Face = Enum.NormalId.Left, Normal = Vector3.new(-1, 0, 0), Axis = "X" },
	{ Face = Enum.NormalId.Top, Normal = Vector3.new(0, 1, 0), Axis = "Y" },
	{ Face = Enum.NormalId.Bottom, Normal = Vector3.new(0, -1, 0), Axis = "Y" },
}

local function thinAxis(size: Vector3): string
	if size.Z <= size.X and size.Z <= size.Y then
		return "Z"
	elseif size.X <= size.Y then
		return "X"
	end
	return "Y"
end

local function faceDimensions(size: Vector3, axis: string): (number, number)
	if axis == "Z" then
		return size.X, size.Y
	elseif axis == "X" then
		return size.Z, size.Y
	end
	return size.X, size.Z
end

function OwnerSign.Faces(panel: BasePart, base: BasePart): (Face, Face, number)
	local axis = thinAxis(panel.Size)
	local forward = base.CFrame.LookVector
	local toCenter = Vector3.new(-panel.CFrame.Position.X, 0, -panel.CFrame.Position.Z)
	local best: Face? = nil
	local bestScore = -math.huge
	local opposite: Face? = nil
	for _, face in faces do
		if face.Axis == axis then
			local normal = panel.CFrame:VectorToWorldSpace(face.Normal)
			local score = normal:Dot(forward) * 1000 + normal:Dot(toCenter)
			if score > bestScore then
				bestScore = score
				best = face
			end
		end
	end
	for _, face in faces do
		if face.Axis == axis and face ~= best then
			opposite = face
		end
	end
	local width, height = faceDimensions(panel.Size, axis)
	return best :: Face, opposite :: Face, width / height
end

local function stroke(parent: Instance, thickness: number)
	Gui.Stroke(parent, thickness, outlineColor, Enum.LineJoinMode.Round)
end

local function newLabel(
	parent: Instance,
	name: string,
	position: UDim2,
	size: UDim2,
	color: Color3,
	thickness: number
)
	return Gui.Label(parent, {
		Name = name,
		Position = position,
		Size = size,
		Color = color,
		XAlignment = Enum.TextXAlignment.Left,
		StrokeThickness = thickness,
		StrokeColor = outlineColor,
		StrokeJoin = Enum.LineJoinMode.Round,
	})
end

local function fill(gui: Instance, aspect: number)
	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.Size = UDim2.fromScale(1, 1)
	plate.BackgroundColor3 = plateColor
	plate.BackgroundTransparency = 0.1
	plate.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.14, 0)
	corner.Parent = plate
	stroke(plate, 4)
	plate.Parent = gui

	local headSize = 0.78
	local headWidth = headSize / aspect
	local head = Instance.new("ImageLabel")
	head.Name = "Headshot"
	head.AnchorPoint = Vector2.new(0, 0.5)
	head.Position = UDim2.fromScale(0.05 / aspect + 0.02, 0.5)
	head.Size = UDim2.fromScale(headWidth, headSize)
	head.BackgroundColor3 = Color3.fromRGB(52, 54, 66)
	head.BorderSizePixel = 0
	head.Visible = false
	local headCorner = Instance.new("UICorner")
	headCorner.CornerRadius = UDim.new(0.2, 0)
	headCorner.Parent = head
	stroke(head, 3)
	head.Parent = plate

	local textX = head.Position.X.Scale + headWidth + 0.03
	local textWidth = 1 - textX - 0.03
	local nameLabel = newLabel(
		plate,
		"DisplayName",
		UDim2.fromScale(textX, 0.12),
		UDim2.fromScale(textWidth, 0.5),
		white,
		3
	)
	nameLabel.Visible = false
	local tagLabel = newLabel(
		plate,
		"UserName",
		UDim2.fromScale(textX, 0.64),
		UDim2.fromScale(textWidth, 0.24),
		subColor,
		2
	)
	tagLabel.Visible = false

	local empty = newLabel(plate, "Empty", UDim2.fromScale(0.04, 0.2), UDim2.fromScale(0.92, 0.6), white, 3)
	empty.TextXAlignment = Enum.TextXAlignment.Center
	empty.Text = emptyText
end

local function newSurface(panel: BasePart, face: Face, aspect: number): SurfaceGui
	local gui = Instance.new("SurfaceGui")
	gui.Name = guiName
	gui.Face = face.Face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = pixelsPerStud
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false
	gui.Adornee = panel
	fill(gui, aspect)
	gui.Parent = panel
	return gui
end

local function newBillboard(base: BasePart): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = guiName
	gui.Size = billboardSize
	gui.StudsOffset = billboardOffset
	gui.MaxDistance = billboardDistance
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.ResetOnSpawn = false
	gui.Adornee = base
	fill(gui, billboardSize.X.Scale / billboardSize.Y.Scale)
	gui.Parent = base
	return gui
end

function OwnerSign.new(model: Model, base: BasePart, trove: TroveInstance): Display
	local guis: { Instance } = {}
	local sign = model:FindFirstChild("Sign")
	local panel = if sign then sign:FindFirstChild("Panel") else nil
	if panel and panel:IsA("BasePart") then
		local front, back, aspect = OwnerSign.Faces(panel, base)
		table.insert(guis, newSurface(panel, front, aspect))
		table.insert(guis, newSurface(panel, back, aspect))
	else
		table.insert(guis, newBillboard(base))
	end
	for _, gui in guis do
		trove:Add(gui)
	end
	local self = setmetatable({ Guis = guis }, OwnerSign)
	local display = self :: any
	display:Set(nil)
	return display
end

function OwnerSign.Set(self: Display, player: Player?)
	for _, gui in self.Guis do
		local plate = gui:FindFirstChild("Plate") :: Frame
		local head = plate:FindFirstChild("Headshot") :: ImageLabel
		local nameLabel = plate:FindFirstChild("DisplayName") :: TextLabel
		local tagLabel = plate:FindFirstChild("UserName") :: TextLabel
		local empty = plate:FindFirstChild("Empty") :: TextLabel
		if player then
			head.Image = `rbxthumb://type=AvatarHeadShot&id={player.UserId}&w=150&h=150`
			nameLabel.Text = player.DisplayName
			tagLabel.Text = `@{player.Name}`
		end
		head.Visible = player ~= nil
		nameLabel.Visible = player ~= nil
		tagLabel.Visible = player ~= nil
		empty.Visible = player == nil
	end
end

return OwnerSign
