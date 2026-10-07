--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldNames = require(ReplicatedStorage.Config.WorldNames)
local Attributes = WorldNames.Attributes
local Prompts = WorldNames.Prompts

export type Context = {
	UserId: number,
	Origin: Vector3?,
	IsCarrying: boolean,
}

local stealName = Prompts.StealPrompt
local knockName = Prompts.KnockPrompt
local takeBackName = Prompts.TakeBackPrompt
local openAttribute = Attributes.Open

local PromptFocus = {}

function PromptFocus.IsManaged(prompt: ProximityPrompt): boolean
	return prompt.Name == stealName or prompt.Name == knockName or prompt.Name == takeBackName
end

local function isOpen(prompt: ProximityPrompt): boolean
	return prompt:GetAttribute(openAttribute) ~= false
end

local function number(prompt: ProximityPrompt, name: string): number
	local value = prompt:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

local function positionOf(prompt: ProximityPrompt): Vector3?
	local parent = prompt.Parent
	if parent and parent:IsA("BasePart") then
		return parent.CFrame.Position
	end
	return nil
end

function PromptFocus.DistanceTo(prompt: ProximityPrompt, origin: Vector3?): number
	local position = positionOf(prompt)
	if not origin or not position then
		return math.huge
	end
	return (position - origin).Magnitude
end

local function isBetter(
	prompt: ProximityPrompt,
	distance: number,
	best: ProximityPrompt,
	bestDistance: number
)
	local income = number(prompt, "Income")
	local bestIncome = number(best, "Income")
	if income ~= bestIncome then
		return income > bestIncome
	end
	local rarity = number(prompt, "RarityIndex")
	local bestRarity = number(best, "RarityIndex")
	if rarity ~= bestRarity then
		return rarity > bestRarity
	end
	return distance < bestDistance
end

function PromptFocus.Pick(prompts: { ProximityPrompt }, origin: Vector3?): ProximityPrompt?
	local best: ProximityPrompt? = nil
	local bestDistance = math.huge
	for _, prompt in prompts do
		local distance = PromptFocus.DistanceTo(prompt, origin)
		if distance <= prompt.MaxActivationDistance then
			if not best or isBetter(prompt, distance, best, bestDistance) then
				best = prompt
				bestDistance = distance
			end
		end
	end
	return best
end

local function victimOf(prompt: ProximityPrompt): number?
	local part = prompt.Parent
	local character = if part then part.Parent else nil
	local value = if character then character:GetAttribute(Attributes.StolenFromUserId) else nil
	return if type(value) == "number" then value else nil
end

function PromptFocus.Refresh(prompts: { ProximityPrompt }, context: Context)
	local candidates: { ProximityPrompt } = {}
	for _, prompt in prompts do
		local ownerId = prompt:GetAttribute(Attributes.OwnerUserId)
		if
			prompt.Name == stealName
			and isOpen(prompt)
			and ownerId ~= context.UserId
			and not context.IsCarrying
		then
			table.insert(candidates, prompt)
		end
	end
	local best = PromptFocus.Pick(candidates, context.Origin)
	for _, prompt in prompts do
		local shouldShow = false
		if prompt.Name == stealName then
			local isOwn = prompt:GetAttribute(Attributes.OwnerUserId) == context.UserId
			shouldShow = not isOwn
				and table.find(candidates, prompt) ~= nil
				and (
					prompt == best
					or PromptFocus.DistanceTo(prompt, context.Origin) > prompt.MaxActivationDistance
				)
		elseif prompt.Name == knockName then
			shouldShow = isOpen(prompt) and victimOf(prompt) == context.UserId
		elseif prompt.Name == takeBackName then
			shouldShow = isOpen(prompt) and prompt:GetAttribute(Attributes.OwnerUserId) == context.UserId
		end
		if prompt.Enabled ~= shouldShow then
			prompt.Enabled = shouldShow
		end
	end
end

return PromptFocus
