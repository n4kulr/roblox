--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Obby = require(ReplicatedStorage.Rules.Obby)
local Types = require(script.Parent.Types)

local config = GameConfig.Obby.Tap

local Taps = {}

function Taps.KeyAt(keys: { BasePart }, point: Vector3): BasePart?
	for _, key in keys do
		local cframe = key.CFrame
		local size = key.Size
		local center = cframe.Position
		local radius = math.max(size.X, size.Z) * 0.75
		if math.abs(center.X - point.X) <= radius and math.abs(center.Z - point.Z) <= radius then
			if Obby.KeyContains(cframe, size, point) then
				return key
			end
		end
	end
	return nil
end

function Taps.Advance(keys: { BasePart }, track: Types.Track, position: Vector3): number
	local from = track.LastPosition or position
	local delta = position - from
	local distance = delta.Magnitude
	if distance > config.MaxJump then
		from = position
		delta = Vector3.zero
		distance = 0
	end
	local steps = math.max(1, math.ceil(distance / config.SampleStep))
	local last = track.LastKey
	local taps = 0
	for step = 1, steps do
		local key = Taps.KeyAt(keys, from + delta * (step / steps))
		if key ~= last then
			if key then
				taps += 1
			end
			last = key
		end
	end
	track.LastKey = last
	track.LastPosition = position
	return taps
end

return Taps
