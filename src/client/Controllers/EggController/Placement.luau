--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Eggs = require(ReplicatedStorage.Config.Eggs)
local FloorGrid = require(ReplicatedStorage.Rules.FloorGrid)
local BaseBounds = require(ReplicatedStorage.Utils.BaseBounds)
local EggPlacement = require(ReplicatedStorage.Utils.EggPlacement)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Placement = {}

function Placement.PointerHit(plot: Types.Plot, point: Vector2): (number?, number?)
	local camera = workspace.CurrentCamera
	if not camera then
		return nil, nil
	end
	local ray = camera:ViewportPointToRay(point.X, point.Y)
	local base = plot.Base.CFrame
	local origin = base:PointToObjectSpace(ray.Origin)
	local direction = base:VectorToObjectSpace(ray.Direction)
	local planeY = plot.Base.Size.Y / 2 + FloorGrid.CapHeight
	if direction.Y >= -1e-4 then
		return nil, nil
	end
	local t = (planeY - origin.Y) / direction.Y
	if t < 0 then
		return nil, nil
	end
	return origin.X + direction.X * t, origin.Z + direction.Z * t
end

function Placement.IsNearBase(plot: Types.Plot, root: BasePart?): boolean
	return root ~= nil
		and BaseBounds.Contains(plot.Base.CFrame, plot.Base.Size, root.Position, Config.NearMargin)
end

function Placement.IsFar(plot: Types.Plot, x: number, z: number): boolean
	return math.abs(x) > plot.Base.Size.X / 2 + Config.FarLimit
		or math.abs(z) > plot.Base.Size.Z / 2 + Config.FarLimit
end

function Placement.Evaluate(plot: Types.Plot, spots: { EggPlacement.Spot }, x: number, z: number): string
	if #spots >= Eggs.PlacedCap then
		return Config.FullVerdict
	end
	return EggPlacement.Check(plot.Base.Size, plot.RollKey, spots, x, z)
end

function Placement.Spots(list: any, into: { EggPlacement.Spot }): { EggPlacement.Spot }
	table.clear(into)
	if type(list) == "table" then
		for _, entry in list do
			if type(entry) == "table" and type(entry.X) == "number" and type(entry.Z) == "number" then
				table.insert(into, { X = entry.X, Z = entry.Z })
			end
		end
	end
	return into
end

return Placement
