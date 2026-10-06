local H = require("../../tests/harness/Harness")

local screenPath = "StarterPlayer.StarterPlayerScripts.Controllers.UIController.Screens.GroupChest"

local function open(scene: any, groupId: number)
	local world = scene.World
	local copy = H.deepCopy(world:require("ReplicatedStorage.Config.GameConfig"))
	local chest = table.clone(copy.GroupChest)
	chest.GroupId = groupId
	copy.GroupChest = chest
	world.overrides[world:node("ReplicatedStorage.Config.GameConfig")] = copy
	local screen = world:require(screenPath).new(scene.Context)
	scene.Chest = screen
	screen:Open()
	for _ = 1, 6 do
		world.fakeServices.RunService.Heartbeat:Fire(0.1)
	end
	world:flush()
end

return {
	{
		Name = "chest_join",
		Screens = {},
		Run = function(scene)
			open(scene, 4242)
		end,
	},
	{
		Name = "chest_soon",
		Screens = {},
		Run = function(scene)
			open(scene, 0)
		end,
	},
}
