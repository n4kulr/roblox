--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Kit = require(script.Parent.UIController.Kit)

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	_trove: TroveInstance?,
}

local config = GameConfig.Steal
local promptName = "StealPrompt"
local tagButtonOffset = -124
local beamColor = Color3.fromRGB(255, 96, 96)

local StealController = {
	Name = "StealController",
	_trove = nil :: TroveInstance?,
}
local controllers: { [string]: any } = {}
local isTagging = false
local tagButton: Kit.Button? = nil
local isTagVisible = false
local carryTrove: TroveInstance? = nil

local function escapeRichText(text: string): string
	local escaped = string.gsub(text, "&", "&amp;")
	escaped = string.gsub(escaped, "<", "&lt;")
	escaped = string.gsub(escaped, ">", "&gt;")
	return escaped
end

local function toast(text: string, kind: string)
	local ui = controllers.UIController
	if ui then
		ui:Toast(text, kind)
	end
end

local function keyName(index: number): string
	local key = Keys.Catalog[index]
	return if key then key.Name else "key"
end

local function hideOwnPrompt(instance: Instance)
	if instance:IsA("ProximityPrompt") and instance.Name == promptName then
		if instance:GetAttribute("OwnerUserId") == Players.LocalPlayer.UserId then
			instance.Enabled = false
		end
	end
end

local function playAlarm(index: number)
	local sounds = controllers.SoundController
	if not sounds then
		return
	end
	local key = Keys.Catalog[index]
	local rarity = if key then Keys.GetRarity(key) else nil
	if rarity and rarity.Reveal then
		sounds:PlayReveal(rarity, "Other")
	else
		sounds:PlayUi("Error")
	end
end

local function onAlert(name: string, keyIndex: number, phase: number)
	if phase == 1 then
		toast(`{name} is stealing your {keyName(keyIndex)}!`, "Bad")
		playAlarm(keyIndex)
	elseif phase == 2 then
		toast(`{name} stole your {keyName(keyIndex)}! Chase them!`, "Bad")
		playAlarm(keyIndex)
	elseif phase == 3 then
		if not isTagging then
			toast("Your key came back!", "Good")
		end
	elseif phase == 4 then
		toast(`{name} got away with your {keyName(keyIndex)}!`, "Bad")
	elseif phase == 10 then
		toast(name, "Info")
	elseif phase == 11 then
		toast(name, "Good")
	elseif phase == 9 then
		toast(name, "Bad")
		local sounds = controllers.SoundController
		if sounds then
			sounds:PlayUi("Error")
		end
	end
end

local function onFeed(thiefName: string, victimName: string, keyIndex: number)
	local name = keyName(keyIndex)
	local channels = TextChatService:FindFirstChild("TextChannels")
	local general = if channels then channels:FindFirstChild("RBXGeneral") else nil
	if general and general:IsA("TextChannel") then
		general:DisplaySystemMessage(
			`[{GameConfig.Name}] {escapeRichText(thiefName)} stole {name} from {escapeRichText(victimName)}!`
		)
	end
	if thiefName == Players.LocalPlayer.DisplayName then
		toast(`You stole {name}!`, "Good")
	end
end

local function findCarrier(): Player?
	local localPlayer = Players.LocalPlayer
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if
			player ~= localPlayer
			and character
			and character:GetAttribute("CarryingKey") ~= nil
			and character:GetAttribute("StolenFromUserId") == localPlayer.UserId
		then
			return player
		end
	end
	return nil
end

local function distanceTo(player: Player): number
	local own = Players.LocalPlayer.Character
	local theirs = player.Character
	local ownRoot = if own then own:FindFirstChild("HumanoidRootPart") else nil
	local theirRoot = if theirs then theirs:FindFirstChild("HumanoidRootPart") else nil
	if ownRoot and theirRoot and ownRoot:IsA("BasePart") and theirRoot:IsA("BasePart") then
		return (ownRoot.Position - theirRoot.Position).Magnitude
	end
	return math.huge
end

local function setTagVisible(isVisible: boolean)
	local button = tagButton
	if not button or isTagVisible == isVisible then
		return
	end
	isTagVisible = isVisible
	button.Instance.Visible = isVisible
	button.SetGlow(isVisible)
end

local function updateTagButton()
	local carrier = findCarrier()
	if not carrier then
		setTagVisible(false)
		return
	end
	local lessonDone = controllers.DataController:Get({ "TheftLessonDone" })
	local range = if lessonDone == false then config.LessonTagRange else config.TagRange
	setTagVisible(distanceTo(carrier) <= range)
end

local function requestTag()
	if isTagging then
		return
	end
	local carrier = findCarrier()
	if not carrier then
		return
	end
	isTagging = true
	task.spawn(function()
		local success = Packets.TagThief:Fire(carrier.UserId)
		isTagging = false
		if success == true then
			toast("You got your key back!", "Good")
		end
	end)
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

local function stopCarrying()
	local current = carryTrove
	carryTrove = nil
	if current then
		current:Destroy()
	end
end

local function startCarrying(character: Model)
	stopCarrying()
	local root = character:FindFirstChild("HumanoidRootPart")
	local base = findOwnBase()
	toast("Run home to keep it!", "Info")
	if not root or not root:IsA("BasePart") or not base then
		return
	end
	local current = Trove.new()
	carryTrove = current
	local from = Instance.new("Attachment")
	from.Name = "CarryBeamStart"
	from.Parent = root
	current:Add(from)
	local to = Instance.new("Attachment")
	to.Name = "CarryBeamEnd"
	to.Parent = base
	current:Add(to)
	local beam = Instance.new("Beam")
	beam.Name = "CarryBeam"
	beam.Attachment0 = from
	beam.Attachment1 = to
	beam.Color = ColorSequence.new(beamColor)
	beam.Width0 = 1.2
	beam.Width1 = 1.2
	beam.FaceCamera = true
	beam.LightEmission = 1
	beam.Segments = 1
	beam.Parent = root
	current:Add(beam)
end

local function watchCharacter(character: Model, trove: TroveInstance)
	local function refresh()
		if character:GetAttribute("CarryingKey") ~= nil then
			startCarrying(character)
		else
			stopCarrying()
		end
	end
	trove:Connect(character:GetAttributeChangedSignal("CarryingKey"), refresh)
	if character:GetAttribute("CarryingKey") ~= nil then
		refresh()
	end
end

local function buildTagButton(trove: TroveInstance, playerGui: Instance)
	local _gui, root = Kit.ScreenGui("ThockTag", 15, playerGui, trove)
	local button = Kit.Button(trove, {
		Parent = root,
		Name = "TagThief",
		Text = "TAG THIEF!",
		Glyph = "Run",
		IconLeft = true,
		Size = UDim2.fromOffset(250, 64),
		Position = UDim2.new(0.5, 0, 1, tagButtonOffset),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = Kit.Theme.Red,
		TextSize = 30,
		Immediate = true,
		Callback = requestTag,
		Sound = Kit.UiSound(controllers),
	})
	button.Instance.Visible = false
	tagButton = button
end

function StealController.Init(self: State, registry: { [string]: any })
	controllers = registry
	self._trove = Trove.new()
end

function StealController.Start(self: State)
	local trove = self._trove :: TroveInstance
	trove:Add(Packets.StealAlert.OnClientEvent:Connect(onAlert))
	trove:Add(Packets.StealFeed.OnClientEvent:Connect(onFeed))
	local function onPrompt(instance: Instance)
		hideOwnPrompt(instance)
	end
	for _, descendant in workspace:GetDescendants() do
		onPrompt(descendant)
	end
	trove:Connect(workspace.DescendantAdded, onPrompt)
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		buildTagButton(trove, playerGui)
	end
	trove:Connect(RunService.Heartbeat, updateTagButton)
	local localPlayer = Players.LocalPlayer
	local characterTrove = Trove.new()
	trove:Add(characterTrove)
	trove:Connect(localPlayer.CharacterAdded, function(character: Model)
		characterTrove:Clean()
		stopCarrying()
		watchCharacter(character, characterTrove)
	end)
	if localPlayer.Character then
		watchCharacter(localPlayer.Character, characterTrove)
	end
end

function StealController.Destroy(self: State)
	stopCarrying()
	tagButton = nil
	isTagVisible = false
	isTagging = false
	table.clear(controllers)
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return StealController
