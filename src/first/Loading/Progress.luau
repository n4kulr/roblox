--!strict

local Config = require(script.Parent.Config)

export type Input = {
	Loaded: boolean,
	Ready: boolean,
	TimedOut: boolean,
	Queue: number,
	MaxQueue: number,
}

local Progress = {}

function Progress.Target(input: Input): number
	local assets = 0
	if input.MaxQueue > 0 then
		assets = 1 - math.clamp(input.Queue / input.MaxQueue, 0, 1)
	end
	if input.Loaded and input.Queue <= 0 then
		assets = 1
	end
	local finished = input.Ready or input.TimedOut
	if input.Loaded and finished then
		return 1
	end
	local total = Config.Weights.Assets * assets
	if input.Loaded then
		total += Config.Weights.Loaded
	end
	if finished then
		total += Config.Weights.Ready
	end
	return math.min(total, 0.97)
end

function Progress.Advance(displayed: number, target: number, elapsed: number, dt: number): number
	local limit = math.min(target, elapsed / Config.MinShow)
	return math.max(displayed, math.min(limit, displayed + dt * Config.FillRate))
end

function Progress.LitCount(displayed: number, total: number): number
	return math.floor(displayed * total + 0.0001)
end

return Progress
