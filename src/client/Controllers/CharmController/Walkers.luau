--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FloorGrid = require(ReplicatedStorage.Rules.FloorGrid)
local EggPlacement = require(ReplicatedStorage.Utils.EggPlacement)
local PetWander = require(ReplicatedStorage.Utils.PetWander)

export type Entry = {
	Walker: PetWander.Walker,
	Base: BasePart,
	Lift: number,
}

export type Walkers = { [Model]: Entry }

local folderName = "Pets"

local Walkers = {}

function Walkers.New(): Walkers
	return {}
end

local function register(walkers: Walkers, plot: Instance, model: Model)
	local base = plot:FindFirstChild("Base")
	local seed = model:GetAttribute("Seed")
	if not base or not base:IsA("BasePart") or type(seed) ~= "number" then
		return
	end
	local rollKey = plot:FindFirstChild("RollKey")
	local avoid = if rollKey and rollKey:IsA("BasePart")
		then EggPlacement.RectOf(base.CFrame, rollKey)
		else nil
	local lift = model:GetAttribute("Lift")
	walkers[model] = {
		Walker = PetWander.New(seed, base.Size.X / 2, base.Size.Z / 2, avoid),
		Base = base,
		Lift = if type(lift) == "number" then lift else 0.4,
	}
end

function Walkers.Sync(walkers: Walkers, plots: Instance)
	for model in walkers do
		if model.Parent == nil then
			walkers[model] = nil
		end
	end
	for _, plot in plots:GetChildren() do
		local folder = plot:FindFirstChild(folderName)
		if folder then
			for _, model in folder:GetChildren() do
				if model:IsA("Model") and walkers[model] == nil then
					register(walkers, plot, model)
				end
			end
		end
	end
end

function Walkers.Step(walkers: Walkers, dt: number)
	for model, entry in walkers do
		if model.Parent == nil then
			walkers[model] = nil
		else
			local walker = entry.Walker
			PetWander.Step(walker, dt)
			local base = entry.Base
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
