--!strict

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local Obby = require(ReplicatedStorage.Rules.Obby)
local KeyVisual = require(script.Parent.Parent.Parent.Utils.KeyVisual)
local Types = require(script.Parent.Types)

local config = GameConfig.Obby.Pickup
local capSize = Vector3.new(3, 1.6, 3)

local Pickups = {}

Pickups.Name = "ObbyKey"
Pickups.PromptName = "TakePrompt"

function Pickups.PickKey(rng: Random, rarities: string): string
	local rarity = Obby.RarityFor(rarities, rng:NextNumber())
	local group = Keys.ByRarity[rarity]
	return group[rng:NextInteger(1, #group)].Id
end

function Pickups.Create(
	point: Types.SpawnPoint,
	keyId: string,
	parent: Instance
): (BasePart?, ProximityPrompt?)
	local key = Keys.ById[keyId]
	local cap = KeyVisual.NewCap(keyId, Pickups.Name, capSize)
	if not cap or not key then
		return nil, nil
	end
	cap.Anchored = true
	cap.CFrame = point.Part.CFrame * CFrame.new(0, config.Hover, 0)
	cap:SetAttribute("KeyId", keyId)
	cap:SetAttribute("SpinSpeed", config.Spin)
	CollectionService:AddTag(cap, "Spinner")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = Pickups.PromptName
	prompt.ActionText = "Take"
	prompt.ObjectText = key.Name
	prompt.HoldDuration = config.HoldSeconds
	prompt.MaxActivationDistance = config.Distance
	prompt.RequiresLineOfSight = false
	prompt.Parent = cap
	cap.Parent = parent
	return cap, prompt
end

return Pickups
