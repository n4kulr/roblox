--!strict

local Kit = require(script.Parent.Parent.Parent.UIController.Kit)
local Viewport = require(script.Parent.Parent.Parent.UIController.Viewport)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

type Role = Types.Role
type FadeEntry = Types.FadeEntry
type Piece = Types.Piece
type View = Types.View
local cardHeight = Config.CardHeight
local rowTop = Config.RowTop
local chipHeight = Config.ChipHeight
local holderHeight = Config.HolderHeight
local chipGap = Config.ChipGap
local facePad = Config.FacePad
local slotMaxWidth = Config.SlotMaxWidth
local bottomOffset = Config.BottomOffset
local fadeSeconds = Config.FadeSeconds
local confettiCap = Config.ConfettiCap
local modelSize = Config.ModelSize
local modelInset = Config.ModelInset
local nameTextSize = Config.NameTextSize
local chipTextSize = Config.ChipTextSize
local bannerTextSize = Config.BannerTextSize
local white = Config.White
local goldColor = Kit.Theme.Gold
local ink = Kit.Theme.Ink

local Build = {}

local emptyList: { string } = {}
local fadeProperties: { [string]: { string } } = {
	Frame = { "BackgroundTransparency" },
	TextLabel = { "TextTransparency", "BackgroundTransparency" },
	ImageLabel = { "ImageTransparency" },
	ViewportFrame = { "ImageTransparency", "BackgroundTransparency" },
	UIStroke = { "Transparency" },
}

local function collectFades(root: Instance): { FadeEntry }
	local entries: { FadeEntry } = {}
	for _, item in root:GetDescendants() do
		local target: any = item
		local properties = fadeProperties[item.ClassName]
		for _, property in properties or emptyList do
			local ok, base = pcall(function()
				return target[property]
			end)
			if ok and type(base) == "number" then
				table.insert(entries, { Target = target, Property = property, Base = base })
			end
		end
	end
	return entries
end

function Build.ApplyAlpha(view: View, alpha: number)
	if view.Alpha == alpha then
		return
	end
	view.Alpha = alpha
	for _, entry in view.Fades do
		entry.Target[entry.Property] = entry.Base + (1 - entry.Base) * alpha
	end
end

local function buildBurst(parent: Instance, name: string, zIndex: number): Frame
	local burst =
		Kit.Burst({ Parent = parent, Diameter = 400, Position = UDim2.new(0.5, 0, 0, cardHeight / 2) })
	burst.Name = name
	burst.ZIndex = zIndex
	burst.Visible = false
	for _, child in burst:GetChildren() do
		if child:IsA("ImageLabel") then
			child.ZIndex = zIndex
			child.ImageTransparency = 0.3
		elseif child:IsA("GuiObject") then
			child.ZIndex = zIndex
		end
	end
	return burst
end

local function buildChip(parent: Instance, name: string, order: number): (Frame, TextLabel)
	local label = Kit.Chip({
		Parent = parent,
		Name = name,
		Text = "",
		Size = UDim2.fromOffset(120, chipHeight),
		LayoutOrder = order,
		TextSize = chipTextSize,
	})
	local chip = label.Parent :: Frame
	chip.ZIndex = 4
	label.ZIndex = 5
	return chip, label
end

function Build.View(root: Instance, index: number): View
	local holder = Instance.new("Frame")
	holder.Name = `Result{index}`
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.ClipsDescendants = false
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -bottomOffset)
	holder.Size = UDim2.fromOffset(slotMaxWidth, holderHeight)
	holder.Visible = false
	holder.Parent = root
	local scale = Instance.new("UIScale")
	scale.Parent = holder

	local burst = buildBurst(holder, "Burst", 1)
	local burstEcho = buildBurst(holder, "BurstEcho", 1)

	local goldFrame = Kit.Panel({
		Parent = holder,
		Name = "GoldFrame",
		Color = goldColor,
		Position = UDim2.fromOffset(-7, -7),
		Size = UDim2.new(1, 14, 0, cardHeight + 14),
		Radius = 20,
		StrokeColor = ink,
		StrokeThickness = 3,
	})
	goldFrame.ZIndex = 2
	goldFrame.Visible = false

	local card = Kit.Panel({
		Parent = holder,
		Name = "Card",
		Color = Kit.Theme.Panel,
		Size = UDim2.new(1, 0, 0, cardHeight),
		Radius = 16,
		StrokeColor = ink,
		StrokeThickness = 3,
	})
	card.ZIndex = 3

	local face = Kit.Panel({
		Parent = card,
		Name = "Face",
		Color = Kit.Theme.Panel,
		Position = UDim2.fromOffset(facePad, 5),
		Size = UDim2.new(1, -facePad * 2, 1, -17),
		Radius = 12,
		StrokeColor = ink,
		StrokeThickness = 2,
	})
	face.ZIndex = 3
	Kit.Gloss(face, 12)

	local name = Kit.Label({
		Parent = face,
		Name = "KeyName",
		Size = UDim2.new(1, -modelInset - 28, 1, -6),
		Position = UDim2.fromOffset(modelInset + 8, 3),
		TextSize = nameTextSize,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	name.ZIndex = 4

	local shimmer = Instance.new("Frame")
	shimmer.Name = "Shimmer"
	shimmer.BackgroundColor3 = white
	shimmer.BackgroundTransparency = 0
	shimmer.BorderSizePixel = 0
	shimmer.Size = UDim2.fromScale(1, 1)
	shimmer.ZIndex = 6
	shimmer.Visible = false
	Kit.Corner(shimmer, 12)
	local shimmerGradient = Instance.new("UIGradient")
	shimmerGradient.Rotation = 25
	shimmerGradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.38, 1),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(0.62, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	shimmerGradient.Offset = Vector2.new(-1, 0)
	shimmerGradient.Parent = shimmer
	shimmer.Parent = face

	local model = Viewport.new({
		Parent = holder,
		Name = "KeyModel",
		Size = UDim2.fromOffset(modelSize, modelSize),
		Position = UDim2.fromOffset(-24, -12),
		ZIndex = 5,
	})
	Viewport.Glint(model, 0)

	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.ClipsDescendants = false
	row.Position = UDim2.fromOffset(0, rowTop)
	row.Size = UDim2.new(1, 0, 0, chipHeight)
	row.ZIndex = 4
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, chipGap)
	list.Parent = row
	row.Parent = holder
	local rarityChip, rarityLabel = buildChip(row, "RarityChip", 1)
	local incomeChip, incomeLabel = buildChip(row, "IncomeChip", 2)
	Kit.Paint(incomeChip, Kit.Theme.Green)

	local banner = Kit.Label({
		Parent = holder,
		Name = "Banner",
		Size = UDim2.fromOffset(360, 56),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -8),
		TextSize = bannerTextSize,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	banner.ZIndex = 7
	banner.Visible = false
	local bannerStroke = banner:FindFirstChild("TextStroke") :: UIStroke
	bannerStroke.Thickness = 5
	local bannerScale = Instance.new("UIScale")
	bannerScale.Parent = banner

	return {
		Holder = holder,
		Scale = scale,
		GoldFrame = goldFrame,
		Card = card,
		Face = face,
		Model = model,
		ModelKey = "",
		Name = name,
		Shimmer = shimmer,
		ShimmerGradient = shimmerGradient,
		Row = row,
		RarityChip = rarityChip,
		RarityLabel = rarityLabel,
		IncomeChip = incomeChip,
		IncomeLabel = incomeLabel,
		Banner = banner,
		BannerScale = bannerScale,
		Burst = burst,
		BurstEcho = burstEcho,
		Fades = collectFades(holder),
		Tweens = {},
		Role = nil,
		Slot = "Center",
		Width = slotMaxWidth,
		Rank = 1,
		Age = 0,
		Token = 0,
		FadeElapsed = 0,
		FadeSeconds = fadeSeconds,
		IsFading = false,
		Alpha = 0,
	}
end

function Build.Pieces(layer: Frame): { Piece }
	local pieces: { Piece } = {}
	for index = 1, confettiCap do
		local frame = Instance.new("Frame")
		frame.Name = `Piece{index}`
		frame.BorderSizePixel = 0
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.Size = UDim2.fromOffset(10, 14)
		frame.ZIndex = 8
		frame.Visible = false
		frame.Parent = layer
		table.insert(pieces, {
			Frame = frame,
			Active = false,
			X = 0,
			Y = 0,
			VX = 0,
			VY = 0,
			Rotation = 0,
			Spin = 0,
			Age = 0,
			Life = 1,
		})
	end
	return pieces
end

return Build
