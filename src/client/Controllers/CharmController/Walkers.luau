--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FloorGrid = require(ReplicatedStorage.Rules.FloorGrid)
local EggPlacement = require(ReplicatedStorage.Utils.EggPlacement)
local PetWander = require(ReplicatedStorage.Utils.PetWander)
local WorldNames = require(ReplicatedStorage.Config.WorldNames)
local Config = require(script.Parent.Config)

local Attributes = WorldNames.Attributes
local Parts = WorldNames.Parts

export type Entry = {
	Walker: PetWander.Walker,
	Base: BasePart,
	Lift: number,
}

export type Walkers = { [Model]: Entry }

local Walkers = {}

function Walkers.New(): Walkers
	return {}
end

function Walkers.Register(walkers: Walkers, plot: Model, model: Model)
	local base = plot:FindFirstChild(Parts.Base)
	local seed = model:GetAttribute(Attributes.Seed)
	if not base or not base:IsA("BasePart") or type(seed) ~= "number" then
		return
	end
	local rollKey = plot:FindFirstChild(Parts.RollKey)
	local avoid = if rollKey and rollKey:IsA("BasePart")
		then EggPlacement.RectOf(base.CFrame, rollKey)
		else nil
	local lift = model:GetAttribute(Attributes.Lift)
	walkers[model] = {
		Walker = PetWander.New(seed, base.Size.X / 2, base.Size.Z / 2, avoid),
		Base = base,
		Lift = if type(lift) == "number" then lift else Config.DefaultLift,
	}
end

function Walkers.Remove(walkers: Walkers, model: Model)
	walkers[model] = nil
end

function Walkers.Step(walkers: Walkers, dt: number, origin: Vector3?)
	local range = Config.WalkerRange
	for model, entry in walkers do
		local walker = entry.Walker
		PetWander.Step(walker, dt)
		local base = entry.Base
		if not origin or (base.CFrame.Position - origin).Magnitude <= range + base.Size.Magnitude * 0.5 then
			local y = base.Size.Y / 2 + FloorGrid.CapHeight + entry.Lift + PetWander.Hop(walker)
			model:PivotTo(
				base.CFrame * CFrame.new(walker.X, y, walker.Z) * CFrame.Angles(0, walker.Heading, 0)
			)
		end
	end
end

function Walkers.Clear(walkers: Walkers)
	table.clear(walkers)
end

return Walkers
