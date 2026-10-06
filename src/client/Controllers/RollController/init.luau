--!strict

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local Packets = require(ReplicatedStorage.Packets)
local Charms = require(ReplicatedStorage.Rules.Charms)
local Stats = require(ReplicatedStorage.Rules.Stats)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local AdminRewards = require(script.AdminRewards)
local BaseZone = require(script.BaseZone)
local Travel = require(script.Travel)
local ResultSlots = require(script.ResultSlots)
local ResultCards = require(script.ResultCards)
local Cinematic = require(script.Cinematic)
local KeyVisual = require(script.KeyVisual)
local Tiers = require(script.Tiers)
local ChatNotice = require(script.Parent.Parent.Util.ChatNotice)

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	_trove: TroveInstance?,
}

local comboWindow = 0.6
local comboStep = 0.03
local comboMax = 0.3
local releaseDelay = 0.07
local goldColor = Color3.fromRGB(255, 210, 64)
local rewardStaggerSeconds = 1.6

local rarityRank: { [string]: number } = {}
for index, rarity in Keys.Rarities do
	rarityRank[rarity.Name] = index
end

local RollController = {
	Name = "RollController",
	AutoChanged = Signal.new() :: Signal.Signal<boolean>,
	InBaseChanged = Signal.new() :: Signal.Signal<boolean>,
	_trove = nil :: TroveInstance?,
}
local controllers: { [string]: any } = {}
local plot: Model? = nil
local lastPress = 0
local lastComboPress = 0
local combo = 0
local holdPitch = 1
local isHolding = false
local destroyed = false
local isLowGraphics = false
local effectsMinRank = 5
local cinematic: Cinematic.Cinematic? = nil
local isAuto = false
local isInBase = false
local rollInterval = 1 / GameConfig.RollsPerSecond
local board: any = {}
local upgradeLevels: any = {}
local charmSpeed = 1
local visual = KeyVisual.new(function()
	return isLowGraphics
end, function()
	return destroyed
end)

local epicRank = rarityRank.Epic or 4
local legendaryRank = rarityRank.Legendary or 5
local rareRank = rarityRank.Rare or 3
local legendaryRarity: Keys.Rarity? = nil
for _, rarity in Keys.Rarities do
	if rarity.Name == "Legendary" then
		legendaryRarity = rarity
	end
end

local resultSlots: ResultSlots.ResultSlots? = nil
local cards: ResultCards.ResultCards? = nil

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
	local shown = cards
	if not shown then
		return
	end
	local payload: ResultCards.Payload = { Key = key, Rarity = rarity, IsGolden = isGolden }
	shown:Run(slots:Push(payload, hold, os.clock()))
end

local function goldenFeedback()
	local sounds = controllers.SoundController
	if legendaryRarity then
		sounds:PlayReveal(legendaryRarity, "Roll")
	end
	local shown = cards
	if shown then
		shown:Flash(goldColor, 0.35, 0.4)
	end
	KeyVisual.Tint(visual, goldColor)
end

local function isInRange(): boolean
	local part = visual.Key
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
	local shownCinematic = cinematic
	if
		shownCinematic
		and Tiers.ShouldPlay(Tiers.RankOf(rarity), effectsMinRank)
		and shownCinematic:CanAccept()
	then
		local sounds = controllers.SoundController
		sounds:PlaySwitch(key.Switch, "Press", 1, 1, nil, "Roll")
		sounds:PlayFlair(key, nil, "Roll")
		shownCinematic:Play({ Key = key, Rarity = rarity, IsGolden = isGolden }, function()
			if not destroyed then
				showCard(key, rarity, isGolden)
			end
		end)
		return
	end
	if rarity.BuildUpSeconds > 0 then
		controllers.SoundController:PlaySwell(rarity, rarity.BuildUpSeconds, "Roll")
		KeyVisual.BuildUp(visual, rarity)
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
		KeyVisual.PunchCamera(visual)
	end
end

local function press(autoRelease: boolean): boolean
	local now = os.clock()
	if destroyed or not isInBase or now - lastPress < rollInterval then
		return false
	end
	lastPress = now
	if now - lastComboPress <= comboWindow then
		combo += 1
	else
		combo = 0
	end
	lastComboPress = now
	KeyVisual.Squash(visual)
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
	local part = visual.Key
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
	KeyVisual.Bind(visual, model)
end

local function updateRollInterval()
	local stats = Stats.Compute(board, upgradeLevels, { Speed = charmSpeed })
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
	ChatNotice.Post(
		`{ChatNotice.Escape(playerName)} rolled {key.Name} ({rarity.Name}, 1 in {NumberFormat.Commas(
			rarity.Chance
		)})!`
	)
	controllers.SoundController:PlayReveal(rarity, "Other")
end

local rewardHandlers: AdminRewards.Handlers = {
	Key = function(keyId: string, order: number)
		local key = Keys.Resolve(keyId)
		if not key then
			return
		end
		task.delay((order - 1) * rewardStaggerSeconds, function()
			if not destroyed then
				reveal(key.Index, false)
			end
		end)
	end,
	Toast = function(text: string, kind: string)
		local ui = controllers.UIController
		if ui then
			ui:Toast(text, kind)
		end
	end,
	Pop = function()
		local sounds = controllers.SoundController
		if sounds then
			sounds:PlayUi("Confirm")
		end
	end,
}

local function onAdminReward(kind: string, id: string, count: number)
	AdminRewards.Dispatch(rewardHandlers, kind, id, count)
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

function RollController.IsInBase(_self: State): boolean
	return isInBase
end

local function refreshInBase()
	local value = BaseZone.IsInside(plot, Players.LocalPlayer.Character)
	if value ~= isInBase then
		isInBase = value
		RollController.InBaseChanged:Fire(value)
	end
end

function RollController.IsAuto(_self: State): boolean
	return isAuto
end

function RollController.TeleportToBase(_self: State): (boolean, string?)
	return Travel.ToBase(Players.LocalPlayer.Character, plot)
end

function RollController.TeleportToMarket(_self: State): (boolean, string?)
	return Travel.ToMarket(Players.LocalPlayer.Character, workspace)
end

function RollController.Init(self: State, registry: { [string]: any })
	controllers = registry
	destroyed = false
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
	trove:Add(controllers.DataController:Observe({ "EquippedCharms" }, function(value: any)
		charmSpeed = Charms.Effects(value).Speed
		updateRollInterval()
	end))
	trove:Add(controllers.DataController:Observe({ "Settings", "LowGraphics" }, function(value: any)
		isLowGraphics = value == true
	end))
	trove:Add(controllers.DataController:Observe({ "Settings", "EffectsMinRarity" }, function(value: any)
		effectsMinRank = Tiers.Clamp(value)
	end))
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		cinematic = Cinematic.new(playerGui, trove, function()
			return isLowGraphics
		end, function()
			return controllers
		end)
		cards = ResultCards.new(playerGui, trove, function()
			return isLowGraphics
		end)
		resultSlots = ResultSlots.new()
	end
	trove:Connect(UserInputService.InputBegan, onInput)
	trove:Connect(UserInputService.InputEnded, onInputEnded)
	trove:Connect(RunService.Heartbeat, function(dt: number)
		refreshInBase()
		if isAuto then
			press(true)
		end
		local slots = resultSlots
		local shown = cards
		if slots and shown then
			shown:Run(slots:Tick(os.clock()))
			shown:Step(dt)
		end
		local playing = cinematic
		if playing then
			playing:Step(dt)
		end
	end)
	trove:Add(Packets.RareRoll.OnClientEvent:Connect(onRareRoll))
	trove:Add(Packets.AdminReward.OnClientEvent:Connect(onAdminReward))
	trove:Add(controllers.PlotController:Observe(setPlot))
end

function RollController.Destroy(self: State)
	destroyed = true
	isLowGraphics = false
	isAuto = false
	isInBase = false
	isHolding = false
	plot = nil
	KeyVisual.Clear(visual)
	cards = nil
	cinematic = nil
	effectsMinRank = 5
	resultSlots = nil
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return RollController
