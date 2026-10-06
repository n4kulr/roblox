local screensPath = "StarterPlayer.StarterPlayerScripts.Controllers.UIController.Screens"

local function tick(scene: any, seconds: number)
	local heartbeat = scene.World.fakeServices.RunService.Heartbeat
	for _ = 1, 6 do
		heartbeat:Fire(seconds / 6)
	end
	scene.World:flush()
end

local function goldenAt(name: string, progress: number): any
	return {
		Name = name,
		Screens = {},
		NoBase = true,
		Run = function(scene)
			scene.Data.GoldenProgress = progress
			for _, screen in { "Hud", "Offers" } do
				scene.Screens[screen] = scene.World:require(`{screensPath}.{screen}`).new(scene.Context)
			end
			tick(scene, 0.6)
		end,
	}
end

return {
	goldenAt("hud_golden_60", 52),
	goldenAt("hud_golden_10", 8),
	goldenAt("hud_golden_next", 99),
}
