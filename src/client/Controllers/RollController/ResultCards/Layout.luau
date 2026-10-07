--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Keys = require(ReplicatedStorage.Config.Keys)
local Kit = require(script.Parent.Parent.Parent.UIController.Kit)
local ResultSlots = require(script.Parent.Parent.ResultSlots)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

type View = Types.View
type ResultCards = Types.ResultCards
local chipHeight = Config.ChipHeight
local holderHeight = Config.HolderHeight
local chipGap = Config.ChipGap
local chipPad = Config.ChipPad
local slotMaxWidth = Config.SlotMaxWidth
local slotShare = Config.SlotShare
local bottomOffset = Config.BottomOffset
local minWidth = Config.MinWidth
local nameTextSize = Config.NameTextSize
local chipTextSize = Config.ChipTextSize
local glyphWidth = Config.GlyphWidth
local legendaryRank = Config.LegendaryRank
local ink = Kit.Theme.Ink
local slotAnchor = Config.SlotAnchor
local slotOffset = Config.SlotOffset

local Layout = {}

function Layout.Estimate(text: string, size: number): number
	return #text * size * glyphWidth
end

function Layout.MaxWidth(self: ResultCards): number
	local scale = self._scale
	local virtualWidth = if scale and scale.Scale > 0 then self._gui.AbsoluteSize.X / scale.Scale else 1280
	if virtualWidth <= 0 then
		virtualWidth = 1280
	end
	return math.max(math.min(slotMaxWidth, slotShare * virtualWidth), 160)
end

function Layout.Place(view: View, slot: ResultSlots.Slot)
	view.Slot = slot
	view.Holder.AnchorPoint = Vector2.new(slotAnchor[slot], 1)
	view.Holder.Position = UDim2.new(0.5, slotOffset[slot], 1, -bottomOffset)
end

function Layout.PaintCard(view: View, rarity: Keys.Rarity, isGolden: boolean)
	local color = rarity.Color
	Kit.Paint(view.Card, color)
	Kit.Paint(view.Face, Kit.Shade(color, 0.12))
	Kit.Paint(view.RarityChip, Kit.Shade(color, -0.12))
	local stroke = Kit.StrokeOf(view.Card)
	stroke.Color = ink
	stroke.Thickness = 3
	view.GoldFrame.Visible = isGolden
end

function Layout.SizeCard(
	self: ResultCards,
	view: View,
	nameText: string,
	rarityText: string,
	incomeText: string
)
	local limit = Layout.MaxWidth(self)
	local nameWidth = Layout.Estimate(nameText, nameTextSize) + 40
	local rarityWidth = Layout.Estimate(rarityText, chipTextSize) + chipPad
	local incomeWidth = Layout.Estimate(incomeText, chipTextSize) + chipPad
	local rowWidth = rarityWidth + incomeWidth + chipGap
	local width = math.clamp(math.max(nameWidth, rowWidth, minWidth), minWidth, limit)
	local fit = math.min(1, width / rowWidth)
	view.Width = width
	view.Holder.Size = UDim2.fromOffset(width, holderHeight)
	view.RarityChip.Size = UDim2.fromOffset(math.floor(rarityWidth * fit), chipHeight)
	view.IncomeChip.Size = UDim2.fromOffset(math.floor(incomeWidth * fit), chipHeight)
end

function Layout.BannerText(rarity: Keys.Rarity, rank: number, isGolden: boolean, isCentered: boolean): string?
	if rank >= legendaryRank then
		local text = `{string.upper(rarity.Name)}!`
		return if isGolden then `GOLDEN {text}` else text
	end
	if isGolden and isCentered then
		return "GOLDEN!"
	end
	return nil
end

return Layout
