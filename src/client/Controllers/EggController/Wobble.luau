--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldNames = require(ReplicatedStorage.Config.WorldNames)
local Config = require(script.Parent.Config)

local Attributes = WorldNames.Attributes
local wobble = Config.Wobble

export type Entry = {
	Model: Model,
	Rest: CFrame?,
	Drop: number?,
	Phase: number?,
	ReadyAt: number?,
}

export type Entries = { [Model]: Entry }

local Wobble = {}

function Wobble.Track(model: Model, trove: any): Entry
	local entry: Entry = { Model = model, Rest = nil, Drop = nil, Phase = nil, ReadyAt = nil }
	local function read()
		local rest = model:GetAttribute(Attributes.BaseCFrame)
		local drop = model:GetAttribute(Attributes.Drop)
		local phase = model:GetAttribute(Attributes.Phase)
		local readyAt = model:GetAttribute(Attributes.ReadyAt)
		entry.Rest = if typeof(rest) == "CFrame" then rest else nil
		entry.Drop = if type(drop) == "number" then drop else nil
		entry.Phase = if type(phase) == "number" then phase else nil
		entry.ReadyAt = if type(readyAt) == "number" then readyAt else nil
	end
	read()
	for _, name in { Attributes.BaseCFrame, Attributes.Drop, Attributes.Phase, Attributes.ReadyAt } do
		trove:Connect(model:GetAttributeChangedSignal(name), read)
	end
	return entry
end

function Wobble.Step(entries: Entries, now: number, clock: number, origin: Vector3?)
	local range = Config.WobbleRange
	for model, entry in entries do
		local rest = entry.Rest
		local drop = entry.Drop
		local phase = entry.Phase
		if rest and drop and phase and model.Parent ~= nil then
			if not origin or (rest.Position - origin).Magnitude <= range then
				local readyAt = entry.ReadyAt
				local isReady = readyAt ~= nil and now >= readyAt
				local amplitude = if isReady then wobble.ReadyAmplitude else wobble.IdleAmplitude
				local speed = if isReady then wobble.ReadySpeed else wobble.IdleSpeed
				local t = clock * speed + phase
				local tilt =
					CFrame.Angles(math.sin(t) * amplitude, 0, math.cos(t * wobble.SwayRatio) * amplitude)
				model:PivotTo(rest * CFrame.new(0, -drop, 0) * tilt * CFrame.new(0, drop, 0))
			end
		end
	end
end

return Wobble
