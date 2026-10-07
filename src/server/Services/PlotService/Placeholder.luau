--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local WorldNames = require(ReplicatedStorage.Config.WorldNames)
local Parts = require(ReplicatedStorage.Utils.Parts)

local Placeholder = {}

local function newPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	return Parts.New({
		Name = name,
		Parent = parent,
		Anchored = true,
		Size = size,
		CFrame = cframe,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
	})
end

function Placeholder.Build(folder: Folder)
	local count = GameConfig.PlotCount
	for index = 1, count do
		local angle = (index - 1) / count * math.pi * 2
		local position = Vector3.new(math.cos(angle) * 80, 0.5, math.sin(angle) * 80)
		local origin = CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
		local model = Instance.new("Model")
		model.Name = `Plot{index}`
		local base =
			newPart(model, WorldNames.Parts.Base, Vector3.new(44, 1, 44), origin, Color3.fromRGB(70, 74, 86))
		newPart(
			model,
			WorldNames.Parts.RollKey,
			Vector3.new(8, 3, 8),
			origin * CFrame.new(0, 2, -10),
			Color3.fromRGB(215, 215, 220)
		)
		newPart(
			model,
			"Board",
			Vector3.new(31, 1.5, 9.6),
			origin * CFrame.new(0, 1.25, 12),
			Color3.fromRGB(35, 36, 42)
		)
		model.PrimaryPart = base
		model.Parent = folder
	end
end

return Placeholder
