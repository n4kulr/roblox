--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local Steal = require(ReplicatedStorage.Rules.Steal)
local Variants = require(ReplicatedStorage.Rules.Variants)

local config = GameConfig.Steal

local Prompts = {
	StealName = "StealPrompt",
	KnockName = "KnockPrompt",
	TakeBackName = "TakeBackPrompt",
	OpenAttribute = "Open",
	BaseHoldAttribute = "BaseHold",
	KnockSlack = 2,
	TakeBackSlack = 4,
	TakeBackHold = 0.5,
	TakeBackRange = 8,
}

function Prompts.Create(parent: BasePart, ownerUserId: number, slot: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = Prompts.StealName
	prompt.ActionText = "Steal!"
	prompt.MaxActivationDistance = config.PromptRange
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OwnerUserId", ownerUserId)
	prompt:SetAttribute("Slot", slot)
	prompt.Parent = parent
	return prompt
end

function Prompts.Update(prompt: ProximityPrompt, keyId: string, lessonPending: boolean, isOpen: boolean)
	local key = Keys.Resolve(keyId)
	prompt.ObjectText = if key then Variants.Name(keyId) else ""
	local baseHold = Steal.HoldSeconds(Steal.RarityIndex(keyId), lessonPending)
	prompt.HoldDuration = baseHold
	prompt:SetAttribute(Prompts.BaseHoldAttribute, baseHold)
	prompt.Enabled = isOpen
	prompt:SetAttribute(Prompts.OpenAttribute, isOpen)
	prompt:SetAttribute("KeyId", keyId)
	prompt:SetAttribute("Income", Keys.GetIncome(keyId))
	prompt:SetAttribute("RarityIndex", Steal.RarityIndex(keyId))
end

function Prompts.KnockRange(lessonPending: boolean): number
	return if lessonPending then config.LessonTagRange else config.TagRange
end

function Prompts.CreateKnock(root: BasePart, victimUserId: number, range: number): ProximityPrompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = Prompts.KnockName
	prompt.ActionText = "Knock down!"
	prompt.ObjectText = "Thief"
	prompt.HoldDuration = 0
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = range
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt:SetAttribute("VictimUserId", victimUserId)
	prompt:SetAttribute(Prompts.OpenAttribute, true)
	prompt.Parent = root
	return prompt
end

function Prompts.CreateTakeBack(part: BasePart, ownerUserId: number, keyId: string): ProximityPrompt
	local key = Keys.Resolve(keyId)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = Prompts.TakeBackName
	prompt.ActionText = "Take back"
	prompt.ObjectText = if key then Variants.Name(keyId) else ""
	prompt.HoldDuration = Prompts.TakeBackHold
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = Prompts.TakeBackRange
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt:SetAttribute("OwnerUserId", ownerUserId)
	prompt:SetAttribute(Prompts.OpenAttribute, true)
	prompt.Parent = part
	return prompt
end

return Prompts
