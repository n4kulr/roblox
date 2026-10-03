--!strict

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local inputPath = process.args[1] or "assets/map/ThockMap.rbxm"
local outputPath = process.args[2] or "footprints.json"

local entries = {}

local function visit(instance: roblox.Instance, path: string)
	if instance:IsA("BasePart") then
		local part = instance :: any
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = part.CFrame:GetComponents()
		local color = part.Color
		table.insert(entries, {
			path = path,
			shape = tostring(part.Shape),
			size = { part.Size.X, part.Size.Y, part.Size.Z },
			cframe = { x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 },
			color = { math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5) },
		})
	end
	for _, child in instance:GetChildren() do
		visit(child, `{path}/{child.Name}`)
	end
end

for _, root in roblox.deserializeModel(fs.readFile(inputPath)) do
	visit(root, root.Name)
end
fs.writeFile(outputPath, serde.encode("json", entries))
