local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local outputPath = "assets/map/Obby.rbxm"

local services = { Config = {}, Rules = {} }
local env: { [string]: any } = {
	script = { Parent = services.Config },
	Instance = roblox.Instance,
	Vector3 = roblox.Vector3,
	CFrame = roblox.CFrame,
	Color3 = roblox.Color3,
	UDim2 = roblox.UDim2,
	Enum = roblox.Enum,
	Font = roblox.Font,
	game = {
		GetService = function(_self: any, _name: string)
			return services
		end,
	},
	require = function(module: any)
		return module
	end,
}

local function load(path: string): any
	local bytecode = luau.compile(fs.readFile(path))
	local chunk = luau.load(bytecode, { debugName = path, environment = env })
	return chunk()
end

services.Config.GameConfig = load("src/shared/Config/GameConfig.luau")
services.Config.SwitchSounds = load("src/shared/Config/SwitchSounds.luau")
services.Config.Keys = load("src/shared/Config/Keys.luau")
local obby = load("src/shared/Rules/Obby.luau")
services.Rules.Obby = obby
local course = load("src/server/Services/ObbyService/Course.luau")

local model = course.Build(obby.Entrance(nil), course.ModelName)
local parts = 0
for _, descendant in model:GetDescendants() do
	if descendant:IsA("BasePart") then
		assert(descendant.Anchored, `{descendant:GetFullName()} is not anchored`)
		parts += 1
	end
end
local zone = model:FindFirstChild("Zone")
assert(zone and zone:IsA("BasePart"), "Obby needs a Zone part")
fs.writeFile(outputPath, roblox.serializeModel({ model }))
print(`Wrote {outputPath}: {parts} parts, Zone at {zone.CFrame.Position}`)
