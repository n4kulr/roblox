--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Charms = require(ReplicatedStorage.Rules.Charms)
local Keys = require(ReplicatedStorage.Config.Keys)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local PromptFocus = require(script.PromptFocus)
local Ragdoll = require(script.Ragdoll)

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	_trove: TroveInstance?,
}

local baseHoldAttribute = "BaseHold"
local refreshSeconds = 0.2
local beamColor = Color3.fromRGB(255, 96, 96)

local StealController = {
	Name = "StealController",
	_trove = nil :: TroveInstance?,
}
local stealPromptName = "StealPrompt"
local controllers: { [string]: any } = {}
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
		toast("Your key came back!", "Good")
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

function StealController.Init(self: State, registry: { [string]: any })
	controllers = registry
	self._trove = Trove.new()
end

function StealController.Start(self: State)
	local trove = self._trove :: TroveInstance
	trove:Add(Packets.StealAlert.OnClientEvent:Connect(onAlert))
	trove:Add(Packets.StealFeed.OnClientEvent:Connect(onFeed))
	local watched: { [ProximityPrompt]: boolean } = {}
	local function speedUp(instance: Instance)
		if not instance:IsA("ProximityPrompt") or instance.Name ~= stealPromptName then
			return
		end
		local function apply()
			local baseHold = instance:GetAttribute(baseHoldAttribute)
			if type(baseHold) ~= "number" then
				return
			end
			local speed = Charms.Effects(controllers.DataController:Get({ "EquippedCharms" })).StealSpeed
			instance.HoldDuration = baseHold / math.max(speed, 1)
		end
		apply()
		trove:Connect(instance:GetAttributeChangedSignal(baseHoldAttribute), apply)
	end
	local function onPrompt(instance: Instance)
		if instance:IsA("ProximityPrompt") and PromptFocus.IsManaged(instance) then
			watched[instance] = true
			speedUp(instance)
		end
	end
	for _, descendant in workspace:GetDescendants() do
		onPrompt(descendant)
	end
	trove:Connect(workspace.DescendantAdded, onPrompt)
	trove:Connect(workspace.DescendantRemoving, function(instance: Instance)
		if instance:IsA("ProximityPrompt") then
			watched[instance] = nil
		end
	end)
	trove:Add(task.spawn(function()
		while true do
			task.wait(refreshSeconds)
			local list: { ProximityPrompt } = {}
			for prompt in watched do
				table.insert(list, prompt)
			end
			local character = Players.LocalPlayer.Character
			local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
			PromptFocus.Refresh(list, {
				UserId = Players.LocalPlayer.UserId,
				Origin = if root and root:IsA("BasePart") then root.CFrame.Position else nil,
				IsCarrying = character ~= nil and character:GetAttribute("CarryingKey") ~= nil,
			})
		end
	end))
	local localPlayer = Players.LocalPlayer
	local characterTrove = Trove.new()
	trove:Add(characterTrove)
	trove:Connect(localPlayer.CharacterAdded, function(character: Model)
		characterTrove:Clean()
		stopCarrying()
		watchCharacter(character, characterTrove)
		Ragdoll.Watch(character, characterTrove)
	end)
	if localPlayer.Character then
		watchCharacter(localPlayer.Character, characterTrove)
		Ragdoll.Watch(localPlayer.Character, characterTrove)
	end
end

function StealController.Destroy(self: State)
	stopCarrying()
	table.clear(controllers)
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return StealController
