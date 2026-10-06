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

local function devPanel(name: string, tab: string?, grow: any?): any
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
			if grow then
				local gui = scene.PlayerGui:FindFirstChild("ThockCheats")
				local grip = gui and gui:FindFirstChild("ResizeGrip", true)
				local uis = scene.World.fakeServices.UserInputService
				if grip then
					grip.InputBegan:Fire({
						UserInputType = Enum.UserInputType.MouseButton1,
						Position = roblox.Vector3.new(0, 0, 0),
					})
					uis.InputChanged:Fire({
						UserInputType = Enum.UserInputType.MouseMovement,
						Position = roblox.Vector3.new(grow.X, grow.Y, 0),
					})
					uis.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton1 })
				end
			end
			tick(scene, 0.6)
		end,
	}
end

return {
	devPanel("dev_panel_money", nil),
	devPanel("dev_panel_items", "ITEMS"),
	devPanel("dev_panel_small", "ITEMS", { X = -500, Y = -500 }),
	devPanel("dev_panel_large", "ITEMS", { X = 300, Y = 220 }),
	goldenAt("hud_golden_60", 52),
	goldenAt("hud_golden_10", 8),
	goldenAt("hud_golden_next", 99),
}
