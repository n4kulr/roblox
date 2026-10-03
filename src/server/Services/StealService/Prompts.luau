--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local Steal = require(ReplicatedStorage.Rules.Steal)

local config = GameConfig.Steal

local Prompts = {}

function Prompts.Create(parent: BasePart, ownerUserId: number, slot: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "StealPrompt"
	prompt.ActionText = "Steal!"
	prompt.MaxActivationDistance = config.PromptRange
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerUserId", ownerUserId)
	prompt:SetAttribute("Slot", slot)
	prompt.Parent = parent
	return prompt
end

function Prompts.Update(prompt: ProximityPrompt, keyId: string, lessonPending: boolean)
	local key = Keys.ById[keyId]
	prompt.ObjectText = if key then key.Name else ""
	prompt.HoldDuration = Steal.HoldSeconds(Steal.RarityIndex(keyId), lessonPending)
end

return Prompts
