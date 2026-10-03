--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Keys = require(ReplicatedStorage.Config.Keys)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Kit = require(script.Parent.Kit)

type TroveInstance = typeof(Trove.new())

export type CellProps = {
	Parent: Instance,
	Key: Keys.Key,
	LayoutOrder: number?,
	HasChips: boolean?,
	Callback: (() -> ())?,
	Sound: ((name: string) -> ())?,
}

export type Cell = {
	Instance: Frame,
	Keycap: Kit.Keycap,
	Name: TextLabel,
	Info: TextLabel,
	Count: TextLabel?,
	CountChip: Frame?,
	TagChip: Frame?,
	SetFound: (isFound: boolean, info: string, infoColor: Color3?) -> (),
}

local theme = Kit.Theme
local perkIcons: { [string]: string } = { Luck = "🍀", Speed = "⚡", Income = "💰" }
local pressInfo = TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local springInfo = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local unknownColor = Color3.fromRGB(122, 127, 138)

local rarityRank: { [string]: number } = {}
for index, rarity in Keys.Rarities do
	rarityRank[rarity.Name] = index
end

local Cells = {
	Size = UDim2.fromOffset(120, 140),
	RarityRank = rarityRank,
}

function Cells.SortedCatalog(isHighFirst: boolean): { Keys.Key }
	local sorted = table.clone(Keys.Catalog)
	table.sort(sorted, function(a: Keys.Key, b: Keys.Key)
		local rankA = rarityRank[a.Rarity]
		local rankB = rarityRank[b.Rarity]
		if rankA ~= rankB then
			if isHighFirst then
				return rankA > rankB
			end
			return rankA < rankB
		end
		return a.Index < b.Index
	end)
	return sorted
end

function Cells.Glyph(key: Keys.Key): string
	local perk = key.Perk
	if perk then
		return perkIcons[perk.Kind] or string.sub(key.Name, 1, 1)
	end
	return string.sub(key.Name, 1, 1)
end

function Cells.PerkText(key: Keys.Key): string?
	local perk = key.Perk
	if not perk then
		return nil
	end
	local percent = math.floor(perk.Amount * 100 + 0.5)
	local label = if perk.Kind == "Speed"
		then "Roll Speed"
		elseif perk.Kind == "Income" then "Clicks"
		else "Luck"
	return `{perkIcons[perk.Kind]} +{percent}% {label}`
end

function Cells.New(trove: TroveInstance, props: CellProps): Cell
	local key = props.Key
	local rarity = Keys.GetRarity(key)
	local cell = Kit.Panel({
		Parent = props.Parent,
		Name = key.Id,
		Size = Cells.Size,
		Color = theme.Cell,
		LayoutOrder = props.LayoutOrder,
	})
	Kit.Burst({
		Parent = cell,
		Diameter = 104,
		Position = UDim2.fromOffset(60, 58),
	})
	local keycap = Kit.Keycap({
		Parent = cell,
		Color = rarity.Color,
		Glyph = Cells.Glyph(key),
		Size = UDim2.fromOffset(62, 62),
		Position = UDim2.new(0.5, 0, 0, 26),
		AnchorPoint = Vector2.new(0.5, 0),
	})
	local strip = Instance.new("Frame")
	strip.Name = "Strip"
	strip.BorderSizePixel = 0
	strip.BackgroundColor3 = rarity.Color
	strip.Position = UDim2.new(0, 3, 1, -9)
	strip.Size = UDim2.new(1, -6, 0, 6)
	strip.Parent = cell
	local nameLabel = Kit.Label({
		Parent = cell,
		Name = "Name",
		Text = key.Name,
		Position = UDim2.fromOffset(4, 88),
		Size = UDim2.new(1, -8, 0, 22),
		TextSize = 18,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local infoLabel = Kit.Label({
		Parent = cell,
		Name = "Info",
		Text = "",
		Position = UDim2.fromOffset(4, 110),
		Size = UDim2.new(1, -8, 0, 18),
		TextSize = 15,
		Color = theme.Good,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local count: TextLabel? = nil
	local countChip: Frame? = nil
	local tagChip: Frame? = nil
	if props.HasChips == true then
		count = Kit.Chip({
			Parent = cell,
			Name = "Count",
			Text = "x1",
			Size = UDim2.fromOffset(40, 20),
			Position = UDim2.new(1, -4, 0, 4),
			AnchorPoint = Vector2.new(1, 0),
			Color = theme.Red,
			TextSize = 16,
		})
		countChip = (count :: TextLabel).Parent :: Frame
		local tag = Kit.Chip({
			Parent = cell,
			Name = "OnBoard",
			Text = "✓ ON BOARD",
			Size = UDim2.fromOffset(68, 18),
			Position = UDim2.fromOffset(4, 4),
			Color = theme.Green,
			TextSize = 12,
		})
		local tagFrame = tag.Parent :: Frame
		tagFrame.Visible = false
		tagChip = tagFrame
	end
	local callback = props.Callback
	if callback then
		local pressScale = Instance.new("UIScale")
		pressScale.Parent = cell
		local hit = Instance.new("TextButton")
		hit.Name = "Hit"
		hit.AutoButtonColor = false
		hit.BackgroundTransparency = 1
		hit.BorderSizePixel = 0
		hit.Text = ""
		hit.Size = UDim2.fromScale(1, 1)
		hit.ZIndex = 5
		hit.Parent = cell
		trove:Connect(hit.MouseButton1Down, function()
			Kit.Tween(pressScale, pressInfo, { Scale = 0.94 })
		end)
		trove:Connect(hit.MouseLeave, function()
			Kit.Tween(pressScale, springInfo, { Scale = 1 })
		end)
		trove:Connect(hit.Activated, function()
			Kit.Tween(pressScale, springInfo, { Scale = 1 })
			local sound = props.Sound
			if sound then
				sound("Click")
			end
			callback()
		end)
	end
	return {
		Instance = cell,
		Keycap = keycap,
		Name = nameLabel,
		Info = infoLabel,
		Count = count,
		CountChip = countChip,
		TagChip = tagChip,
		SetFound = function(isFound: boolean, info: string, infoColor: Color3?)
			keycap.SetColor(if isFound then rarity.Color else unknownColor)
			if isFound then
				keycap.SetGlyph(Cells.Glyph(key))
			else
				keycap.SetGlyph("?", theme.Gold)
			end
			strip.BackgroundColor3 = if isFound then rarity.Color else unknownColor
			nameLabel.Text = if isFound then key.Name else "???"
			infoLabel.Text = info
			infoLabel.TextColor3 = infoColor or theme.Good
		end,
	}
end

return Cells
