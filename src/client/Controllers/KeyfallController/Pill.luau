--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Kit = require(script.Parent.Parent.UIController.Kit)

type TroveInstance = typeof(Trove.new())

local rollHeight = 98
local bottomMargin = 14
local gap = 8

local Pill = {}

function Pill.Build(trove: TroveInstance, root: Frame): (count: number) -> ()
	local panel = Kit.Panel({
		Parent = root,
		Name = "KeyfallPill",
		Size = UDim2.fromOffset(250, 38),
		Position = UDim2.new(0.5, 0, 1, -(bottomMargin + rollHeight + gap)),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = Kit.Theme.Gold,
		Radius = 8,
		StrokeThickness = 2.5,
		Bevel = false,
	})
	panel.Visible = false
	local label = Kit.Label({
		Parent = panel,
		Name = "Text",
		Text = "",
		Size = UDim2.fromScale(1, 1),
		TextSize = 22,
		Color = Kit.Theme.TextInk,
		Outline = false,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	trove:Add(panel)
	return function(count: number)
		panel.Visible = count > 0
		label.Text = `{count}/{GameConfig.Keyfall.CarryLimit}  run home!`
	end
end

return Pill
