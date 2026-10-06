local roblox = require("@lune/roblox")
local Enum = roblox.Enum

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

local function devPanel(name: string, tab: string?): any
	return {
		Name = name,
		Screens = {},
		NoBase = true,
		Run = function(scene)
			scene.World.Players.LocalPlayer:SetAttribute("IsDeveloper", true)
			for _, screen in { "Hud", "Offers", "Cheats" } do
				scene.Screens[screen] = scene.World:require(`{screensPath}.{screen}`).new(scene.Context)
			end
			scene.Screens.Cheats:Open()
			scene.World:flush()
			if tab then
				local gui = scene.PlayerGui:FindFirstChild("ThockCheats")
				local button = gui and gui:FindFirstChild(`Tab{tab}`, true)
				if button then
					button.Activated:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
				end
			end
			tick(scene, 0.6)
		end,
	}
end

return {
	devPanel("dev_panel_money", nil),
	devPanel("dev_panel_items", "ITEMS"),
	goldenAt("hud_golden_60", 52),
	goldenAt("hud_golden_10", 8),
	goldenAt("hud_golden_next", 99),
}
