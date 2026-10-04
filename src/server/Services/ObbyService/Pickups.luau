--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local Obby = require(ReplicatedStorage.Rules.Obby)
local Steal = require(ReplicatedStorage.Rules.Steal)
local KeyVisual = require(script.Parent.Parent.Parent.Utils.KeyVisual)
local Types = require(script.Parent.Types)

local config = GameConfig.Obby
local capSize = Vector3.new(3, 1.6, 3)

local Pickups = {}

Pickups.Name = "ObbyKey"
Pickups.PromptName = "ObbyTakePrompt"

function Pickups.PickKey(rng: Random, section: number): string
	local rarity = Obby.RarityFor(section, rng:NextNumber())
	local group = Keys.ByRarity[rarity]
	return group[rng:NextInteger(1, #group)].Id
end

function Pickups.Create(point: Types.SpawnPoint, keyId: string, parent: Instance): BasePart?
	local cap = KeyVisual.NewCap(keyId, Pickups.Name, capSize)
	if not cap then
		return nil
	end
	cap.Anchored = true
	cap.CFrame = point.Part.CFrame * CFrame.new(0, config.PickupHover, 0)
	cap:SetAttribute("KeyId", keyId)
	cap:SetAttribute("Section", point.Section)
	cap:SetAttribute("SpinSpeed", config.PickupSpin)
	CollectionService:AddTag(cap, "Spinner")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = Pickups.PromptName
	prompt.ActionText = "Take"
	prompt.ObjectText = if Keys.ById[keyId] then Keys.ById[keyId].Name else "Key"
	prompt.HoldDuration = Steal.HoldSeconds(Steal.RarityIndex(keyId), false)
	prompt.MaxActivationDistance = config.PickupRange
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("KeyId", keyId)
	prompt.Parent = cap
	cap.Parent = parent
	return cap
end

return Pickups
