local screensPath = "StarterPlayer.StarterPlayerScripts.Controllers.RollController"

local function pickKey(world: any, rarityName: string, longest: boolean?): any
	local Keys = world:require("ReplicatedStorage.Config.Keys")
	local pick = Keys.ByRarity[rarityName][1]
	if longest then
		for _, key in Keys.ByRarity[rarityName] do
			if #key.Name > #pick.Name then
				pick = key
			end
		end
	end
	return pick
end

local function show(scene: any, specs: { any }, settle: number)
	local world = scene.World
	local Trove = world:require("ReplicatedStorage.Packages.Trove")
	local Keys = world:require("ReplicatedStorage.Config.Keys")
	local ResultCards = world:require(`{screensPath}.ResultCards`)
	local trove = Trove.new()
	local cards = ResultCards.new(scene.PlayerGui, trove, function()
		return false
	end)
	for _, spec in specs do
		local key = pickKey(world, spec.Rarity, spec.Longest)
		cards:Show(
			spec.Slot,
			{ Key = key, Rarity = Keys.GetRarity(key), IsGolden = spec.Golden == true },
			spec.IsRare == true
		)
	end
	for _ = 1, settle do
		cards:Step(0.05)
	end
	for _, d in scene.PlayerGui:GetDescendants() do
		if d.Name == "Image" then
			d.ImageColor3 = require("@lune/roblox").Color3.new(1, 1, 1)
		end
	end
	world:flush()
	scene.Cards = cards
end

local function cinematic(scene: any, rarityName: string, seconds: number, isGolden: boolean?)
	local world = scene.World
	local Trove = world:require("ReplicatedStorage.Packages.Trove")
	local Keys = world:require("ReplicatedStorage.Config.Keys")
	local Cinematic = world:require(`{screensPath}.Cinematic`)
	local trove = Trove.new()
	local cine = Cinematic.new(scene.PlayerGui, trove, function()
		return false
	end, function()
		return {}
	end)
	local key = pickKey(world, rarityName, true)
	cine:Play({ Key = key, Rarity = Keys.GetRarity(key), IsGolden = isGolden == true }, nil)
	cine:Seek(seconds)
	world:flush()
	scene.Cine = cine
end

local function cineScenario(name: string, rarity: string, seconds: number): any
	return {
		Name = name,
		Screens = {},
		NoBase = true,
		Run = function(scene)
			cinematic(scene, rarity, seconds)
		end,
	}
end

return {
	cineScenario("cine_legendary_drop", "Legendary", 0.38),
	cineScenario("cine_legendary", "Legendary", 0.95),
	cineScenario("cine_legendary_hold", "Legendary", 1.5),
	cineScenario("cine_epic", "Epic", 0.5),
	cineScenario("cine_mini", "Rare", 0.22),
	cineScenario("cine_mythic_charge", "Mythic", 1.2),
	cineScenario("cine_mythic_impact", "Mythic", 1.62),
	cineScenario("cine_mythic", "Mythic", 2.2),
	cineScenario("cine_secret_descend", "Secret", 0.9),
	cineScenario("cine_secret_impact", "Secret", 2.15),
	cineScenario("cine_secret", "Secret", 2.9),
	{
		Name = "roll_common",
		Screens = {},
		Run = function(scene)
			show(scene, { { Rarity = "Common", Slot = "Center" } }, 2)
		end,
	},
	{
		Name = "roll_rare",
		Screens = {},
		Run = function(scene)
			show(scene, { { Rarity = "Rare", Slot = "Center" } }, 4)
		end,
	},
	{
		Name = "roll_epic",
		Screens = {},
		Run = function(scene)
			show(scene, { { Rarity = "Epic", Slot = "Center" } }, 6)
		end,
	},
	{
		Name = "roll_legendary",
		Screens = {},
		Run = function(scene)
			show(scene, { { Rarity = "Legendary", Slot = "Center", IsRare = true } }, 6)
		end,
	},
	{
		Name = "roll_pair",
		Screens = {},
		Run = function(scene)
			show(scene, {
				{ Rarity = "Legendary", Slot = "Left", IsRare = true, Longest = true },
				{ Rarity = "Uncommon", Slot = "Right", Longest = true },
			}, 8)
		end,
	},
	{
		Name = "roll_golden_pair",
		Screens = {},
		Run = function(scene)
			show(scene, {
				{ Rarity = "Mythic", Slot = "Left", IsRare = true, Golden = true },
				{ Rarity = "Common", Slot = "Right", Golden = true },
			}, 8)
		end,
	},
}
