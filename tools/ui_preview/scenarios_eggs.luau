local roblox = require("@lune/roblox")

local screensPath = "StarterPlayer.StarterPlayerScripts.Controllers.UIController.Screens"

local function tick(scene: any, seconds: number)
	local heartbeat = scene.World.fakeServices.RunService.Heartbeat
	for _ = 1, 6 do
		heartbeat:Fire(seconds / 6)
	end
	scene.World:flush()
end

local function build(scene: any, name: string): any
	local screen = scene.World:require(`{screensPath}.{name}`).new(scene.Context)
	scene.Screens[name] = screen
	return screen
end

local function press(button: any)
	button.Activated:Fire({ UserInputType = roblox.Enum.UserInputType.MouseButton1 })
end

local function stock(scene: any, bag: { [string]: number })
	scene.Data.EggInventory = bag
	scene.Data.PlacedEggs = {}
	scene.Data.Charms = {}
	scene.Data.EquippedCharms = {}
end

local function openMarket(scene: any)
	local screen = build(scene, "Market")
	screen:Open()
	tick(scene, 0.6)
	return screen
end

local ownedCharms = {
	KeycapPin = 3,
	CloverFob = 1,
	BrassStab = 1,
	GoldenTick = 2,
	ThockPad = 2,
	LuckyCable = 1,
	StickyFingers = 1,
	LaserLens = 1,
	RainbowCoil = 1,
	GhostHand = 1,
	GoldSpacebar = 1,
	MidasKey = 1,
	DiamondSpacebar = 1,
}

local function openCharms(scene: any, equipped: { string })
	stock(scene, {})
	scene.Data.Charms = ownedCharms
	scene.Data.EquippedCharms = equipped
	local screen = build(scene, "Charms")
	screen:Open()
	tick(scene, 0.6)
	return screen
end

local function hatch(scene: any, eggId: string, charmId: string, seconds: number)
	stock(scene, {})
	local screen = build(scene, "Hatch")
	screen:Open()
	screen:Play(eggId, charmId)
	tick(scene, 0.1)
	screen:Seek(seconds)
	scene.World:flush()
end

return {
	{
		Name = "egg_market",
		Screens = {},
		Run = function(scene)
			stock(scene, { Linear = 2, Golden = 1 })
			openMarket(scene)
		end,
	},
	{
		Name = "egg_market_expanded",
		Screens = {},
		Run = function(scene)
			stock(scene, {})
			scene.Data.Cash = 900000
			openMarket(scene)
			local card = scene.PlayerGui:FindFirstChild("Offer2", true)
			press(card:FindFirstChild("Tap", true))
			tick(scene, 0.3)
		end,
	},
	{
		Name = "egg_market_full",
		Screens = {},
		Run = function(scene)
			stock(scene, { Linear = 4, Golden = 3, Rainbow = 3 })
			openMarket(scene)
		end,
	},
	{
		Name = "charms",
		Screens = {},
		Run = function(scene)
			openCharms(scene, { "DiamondSpacebar", "GoldSpacebar", "ThockPad" })
		end,
	},
	{
		Name = "charms_partial",
		Screens = {},
		Run = function(scene)
			openCharms(scene, { "KeycapPin" })
		end,
	},
	{
		Name = "charms_empty",
		Screens = {},
		Run = function(scene)
			stock(scene, {})
			local screen = build(scene, "Charms")
			screen:Open()
			tick(scene, 0.6)
		end,
	},
	{
		Name = "hatch_wobble",
		Screens = {},
		Run = function(scene)
			hatch(scene, "Golden", "GoldSpacebar", 1.9)
		end,
	},
	{
		Name = "hatch_reveal_mythic",
		Screens = {},
		Run = function(scene)
			hatch(scene, "Rainbow", "DiamondSpacebar", 3.4)
		end,
	},
	{
		Name = "hatch_reveal_common",
		Screens = {},
		Run = function(scene)
			hatch(scene, "Linear", "TinySwitch", 3.4)
		end,
	},
}
