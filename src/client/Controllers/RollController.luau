--!strict

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
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

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	_trove: TroveInstance?,
}

local comboWindow = 0.6
local comboStep = 0.03
local comboMax = 0.3
local releaseDelay = 0.07
local cardSize = Vector2.new(440, 82)
local cardWidthScale = 0.48
local slotOffset = 0.26
local slideDelay = 0.35
local slideTime = 0.25
local slotX: { [string]: number } = { Center = 0.5, Left = 0.5 - slotOffset, Right = 0.5 + slotOffset }
local cardBottomOffset = 124
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
local rareRank = rarityRank.Rare or 3
local legendaryRank = rarityRank.Legendary or 5
local legendaryRarity: Keys.Rarity? = nil
for _, rarity in Keys.Rarities do
	if rarity.Name == "Legendary" then
		legendaryRarity = rarity
	end
end

type Card = {
	Holder: Frame,
	Group: CanvasGroup,
	Scale: UIScale,
	Name: TextLabel,
	NameStroke: UIStroke,
	NameGradient: UIGradient,
	Sub: TextLabel,
	Info: TextLabel,
	Tweens: { Tween },
	Thread: thread?,
	IsActive: boolean,
	Slot: string,
}

type Pending = {
	Key: Keys.Key,
	Rarity: Keys.Rarity,
	IsGolden: boolean,
}

local cards: { Card } = {}
local pinnedCard: Card? = nil
local isPinnedSettled = false
local pendingCommon: Pending? = nil
local flashFrame: Frame? = nil

local function buildCard(root: Frame, index: number): Card
	local holder = Instance.new("Frame")
	holder.Name = `Holder{index}`
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 1)
	holder.Position = UDim2.new(slotX.Center, 0, 1, -cardBottomOffset)
	holder.Size = UDim2.new(cardWidthScale, 0, 0, cardSize.Y)
	holder.Visible = false
	holder.Parent = root
	local constraint = Instance.new("UISizeConstraint")
	constraint.MaxSize = Vector2.new(cardSize.X, cardSize.Y)
	constraint.Parent = holder
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
		Size = UDim2.new(1, 0, 0, 50),
		TextSize = 46,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local nameStroke = nameLabel:FindFirstChild("TextStroke") :: UIStroke
	nameStroke.Thickness = 3.5
	local nameGradient = Instance.new("UIGradient")
	nameGradient.Color = ColorSequence.new(Color3.fromRGB(255, 240, 150), Color3.fromRGB(255, 150, 20))
	nameGradient.Rotation = 90
	nameGradient.Enabled = false
	nameGradient.Parent = nameStroke
	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundTransparency = 1
	row.BorderSizePixel = 0
	row.Position = UDim2.fromOffset(0, 52)
	row.Size = UDim2.new(1, 0, 0, 26)
	local rowList = Instance.new("UIListLayout")
	rowList.FillDirection = Enum.FillDirection.Horizontal
	rowList.HorizontalAlignment = Enum.HorizontalAlignment.Center
	rowList.VerticalAlignment = Enum.VerticalAlignment.Center
	rowList.SortOrder = Enum.SortOrder.LayoutOrder
	rowList.Padding = UDim.new(0, 16)
	rowList.Parent = row
	row.Parent = group
	local sub = Kit.Label({
		Parent = row,
		Name = "Sub",
		Size = UDim2.fromOffset(0, 26),
		TextSize = 24,
		Align = Enum.TextXAlignment.Right,
		LayoutOrder = 1,
	})
	sub.AutomaticSize = Enum.AutomaticSize.X
	sub.TextTruncate = Enum.TextTruncate.None
	local info = Kit.Label({
		Parent = row,
		Name = "Info",
		Size = UDim2.fromOffset(0, 26),
		TextSize = 24,
		Color = Kit.Theme.Good,
		Align = Enum.TextXAlignment.Left,
		LayoutOrder = 2,
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
		Sub = sub,
		Info = info,
		Tweens = {},
		Thread = nil,
		IsActive = false,
		Slot = "Center",
	}
end

local function buildCards(trove: TroveInstance, playerGui: PlayerGui)
	local _gui, root = Kit.ScreenGui("RollCard", 3, playerGui, trove)
	table.clear(cards)
	for index = 1, 2 do
		table.insert(cards, buildCard(root, index))
	end
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

local function stopCard(view: Card)
	for _, active in view.Tweens do
		active:Cancel()
		active:Destroy()
	end
	table.clear(view.Tweens)
	if view.Thread then
		task.cancel(view.Thread)
		view.Thread = nil
	end
end

local function stopAllCards()
	for _, view in cards do
		stopCard(view)
	end
	pinnedCard = nil
	isPinnedSettled = false
	pendingCommon = nil
end

local function placeCard(view: Card, slot: string)
	view.Slot = slot
	view.Holder.Position = UDim2.new(slotX[slot], 0, 1, -cardBottomOffset)
end

local function fadeCard(view: Card, seconds: number, hasDrift: boolean)
	stopCard(view)
	if view == pinnedCard then
		pinnedCard = nil
		isPinnedSettled = false
		pendingCommon = nil
	end
	if not view.IsActive then
		return
	end
	local fade = TweenService:Create(
		view.Group,
		TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ GroupTransparency = 1 }
	)
	table.insert(view.Tweens, fade)
	if hasDrift and not isLowGraphics then
		local drift = TweenService:Create(
			view.Holder,
			TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.new(slotX[view.Slot], 0, 1, -cardBottomOffset + 24) }
		)
		table.insert(view.Tweens, drift)
		drift:Play()
	end
	fade.Completed:Once(function(state: Enum.PlaybackState)
		if state == Enum.PlaybackState.Completed then
			view.Holder.Visible = false
			view.IsActive = false
		end
	end)
	fade:Play()
end

local function pickCard(excluded: Card?, slot: string): Card?
	local fallback: Card? = nil
	for _, view in cards do
		if view ~= excluded then
			if view.IsActive and view.Slot == slot then
				return view
			end
			if fallback == nil or not view.IsActive then
				fallback = view
			end
		end
	end
	return fallback
end

local function presentCard(view: Card, slot: string, key: Keys.Key, rarity: Keys.Rarity, isGolden: boolean)
	stopCard(view)
	placeCard(view, slot)
	view.Name.Text = if isGolden then `⭐ {key.Name}` else key.Name
	view.Name.TextColor3 = rarity.Color
	view.NameGradient.Enabled = isGolden
	view.NameStroke.Color = if isGolden then Color3.new(1, 1, 1) else Kit.Theme.TextInk
	view.Sub.Text = `{rarity.Name} · 1 in {NumberFormat.Commas(rarity.Chance)}`
	view.Sub.TextColor3 = rarity.Color
	view.Info.Text = `+{NumberFormat.Compact(Keys.GetIncome(key.Id))}/s`
	view.Group.GroupTransparency = 0
	view.Holder.Visible = true
	view.IsActive = true
	if isLowGraphics then
		view.Scale.Scale = 1
	else
		view.Scale.Scale = 0.7
		local pop = TweenService:Create(
			view.Scale,
			TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }
		)
		table.insert(view.Tweens, pop)
		pop:Play()
	end
end

local function showCommon(key: Keys.Key, rarity: Keys.Rarity, isGolden: boolean)
	local slot = if pinnedCard then "Right" else "Center"
	if pinnedCard and not isPinnedSettled then
		pendingCommon = { Key = key, Rarity = rarity, IsGolden = isGolden }
		return
	end
	local view = pickCard(pinnedCard, slot)
	if not view then
		return
	end
	if not pinnedCard then
		for _, other in cards do
			if other ~= view and other.IsActive then
				fadeCard(other, 0.15, false)
			end
		end
	end
	presentCard(view, slot, key, rarity, isGolden)
	view.Thread = task.delay(0.7, function()
		view.Thread = nil
		if destroyed then
			return
		end
		fadeCard(view, 0.25, true)
	end)
end

local function showRare(key: Keys.Key, rarity: Keys.Rarity, rank: number, isGolden: boolean)
	local old = pinnedCard
	if old then
		fadeCard(old, 0.15, false)
	end
	pendingCommon = nil
	isPinnedSettled = false
	local view = pickCard(old, "Center")
	if not view then
		return
	end
	for _, other in cards do
		if other ~= view and other ~= old and other.IsActive then
			fadeCard(other, 0.15, false)
		end
	end
	presentCard(view, "Center", key, rarity, isGolden)
	pinnedCard = view
	local hold = if rank >= legendaryRank then 5 elseif rank >= epicRank then 4 else 3
	if isGolden then
		hold += 1
	end
	view.Thread = task.spawn(function()
		if isLowGraphics then
			placeCard(view, "Left")
		else
			task.wait(slideDelay)
			placeCard(view, "Center")
			local slide = TweenService:Create(
				view.Holder,
				TweenInfo.new(slideTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
				{ Position = UDim2.new(slotX.Left, 0, 1, -cardBottomOffset) }
			)
			table.insert(view.Tweens, slide)
			slide:Play()
			view.Slot = "Left"
			task.wait(slideTime)
		end
		if destroyed or pinnedCard ~= view then
			return
		end
		isPinnedSettled = true
		local pending = pendingCommon
		pendingCommon = nil
		if pending then
			showCommon(pending.Key, pending.Rarity, pending.IsGolden)
		end
		task.wait(hold)
		view.Thread = nil
		if destroyed then
			return
		end
		fadeCard(view, 0.25, false)
	end)
end

local function showCard(key: Keys.Key, rarity: Keys.Rarity, isGolden: boolean)
	if #cards == 0 then
		return
	end
	local rank = rarityRank[rarity.Name] or 1
	if rank >= rareRank or isGolden then
		showRare(key, rarity, rank, isGolden)
	else
		showCommon(key, rarity, isGolden)
	end
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

local function setPlot(model: Model?)
	if model == plot then
		return
	end
	plot = model
	local key = if model then model:FindFirstChild("RollKey") else nil
	if key and key:IsA("BasePart") then
		rollKey = key
		originCFrame = key.CFrame
		originSize = key.Size
		originColor = key.Color
	else
		rollKey = nil
	end
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
		buildCards(trove, playerGui)
	end
	trove:Connect(UserInputService.InputBegan, onInput)
	trove:Connect(UserInputService.InputEnded, onInputEnded)
	trove:Connect(RunService.Heartbeat, function()
		if isAuto then
			press(true)
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
	stopAllCards()
	table.clear(cards)
	flashFrame = nil
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return RollController
