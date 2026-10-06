local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3
local H = require("../harness/Harness")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

describe("Steal prompt focus", function()
	local world, PromptFocus, Ragdoll, Keys, Steal

	beforeEach(function()
		world = H.newWorld({ Time = 1700000000 })
		local path = "StarterPlayer.StarterPlayerScripts.Controllers.StealController"
		PromptFocus = world:require(`{path}.PromptFocus`)
		Ragdoll = world:require(`{path}.Ragdoll`)
		Keys = world:require("ReplicatedStorage.Config.Keys")
		Steal = world:require("ReplicatedStorage.Rules.Steal")
	end)

	local function stealPrompt(keyId: string, x: number, ownerId: number?): any
		local part = world:newPart("Cap", x, 0, 0)
		local prompt = world:newInstance("ProximityPrompt")
		prompt.Name = "StealPrompt"
		prompt.MaxActivationDistance = 8
		prompt.Enabled = true
		prompt:SetAttribute("OwnerUserId", ownerId or 500)
		prompt:SetAttribute("KeyId", keyId)
		prompt:SetAttribute("Income", Keys.GetIncome(keyId))
		prompt:SetAttribute("RarityIndex", Steal.RarityIndex(keyId))
		prompt:SetAttribute("Open", true)
		prompt.Parent = part
		return prompt
	end

	local origin = Vector3.new(0, 0, 0)
	local context = { UserId = 1, Origin = origin, IsCarrying = false }

	it("enables only the most valuable prompt within range", function()
		local low = stealPrompt("PlainClack", 2)
		local high = stealPrompt("GlassTink", 5)
		local mid = stealPrompt("OfficeTap", 3)
		PromptFocus.Refresh({ low, high, mid }, context)
		expect(high.Enabled):toBe(true)
		expect(low.Enabled):toBe(false)
		expect(mid.Enabled):toBe(false)
		expect(PromptFocus.Pick({ low, high, mid }, origin) == high):toBe(true)
	end)

	it("breaks income ties by rarity then distance", function()
		local near = stealPrompt("PlainClack", 2)
		local far = stealPrompt("PlainClack", 6)
		expect(PromptFocus.Pick({ far, near }, origin) == near):toBe(true)
		near:SetAttribute("RarityIndex", 1)
		far:SetAttribute("RarityIndex", 2)
		expect(PromptFocus.Pick({ near, far }, origin) == far):toBe(true)
	end)

	it("ignores prompts out of range and follows the player", function()
		local close = stealPrompt("PlainClack", 3)
		local rich = stealPrompt("GlassTink", 30)
		PromptFocus.Refresh({ close, rich }, context)
		expect(close.Enabled):toBe(true)
		expect(PromptFocus.Pick({ close, rich }, origin) == close):toBe(true)
		local moved = Vector3.new(28, 0, 0)
		PromptFocus.Refresh({ close, rich }, { UserId = 1, Origin = moved, IsCarrying = false })
		expect(PromptFocus.Pick({ close, rich }, moved) == rich):toBe(true)
		expect(rich.Enabled):toBe(true)
	end)

	it("never shows prompts on the local base, closed prompts or while carrying", function()
		local own = stealPrompt("GlassTink", 2, 1)
		local closed = stealPrompt("GlassTink", 3)
		closed:SetAttribute("Open", false)
		local other = stealPrompt("PlainClack", 4)
		PromptFocus.Refresh({ own, closed, other }, context)
		expect(own.Enabled):toBe(false)
		expect(closed.Enabled):toBe(false)
		expect(other.Enabled):toBe(true)
		PromptFocus.Refresh({ own, closed, other }, { UserId = 1, Origin = origin, IsCarrying = true })
		expect(other.Enabled):toBe(false)
	end)

	it("shows the knock prompt only to the victim", function()
		local character = world:newInstance("Model")
		character:SetAttribute("StolenFromUserId", 7)
		local root = world:newPart("HumanoidRootPart", 1, 0, 0)
		root.Parent = character
		local prompt = world:newInstance("ProximityPrompt")
		prompt.Name = "KnockPrompt"
		prompt.MaxActivationDistance = 10
		prompt.Enabled = false
		prompt.Parent = root
		PromptFocus.Refresh({ prompt }, { UserId = 8, Origin = origin, IsCarrying = false })
		expect(prompt.Enabled):toBe(false)
		PromptFocus.Refresh({ prompt }, { UserId = 7, Origin = origin, IsCarrying = false })
		expect(prompt.Enabled):toBe(true)
		prompt:SetAttribute("Open", false)
		PromptFocus.Refresh({ prompt }, { UserId = 7, Origin = origin, IsCarrying = false })
		expect(prompt.Enabled):toBe(false)
	end)

	it("shows the take back prompt only to the owner", function()
		local part = world:newPart("DroppedKey", 1, 0, 0)
		local prompt = world:newInstance("ProximityPrompt")
		prompt.Name = "TakeBackPrompt"
		prompt.MaxActivationDistance = 8
		prompt.Enabled = false
		prompt:SetAttribute("OwnerUserId", 7)
		prompt.Parent = part
		PromptFocus.Refresh({ prompt }, { UserId = 8, Origin = origin, IsCarrying = false })
		expect(prompt.Enabled):toBe(false)
		PromptFocus.Refresh({ prompt }, { UserId = 7, Origin = origin, IsCarrying = false })
		expect(prompt.Enabled):toBe(true)
	end)

	it("sets the local humanoid state from the Ragdolled attribute", function()
		local humanoid = world:newInstance("Humanoid")
		humanoid.PlatformStand = false
		local states = {}
		humanoid.ChangeState = function(_self: any, state: any)
			table.insert(states, state)
		end
		Ragdoll.Set(humanoid, true)
		expect(humanoid.PlatformStand):toBe(true)
		Ragdoll.Set(humanoid, false)
		expect(humanoid.PlatformStand):toBe(false)
		expect(#states):toBe(2)
	end)
end)
