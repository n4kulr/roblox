local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local H = require("../../tests/harness/Harness")
local Layout = require("./Layout")

local outDir = process.args[1] or "ui-preview/json"
local width = tonumber(process.args[2]) or 1280
local height = tonumber(process.args[3]) or 720
local seconds = tonumber(process.args[4]) or 1.2
local gameLoaded = process.args[5] ~= "pending"

local world = H.newWorld({ GuiSize = roblox.Vector2.new(width, height), PrintErrors = true })
local player = world:newPlayer({ Name = "You" })
world.Players.LocalPlayer = player
local playerGui = world:newInstance("Folder")
playerGui.Name = "PlayerGui"
playerGui.Parent = player
world.gameLoaded = gameLoaded

local Loader = world:require("ReplicatedFirst.Loading.Loader")
Loader.Start(player)
for _ = 1, math.round(seconds / 0.05) do
	world.fakeServices.RunService.Heartbeat:Fire(0.05)
end

local guis = {}
for _, gui in playerGui:GetChildren() do
	if gui.ClassName == "ScreenGui" then
		table.insert(guis, Layout.Gui(gui, roblox.Vector2.new(width, height)))
	end
end
fs.writeDir(outDir)
local payload = { name = "loading", width = width, height = height, guis = guis, errors = world.errors }
fs.writeFile(`{outDir}/loading.json`, serde.encode("json", payload))
print(`[ui_preview] loading written ({#guis} guis, {#world.errors} errors)`)
