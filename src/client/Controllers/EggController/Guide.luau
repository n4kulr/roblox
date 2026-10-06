--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Eggs = require(ReplicatedStorage.Config.Eggs)
local Trove = require(ReplicatedStorage.Packages.Trove)
local FloorGrid = require(ReplicatedStorage.Rules.FloorGrid)
local BaseBounds = require(ReplicatedStorage.Utils.BaseBounds)
local EdgeIndicator = require(ReplicatedStorage.Utils.EdgeIndicator)
local Kit = require(script.Parent.Parent.UIController.Kit)

export type Guide = {
	Update: (self: Guide, clock: number, root: BasePart?, camera: Camera?) -> (),
	Destroy: (self: Guide) -> (),
}

type Piece = { Part: Part, Offset: CFrame }

local config = Eggs.Guide
local folderName = "EggGuide"
local guiName = "EggGuide"
local headAngle = math.pi / 4
local barLength = 5
local barThickness = 1.4
local shaftLength = 4
local shaftThickness = 1.5
local tipOffset = barLength * math.sqrt(0.5) / 2
local edgeLabelHeight = 24
local edgeGap = 4
local edgeTextSize = 20
local hintHeight = 40
local hintBottom = 120
local hintWidth = 520
local hintTextSize = 28
local guiOrder = 5

local Guide = {}

local function invisibleAnchor(name: string, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Parent = parent
	return part
end

local function solidPart(name: string, size: Vector3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = config.Color
	part.Size = size
	part.Parent = parent
	return part
end

local function buildArrow(parent: Instance): (Model, { Piece })
	local model = Instance.new("Model")
	model.Name = "Arrow"
	local scale = config.ArrowSize
	local barSize = Vector3.new(barLength * scale, barThickness * scale, shaftThickness * scale)
	local shift = tipOffset * scale
	local shaftHeight = shift + shaftLength * scale
	local pieces: { Piece } = {
		{
			Part = solidPart("HeadLeft", barSize, model),
			Offset = CFrame.new(-shift, shift, 0) * CFrame.Angles(0, 0, -headAngle),
		},
		{
			Part = solidPart("HeadRight", barSize, model),
			Offset = CFrame.new(shift, shift, 0) * CFrame.Angles(0, 0, headAngle),
		},
		{
			Part = solidPart(
				"Shaft",
				Vector3.new(shaftThickness * scale, shaftHeight, shaftThickness * scale),
				model
			),
			Offset = CFrame.new(0, shift + shaftHeight / 2, 0),
		},
	}
	model.Parent = parent
	return model, pieces
end

function Guide.new(base: BasePart, playerGui: Instance): Guide
	local trove = Trove.new()
	local folder = Instance.new("Folder")
	folder.Name = folderName
	folder.Parent = workspace
	trove:Add(folder)

	local floorY = base.Size.Y / 2 + FloorGrid.CapHeight
	local anchorCFrame = base.CFrame * CFrame.new(0, floorY + config.TargetHeight, 0)
	local target = invisibleAnchor("Target", folder)
	target.CFrame = anchorCFrame
	local targetAttachment = Instance.new("Attachment")
	targetAttachment.Name = "GuideTarget"
	targetAttachment.Parent = target

	local beam = Instance.new("Beam")
	beam.Name = "GuideBeam"
	beam.Color = ColorSequence.new(config.Color)
	beam.LightEmission = 0
	beam.LightInfluence = 0
	beam.Texture = ""
	beam.FaceCamera = true
	beam.Segments = config.BeamSegments
	beam.CurveSize0 = config.BeamCurve
	beam.CurveSize1 = -config.BeamCurve
	beam.Width0 = config.BeamWidth
	beam.Width1 = config.BeamWidth
	beam.Transparency = NumberSequence.new(config.BeamTransparency)
	beam.Enabled = false
	beam.Attachment1 = targetAttachment
	beam.Parent = folder

	local arrow, pieces = buildArrow(folder)
	trove:Add(arrow)

	local gui = Instance.new("ScreenGui")
	gui.Name = guiName
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = guiOrder
	gui.Parent = playerGui
	trove:Add(gui)

	local edge = Instance.new("Frame")
	edge.Name = "Edge"
	edge.BackgroundTransparency = 1
	edge.AnchorPoint = Vector2.new(0.5, 0.5)
	edge.Size = UDim2.fromOffset(config.EdgeArrowSize * 3, config.EdgeArrowSize + edgeLabelHeight + edgeGap)
	edge.Visible = false
	edge.Parent = gui
	local edgeArrow = Kit.Icon({
		Parent = edge,
		Name = "Arrow",
		Glyph = "Arrow",
		Color = config.Color,
		Size = UDim2.fromOffset(config.EdgeArrowSize, config.EdgeArrowSize),
		Position = UDim2.new(0.5, 0, 0, config.EdgeArrowSize / 2),
		AnchorPoint = Vector2.new(0.5, 0.5),
	})
	Kit.Label({
		Parent = edge,
		Name = "Text",
		Text = config.EdgeText,
		Size = UDim2.new(1, 0, 0, edgeLabelHeight),
		Position = UDim2.new(0, 0, 0, config.EdgeArrowSize + edgeGap),
		TextSize = edgeTextSize,
		Color = config.Color,
		Title = true,
		Scaled = true,
		Align = Enum.TextXAlignment.Center,
	})

	local hint = Kit.Label({
		Parent = gui,
		Name = "Hint",
		Text = if UserInputService.TouchEnabled then config.HintTouchText else config.HintText,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -hintBottom),
		Size = UDim2.fromOffset(hintWidth, hintHeight),
		TextSize = hintTextSize,
		Color = config.Color,
		Title = true,
		Scaled = true,
		Align = Enum.TextXAlignment.Center,
	})
	hint.Visible = false

	local rootAttachment: Attachment? = nil
	local attachedRoot: BasePart? = nil

	local function attachTo(root: BasePart?)
		if root == attachedRoot then
			return
		end
		if rootAttachment then
			rootAttachment:Destroy()
			rootAttachment = nil
		end
		attachedRoot = root
		if root then
			local attachment = Instance.new("Attachment")
			attachment.Name = "GuideOrigin"
			attachment.Parent = root
			rootAttachment = attachment
		end
		beam.Attachment0 = rootAttachment
	end
	trove:Add(function()
		attachTo(nil)
	end)

	local object = {} :: Guide

	function object.Update(_self: Guide, clock: number, root: BasePart?, camera: Camera?)
		attachTo(root)
		local isInside = root ~= nil and BaseBounds.Contains(base.CFrame, base.Size, root.Position, 0)
		beam.Enabled = root ~= nil and not isInside
		arrow.Parent = if isInside then nil else folder
		hint.Visible = isInside
		local wave = math.sin(clock * config.BeamPulseSpeed)
		local width = config.BeamWidth * (1 + config.BeamPulse * wave)
		beam.Width0 = width
		beam.Width1 = width
		beam.Transparency =
			NumberSequence.new(config.BeamTransparency + config.BeamTransparencyPulse * (wave * 0.5 + 0.5))
		if not isInside then
			local bounce = math.sin(clock * config.ArrowBounceSpeed) * config.ArrowBounce
			local pivot = base.CFrame
				* CFrame.new(0, floorY + config.ArrowHeight + bounce, 0)
				* CFrame.Angles(0, math.rad(clock * config.ArrowSpin), 0)
			for _, piece in pieces do
				piece.Part.CFrame = pivot * piece.Offset
			end
		end
		local isEdge = false
		if camera and not isInside then
			local point, isOnScreen = camera:WorldToViewportPoint(anchorCFrame.Position)
			if not isOnScreen then
				local position, rotation = EdgeIndicator.Place(
					Vector2.new(point.X, point.Y),
					point.Z < 0,
					camera.ViewportSize,
					config.EdgeMargin
				)
				edge.Position = UDim2.fromOffset(position.X, position.Y)
				edgeArrow.Rotation = rotation
				isEdge = true
			end
		end
		edge.Visible = isEdge
	end

	function object.Destroy(_self: Guide)
		trove:Destroy()
	end

	return object
end

return table.freeze(Guide)
