--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldNames = require(ReplicatedStorage.Config.WorldNames)
local Attributes = WorldNames.Attributes
local Folders = WorldNames.Folders

local Wobble = {}

local idleAmplitude = 0.045
local idleSpeed = 1.6
local readyAmplitude = 0.11
local readySpeed = 5

function Wobble.Collect(): { Model }
	local found: { Model } = {}
	local plots = workspace:FindFirstChild(Folders.Plots)
	if not plots then
		return found
	end
	for _, plot in plots:GetChildren() do
		local folder = plot:FindFirstChild(Folders.PlacedEggs)
		if folder then
			for _, child in folder:GetChildren() do
				if child:IsA("Model") then
					table.insert(found, child)
				end
			end
		end
	end
	return found
end

function Wobble.Step(models: { Model }, now: number, clock: number)
	for _, model in models do
		local rest = model:GetAttribute(Attributes.BaseCFrame)
		local drop = model:GetAttribute(Attributes.Drop)
		local readyAt = model:GetAttribute(Attributes.ReadyAt)
		local phase = model:GetAttribute(Attributes.Phase)
		if
			typeof(rest) == "CFrame"
			and type(drop) == "number"
			and type(phase) == "number"
			and model.Parent ~= nil
		then
			local isReady = type(readyAt) == "number" and now >= readyAt
			local amplitude = if isReady then readyAmplitude else idleAmplitude
			local speed = if isReady then readySpeed else idleSpeed
			local t = clock * speed + phase
			local tilt = CFrame.Angles(math.sin(t) * amplitude, 0, math.cos(t * 0.8) * amplitude)
			model:PivotTo(rest * CFrame.new(0, -drop, 0) * tilt * CFrame.new(0, drop, 0))
		end
	end
end

return Wobble
