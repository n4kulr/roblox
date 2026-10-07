--!strict

local Kit = require(script.Parent.Parent.Parent.Kit)
local Layout = require(script.Parent.Parent.Parent.HudLayout)
local Types = require(script.Parent.Types)

local StatChips = {}

function StatChips.Build(env: Types.Env): Types.StatLabels
	local trove = env.Trove
	local root = env.Root
	local theme = Kit.Theme
	local margin = Layout.Margin
	local statWidth = Layout.StatWidth
	local statHeight = Layout.StatHeight
	local statGap = Layout.StatGap
	local statsHeight = Layout.StatsHeight
	local stats = Instance.new("Frame")
	stats.Name = "Multipliers"
	stats.BackgroundTransparency = 1
	stats.AnchorPoint = Vector2.new(1, 1)
	stats.Position = UDim2.new(1, -margin, 1, -margin)
	stats.Size = UDim2.fromOffset(statWidth, statsHeight)
	local statList = Instance.new("UIListLayout")
	statList.SortOrder = Enum.SortOrder.LayoutOrder
	statList.HorizontalAlignment = Enum.HorizontalAlignment.Right
	statList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	statList.Padding = UDim.new(0, statGap)
	statList.Parent = stats
	stats.Parent = root
	local function statChip(
		name: string,
		caption: string,
		glyph: string,
		discColor: Color3,
		order: number,
		tip: string
	): TextLabel
		local pill = Kit.Pill({
			Parent = stats,
			Name = name,
			Glyph = glyph,
			Caption = caption,
			Text = "",
			DiscColor = discColor,
			Size = UDim2.fromOffset(statWidth - 10, statHeight),
			LayoutOrder = order,
			TextSize = Kit.Text.Title,
		})
		Kit.Tooltip(trove, pill.Instance, tip, "Left")
		return pill.Label
	end
	local statText: Types.StatLabels = {
		Luck = statChip("Luck", "LUCK", "Luck", theme.Green, 1, "Higher Luck finds rarer keys!"),
		Speed = statChip("Speed", "SPEED", "Speed", theme.Gold, 2, "Rolls you make every second!"),
		Income = statChip("Income", "CLICKS", "Clicks", theme.Orange, 3, "Multiplies your Clicks!"),
	}
	return statText
end

return StatChips
