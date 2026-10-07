--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Kit = require(script.Parent.Parent.Parent.Kit)
local Layout = require(script.Parent.Parent.Parent.HudLayout)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Types = require(script.Parent.Types)

local Currency = {}

function Currency.Build(env: Types.Env): Types.Currency
	local root = env.Root
	local theme = Kit.Theme
	local money = Kit.Panel({
		Parent = root,
		Name = "Currency",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, Layout.TabBarTop + Layout.TabBarHeight + Layout.ClicksGap),
		Size = UDim2.fromOffset(0, Layout.ClicksHeight),
		Color = theme.Track,
		Pill = true,
		Flat = true,
	})
	money.AutomaticSize = Enum.AutomaticSize.X
	local moneyRow = Instance.new("Frame")
	moneyRow.Name = "Row"
	moneyRow.BackgroundTransparency = 1
	moneyRow.BorderSizePixel = 0
	moneyRow.AutomaticSize = Enum.AutomaticSize.X
	moneyRow.Size = UDim2.fromOffset(0, Layout.ClicksHeight)
	moneyRow.Parent = money
	local moneyList = Instance.new("UIListLayout")
	moneyList.SortOrder = Enum.SortOrder.LayoutOrder
	moneyList.FillDirection = Enum.FillDirection.Horizontal
	moneyList.HorizontalAlignment = Enum.HorizontalAlignment.Left
	moneyList.VerticalAlignment = Enum.VerticalAlignment.Center
	moneyList.Padding = UDim.new(0, Kit.Space.S)
	moneyList.Parent = moneyRow
	local moneyPadding = Instance.new("UIPadding")
	moneyPadding.PaddingLeft = UDim.new(0, 10)
	moneyPadding.PaddingRight = UDim.new(0, 20)
	moneyPadding.Parent = moneyRow
	Kit.Icon({
		Parent = moneyRow,
		Name = "Coin",
		Size = UDim2.fromOffset(Layout.ClicksHeight - 10, Layout.ClicksHeight - 10),
		Glyph = "Clicks",
		LayoutOrder = 1,
	})
	local cashLabel = Kit.Label({
		Parent = moneyRow,
		Name = "Cash",
		Text = "...",
		Size = UDim2.fromOffset(0, Layout.ClicksHeight),
		TextSize = Kit.Text.Display,
		LayoutOrder = 2,
	})
	cashLabel.AutomaticSize = Enum.AutomaticSize.X
	cashLabel.TextTruncate = Enum.TextTruncate.None
	local cashCount = Kit.CountUp({ Label = cashLabel, Format = NumberFormat.Compact })
	local incomeLabel = Kit.Label({
		Parent = moneyRow,
		Name = "Income",
		Text = "",
		Size = UDim2.fromOffset(0, Layout.ClicksHeight),
		TextSize = Kit.Text.Label,
		Color = theme.Good,
		LayoutOrder = 3,
	})
	incomeLabel.AutomaticSize = Enum.AutomaticSize.X
	incomeLabel.TextTruncate = Enum.TextTruncate.None
	return { Cash = cashCount, Income = incomeLabel }
end

return Currency
