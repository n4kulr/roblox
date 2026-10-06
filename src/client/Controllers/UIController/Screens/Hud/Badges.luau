--!strict

local Kit = require(script.Parent.Parent.Parent.Kit)
local PetState = require(script.Parent.Parent.Parent.PetState)
local Types = require(script.Parent.Types)

local Badges = {}

function Badges.Build(env: Types.Env, buttons: Types.SideMenu): Types.Badges
	local trove = env.Trove
	local context = env.Context
	local theme = Kit.Theme
	local upgradesButton = buttons.Upgrades
	local rebirthButton = buttons.Rebirth
	local dailyButton = buttons.Daily
	local petsButton = buttons.Pets
	local passButton = buttons.Pass
	local petsBadge = Kit.Badge(petsButton.Instance, "!")
	petsBadge.Visible = false
	local pets = PetState.For(context, trove)
	local ownedPets = pets.Total()
	local seenPets = 0
	local hasPetBaseline = false
	local function refreshPets()
		ownedPets = pets.Total()
		if not hasPetBaseline and pets.IsLoaded() then
			hasPetBaseline = true
			seenPets = ownedPets
		end
		petsBadge.Visible = ownedPets > seenPets and not context.IsOpen("Pets")
	end
	trove:Add(pets.Subscribe(refreshPets))
	refreshPets()
	trove:Connect(petsButton.Instance.Activated, function()
		seenPets = ownedPets
		petsBadge.Visible = false
	end)
	local upgradesBadge = Kit.Badge(upgradesButton.Instance, "!")
	upgradesBadge.Visible = false
	local rebirthBadge = Kit.Badge(rebirthButton.Instance, "!")
	rebirthBadge.Visible = false
	local dailyBadge = Kit.Badge(dailyButton.Instance, "1")
	dailyBadge.Visible = false
	local dailyBadgeText = dailyBadge:FindFirstChild("Text") :: TextLabel
	local dailyTimer = Kit.Chip({
		Parent = dailyButton.Instance,
		Name = "GiftTimer",
		Text = "",
		Size = UDim2.fromOffset(46, 22),
		Position = UDim2.new(1, 8, 0, -8),
		AnchorPoint = Vector2.new(1, 0),
		Color = theme.Blue,
		TextSize = Kit.Text.Small,
	}).Parent :: Frame
	dailyTimer.ZIndex = Kit.ZIndex.Badge
	dailyTimer.Visible = false
	local dailyTimerText = dailyTimer:FindFirstChild("Text") :: TextLabel
	local dailyBadgeHome = dailyBadge.Position
	local dailyBadgeHop =
		Kit.Tween(dailyBadge, Kit.Motion.Bounce, { Position = dailyBadgeHome - UDim2.fromOffset(0, 5) })
	trove:Add(function()
		dailyBadgeHop:Cancel()
	end)

	local passBadge = Kit.Badge(passButton.Instance, "!")
	passBadge.Visible = false
	return {
		Upgrades = upgradesBadge,
		Rebirth = rebirthBadge,
		Pass = passBadge,
		Daily = dailyBadge,
		DailyText = dailyBadgeText,
		DailyTimer = dailyTimer,
		DailyTimerText = dailyTimerText,
	}
end

return Badges
