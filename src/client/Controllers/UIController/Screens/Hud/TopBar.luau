--!strict

local Kit = require(script.Parent.Parent.Parent.Kit)
local Layout = require(script.Parent.Parent.Parent.HudLayout)
local Types = require(script.Parent.Types)

local TopBar = {}

function TopBar.Build(env: Types.Env): Kit.Button
	local trove = env.Trove
	local root = env.Root
	local context = env.Context
	local rollController = env.RollController
	local theme = Kit.Theme
	local topButtonWidth = Layout.TopButtonWidth
	local topGap = Layout.TopGap
	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.BackgroundTransparency = 1
	topBar.AnchorPoint = Vector2.new(0.5, 0)
	topBar.Position = UDim2.new(0.5, 0, 0, Layout.TabBarTop)
	topBar.Size = UDim2.fromOffset(topButtonWidth * 2 + topGap, Layout.TabBarHeight)
	topBar.Parent = root
	local function jumpButton(
		name: string,
		glyph: string,
		label: string,
		color: Color3,
		x: number,
		go: () -> (boolean, string?)
	): Kit.Button
		return Kit.Button(trove, {
			Parent = topBar,
			Name = name,
			Glyph = glyph,
			IconLeft = true,
			Text = label,
			Size = UDim2.fromOffset(topButtonWidth, Layout.TabBarHeight),
			Position = UDim2.fromOffset(x, 0),
			Color = color,
			TextSize = Kit.Text.Heading,
			Pill = true,
			Callback = function()
				local ok, reason = go()
				if not ok then
					context.Toast(reason or "You can't go there right now!", "Bad")
				end
			end,
		})
	end
	jumpButton("Shop", "Shop", "SHOP", theme.Orange, 0, function()
		return rollController:TeleportToMarket()
	end)
	local myBaseButton = jumpButton("MyBase", "Home", "BASE", theme.Blue, topButtonWidth + topGap, function()
		return rollController:TeleportToBase()
	end)
	return myBaseButton
end

return TopBar
