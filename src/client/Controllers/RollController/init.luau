--!strict

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local Packets = require(ReplicatedStorage.Packets)
local Stats = require(ReplicatedStorage.Rules.Stats)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local WaitFor = require(ReplicatedStorage.Packages.WaitFor)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Kit = require(script.Parent.UIController.Kit)
local ResultSlots = require(script.ResultSlots)

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	_trove: TroveInstance?,
}

local comboWindow = 0.6
local comboStep = 0.03
local comboMax = 0.3
local releaseDelay = 0.07
local cardHeight = 64
local rowY = 42
local starSize = 28
local starGap = 8
local slotMaxWidth = 440
local slotShare = 0.45
local slotGap = 36
local rowGap = 4
local subTextSize = 13
local commonNameSize = 22
local rareNameSize = 28
local topNameSize = 32
local pauseSeconds = 1
local slideSeconds = 0.3
local fadeSeconds = 0.25
local fastFadeSeconds = 0.15
local cardBottomOffset = 104
local goldColor = Color3.fromRGB(255, 210, 64)

local rarityRank: { [string]: number } = {}
for index, rarity in Keys.Rarities do
	rarityRank[rarity.Name] = index
end

local RollController = {
	Name = "RollController",
	AutoChanged = Signal.new() :: Signal.Signal<boolean>,
	_trove = nil :: TroveInstance?,
}
local controllers: { [string]: any } = {}
local plot: Model? = nil
local rollKey: BasePart? = nil
local keyConnections: { RBXScriptConnection } = {}
local originCFrame = CFrame.identity
local originSize = Vector3.one
local originColor = Color3.new(1, 1, 1)
local lastPress = 0
local lastComboPress = 0
local combo = 0
local buildingCount = 0
local punching = false
local holdPitch = 1
local isHolding = false
local destroyed = false
local isLowGraphics = false
local isAuto = false
local rollInterval = 1 / GameConfig.RollsPerSecond
local board: any = {}
local upgradeLevels: any = {}
local squashTweens: { Tween } = {}

local function escapeRichText(text: string): string
	local escaped = string.gsub(text, "&", "&amp;")
	escaped = string.gsub(escaped, "<", "&lt;")
	escaped = string.gsub(escaped, ">", "&gt;")
	return escaped
end

local epicRank = rarityRank.Epic or 4
local legendaryRank = rarityRank.Legendary or 5
local rareRank = rarityRank.Rare or 3
local legendaryRarity: Keys.Rarity? = nil
for _, rarity in Keys.Rarities do
	if rarity.Name == "Legendary" then
		legendaryRarity = rarity
	end
end

type Role = "Rail" | "Fading" | "Common"

type View = {
	Holder: Frame,
	Group: CanvasGroup,
	Scale: UIScale,
	Name: TextLabel,
	NameStroke: UIStroke,
	NameGradient: UIGradient,
	NamePadding: UIPadding,
	Star: GuiObject,
	Row: Frame,
	Sub: TextLabel,
	Info: TextLabel,
	Tweens: { Tween },
	Role: Role?,
	Token: number,
	Fit: number,
}

type Payload = {
	Key: Keys.Key,
	Rarity: Keys.Rarity,
	IsGolden: boolean,
}

local slotAnchor: { [ResultSlots.Slot]: number } = { Center = 0.5, Left = 1, Right = 0 }
local slotOffset: { [ResultSlots.Slot]: number } = { Center = 0, Left = -slotGap, Right = slotGap }
local slotAlign: { [ResultSlots.Slot]: Enum.TextXAlignment } = {
	Center = Enum.TextXAlignment.Center,
	Left = Enum.TextXAlignment.Right,
	Right = Enum.TextXAlignment.Left,
}

local views: { View } = {}
local railView: View? = nil
local commonView: View? = nil
local resultSlots: ResultSlots.ResultSlots? = nil
local cardGui: ScreenGui? = nil
local cardScale: UIScale? = nil
local flashFrame: Frame? = nil

local function buildView(parent: Instance, index: number): View
	local holder = Instance.new("Frame")
	holder.Name = `Holder{index}`
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(0.5, 0, 1, -cardBottomOffset)
	holder.Size = UDim2.fromOffset(slotMaxWidth, cardHeight)
	holder.Visible = false
	holder.Parent = parent
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	local group = Instance.new("CanvasGroup")
	group.Name = "Group"
	group.BackgroundTransparency = 1
	group.BorderSizePixel = 0
	group.Size = UDim2.fromScale(1, 1)
	group.Parent = holder
	local nameLabel = Kit.Label({
		Parent = group,
		Name = "KeyName",
		Size = UDim2.fromOffset(0, 36),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		TextSize = topNameSize,
		Align = Enum.TextXAlignment.Center,
		Outline = true,
	})
	local namePadding = Instance.new("UIPadding")
	namePadding.Parent = nameLabel
	local star = Kit.Glyph(nameLabel, "star", starSize, Color3.new(1, 1, 1))
	star.Name = "Star"
	star.AnchorPoint = Vector2.new(0, 0.5)
	star.Position = UDim2.new(0, -(starSize + starGap), 0.5, 0)
	star.Visible = false
	nameLabel.AutomaticSize = Enum.AutomaticSize.X
	nameLabel.TextTruncate = Enum.TextTruncate.None
	local nameStroke = nameLabel:FindFirstChild("TextStroke") :: UIStroke
	nameStroke.Thickness = 3
	local nameGradient = Instance.new("UIGradient")
	nameGradient.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 150, 20))
	nameGradient.Rotation = 90
	nameGradient.Enabled = false
	nameGradient.Parent = nameStroke
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.new(0.5, 0, 0, rowY)
	row.Size = UDim2.fromOffset(0, 18)
	row.AutomaticSize = Enum.AutomaticSize.X
	local rowList = Instance.new("UIListLayout")
	rowList.FillDirection = Enum.FillDirection.Horizontal
	rowList.HorizontalAlignment = Enum.HorizontalAlignment.Left
	rowList.VerticalAlignment = Enum.VerticalAlignment.Center
	rowList.SortOrder = Enum.SortOrder.LayoutOrder
	rowList.Padding = UDim.new(0, rowGap)
	rowList.Parent = row
	row.Parent = group
	local sub = Kit.Label({
		Parent = row,
		Name = "Sub",
		Size = UDim2.fromOffset(0, 18),
		TextSize = subTextSize,
		Align = Enum.TextXAlignment.Right,
		LayoutOrder = 1,
		Outline = true,
		Body = true,
	})
	sub.AutomaticSize = Enum.AutomaticSize.X
	sub.TextTruncate = Enum.TextTruncate.None
	local info = Kit.Label({
		Parent = row,
		Name = "Info",
		Size = UDim2.fromOffset(0, 18),
		TextSize = subTextSize,
		Align = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
		Outline = true,
		Body = true,
	})
	info.AutomaticSize = Enum.AutomaticSize.X
	info.TextTruncate = Enum.TextTruncate.None
	return {
		Holder = holder,
		Group = group,
		Scale = scale,
		Name = nameLabel,
		NameStroke = nameStroke,
		NameGradient = nameGradient,
		NamePadding = namePadding,
		Star = star,
		Row = row,
		Sub = sub,
		Info = info,
		Tweens = {},
		Role = nil,
		Token = 0,
		Fit = 1,
	}
end

local function buildCard(trove: TroveInstance, playerGui: PlayerGui)
	local gui, root = Kit.ScreenGui("RollCard", 3, playerGui, trove)
	cardGui = gui
	cardScale = root:FindFirstChild("ViewportScale") :: UIScale?
	table.clear(views)
	for index = 1, 2 do
		table.insert(views, buildView(root, index))
	end
	resultSlots = ResultSlots.new({
		PauseSeconds = pauseSeconds,
		SlideSeconds = slideSeconds,
		FadeSeconds = fadeSeconds,
	})
	local flashGui = Instance.new("ScreenGui")
	flashGui.Name = "RollFlash"
	flashGui.ResetOnSpawn = false
	flashGui.IgnoreGuiInset = true
	flashGui.DisplayOrder = 4
	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.BorderSizePixel = 0
	flash.BackgroundColor3 = goldColor
	flash.BackgroundTransparency = 1
	flash.Size = UDim2.fromScale(1, 1)
	flash.Active = false
	flash.Parent = flashGui
	flashGui.Parent = playerGui
	flashFrame = flash
	trove:Add(flashGui)
end

local function cancelViewTweens(view: View)
	view.Token += 1
	for _, active in view.Tweens do
		active:Cancel()
		active:Destroy()
	end
	table.clear(view.Tweens)
end

local function track(view: View, tween: Tween)
	table.insert(view.Tweens, tween)
	return tween
end

local function releaseView(view: View)
	cancelViewTweens(view)
	view.Holder.Visible = false
	view.Role = nil
	if view == railView then
		railView = nil
	end
	if view == commonView then
		commonView = nil
	end
end

local function acquireView(): View
	local order: { Role? } = { nil, "Common", "Fading", "Rail" }
	for index = 1, 4 do
		local wanted = order[index]
		for _, view in views do
			if view.Role == wanted then
				return view
			end
		end
	end
	return views[1]
end

local function applyLayout(view: View, slot: ResultSlots.Slot)
	local anchor = slotAnchor[slot]
	view.Holder.AnchorPoint = Vector2.new(anchor, 1)
	view.Holder.Position = UDim2.new(0.5, slotOffset[slot], 1, -cardBottomOffset)
	view.Name.AnchorPoint = Vector2.new(anchor, 0)
	view.Name.Position = UDim2.fromScale(anchor, 0)
	view.Row.AnchorPoint = Vector2.new(anchor, 0)
	view.Row.Position = UDim2.new(anchor, 0, 0, rowY)
	view.Name.TextXAlignment = slotAlign[slot]
	view.Sub.TextXAlignment = slotAlign[slot]
	view.Info.TextXAlignment = slotAlign[slot]
end

local function fitView(view: View)
	local gui = cardGui
	local scale = cardScale
	local virtualWidth = if gui and scale and scale.Scale > 0 then gui.AbsoluteSize.X / scale.Scale else 1280
	local maxWidth = math.min(slotMaxWidth, slotShare * virtualWidth)
	local huge = Vector2.new(100000, 100000)
	local nameWidth = TextService:GetTextSize(view.Name.Text, view.Name.TextSize, Kit.Font, huge).X
		+ view.NamePadding.PaddingLeft.Offset
	local rowWidth = TextService:GetTextSize(view.Sub.Text, subTextSize, Kit.BodyFont, huge).X
		+ rowGap
		+ TextService:GetTextSize(view.Info.Text, subTextSize, Kit.BodyFont, huge).X
	local content = math.max(nameWidth, rowWidth, 1)
	local fit = math.min(1, maxWidth / content)
	view.Fit = fit
	view.Holder.Size = UDim2.fromOffset(maxWidth / fit, cardHeight)
end

local function showView(view: View, slot: ResultSlots.Slot, payload: Payload, isRare: boolean)
	cancelViewTweens(view)
	view.Role = if isRare then "Rail" else "Common"
	if isRare then
		railView = view
		if commonView == view then
			commonView = nil
		end
	else
		commonView = view
		if railView == view then
			railView = nil
		end
	end
	local key, rarity, isGolden = payload.Key, payload.Rarity, payload.IsGolden
	local rank = rarityRank[rarity.Name] or 1
	local isTop = rank >= legendaryRank
	view.Name.Text = key.Name
	view.Name.TextSize = if isTop
		then topNameSize
		elseif rank >= rareRank then rareNameSize
		else commonNameSize
	view.Name.TextColor3 = rarity.Color
	local hasStar = isGolden or isTop
	view.Star.Visible = hasStar
	view.NamePadding.PaddingLeft = UDim.new(0, if hasStar then starSize + starGap else 0)
	if view.Star:IsA("ImageLabel") then
		view.Star.ImageColor3 = if isGolden then goldColor else rarity.Color
	elseif view.Star:IsA("TextLabel") then
		view.Star.TextColor3 = if isGolden then goldColor else rarity.Color
	end
	view.NameGradient.Enabled = isGolden
	view.NameStroke.Color = if isGolden then Color3.new(1, 1, 1) else Kit.Theme.TextInk
	view.Sub.Text = string.upper(`{rarity.Name} · 1 in {NumberFormat.Commas(rarity.Chance)}`)
	view.Info.Text = `· +{NumberFormat.Compact(Keys.GetIncome(key.Id))}/s`
	fitView(view)
	applyLayout(view, slot)
	view.Group.GroupTransparency = 0
	view.Holder.Visible = true
	if isLowGraphics then
		view.Scale.Scale = view.Fit
	else
		view.Scale.Scale = 0.7 * view.Fit
		local pop = track(
			view,
			TweenService:Create(
				view.Scale,
				TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
				{ Scale = view.Fit }
			)
		)
		pop:Play()
	end
end

local function slideView(view: View)
	local slot: ResultSlots.Slot = "Left"
	local anchor = slotAnchor[slot]
	view.Name.TextXAlignment = slotAlign[slot]
	view.Sub.TextXAlignment = slotAlign[slot]
	view.Info.TextXAlignment = slotAlign[slot]
	local info = TweenInfo.new(slideSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local tweens = {
		TweenService:Create(view.Holder, info, {
			AnchorPoint = Vector2.new(anchor, 1),
			Position = UDim2.new(0.5, slotOffset[slot], 1, -cardBottomOffset),
		}),
		TweenService:Create(
			view.Name,
			info,
			{ AnchorPoint = Vector2.new(anchor, 0), Position = UDim2.fromScale(anchor, 0) }
		),
		TweenService:Create(
			view.Row,
			info,
			{ AnchorPoint = Vector2.new(anchor, 0), Position = UDim2.new(anchor, 0, 0, rowY) }
		),
	}
	for _, tween in tweens do
		track(view, tween):Play()
	end
end

local function fadeView(view: View, isFast: boolean)
	cancelViewTweens(view)
	local token = view.Token
	local seconds = if isFast then fastFadeSeconds else fadeSeconds
	local info = TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	local fade = track(view, TweenService:Create(view.Group, info, { GroupTransparency = 1 }))
	if not isLowGraphics then
		local current = view.Holder.Position
		track(
			view,
			TweenService:Create(view.Holder, info, {
				Position = UDim2.new(
					current.X.Scale,
					current.X.Offset,
					current.Y.Scale,
					current.Y.Offset + 24
				),
			})
		):Play()
	end
	fade.Completed:Once(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed and view.Token == token then
			view.Holder.Visible = false
			view.Role = nil
		end
	end)
	fade:Play()
end

local function runActions(actions: { ResultSlots.Action })
	for _, action in actions do
		if action.Kind == "Show" then
			local view = if action.IsRare then acquireView() else commonView or acquireView()
			if view.Role == "Rail" and view == railView then
				railView = nil
			end
			showView(view, action.Slot, action.Payload :: Payload, action.IsRare)
		elseif action.Kind == "Slide" then
			if railView then
				slideView(railView)
			end
		elseif action.Kind == "Fade" then
			local view = if action.IsRare then railView else commonView
			if view then
				if action.IsRare then
					railView = nil
					view.Role = "Fading"
				end
				fadeView(view, action.Fast == true)
			end
		elseif action.Kind == "Hide" then
			local view = if action.IsRare then railView else commonView
			if view then
				releaseView(view)
			end
		end
	end
end

local function stopCard()
	for _, view in views do
		cancelViewTweens(view)
	end
	table.clear(views)
	railView = nil
	commonView = nil
end

local function showCard(key: Keys.Key, rarity: Keys.Rarity, isGolden: boolean)
	local slots = resultSlots
	if not slots then
		return
	end
	local rank = rarityRank[rarity.Name] or 1
	local isRare = rank >= legendaryRank
	local hold = if isRare then 5 elseif rank >= epicRank then 2 elseif rank >= rareRank then 1.2 else 0.7
	if isGolden then
		hold += 1
	end
	local payload: Payload = { Key = key, Rarity = rarity, IsGolden = isGolden }
	runActions(slots:Push(payload, isRare, hold, os.clock(), isLowGraphics))
end

local function goldenFeedback()
	local sounds = controllers.SoundController
	if legendaryRarity then
		sounds:PlayReveal(legendaryRarity, "Roll")
	end
	local flash = flashFrame
	if flash and not isLowGraphics then
		flash.BackgroundTransparency = 0.35
		local fadeOut = TweenService:Create(
			flash,
			TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ BackgroundTransparency = 1 }
		)
		fadeOut.Completed:Once(function()
			fadeOut:Destroy()
		end)
		fadeOut:Play()
	end
	local part = rollKey
	if part then
		part.Color = goldColor
		task.delay(0.5, function()
			if not destroyed and part.Parent and buildingCount == 0 then
				part.Color = originColor
			end
		end)
	end
end

local function punchCamera()
	local camera = workspace.CurrentCamera
	if not camera or punching or isLowGraphics then
		return
	end
	punching = true
	local baseFov = camera.FieldOfView
	local out = TweenService:Create(
		camera,
		TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ FieldOfView = baseFov + 8 }
	)
	local back = TweenService:Create(
		camera,
		TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
		{ FieldOfView = baseFov }
	)
	out.Completed:Once(function()
		back:Play()
	end)
	back.Completed:Once(function()
		punching = false
		out:Destroy()
		back:Destroy()
	end)
	out:Play()
end

local function squash()
	local part = rollKey
	if not part then
		return
	end
	for _, active in squashTweens do
		active:Cancel()
		active:Destroy()
	end
	table.clear(squashTweens)
	local down =
		TweenService:Create(part, TweenInfo.new(0.04, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(originSize.X * 1.08, originSize.Y * 0.6, originSize.Z * 1.08),
			CFrame = originCFrame * CFrame.new(0, -originSize.Y * 0.2, 0),
		})
	local up = TweenService:Create(
		part,
		TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = originSize, CFrame = originCFrame }
	)
	squashTweens = { down, up }
	down.Completed:Once(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed then
			up:Play()
		end
	end)
	down:Play()
end

local function buildUp(part: BasePart?, rarity: Keys.Rarity)
	local seconds = rarity.BuildUpSeconds
	controllers.SoundController:PlaySwell(rarity, seconds, "Roll")
	local startedAt = os.clock()
	local connection: RBXScriptConnection? = nil
	if part then
		connection = RunService.RenderStepped:Connect(function()
			local alpha = math.clamp((os.clock() - startedAt) / seconds, 0, 1)
			local amplitude = 0.05 + 0.25 * alpha
			if not isLowGraphics then
				part.CFrame = originCFrame
					* CFrame.new(
						(math.random() - 0.5) * amplitude * 2,
						0,
						(math.random() - 0.5) * amplitude * 2
					)
			end
			part.Color = originColor:Lerp(rarity.Color, alpha)
		end)
	end
	buildingCount += 1
	task.wait(seconds)
	if connection then
		connection:Disconnect()
	end
	buildingCount -= 1
	if part and buildingCount == 0 and not destroyed and part.Parent then
		part.CFrame = originCFrame
		part.Color = originColor
	end
end

local function isInRange(): boolean
	local part = rollKey
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not part or not root or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - part.Position).Magnitude <= GameConfig.RollRange
end

local function reveal(index: number, isGolden: boolean)
	local key = Keys.Catalog[index]
	if not key then
		return
	end
	local rarity = Keys.GetRarity(key)
	if isGolden then
		goldenFeedback()
	end
	if rarity.BuildUpSeconds > 0 then
		buildUp(rollKey, rarity)
	end
	if destroyed then
		return
	end
	local sounds = controllers.SoundController
	sounds:PlaySwitch(key.Switch, "Press", 1, 1, nil, "Roll")
	sounds:PlayFlair(key, nil, "Roll")
	sounds:PlayReveal(rarity, "Roll")
	showCard(key, rarity, isGolden)
	if rarity.Announce then
		punchCamera()
	end
end

local function press(autoRelease: boolean): boolean
	local now = os.clock()
	if destroyed or now - lastPress < rollInterval then
		return false
	end
	lastPress = now
	if now - lastComboPress <= comboWindow then
		combo += 1
	else
		combo = 0
	end
	lastComboPress = now
	squash()
	holdPitch = 1 + math.min(combo * comboStep, comboMax)
	local sounds = controllers.SoundController
	sounds:PlaySwitch(Keys.RollKeySwitch, "Press", holdPitch, 1, nil, "Roll")
	if autoRelease then
		local pitch = holdPitch
		task.delay(releaseDelay, function()
			if not destroyed then
				sounds:PlaySwitch(Keys.RollKeySwitch, "Release", pitch, 1, nil, "Roll")
			end
		end)
	end
	task.spawn(function()
		local index: any, isGolden: any = Packets.Roll:Fire()
		if type(index) == "number" and index > 0 and not destroyed then
			reveal(index, isGolden == true)
		end
	end)
	return true
end

local function isAimedAtKey(input: InputObject): boolean
	local part = rollKey
	local camera = workspace.CurrentCamera
	if not part or not camera then
		return false
	end
	local inset = GuiService:GetGuiInset()
	local ray = camera:ViewportPointToRay(input.Position.X + inset.X, input.Position.Y + inset.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { part }
	return workspace:Raycast(ray.Origin, ray.Direction * 500, params) ~= nil
end

local function onInput(input: InputObject, gameProcessed: boolean)
	if gameProcessed then
		return
	end
	local inputType = input.UserInputType
	if inputType == Enum.UserInputType.MouseButton1 or inputType == Enum.UserInputType.Touch then
		if isAimedAtKey(input) and press(false) then
			isHolding = true
		end
	elseif input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonR2 then
		if isInRange() and press(false) then
			isHolding = true
		end
	end
end

local function onInputEnded(input: InputObject, _gameProcessed: boolean)
	if not isHolding or destroyed then
		return
	end
	local inputType = input.UserInputType
	if
		inputType == Enum.UserInputType.MouseButton1
		or inputType == Enum.UserInputType.Touch
		or input.KeyCode == Enum.KeyCode.E
		or input.KeyCode == Enum.KeyCode.ButtonR2
	then
		isHolding = false
		controllers.SoundController:PlaySwitch(Keys.RollKeySwitch, "Release", holdPitch, 1, nil, "Roll")
	end
end

local function disconnectKeyWatch()
	for _, connection in keyConnections do
		connection:Disconnect()
	end
	table.clear(keyConnections)
end

local function pickKey(model: Model?)
	disconnectKeyWatch()
	local key = if model then model:FindFirstChild("RollKey") else nil
	if model and key and key:IsA("BasePart") then
		rollKey = key
		originCFrame = key.CFrame
		originSize = key.Size
		originColor = key.Color
		table.insert(
			keyConnections,
			key.AncestryChanged:Connect(function()
				if key.Parent ~= model then
					pickKey(model)
				end
			end)
		)
	else
		rollKey = nil
	end
	if model then
		table.insert(
			keyConnections,
			model.ChildAdded:Connect(function(child: Instance)
				if child.Name == "RollKey" and child ~= rollKey then
					pickKey(model)
				end
			end)
		)
	end
end

local function setPlot(model: Model?)
	if model == plot then
		return
	end
	plot = model
	pickKey(model)
end

local function refreshPlot(folder: Instance)
	for _, child in folder:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("Owner") == Players.LocalPlayer.UserId then
			setPlot(child)
			return
		end
	end
	setPlot(nil)
end

local function watchPlots(folder: Instance, trove: TroveInstance)
	local function watch(child: Instance)
		if child:IsA("Model") then
			trove:Connect(child:GetAttributeChangedSignal("Owner"), function()
				refreshPlot(folder)
			end)
		end
	end
	for _, child in folder:GetChildren() do
		watch(child)
	end
	trove:Connect(folder.ChildAdded, function(child: Instance)
		watch(child)
		refreshPlot(folder)
	end)
	trove:Connect(folder.ChildRemoved, function()
		refreshPlot(folder)
	end)
	refreshPlot(folder)
end

local function updateRollInterval()
	local stats = Stats.Compute(board, upgradeLevels)
	rollInterval = 1 / math.max(stats.RollsPerSecond, 0.1)
end

local function onRareRoll(playerName: string, index: number)
	if playerName == Players.LocalPlayer.DisplayName then
		return
	end
	local key = Keys.Catalog[index]
	if not key then
		return
	end
	local rarity = Keys.GetRarity(key)
	local channels = TextChatService:FindFirstChild("TextChannels")
	local general = if channels then channels:FindFirstChild("RBXGeneral") else nil
	if general and general:IsA("TextChannel") then
		general:DisplaySystemMessage(
			`[{GameConfig.Name}] {escapeRichText(playerName)} rolled {key.Name} ({rarity.Name}, 1 in {NumberFormat.Commas(
				rarity.Chance
			)})!`
		)
	end
	controllers.SoundController:PlayReveal(rarity, "Other")
end

function RollController.RequestRoll(_self: State): boolean
	return press(true)
end

function RollController.SetAuto(_self: State, isOn: boolean)
	if isOn == isAuto then
		return
	end
	isAuto = isOn
	RollController.AutoChanged:Fire(isOn)
end

function RollController.IsAuto(_self: State): boolean
	return isAuto
end

function RollController.TeleportToBase(_self: State): boolean
	local base = if plot then plot:FindFirstChild("Base") else nil
	local character = Players.LocalPlayer.Character
	if not base or not base:IsA("BasePart") or not character then
		return false
	end
	character:PivotTo(base.CFrame * CFrame.new(0, base.Size.Y / 2 + 3, 0))
	return true
end

function RollController.Init(self: State, registry: { [string]: any })
	controllers = registry
	self._trove = Trove.new()
end

function RollController.Start(self: State)
	local trove = self._trove :: TroveInstance
	trove:Add(controllers.DataController:Observe({ "Board" }, function(value: any)
		board = if type(value) == "table" then value else {}
		updateRollInterval()
	end))
	trove:Add(controllers.DataController:Observe({ "Upgrades" }, function(value: any)
		upgradeLevels = if type(value) == "table" then value else {}
		updateRollInterval()
	end))
	trove:Add(controllers.DataController:Observe({ "Settings", "LowGraphics" }, function(value: any)
		isLowGraphics = value == true
	end))
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		buildCard(trove, playerGui)
	end
	trove:Connect(UserInputService.InputBegan, onInput)
	trove:Connect(UserInputService.InputEnded, onInputEnded)
	trove:Connect(RunService.Heartbeat, function()
		if isAuto then
			press(true)
		end
		local slots = resultSlots
		if slots then
			runActions(slots:Tick(os.clock()))
		end
	end)
	trove:Add(Packets.RareRoll.OnClientEvent:Connect(onRareRoll))
	local promise = WaitFor.Child(workspace, "Plots", 30)
		:andThen(function(folder: Instance)
			if destroyed then
				return
			end
			local newTrove = Trove.new()
			trove:Add(newTrove)
			watchPlots(folder, newTrove)
		end)
		:catch(function(problem: any)
			warn(`[RollController] workspace.Plots not found: {tostring(problem)}`)
		end)
	trove:Add(function()
		promise:cancel()
	end)
end

function RollController.Destroy(self: State)
	destroyed = true
	isLowGraphics = false
	isAuto = false
	isHolding = false
	table.clear(squashTweens)
	plot = nil
	rollKey = nil
	disconnectKeyWatch()
	stopCard()
	resultSlots = nil
	cardGui = nil
	cardScale = nil
	flashFrame = nil
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return RollController
