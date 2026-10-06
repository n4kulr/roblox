--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local TweenService = game:GetService("TweenService")
local Keys = require(ReplicatedStorage.Config.Keys)
local KeyTiers = require(ReplicatedStorage.Config.KeyTiers)
local KeyModels = require(ReplicatedStorage.Utils.KeyModels)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Kit = require(script.Parent.Parent.UIController.Kit)
local Viewport = require(script.Parent.Parent.UIController.Viewport)
local CameraShake = require(script.Parent.CameraShake)
local ResultSlots = require(script.Parent.ResultSlots)
local Build = require(script.Build)
local Layout = require(script.Layout)
local Confetti = require(script.Confetti)
local Shake = require(script.Shake)
local Config = require(script.Config)
local Types = require(script.Types)

type TroveInstance = typeof(Trove.new())
export type Payload = Types.Payload
export type ResultCards = Types.ResultCards
type Role = Types.Role
type View = Types.View
local fadeSeconds = Config.FadeSeconds
local fastFadeSeconds = Config.FastFadeSeconds
local staticYaw = Config.StaticYaw
local spinSpeed = Config.SpinSpeed
local bobHeight = Config.BobHeight
local bannerTextSize = Config.BannerTextSize
local white = Config.White
local rareRank = Config.RareRank
local epicRank = Config.EpicRank
local legendaryRank = Config.LegendaryRank
local rarityRank = Config.RarityRank
local goldColor = Kit.Theme.Gold

local ResultCards = {}
ResultCards.__index = ResultCards

function ResultCards.new(playerGui: Instance, trove: TroveInstance, isLowGraphics: () -> boolean): ResultCards
	local gui, root = Kit.ScreenGui("RollCard", 3, playerGui, trove)
	local views: { View } = {}
	for index = 1, 2 do
		table.insert(views, Build.View(root, index))
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
		_pieces = Build.Pieces(confetti),
		_confetti = confetti,
		_flash = flash,
		_flashTween = nil,
		_humanoid = nil,
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
	local fullId = payload.KeyId or key.Id
	local _, variantTier = KeyTiers.Parse(fullId)
	local displayName = if variantTier > 0 then `{KeyTiers.Get(variantTier).Name} {key.Name}` else key.Name
	local rank = rarityRank[rarity.Name] or 1
	local isLow = self._isLowGraphics()
	local rarityText = `{rarity.Name} · 1 in {NumberFormat.Commas(rarity.Chance)}`
	local incomeText = `+{NumberFormat.Compact(Keys.GetIncome(fullId))}/s`
	view.Rank = rank
	view.Age = 0
	view.IsFading = false
	view.Name.Text = displayName
	if view.ModelKey ~= fullId or view.Model.Model == nil then
		Viewport.Set(view.Model, KeyModels.Build(fullId))
		view.ModelKey = fullId
	end
	Viewport.Light(view.Model, if isGolden then goldColor else white, if rank >= epicRank then 0.25 else 0)
	Viewport.Pose(view.Model, staticYaw)
	Viewport.Zoom(view.Model, Viewport.PopScale(0))
	view.RarityLabel.Text = rarityText
	view.IncomeLabel.Text = incomeText
	Layout.PaintCard(view, rarity, isGolden)
	Layout.SizeCard(self, view, displayName, rarityText, incomeText)
	Layout.Place(view, slot)
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

	local banner = Layout.BannerText(rarity, rank, isGolden, slot == "Center")
	view.Banner.Visible = banner ~= nil
	if banner then
		view.Banner.Text = banner
		view.Banner.TextColor3 = if isGolden then goldColor else Kit.Shade(rarity.Color, 0.35)
		view.Banner.Size = UDim2.fromOffset(
			math.clamp(Layout.Estimate(banner, bannerTextSize) + 40, 160, view.Width + 80),
			56
		)
	end
	view.BannerScale.Scale = 1

	Build.ApplyAlpha(view, 0)
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
			Shake.Start(self, if rank >= legendaryRank then 0.45 else 0.22)
		end
		if rank >= legendaryRank then
			Confetti.Spawn(self, view, rarity, rank)
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
	Viewport.Zoom(view.Model, Viewport.PopScale(view.Age))
	if self._isLowGraphics() then
		view.Shimmer.Visible = false
	else
		local handle = view.Model
		Viewport.Glint(handle, view.Age)
		Viewport.Pose(
			handle,
			(staticYaw + view.Age * spinSpeed) % 360,
			0,
			0,
			math.sin(view.Age * 2.6) * bobHeight * handle.Radius
		)
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
		Build.ApplyAlpha(view, alpha * alpha)
		if alpha >= 1 then
			release(self, view)
		end
	end
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
	Confetti.Step(self, dt)
	if self._isLowGraphics() and self._shakeLeft > 0 then
		self._shakeLeft = 0
		local humanoid = self._humanoid
		if humanoid then
			CameraShake.Clear(humanoid, self)
		end
	end
	Shake.Step(self, dt)
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
		Viewport.Clear(view.Model)
		view.ModelKey = ""
	end
	local flashTween = self._flashTween
	if flashTween then
		flashTween:Cancel()
		flashTween:Destroy()
		self._flashTween = nil
	end
	local humanoid = self._humanoid
	if humanoid then
		CameraShake.Clear(humanoid, self)
	end
	self._shakeLeft = 0
	table.clear(self._views)
	self._rail = nil
	self._common = nil
end

return ResultCards
