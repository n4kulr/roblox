local screensPath = "StarterPlayer.StarterPlayerScripts.Controllers.UIController.Screens"

local function tick(scene: any, seconds: number)
	local heartbeat = scene.World.fakeServices.RunService.Heartbeat
	for _ = 1, 6 do
		heartbeat:Fire(seconds / 6)
	end
	scene.World:flush()
end

local function openPets(scene: any, owned: { [string]: number })
	scene.Data.Charms = owned
	local screen = scene.World:require(`{screensPath}.Pets`).new(scene.Context)
	scene.Screens.Pets = screen
	screen:Open()
	tick(scene, 0.6)
end

return {
	{
		Name = "pets",
		Screens = {},
		Run = function(scene)
			openPets(scene, {
				KeycapPin = 3,
				CloverFob = 1,
				TinySwitch = 1,
				BrassStab = 1,
				GoldenTick = 2,
				ThockPad = 1,
				LuckyCable = 1,
				StickyFingers = 1,
				LaserLens = 1,
				GhostHand = 1,
				MidasKey = 1,
				DiamondSpacebar = 1,
			})
		end,
	},
	{
		Name = "pets_empty",
		Screens = {},
		Run = function(scene)
			openPets(scene, {})
		end,
	},
}
