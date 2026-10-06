--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Keys = require(ReplicatedStorage.Config.Keys)

local rarityRank: { [string]: number } = {}
for index, rarity in Keys.Rarities do
	rarityRank[rarity.Name] = index
end

local slotGap = 44

return table.freeze({
	CardHeight = 76,
	RowTop = 84,
	ChipHeight = 30,
	HolderHeight = 116,
	ChipGap = 8,
	ChipPad = 26,
	FacePad = 6,
	SlotMaxWidth = 440,
	SlotShare = 0.45,
	SlotGap = slotGap,
	BottomOffset = 160,
	MinWidth = 220,
	FadeSeconds = 0.25,
	FastFadeSeconds = 0.15,
	ConfettiCap = 30,
	Gravity = 1100,
	ModelSize = 88,
	ModelInset = 64,
	StaticYaw = 28,
	SpinSpeed = 70,
	BobHeight = 0.07,
	NameTextSize = 46,
	ChipTextSize = 20,
	BannerTextSize = 48,
	GlyphWidth = 0.6,
	White = Color3.new(1, 1, 1),
	SlotAnchor = table.freeze({ Center = 0.5, Left = 1, Right = 0 } :: { [string]: number }),
	SlotOffset = table.freeze({ Center = 0, Left = -slotGap, Right = slotGap } :: { [string]: number }),
	RarityRank = rarityRank,
	RareRank = rarityRank.Rare or 3,
	EpicRank = rarityRank.Epic or 4,
	LegendaryRank = rarityRank.Legendary or 5,
})
