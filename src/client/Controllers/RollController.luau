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

type TroveInstance = typeof(Trove.new())
type Popup = {
	Gui: BillboardGui,
	Group: CanvasGroup,
	Scale: UIScale,
	Name: TextLabel,
	Chance: TextLabel,
	IsBusy: boolean,
	StartedAt: number,
	Tweens: { Tween },
}
type State = {
	Name: string,
	_trove: TroveInstance?,
}

local comboWindow = 0.6
local comboStep = 0.03
local comboMax = 0.3
local maxPopups = 8
local lowMaxPopups = 3
local smallPopupMaxRank = 2
local releaseDelay = 0.07
local fullPopupSize = Vector2.new(300, 90)
local smallPopupSize = Vector2.new(200, 44)

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
local popups: { Popup } = {}
local popupGuis: Folder? = nil
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

local function newLabel(parent: Instance, name: string, position: UDim2, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(22, 18, 38)
	stroke.Thickness = 2.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = label
	label.Parent = parent
	return label
end

local function createPopup(): Popup
	local gui = Instance.new("BillboardGui")
	gui.Name = "RollPopup"
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(fullPopupSize.X, fullPopupSize.Y)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.Enabled = false
	gui.ResetOnSpawn = false
	local group = Instance.new("CanvasGroup")
	group.Name = "Group"
	group.BackgroundTransparency = 1
	group.Size = UDim2.fromScale(1, 1)
	group.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Parent = group
	local nameLabel = newLabel(group, "KeyName", UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.6))
	local chanceLabel = newLabel(group, "Chance", UDim2.fromScale(0, 0.6), UDim2.fromScale(1, 0.4))
	gui.Parent = popupGuis
	return {
		Gui = gui,
		Group = group,
		Scale = scale,
		Name = nameLabel,
		Chance = chanceLabel,
		IsBusy = false,
		StartedAt = 0,
		Tweens = {},
	}
end

local function stopPopup(popup: Popup)
	for _, active in popup.Tweens do
		active:Cancel()
		active:Destroy()
	end
	table.clear(popup.Tweens)
	popup.Gui.Enabled = false
	popup.IsBusy = false
end

local function acquirePopup(): Popup?
	local oldest: Popup? = nil
	for _, popup in popups do
		if not popup.IsBusy then
			return popup
		end
		if not oldest or popup.StartedAt < oldest.StartedAt then
			oldest = popup
		end
	end
	if #popups < (if isLowGraphics then lowMaxPopups else maxPopups) then
		local popup = createPopup()
		table.insert(popups, popup)
		return popup
	end
	if oldest then
		stopPopup(oldest)
	end
	return oldest
end

local function showPopup(key: Keys.Key, rarity: Keys.Rarity, adornee: BasePart)
	local popup = acquirePopup()
	if not popup then
		return
	end
	popup.IsBusy = true
	popup.StartedAt = os.clock()
	local isSmall = (rarityRank[rarity.Name] or 1) <= smallPopupMaxRank
	local size = if isSmall then smallPopupSize else fullPopupSize
	local gui = popup.Gui
	gui.Size = UDim2.fromOffset(
		size.X * (if rarity.Announce then 1.4 else 1),
		size.Y * (if rarity.Announce then 1.4 else 1)
	)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.Adornee = adornee
	popup.Name.Text = key.Name
	popup.Name.TextColor3 = rarity.Color
	popup.Name.Size = if isSmall then UDim2.fromScale(1, 1) else UDim2.fromScale(1, 0.6)
	popup.Chance.Visible = not isSmall
	popup.Chance.Text = `1 in {NumberFormat.Commas(rarity.Chance)}`
	popup.Group.GroupTransparency = 0
	popup.Scale.Scale = 0.5
	gui.Enabled = true
	local lifetime = if isSmall then 0.6 else 1.3
	local fadeDelay = if isSmall then 0.3 else 0.8
	local rise = TweenService:Create(
		gui,
		TweenInfo.new(lifetime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffset = Vector3.new(0, if isSmall then 7 else 9, 0) }
	)
	local pop = TweenService:Create(
		popup.Scale,
		TweenInfo.new(0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }
	)
	local fade = TweenService:Create(
		popup.Group,
		TweenInfo.new(
			lifetime - fadeDelay,
			Enum.EasingStyle.Linear,
			Enum.EasingDirection.In,
			0,
			false,
			fadeDelay
		),
		{ GroupTransparency = 1 }
	)
	popup.Tweens = { rise, pop, fade }
	fade.Completed:Once(function(state: Enum.PlaybackState)
		if state ~= Enum.PlaybackState.Completed or popup.Tweens[3] ~= fade then
			return
		end
		stopPopup(popup)
	end)
	rise:Play()
	pop:Play()
	fade:Play()
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

local function popupAnchor(): BasePart?
	if rollKey and isInRange() then
		return rollKey
	end
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return root
	end
	return rollKey
end

local function reveal(index: number)
	local key = Keys.Catalog[index]
	if not key then
		return
	end
	local rarity = Keys.GetRarity(key)
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
	local anchor = popupAnchor()
	if anchor then
		showPopup(key, rarity, anchor)
	end
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
		local index = Packets.Roll:Fire()
		if type(index) == "number" and index > 0 and not destroyed then
			reveal(index)
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
	local guis = Instance.new("Folder")
	guis.Name = "RollPopups"
	guis.Parent = workspace
	popupGuis = guis
	trove:Add(guis)
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
	popupGuis = nil
	table.clear(popups)
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return RollController
