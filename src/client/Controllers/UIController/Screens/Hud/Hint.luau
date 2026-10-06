--!strict

local Kit = require(script.Parent.Parent.Parent.Kit)
local Layout = require(script.Parent.Parent.Parent.HudLayout)
local Types = require(script.Parent.Types)

local Hint = {}

function Hint.Build(env: Types.Env, upgradesButton: Kit.Button): (isOn: boolean) -> ()
	local trove = env.Trove
	local root = env.Root
	local theme = Kit.Theme
	local margin = Layout.Margin
	local cell = Layout.Cell
	local menuWidth = Layout.MenuWidth
	local menuHeight = Layout.MenuHeight
	local hintX = margin + menuWidth + 18
	local hintY = -menuHeight / 2 + cell / 2
	local tooltip = Kit.Panel({
		Parent = root,
		Name = "Tooltip",
		Size = UDim2.fromOffset(270, 46),
		Position = UDim2.new(0, hintX, 0.5, hintY),
		AnchorPoint = Vector2.new(0, 0.5),
		Color = theme.Gold,
		Pill = true,
		Gloss = true,
	})
	tooltip.Visible = false
	Kit.Label({
		Parent = tooltip,
		Name = "Text",
		Text = "Buy your first upgrade!",
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 1, 0),
		TextSize = Kit.Text.Strong,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local bounce = Kit.Tween(tooltip, Kit.Motion.Throb, { Position = UDim2.new(0, hintX - 10, 0.5, hintY) })
	bounce:Pause()
	trove:Add(function()
		bounce:Cancel()
		bounce:Destroy()
	end)

	local isHinting = false
	local function setHinting(value: boolean)
		if value == isHinting then
			return
		end
		isHinting = value
		tooltip.Visible = value
		upgradesButton.SetGlow(value)
		if value then
			bounce:Play()
		else
			bounce:Pause()
		end
	end
	trove:Add(function()
		setHinting(false)
	end)
	return setHinting
end

return Hint
