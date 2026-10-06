--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Keys = require(ReplicatedStorage.Config.Keys)
local Trove = require(ReplicatedStorage.Packages.Trove)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Kit = require(script.Parent.Parent.UIController.Kit)
local ResultSlots = require(script.Parent.ResultSlots)

type TroveInstance = typeof(Trove.new())

export type Payload = {
	Key: Keys.Key,
	Rarity: Keys.Rarity,
	IsGolden: boolean,
}

type Role = "Rail" | "Fading" | "Common"

type FadeEntry = {
	Target: any,
	Property: string,
	Base: number,
}

type Piece = {
	Frame: Frame,
	Active: boolean,
	X: number,
	Y: number,
	VX: number,
	VY: number,
	Rotation: number,
	Spin: number,
	Age: number,
	Life: number,
}

type View = {
	Holder: Frame,
	Scale: UIScale,
	GoldFrame: Frame,
	Card: Frame,
	Face: Frame,
	Name: TextLabel,
	Shimmer: Frame,
	ShimmerGradient: UIGradient,
	Row: Frame,
	RarityChip: Frame,
	RarityLabel: TextLabel,
	IncomeChip: Frame,
	IncomeLabel: TextLabel,
	Banner: TextLabel,
	BannerScale: UIScale,
	Burst: Frame,
	BurstEcho: Frame,
	Fades: { FadeEntry },
	Tweens: { Tween },
	Role: Role?,
	Slot: ResultSlots.Slot,
	Width: number,
	Rank: number,
	Age: number,
	Token: number,
	FadeElapsed: number,
	FadeSeconds: number,
	IsFading: boolean,
	Alpha: number,
}

export type ResultCards = {
	_trove: TroveInstance,
	_isLowGraphics: () -> boolean,
	_gui: ScreenGui,
	_root: Frame,
	_scale: UIScale?,
	_views: { View },
	_rail: View?,
	_common: View?,
	_pieces: { Piece },
	_confetti: Frame,
	_flash: Frame,
	_flashTween: Tween?,
	_humanoid: Humanoid?,
	_baseOffset: Vector3,
	_shakeLeft: number,
	_shakeTotal: number,
	_shakeStrength: number,
	_destroyed: boolean,
	Show: (self: ResultCards, slot: ResultSlots.Slot, payload: Payload, isRare: boolean) -> (),
	Fade: (self: ResultCards, isRare: boolean, isFast: boolean) -> (),
	Hide: (self: ResultCards, isRare: boolean) -> (),
	Run: (self: ResultCards, actions: { ResultSlots.Action }) -> (),
	Step: (self: ResultCards, dt: number) -> (),
	Flash: (self: ResultCards, color: Color3, transparency: number, seconds: number) -> (),
	VisibleCount: (self: ResultCards) -> number,
	ActiveConfetti: (self: ResultCards) -> number,
	Destroy: (self: ResultCards) -> (),
}

local cardHeight = 76
local rowTop = 84
local chipHeight = 30
local holderHeight = 116
local chipGap = 8
local chipPad = 26
local facePad = 6
local slotMaxWidth = 440
local slotShare = 0.45
local slotGap = 44
local bottomOffset = 160
local minWidth = 220
local fadeSeconds = 0.25
local fastFadeSeconds = 0.15
local confettiCap = 30
local gravity = 1100
local nameTextSize = 46
local chipTextSize = 20
local bannerTextSize = 48
local glyphWidth = 0.6
local goldColor = Kit.Theme.Gold
local ink = Kit.Theme.Ink
local white = Color3.new(1, 1, 1)

local rarityRank: { [string]: number } = {}
for index, rarity in Keys.Rarities do
	rarityRank[rarity.Name] = index
end
local rareRank = rarityRank.Rare or 3
local epicRank = rarityRank.Epic or 4
local legendaryRank = rarityRank.Legendary or 5

local slotAnchor: { [ResultSlots.Slot]: number } = { Center = 0.5, Left = 1, Right = 0 }
local slotOffset: { [ResultSlots.Slot]: number } = { Center = 0, Left = -slotGap, Right = slotGap }

local ResultCards = {}
ResultCards.__index = ResultCards

local function estimate(text: string, size: number): number
	return #text * size * glyphWidth
end

local emptyList: { string } = {}
local fadeProperties: { [string]: { string } } = {
	Frame = { "BackgroundTransparency" },
	TextLabel = { "TextTransparency", "BackgroundTransparency" },
	ImageLabel = { "ImageTransparency" },
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

local function applyAlpha(view: View, alpha: number)
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

local function buildView(root: Instance, index: number): View
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
		Size = UDim2.new(1, -20, 1, -6),
		Position = UDim2.fromOffset(10, 3),
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

local function buildPieces(layer: Frame): { Piece }
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

function ResultCards.new(playerGui: Instance, trove: TroveInstance, isLowGraphics: () -> boolean): ResultCards
	local gui, root = Kit.ScreenGui("RollCard", 3, playerGui, trove)
	local views: { View } = {}
	for index = 1, 2 do
		table.insert(views, buildView(root, index))
	end
	local confetti = Instance.new("Frame")
	confetti.Name = "Confetti"
	confetti.BackgroundTransparency = 1
	confetti.BorderSizePixel = 0
	confetti.ClipsDescendants = false
	confetti.Active = false
	confetti.Size = UDim2.fromScale(1, 1)
	confetti.ZIndex = 8
	confetti.Parent = root

	local flashGui = Instance.new("ScreenGui")
	flashGui.Name = "RollFlash"
	flashGui.ResetOnSpawn = false
	flashGui.IgnoreGuiInset = true
	flashGui.DisplayOrder = 4
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.BorderSizePixel = 0
	flash.BackgroundColor3 = white
	flash.BackgroundTransparency = 1
	flash.Size = UDim2.fromScale(1, 1)
	flash.Active = false
	flash.Parent = flashGui
	flashGui.Parent = playerGui
	trove:Add(flashGui)

	local self: ResultCards = setmetatable({
		_trove = trove,
		_isLowGraphics = isLowGraphics,
		_gui = gui,
		_root = root,
		_scale = root:FindFirstChild("ViewportScale") :: UIScale?,
		_views = views,
		_rail = nil,
		_common = nil,
		_pieces = buildPieces(confetti),
		_confetti = confetti,
		_flash = flash,
		_flashTween = nil,
		_humanoid = nil,
		_baseOffset = Vector3.zero,
		_shakeLeft = 0,
		_shakeTotal = 0,
		_shakeStrength = 0,
		_destroyed = false,
	}, ResultCards) :: any
	trove:Add(function()
		self:Destroy()
	end)
	return self
end

local function cancelTweens(view: View)
	view.Token += 1
	for _, active in view.Tweens do
		active:Cancel()
		active:Destroy()
	end
	table.clear(view.Tweens)
end

local function track(view: View, tween: Tween): Tween
	table.insert(view.Tweens, tween)
	return tween
end

local function release(self: ResultCards, view: View)
	cancelTweens(view)
	view.Holder.Visible = false
	view.IsFading = false
	view.Role = nil
	if view == self._rail then
		self._rail = nil
	end
	if view == self._common then
		self._common = nil
	end
end

local function acquire(self: ResultCards): View
	local order: { Role? } = { nil, "Common", "Fading", "Rail" }
	for index = 1, 4 do
		local wanted = order[index]
		for _, view in self._views do
			if view.Role == wanted then
				return view
			end
		end
	end
	return self._views[1]
end

local function maxWidth(self: ResultCards): number
	local scale = self._scale
	local virtualWidth = if scale and scale.Scale > 0 then self._gui.AbsoluteSize.X / scale.Scale else 1280
	if virtualWidth <= 0 then
		virtualWidth = 1280
	end
	return math.max(math.min(slotMaxWidth, slotShare * virtualWidth), 160)
end

local function place(view: View, slot: ResultSlots.Slot)
	view.Slot = slot
	view.Holder.AnchorPoint = Vector2.new(slotAnchor[slot], 1)
	view.Holder.Position = UDim2.new(0.5, slotOffset[slot], 1, -bottomOffset)
end

local function paintCard(view: View, rarity: Keys.Rarity, isGolden: boolean)
	local color = rarity.Color
	Kit.Paint(view.Card, color)
	Kit.Paint(view.Face, Kit.Shade(color, 0.12))
	Kit.Paint(view.RarityChip, Kit.Shade(color, -0.12))
	local stroke = Kit.StrokeOf(view.Card)
	stroke.Color = ink
	stroke.Thickness = 3
	view.GoldFrame.Visible = isGolden
end

local function sizeCard(
	self: ResultCards,
	view: View,
	nameText: string,
	rarityText: string,
	incomeText: string
)
	local limit = maxWidth(self)
	local nameWidth = estimate(nameText, nameTextSize) + 44
	local rarityWidth = estimate(rarityText, chipTextSize) + chipPad
	local incomeWidth = estimate(incomeText, chipTextSize) + chipPad
	local rowWidth = rarityWidth + incomeWidth + chipGap
	local width = math.clamp(math.max(nameWidth, rowWidth, minWidth), minWidth, limit)
	local fit = math.min(1, width / rowWidth)
	view.Width = width
	view.Holder.Size = UDim2.fromOffset(width, holderHeight)
	view.RarityChip.Size = UDim2.fromOffset(math.floor(rarityWidth * fit), chipHeight)
	view.IncomeChip.Size = UDim2.fromOffset(math.floor(incomeWidth * fit), chipHeight)
end

local function bannerText(rarity: Keys.Rarity, rank: number, isGolden: boolean, isCentered: boolean): string?
	if rank >= legendaryRank then
		local text = `{string.upper(rarity.Name)}!`
		return if isGolden then `GOLDEN {text}` else text
	end
	if isGolden and isCentered then
		return "GOLDEN!"
	end
	return nil
end

local function spawnConfetti(self: ResultCards, view: View, rarity: Keys.Rarity, rank: number)
	local count = if rank >= legendaryRank + 2 then 30 elseif rank >= legendaryRank + 1 then 24 else 18
	local palette =
		{ Kit.Shade(rarity.Color, 0.25), white, goldColor, Kit.Theme.Pink, Kit.Theme.Blue, Kit.Theme.Good }
	local originX = slotOffset[view.Slot] + (0.5 - slotAnchor[view.Slot]) * 2 * (view.Width / 2)
	local spawned = 0
	for _, piece in self._pieces do
		if spawned >= count then
			break
		end
		if not piece.Active then
			spawned += 1
			local angle = math.rad(-90 + (math.random() - 0.5) * 140)
			local speed = 380 + math.random() * 460
			piece.Active = true
			piece.X = originX + (math.random() - 0.5) * view.Width * 0.5
			piece.Y = -bottomOffset - cardHeight / 2
			piece.VX = math.cos(angle) * speed
			piece.VY = math.sin(angle) * speed
			piece.Rotation = math.random() * 360
			piece.Spin = (math.random() - 0.5) * 900
			piece.Age = 0
			piece.Life = 1.3 + math.random() * 0.6
			piece.Frame.BackgroundColor3 = palette[math.random(1, #palette)]
			piece.Frame.BackgroundTransparency = 0
			piece.Frame.Size = UDim2.fromOffset(math.random(8, 12), math.random(12, 18))
			piece.Frame.Visible = true
		end
	end
end

local function startShake(self: ResultCards, strength: number)
	if self._shakeLeft <= 0 then
		local player = Players.LocalPlayer
		local character = if player then player.Character else nil
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if not humanoid then
			return
		end
		self._humanoid = humanoid
		self._baseOffset = humanoid.CameraOffset
	end
	self._shakeTotal = 0.32
	self._shakeLeft = 0.32
	self._shakeStrength = strength
end

function ResultCards.Flash(self: ResultCards, color: Color3, transparency: number, seconds: number)
	if self._destroyed or self._isLowGraphics() then
		return
	end
	local previous = self._flashTween
	if previous then
		previous:Cancel()
		previous:Destroy()
	end
	local flash = self._flash
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = transparency
	local fadeOut = TweenService:Create(
		flash,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 1 }
	)
	self._flashTween = fadeOut
	fadeOut.Completed:Once(function()
		if self._flashTween == fadeOut then
			self._flashTween = nil
		end
		fadeOut:Destroy()
	end)
	fadeOut:Play()
end

function ResultCards.Show(self: ResultCards, slot: ResultSlots.Slot, payload: Payload, isRare: boolean)
	if self._destroyed then
		return
	end
	local view = if isRare then acquire(self) else self._common or acquire(self)
	if view.Role == "Rail" and view == self._rail then
		self._rail = nil
	end
	cancelTweens(view)
	view.Role = if isRare then "Rail" else "Common"
	if isRare then
		self._rail = view
		if self._common == view then
			self._common = nil
		end
	else
		self._common = view
		if self._rail == view then
			self._rail = nil
		end
	end

	local key, rarity, isGolden = payload.Key, payload.Rarity, payload.IsGolden
	local rank = rarityRank[rarity.Name] or 1
	local isLow = self._isLowGraphics()
	local rarityText = `{rarity.Name} · 1 in {NumberFormat.Commas(rarity.Chance)}`
	local incomeText = `+{NumberFormat.Compact(Keys.GetIncome(key.Id))}/s`
	view.Rank = rank
	view.Age = 0
	view.IsFading = false
	view.Name.Text = key.Name
	view.RarityLabel.Text = rarityText
	view.IncomeLabel.Text = incomeText
	paintCard(view, rarity, isGolden)
	sizeCard(self, view, key.Name, rarityText, incomeText)
	place(view, slot)
	view.Holder.ZIndex = if isRare then 2 else 3

	local hasBurst = rank >= rareRank
	view.Burst.Visible = hasBurst
	view.BurstEcho.Visible = hasBurst and rank >= epicRank
	if hasBurst then
		local diameter = if rank >= legendaryRank then 600 elseif rank >= epicRank then 500 else 420
		view.Burst.Size = UDim2.fromOffset(diameter, diameter)
		view.BurstEcho.Size = UDim2.fromOffset(diameter * 0.66, diameter * 0.66)
		local image = view.Burst:FindFirstChild("Image")
		if image then
			(image :: ImageLabel).ImageColor3 = rarity.Color
		end
		local echo = view.BurstEcho:FindFirstChild("Image")
		if echo then
			(echo :: ImageLabel).ImageColor3 = white
		end
		view.Burst.Rotation = math.random() * 360
		view.BurstEcho.Rotation = math.random() * 360
	end
	view.Shimmer.Visible = rank >= epicRank
	view.ShimmerGradient.Offset = Vector2.new(-1, 0)

	local banner = bannerText(rarity, rank, isGolden, slot == "Center")
	view.Banner.Visible = banner ~= nil
	if banner then
		view.Banner.Text = banner
		view.Banner.TextColor3 = if isGolden then goldColor else Kit.Shade(rarity.Color, 0.35)
		view.Banner.Size =
			UDim2.fromOffset(math.clamp(estimate(banner, bannerTextSize) + 40, 160, view.Width + 80), 56)
	end
	view.BannerScale.Scale = 1

	applyAlpha(view, 0)
	view.Holder.Visible = true

	if isLow then
		view.Scale.Scale = 1
		view.Holder.Rotation = 0
		view.BannerScale.Scale = 1
	else
		local isLight = rank < rareRank
		local tilt = (math.random() - 0.5) * (if isLight then 6 else 11)
		view.Scale.Scale = if isLight then 0.55 else 0.4
		view.Holder.Rotation = tilt
		track(
			view,
			TweenService:Create(
				view.Scale,
				TweenInfo.new(if isLight then 0.2 else 0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = 1 }
			)
		):Play()
		track(
			view,
			TweenService:Create(
				view.Holder,
				TweenInfo.new(if isLight then 0.3 else 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Rotation = 0 }
			)
		):Play()
		if banner then
			local token = view.Token
			view.BannerScale.Scale = 0.3
			local punch = track(
				view,
				TweenService:Create(
					view.BannerScale,
					TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
					{ Scale = 1.35 }
				)
			)
			punch.Completed:Once(function()
				if view.Token == token and not self._destroyed then
					track(
						view,
						TweenService:Create(
							view.BannerScale,
							TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
							{ Scale = 1 }
						)
					):Play()
				end
			end)
			punch:Play()
		end
		if rank >= rareRank then
			self:Flash(
				white,
				if rank >= epicRank then 0.35 else 0.62,
				if rank >= epicRank then 0.35 else 0.25
			)
		end
		if rank >= epicRank then
			startShake(self, if rank >= legendaryRank then 0.45 else 0.22)
		end
		if rank >= legendaryRank then
			spawnConfetti(self, view, rarity, rank)
		end
	end
end

function ResultCards.Fade(self: ResultCards, isRare: boolean, isFast: boolean)
	local view = if isRare then self._rail else self._common
	if not view or self._destroyed then
		return
	end
	if isRare then
		self._rail = nil
		view.Role = "Fading"
	end
	cancelTweens(view)
	view.IsFading = true
	view.FadeElapsed = 0
	view.FadeSeconds = if isFast then fastFadeSeconds else fadeSeconds
	if not self._isLowGraphics() then
		local current = view.Holder.Position
		track(
			view,
			TweenService:Create(
				view.Holder,
				TweenInfo.new(view.FadeSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
				{
					Position = UDim2.new(
						current.X.Scale,
						current.X.Offset,
						current.Y.Scale,
						current.Y.Offset + 24
					),
				}
			)
		):Play()
	end
end

function ResultCards.Hide(self: ResultCards, isRare: boolean)
	local view = if isRare then self._rail else self._common
	if view then
		release(self, view)
	end
end

function ResultCards.Run(self: ResultCards, actions: { ResultSlots.Action })
	for _, action in actions do
		if action.Kind == "Show" then
			self:Show(action.Slot, action.Payload :: Payload, action.IsRare)
		elseif action.Kind == "Fade" then
			self:Fade(action.IsRare, action.Fast == true)
		end
	end
end

local function stepView(self: ResultCards, view: View, dt: number)
	view.Age += dt
	if self._isLowGraphics() then
		view.Shimmer.Visible = false
	else
		if view.Burst.Visible then
			view.Burst.Rotation = (view.Burst.Rotation + dt * 24) % 360
			view.BurstEcho.Rotation = (view.BurstEcho.Rotation - dt * 38) % 360
		end
		if view.Shimmer.Visible then
			local phase = (view.Age % 2) / 1.1
			view.ShimmerGradient.Offset = Vector2.new(-1 + 2 * math.min(phase, 1), 0)
		end
	end
	if view.IsFading then
		view.FadeElapsed += dt
		local alpha = math.clamp(view.FadeElapsed / view.FadeSeconds, 0, 1)
		applyAlpha(view, alpha * alpha)
		if alpha >= 1 then
			release(self, view)
		end
	end
end

local function stepConfetti(self: ResultCards, dt: number)
	for _, piece in self._pieces do
		if piece.Active then
			piece.Age += dt
			if piece.Age >= piece.Life then
				piece.Active = false
				piece.Frame.Visible = false
			else
				piece.VY += gravity * dt
				piece.VX *= 1 - math.min(dt * 1.2, 1)
				piece.X += piece.VX * dt
				piece.Y += piece.VY * dt
				piece.Rotation += piece.Spin * dt
				local frame = piece.Frame
				frame.Position = UDim2.new(0.5, piece.X, 1, piece.Y)
				frame.Rotation = piece.Rotation
				local remaining = piece.Life - piece.Age
				frame.BackgroundTransparency = if remaining < 0.4 then 1 - remaining / 0.4 else 0
			end
		end
	end
end

local function stepShake(self: ResultCards, dt: number)
	if self._shakeLeft <= 0 then
		return
	end
	local humanoid = self._humanoid
	self._shakeLeft -= dt
	if not humanoid then
		self._shakeLeft = 0
		return
	end
	if self._shakeLeft <= 0 then
		self._shakeLeft = 0
		humanoid.CameraOffset = self._baseOffset
		return
	end
	local amplitude = self._shakeStrength * (self._shakeLeft / self._shakeTotal)
	humanoid.CameraOffset = self._baseOffset
		+ Vector3.new((math.random() - 0.5) * 2 * amplitude, (math.random() - 0.5) * 2 * amplitude, 0)
end

function ResultCards.Step(self: ResultCards, dt: number)
	if self._destroyed then
		return
	end
	for _, view in self._views do
		if view.Holder.Visible then
			stepView(self, view, dt)
		end
	end
	stepConfetti(self, dt)
	if self._isLowGraphics() then
		self._shakeLeft = 0
	end
	stepShake(self, dt)
end

function ResultCards.VisibleCount(self: ResultCards): number
	local count = 0
	for _, view in self._views do
		if view.Holder.Visible then
			count += 1
		end
	end
	return count
end

function ResultCards.ActiveConfetti(self: ResultCards): number
	local count = 0
	for _, piece in self._pieces do
		if piece.Active then
			count += 1
		end
	end
	return count
end

function ResultCards.Destroy(self: ResultCards)
	if self._destroyed then
		return
	end
	self._destroyed = true
	for _, view in self._views do
		cancelTweens(view)
	end
	local flashTween = self._flashTween
	if flashTween then
		flashTween:Cancel()
		flashTween:Destroy()
		self._flashTween = nil
	end
	local humanoid = self._humanoid
	if humanoid and self._shakeLeft > 0 then
		humanoid.CameraOffset = self._baseOffset
	end
	self._shakeLeft = 0
	table.clear(self._views)
	self._rail = nil
	self._common = nil
end

return ResultCards
