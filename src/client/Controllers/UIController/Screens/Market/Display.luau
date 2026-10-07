--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharmConfig = require(ReplicatedStorage.Config.Charms)
local Eggs = require(ReplicatedStorage.Config.Eggs)
local Kit = require(script.Parent.Parent.Parent.Kit)

local barHeight = 84
local priceGap = 4
local priceIconSize = 34
local priceTextSize = 28

local Display = {
	BarHeight = barHeight,
}

local function percentText(chance: number): string
	local percent = chance * 100
	return if percent >= 10 or percent % 1 == 0
		then string.format("%d%%", math.floor(percent + 0.5))
		else string.format("%.1f%%", percent)
end

function Display.CenterPrice(face: Frame)
	local icon = face:FindFirstChild("Icon") :: GuiObject?
	local text = face:FindFirstChild("Text") :: TextLabel?
	if not (icon and text) then
		return
	end
	local holder = Instance.new("Frame")
	holder.Name = "Price"
	holder.BackgroundTransparency = 1
	holder.BorderSizePixel = 0
	holder.Position = UDim2.fromOffset(0, 2)
	holder.Size = UDim2.new(1, 0, 1, -4)
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, priceGap)
	list.Parent = holder
	icon.AnchorPoint = Vector2.zero
	icon.Position = UDim2.new()
	icon.Size = UDim2.fromOffset(priceIconSize, priceIconSize)
	icon.LayoutOrder = 1
	icon.Parent = holder
	text.Position = UDim2.new()
	text.Size = UDim2.fromScale(0, 1)
	text.AutomaticSize = Enum.AutomaticSize.X
	text.TextScaled = false
	text.TextSize = priceTextSize
	text.TextTruncate = Enum.TextTruncate.None
	text.LayoutOrder = 2
	text.Parent = holder
	holder.Parent = face
end

function Display.BuildDrops(bar: Frame, egg: Eggs.Egg)
	local panel = Instance.new("Frame")
	panel.Name = "Details"
	panel.BackgroundTransparency = 1
	panel.Position = UDim2.fromOffset(30, 0)
	panel.Size = UDim2.new(1, -46, 1, 0)
	panel.Parent = bar
	local total = 0
	local names: { string } = {}
	for _, weight in egg.Drops do
		total += weight
	end
	for _, rarity in CharmConfig.Rarities do
		if egg.Drops[rarity.Name] then
			table.insert(names, rarity.Name)
		end
	end
	local count = #names
	local gap = 6
	for index, name in names do
		local rarity = CharmConfig.RarityByName[name]
		local weight = egg.Drops[name]
		Kit.Chip({
			Parent = panel,
			Name = name,
			Text = `{name} {percentText(weight / total)}`,
			Size = UDim2.new(1 / count, -gap, 0, 30),
			Position = UDim2.new((index - 1) / count, 0, 0, barHeight + 6),
			Color = rarity.Color,
			TextSize = Kit.Text.Label,
		})
	end
	Kit.Label({
		Parent = panel,
		Name = "Description",
		Text = egg.Tagline,
		Position = UDim2.fromOffset(2, barHeight + 42),
		Size = UDim2.new(1, -2, 0, 24),
		TextSize = Kit.Text.Body,
		Subtle = true,
		Scaled = true,
	})
end

return Display
