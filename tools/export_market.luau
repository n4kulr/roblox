local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local roots = roblox.deserializeModel(fs.readFile("assets/map/ThockMap.rbxm"))
local market = nil
for _, root in roots do
	if root.Name == "Market" then
		market = root
	end
end
assert(market, "Market not found in assets/map/ThockMap.rbxm")
local counter = market:FindFirstChild("Counter")
assert(counter and counter:IsA("BasePart"), "Market needs a Counter part")
local parts = 0
for _, descendant in market:GetDescendants() do
	if descendant:IsA("BasePart") then
		assert(descendant.Anchored, `{descendant:GetFullName()} is not anchored`)
		parts += 1
	end
end
fs.writeFile("assets/map/Market.rbxm", roblox.serializeModel({ market }))
print(`Wrote assets/map/Market.rbxm: {parts} parts, Counter at {counter.CFrame.Position}`)
