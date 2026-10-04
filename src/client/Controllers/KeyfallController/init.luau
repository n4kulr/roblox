--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Kit = require(script.Parent.UIController.Kit)
local Beacon = require(script.Beacon)
local CarryBeam = require(script.CarryBeam)
local Pill = require(script.Pill)

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	_trove: TroveInstance?,
}

local config = GameConfig.Keyfall
local eventAnnounce = 1
local eventGrabbed = 2
local eventClaimed = 3
local eventDelivered = 4
local eventVanished = 5
local knockButtonOffset = -198
local beaconRefreshSeconds = 0.25

local KeyfallController = {
	Name = "KeyfallController",
	_trove = nil :: TroveInstance?,
}
local controllers: { [string]: any } = {}
local setPillCount: ((count: number) -> ())? = nil
local knockButton: Kit.Button? = nil
local isKnockVisible = false
local isKnocking = false
local isLowGraphics = false
local beacon: Part? = nil
local goldenCap: BasePart? = nil
local beamTrove: TroveInstance? = nil
local lastCount = 0
local sinceBeaconRefresh = 0

local function toast(text: string, kind: string)
	local ui = controllers.UIController
	if ui then
		ui:Toast(text, kind)
	end
end

local function onEvent(kind: number, text: string, keyIndex: number)
	if kind == eventAnnounce then
		toast("A GOLDEN SPACEBAR fell in the arena! GO GO GO!", "Gold")
		local sounds = controllers.SoundController
		local mythic = Keys.RarityByName.Mythic
		if sounds and mythic then
			sounds:PlayReveal(mythic, "Other")
		end
	elseif kind == eventGrabbed then
		toast(`{text} grabbed the Golden Spacebar!`, "Gold")
	elseif kind == eventClaimed then
		toast(`{text} claimed the Golden Spacebar!`, "Gold")
	elseif kind == eventVanished then
		toast("The Golden Spacebar vanished...", "Info")
	elseif kind == eventDelivered then
		toast(`Delivered {keyIndex} {if keyIndex == 1 then "key" else "keys"}!`, "Good")
	end
end

local function findGoldenCap(): BasePart?
	local folder = workspace:FindFirstChild("KeyfallCaps")
	if not folder then
		return nil
	end
	for _, child in folder:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("KeyId") == config.GoldenSpacebarKeyId then
			return child
		end
	end
	return nil
end

local function removeBeacon()
	local current = beacon
	beacon = nil
	goldenCap = nil
	if current then
		current:Destroy()
	end
end

local function refreshBeacon()
	local cap = if isLowGraphics then nil else findGoldenCap()
	if not cap then
		removeBeacon()
		return
	end
	goldenCap = cap
	if not beacon then
		beacon = Beacon.Create()
	end
end

local function placeBeacon()
	local part = beacon
	local cap = goldenCap
	if part and cap and cap.Parent then
		Beacon.Place(part, cap.Position)
	end
end

local function findOwnBase(): BasePart?
	local folder = workspace:FindFirstChild("Plots")
	if not folder then
		return nil
	end
	for _, model in folder:GetChildren() do
		if model:GetAttribute("Owner") == Players.LocalPlayer.UserId then
			local base = model:FindFirstChild("Base")
			return if base and base:IsA("BasePart") then base else nil
		end
	end
	return nil
end

local function stopBeam()
	local current = beamTrove
	beamTrove = nil
	if current then
		current:Destroy()
	end
end

local function onCountChanged(character: Model)
	local rawCount = character:GetAttribute("KeyfallCount")
	local count = if type(rawCount) == "number" then rawCount else 0
	local show = setPillCount
	if show then
		show(count)
	end
	if count > lastCount then
		local sounds = controllers.SoundController
		if sounds then
			sounds:PlaySwitch(Keys.RollKeySwitch, "Press", 1, 0.8, nil, "Other")
		end
	end
	lastCount = count
	if count > 0 and not beamTrove then
		local root = character:FindFirstChild("HumanoidRootPart")
		local base = findOwnBase()
		if root and root:IsA("BasePart") and base then
			beamTrove = CarryBeam.Start(root, base)
		end
	elseif count == 0 then
		stopBeam()
	end
end

local function watchCharacter(character: Model, trove: TroveInstance)
	trove:Connect(character:GetAttributeChangedSignal("KeyfallCount"), function()
		onCountChanged(character)
	end)
	onCountChanged(character)
end

local function findKnockTarget(): Player?
	local localPlayer = Players.LocalPlayer
	local own = localPlayer.Character
	local ownRoot = if own then own:FindFirstChild("HumanoidRootPart") else nil
	if not ownRoot or not ownRoot:IsA("BasePart") then
		return nil
	end
	local best: Player? = nil
	local bestDistance = config.KnockRange
	for _, player in Players:GetPlayers() do
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local carried = if character then character:GetAttribute("KeyfallCount") else nil
		if
			player ~= localPlayer
			and root
			and root:IsA("BasePart")
			and type(carried) == "number"
			and carried > 0
		then
			local distance = (root.Position - ownRoot.Position).Magnitude
			if distance <= bestDistance then
				best = player
				bestDistance = distance
			end
		end
	end
	return best
end

local function setKnockVisible(isVisible: boolean)
	local button = knockButton
	if not button or isKnockVisible == isVisible then
		return
	end
	isKnockVisible = isVisible
	button.Instance.Visible = isVisible
	button.SetGlow(isVisible)
end

local function requestKnock()
	if isKnocking then
		return
	end
	local target = findKnockTarget()
	if not target then
		return
	end
	isKnocking = true
	task.spawn(function()
		local success = Packets.Knock:Fire(target.UserId)
		task.wait(config.KnockCooldown)
		isKnocking = false
		if success == true then
			toast("Knocked it loose!", "Good")
		end
	end)
end

local function onHeartbeat(dt: number)
	setKnockVisible(findKnockTarget() ~= nil)
	sinceBeaconRefresh += dt
	if sinceBeaconRefresh >= beaconRefreshSeconds then
		sinceBeaconRefresh = 0
		refreshBeacon()
	end
	placeBeacon()
end

local function buildInterface(trove: TroveInstance, playerGui: Instance)
	local _gui, root = Kit.ScreenGui("ThockKeyfall", 15, playerGui, trove)
	setPillCount = Pill.Build(trove, root)
	local button = Kit.Button(trove, {
		Parent = root,
		Name = "KnockCarrier",
		Text = "KNOCK!",
		Glyph = "Speed",
		Size = UDim2.fromOffset(250, 64),
		Position = UDim2.new(0.5, 0, 1, knockButtonOffset),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = Kit.Theme.Orange,
		TextSize = 30,
		Immediate = true,
		Callback = requestKnock,
		Sound = Kit.UiSound(controllers),
	})
	button.Instance.Visible = false
	knockButton = button
end

function KeyfallController.Init(self: State, registry: { [string]: any })
	controllers = registry
	self._trove = Trove.new()
end

function KeyfallController.Start(self: State)
	local trove = self._trove :: TroveInstance
	if not GameConfig.Keyfall.Enabled then
		return
	end
	local localPlayer = Players.LocalPlayer
	trove:Add(Packets.KeyfallEvent.OnClientEvent:Connect(onEvent))
	trove:Add(controllers.DataController:Observe({ "Settings", "LowGraphics" }, function(value: any)
		isLowGraphics = value == true
		refreshBeacon()
	end))
	local playerGui = localPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		buildInterface(trove, playerGui)
	end
	trove:Connect(RunService.Heartbeat, onHeartbeat)
	local characterTrove = Trove.new()
	trove:Add(characterTrove)
	trove:Connect(localPlayer.CharacterAdded, function(character: Model)
		characterTrove:Clean()
		stopBeam()
		lastCount = 0
		watchCharacter(character, characterTrove)
	end)
	if localPlayer.Character then
		watchCharacter(localPlayer.Character, characterTrove)
	end
end

function KeyfallController.Destroy(self: State)
	stopBeam()
	removeBeacon()
	setPillCount = nil
	knockButton = nil
	isKnockVisible = false
	isKnocking = false
	isLowGraphics = false
	lastCount = 0
	sinceBeaconRefresh = 0
	table.clear(controllers)
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return KeyfallController
