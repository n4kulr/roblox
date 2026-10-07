--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local KeyTiers = require(ReplicatedStorage.Config.KeyTiers)
local Keys = require(ReplicatedStorage.Config.Keys)
local Variants = require(ReplicatedStorage.Rules.Variants)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Kit = require(script.Parent.Kit)

type TroveInstance = typeof(Trove.new())

export type CellProps = {
	Parent: Instance,
	Key: Keys.Key,
	KeyId: string?,
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
	StolenChip: Frame?,
	StolenLabel: TextLabel?,
	SetFound: (isFound: boolean, info: string, infoColor: Color3?) -> (),
}

local theme = Kit.Theme
local perkGlyphs: { [string]: string } = { Luck = "Luck", Speed = "Speed", Income = "Clicks" }
local pressInfo = Kit.Motion.Press
local springInfo = Kit.Motion.SpringQuick

local rarityRank: { [string]: number } = {}
for index, rarity in Keys.Rarities do
	rarityRank[rarity.Name] = index
end

local Cells = {
	Size = UDim2.fromOffset(124, 150),
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
		return string.sub(key.Name, 1, 1)
	end
	return string.sub(key.Name, 1, 1)
end

function Cells.PerkGlyph(key: Keys.Key): string?
	local perk = key.Perk
	if not perk then
		return nil
	end
	return perkGlyphs[perk.Kind]
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
	return `+{percent}% {label}`
end

function Cells.New(trove: TroveInstance, props: CellProps): Cell
	local key = props.Key
	local keyId = props.KeyId or key.Id
	local _, tier = KeyTiers.Parse(keyId)
	local tierInfo = KeyTiers.Get(tier)
	local rarity = Keys.GetRarity(key)
	local displayColor = if tier == 1
		then rarity.Color:Lerp(tierInfo.Color, 0.65)
		elseif tier == 3 then rarity.Color:Lerp(theme.Tier3Tint, 0.7)
		else rarity.Color
	local isSecret = rarity.Name == "Secret" or tier == 2
	local cell = Kit.Panel({
		Parent = props.Parent,
		Name = keyId,
		Size = Cells.Size,
		Color = displayColor,
		LayoutOrder = props.LayoutOrder,
		Shards = true,
		Radius = Kit.Radius.L,
	})
	cell.ClipsDescendants = true
	local paintGradient = cell:FindFirstChild("Paint") :: UIGradient
	paintGradient.Enabled = not isSecret
	if tier == 0 then
		Kit.RarityPaint(trove, cell, rarity.Name, rarity.Color, Kit.Radius.L)
	elseif tier == 2 then
		Kit.RarityPaint(trove, cell, "Secret", displayColor, Kit.Radius.L)
	else
		Kit.RarityPaint(trove, cell, if tier == 3 then "Mythic" else "Legendary", displayColor, Kit.Radius.L)
	end
	local rainbow = cell:FindFirstChild("Rainbow") :: UIGradient?
	local shimmer = cell:FindFirstChild("Shimmer") :: GuiObject?
	local isIncomeCard = props.HasChips == true
	Kit.Burst({
		Parent = cell,
		Diameter = if isIncomeCard then 90 else 112,
		Position = if isIncomeCard then UDim2.fromOffset(62, 34) else UDim2.fromOffset(62, 54),
		Color = displayColor,
	})
	local keycap = Kit.Keycap({
		Parent = cell,
		Color = displayColor,
		Glyph = Cells.Glyph(key),
		Size = if isIncomeCard then UDim2.fromOffset(48, 48) else UDim2.fromOffset(62, 62),
		Position = UDim2.new(0.5, 0, 0, if isIncomeCard then 10 else 22),
		AnchorPoint = Vector2.new(0.5, 0),
	})
	local nameLabel = Kit.Label({
		Parent = cell,
		Name = "Name",
		Text = Variants.Name(keyId),
		Position = UDim2.fromOffset(4, if isIncomeCard then 104 else 92),
		Size = UDim2.new(1, -8, 0, if isIncomeCard then 20 else 24),
		TextSize = if isIncomeCard then 16 else 19,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	local infoLabel = Kit.Label({
		Parent = cell,
		Name = "Info",
		Text = "",
		Position = UDim2.fromOffset(6, if isIncomeCard then 60 else 118),
		Size = UDim2.new(1, -12, 0, if isIncomeCard then 42 else 20),
		TextSize = if isIncomeCard then 29 else 16,
		Color = if isIncomeCard then theme.Good else theme.Text,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
		Title = isIncomeCard,
		StrokeSize = if isIncomeCard then 5 else nil,
	})
	local count: TextLabel? = nil
	local countChip: Frame? = nil
	local stolenChip: Frame? = nil
	local stolenLabel: TextLabel? = nil
	if props.HasChips == true then
		count = Kit.Chip({
			Parent = cell,
			Name = "Count",
			Text = "x1",
			Size = UDim2.fromOffset(40, 22),
			Position = UDim2.new(1, -4, 0, 4),
			AnchorPoint = Vector2.new(1, 0),
			Color = theme.Red,
			TextSize = Kit.Text.Small,
		})
		countChip = (count :: TextLabel).Parent :: Frame
		local stolen = Kit.Chip({
			Parent = cell,
			Name = "Stolen",
			Text = "",
			Size = UDim2.new(1, -8, 0, 18),
			Position = UDim2.fromOffset(4, 128),
			Color = theme.Orange,
			TextSize = Kit.Text.Tiny,
		})
		local stolenFrame = stolen.Parent :: Frame
		stolenFrame.Visible = false
		stolenChip = stolenFrame
		stolenLabel = stolen
	end
	if isIncomeCard and tier > 0 then
		Kit.Chip({
			Parent = cell,
			Name = "TierChip",
			Text = tierInfo.Chip,
			Size = UDim2.new(1, -8, 0, 18),
			Position = UDim2.fromOffset(4, 128),
			Color = if tier == 1 then Kit.Shade(tierInfo.Color, -0.25) else tierInfo.Color,
			TextSize = Kit.Text.Tiny,
		})
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
		hit.ZIndex = Kit.ZIndex.Badge
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
		StolenChip = stolenChip,
		StolenLabel = stolenLabel,
		SetFound = function(isFound: boolean, info: string, infoColor: Color3?)
			keycap.SetColor(if isFound then displayColor else theme.Unknown)
			if isFound then
				keycap.SetGlyph(Cells.Glyph(key))
			else
				keycap.SetGlyph("?", theme.Gold)
			end
			Kit.Paint(cell, if isFound then displayColor else Kit.Shade(theme.Unknown, -0.1))
			paintGradient.Enabled = not (isSecret and isFound)
			if rainbow then
				rainbow.Enabled = isFound
			end
			if shimmer then
				shimmer.Visible = isFound
			end
			nameLabel.Text = if isFound then Variants.Name(keyId) else "???"
			infoLabel.Text = info
			infoLabel.TextColor3 = infoColor or theme.Text
		end,
	}
end

return Cells
