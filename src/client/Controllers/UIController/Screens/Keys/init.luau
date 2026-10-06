--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Keys = require(ReplicatedStorage.Config.Keys)
local KeyTiers = require(ReplicatedStorage.Config.KeyTiers)
local Packets = require(ReplicatedStorage.Packets)
local Variants = require(ReplicatedStorage.Rules.Variants)
local Trove = require(ReplicatedStorage.Packages.Trove)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Cells = require(script.Parent.Parent.Cells)
local Economy = require(script.Parent.Parent.Economy)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)
local Detail = require(script.Detail)
local Inventory = require(script.Inventory)
local Sort = require(script.Sort)

type Entry = {
	Id: string,
	Key: Keys.Key,
	Tier: number,
	Income: number,
	Rank: number,
	Name: string,
	Cell: Cells.Cell,
}

local theme = Kit.Theme
local gridShare = Detail.GridShare
local sortModes = Sort.Modes
local sortMode = 1

local KeysScreen = {}

function KeysScreen.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local dataController = context.Controllers.DataController
	local playUi = Kit.UiSound(context.Controllers)
	local entries: { [string]: Entry } = {}
	local inventory: { [string]: number } = {}
	local boardTags: { [number]: string } = {}
	local isOpen = false
	local isDirty = true
	local equipGuard = Kit.Request(trove)
	local tracker: Economy.Tracker

	local modal = Kit.Modal(trove, {
		Parent = context.PlayerGui,
		Name = "Keys",
		Title = "KEYS",
		Glyph = "Keys",
		MaxSize = Vector2.new(900, 640),
		HeaderColor = theme.Purple,
		OnClose = function()
			context.Close("Keys")
		end,
	})
	local body = modal.Body
	local refreshAll: () -> ()
	local sortButton = Kit.Button(trove, {
		Parent = modal.HeaderRight,
		Name = "Sort",
		Text = `SORT: {sortModes[sortMode]}`,
		Glyph = "Arrow",
		IconLeft = true,
		Size = UDim2.fromOffset(172, 46),
		Color = theme.Blue,
		TextSize = Kit.Text.Label,
		LayoutOrder = -1,
		Callback = function()
			sortMode = sortMode % #sortModes + 1
			refreshAll()
		end,
	})

	Kit.Button(trove, {
		Parent = modal.HeaderRight,
		Name = "EquipBest",
		Text = "EQUIP BEST",
		Glyph = "Sparkle",
		IconLeft = true,
		Size = UDim2.fromOffset(176, 46),
		Color = theme.Green,
		TextSize = Kit.Text.Label,
		Callback = function()
			if equipGuard.IsBusy() then
				return
			end
			equipGuard.Run(function()
				return Packets.EquipBest:Fire()
			end, function(isOk: boolean, success: any)
				if isOk and success == true then
					playUi("Confirm")
					context.Toast("Equipped your best keys!", "Good")
				else
					playUi("Error")
					context.Toast("Your keyboard is already the best!", "Info")
				end
			end)
		end,
	})

	local fullGridSize = UDim2.new(1, -12, 1, -12)
	local splitGridSize = UDim2.new(gridShare, -9, 1, -12)
	local grid = Kit.GridScroll({
		Parent = body,
		Name = "Grid",
		Position = UDim2.fromOffset(6, 6),
		Size = fullGridSize,
		CellSize = Cells.Size,
	})
	local emptyLabel = Kit.Label({
		Parent = body,
		Name = "Empty",
		Text = "No keys yet! Hit ROLL to find some!",
		Position = UDim2.new(0, 20, 0.5, -30),
		Size = UDim2.new(1, -40, 0, 60),
		TextSize = Kit.Text.Subhead,
		Align = Enum.TextXAlignment.Center,
		Wrapped = true,
	})

	local function setLayout(showDetail: boolean)
		Kit.Tween(grid, Kit.Motion.Base, {
			Size = if showDetail then splitGridSize else fullGridSize,
		})
	end

	local detail = Detail.Build({
		Trove = trove,
		Context = context,
		Parent = body,
		PlayUi = playUi,
		Spare = function(keyId: string): number
			return inventory[keyId] or 0
		end,
		OnBoard = function(keyId: string): number
			return Inventory.BoardCounts(tracker)[keyId] or 0
		end,
		SetLayout = setLayout,
		MarkDirty = function()
			isDirty = true
		end,
		RefreshAll = function()
			refreshAll()
		end,
	})

	local function ensureEntry(keyId: string): Entry?
		local existing = entries[keyId]
		if existing then
			return existing
		end
		local key = Keys.Resolve(keyId)
		if not key then
			return nil
		end
		local _, tier = KeyTiers.Parse(keyId)
		local cell = Cells.New(trove, {
			Parent = grid,
			Key = key,
			KeyId = keyId,
			LayoutOrder = 0,
			HasChips = true,
			Callback = function()
				detail.Open(keyId)
			end,
		})
		cell.Instance.Visible = false
		cell.Info.Text = `+{NumberFormat.Compact(Keys.GetIncome(keyId))}/s`
		local entry: Entry = {
			Id = keyId,
			Key = key,
			Tier = tier,
			Income = Keys.GetIncome(keyId),
			Rank = Cells.RarityRank[key.Rarity] or 1,
			Name = Variants.Name(keyId),
			Cell = cell,
		}
		entries[keyId] = entry
		return entry
	end

	function refreshAll()
		isDirty = false
		sortButton.SetText(`SORT: {sortModes[sortMode]}`)
		local onBoard = Inventory.BoardCounts(tracker)
		for keyId in inventory do
			ensureEntry(keyId)
		end
		for keyId in onBoard do
			ensureEntry(keyId)
		end
		local totals: { [string]: number } = {}
		for keyId in entries do
			totals[keyId] = (inventory[keyId] or 0) + (onBoard[keyId] or 0)
		end
		local list: { Sort.Entry } = {}
		for _, entry in entries do
			table.insert(list, entry)
		end
		Sort.Order(list, totals, sortModes[sortMode])
		for rank, entry in list do
			entries[entry.Id].Cell.Instance.LayoutOrder = rank
		end
		local tags = Inventory.StolenTags(tracker, boardTags)
		local ownedKinds = 0
		for keyId, entry in entries do
			local cell = entry.Cell
			local total = totals[keyId]
			cell.Instance.Visible = total > 0
			if total > 0 then
				ownedKinds += 1
				local count = cell.Count
				if count then
					count.Text = `x{total}`
				end
				local stolenChip = cell.StolenChip
				local stolenLabel = cell.StolenLabel
				if stolenChip and stolenLabel then
					local stolenFrom = tags[keyId]
					stolenChip.Visible = stolenFrom ~= nil
					if stolenFrom then
						stolenLabel.Text = `Stolen from {stolenFrom}`
					end
				end
			end
		end
		emptyLabel.Visible = ownedKinds == 0
		detail.Refresh()
	end

	local function markDirty()
		isDirty = true
	end
	tracker = Economy.For(context, trove, markDirty)
	trove:Add(dataController:Observe({ "Inventory" }, function(value: any)
		inventory = Inventory.ReadCounts(value)
		markDirty()
	end))

	trove:Add(dataController:Observe({ "BoardTags" }, function(value: any)
		boardTags = Inventory.ReadTags(value)
		markDirty()
	end))

	Kit.Poll(trove, 0, function()
		return isOpen and detail.Current() ~= nil
	end, function()
		detail.Spin(os.clock())
	end)
	Kit.Poll(trove, Kit.PollSeconds.Fast, function()
		return isOpen and isDirty
	end, refreshAll)
	refreshAll()

	return {
		Modal = true,
		StartsOpen = false,
		Open = function(_self: Types.Screen)
			isOpen = true
			detail.Close()
			refreshAll()
			modal.Show()
		end,
		Close = function(_self: Types.Screen)
			isOpen = false
			detail.Close()
			modal.Hide()
		end,
		Destroy = function(_self: Types.Screen)
			detail.Destroy()
			trove:Destroy()
		end,
	}
end

return KeysScreen
