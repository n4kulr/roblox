--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FloorGrid = require(ReplicatedStorage.Rules.FloorGrid)
local WorldNames = require(ReplicatedStorage.Config.WorldNames)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Parts = WorldNames.Parts

local Detection = {}

function Detection.GridKey(column: number, row: number): number
	return (column + Config.GridOffset) * Config.GridStride + row + Config.GridOffset
end

function Detection.GetRoot(player: Player): (BasePart?, boolean)
	local character = player.Character
	if not character then
		return nil, false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid then
		return nil, false
	end
	return root, humanoid.FloorMaterial ~= Enum.Material.Air
end

local function getBase(state: Types.PlotState): BasePart?
	local base = state.Base
	if base and base.Parent then
		return base
	end
	local found = state.Model:FindFirstChild(Parts.Base)
	base = if found and found:IsA("BasePart") then found else nil
	state.Base = base
	return base
end

local function findCosmeticCap(state: Types.CosmeticState?, position: Vector3): Types.CapState?
	if not state then
		return nil
	end
	local localPosition = state.Frame:PointToObjectSpace(position)
	local height = localPosition.Y - state.Height
	if height < Config.MinHeight or height > Config.MaxHeight then
		return nil
	end
	local column = math.floor(localPosition.X / state.Pitch + 0.5)
	local row = math.floor(localPosition.Z / state.Pitch + 0.5)
	return state.Caps[Detection.GridKey(column, row)]
end

function Detection.FindCap(registry: Types.Registry, position: Vector3): Types.CapState?
	for _, state in registry.Plots do
		local base = getBase(state)
		local columns = state.Columns
		local rows = state.Rows
		if
			base
			and columns
			and rows
			and (position - base.CFrame.Position).Magnitude
				<= base.Size.Magnitude * 0.5 + Config.MaxHeight
		then
			local localPosition = base.CFrame:PointToObjectSpace(position)
			local height = localPosition.Y - (base.Size.Y / 2 + FloorGrid.CapHeight)
			if height >= Config.MinHeight and height <= Config.MaxHeight then
				local index = FloorGrid.IndexAt(columns, rows, localPosition.X, localPosition.Z)
				if index then
					return state.Caps[index]
				end
			end
		end
	end
	return findCosmeticCap(registry.Cosmetic, position)
end

return Detection
