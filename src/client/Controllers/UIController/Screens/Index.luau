--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Keys = require(ReplicatedStorage.Config.Keys)
local UiAssets = require(ReplicatedStorage.Config.UiAssets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Cells = require(script.Parent.Parent.Cells)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)

type Filter = {
	Rarity: Keys.Rarity,
	Button: Kit.Button,
}

local theme = Kit.Theme
local refreshSeconds = 0.2
local filterWidth = 124
local filterHeight = 44

local IndexScreen = {}

function IndexScreen.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local playUi = Kit.UiSound(context.Controllers)
	local cells: { [string]: Cells.Cell } = {}
	local filters: { Filter } = {}
	local discovered: { [string]: number } = {}
	local selected: string? = nil
	local isOpen = false
	local isDirty = true

	local modal = Kit.Modal(trove, {
		Parent = context.PlayerGui,
		Name = "Index",
		Title = "INDEX",
		Glyph = "Index",
		IconAsset = UiAssets.Icons.Index,
		MaxSize = Vector2.new(720, 560),
		HeaderColor = theme.Blue,
		OnClose = function()
			context.Close("Index")
		end,
		Sound = playUi,
	})
	local foundLabel = Kit.Label({
		Parent = modal.HeaderRight,
		Name = "Found",
		Text = "Found 0/0",
		Size = UDim2.fromOffset(190, 40),
		TextSize = 28,
		Color = theme.Gold,
		Align = Enum.TextXAlignment.Right,
		Scaled = true,
	})
	local grid = Kit.GridScroll({
		Parent = modal.Body,
		Name = "Grid",
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -(filterWidth + 26), 1, -12),
		CellSize = Cells.Size,
	})
	local column = Kit.Scroll({
		Parent = modal.Body,
		Name = "Filters",
		Position = UDim2.new(1, -(filterWidth + 10), 0, 6),
		AnchorPoint = Vector2.zero,
		Size = UDim2.new(0, filterWidth + 14, 1, -12),
		Padding = 6,
	})

	local function applyFilter()
		for _, filter in filters do
			local isSelected = selected == filter.Rarity.Name
			filter.Button.SetSelected(isSelected)
			filter.Button.SetColor(
				if selected == nil or isSelected
					then filter.Rarity.Color
					else Kit.Shade(filter.Rarity.Color, -0.45)
			)
		end
		for keyId, cell in cells do
			local key = Keys.ById[keyId]
			cell.Instance.Visible = selected == nil or key.Rarity == selected
		end
	end

	for order, rarity in Keys.Rarities do
		local button = Kit.Button(trove, {
			Parent = column,
			Name = rarity.Name,
			Text = rarity.Name,
			Size = UDim2.new(1, 0, 0, filterHeight),
			LayoutOrder = order,
			Color = rarity.Color,
			TextSize = 22,
			Callback = function()
				selected = if selected == rarity.Name then nil else rarity.Name
				applyFilter()
			end,
			Sound = playUi,
		})
		table.insert(filters, { Rarity = rarity, Button = button })
	end

	for rank, key in Cells.SortedCatalog(false) do
		cells[key.Id] = Cells.New(trove, {
			Parent = grid,
			Key = key,
			LayoutOrder = rank,
		})
	end

	local function refreshAll()
		isDirty = false
		local found = 0
		for keyId, cell in cells do
			local key = Keys.ById[keyId]
			if (discovered[keyId] or 0) > 0 then
				found += 1
				local rarity = Keys.GetRarity(key)
				cell.SetFound(true, `1 in {NumberFormat.Commas(rarity.Chance)}`, theme.TextDim)
			else
				cell.SetFound(false, key.Rarity, theme.TextDim)
			end
		end
		foundLabel.Text = `Found {found}/{#Keys.Catalog}`
	end

	trove:Add(context.Controllers.DataController:Observe({ "Discovered" }, function(value: any)
		local copy: { [string]: number } = {}
		if type(value) == "table" then
			for keyId, count in value do
				if type(keyId) == "string" and type(count) == "number" then
					copy[keyId] = count
				end
			end
		end
		discovered = copy
		isDirty = true
	end))

	local elapsed = 0
	trove:Connect(RunService.Heartbeat, function(dt: number)
		if not isOpen or not isDirty then
			return
		end
		elapsed += dt
		if elapsed >= refreshSeconds then
			elapsed = 0
			refreshAll()
		end
	end)
	refreshAll()

	return {
		Modal = true,
		StartsOpen = false,
		Open = function(_self: Types.Screen)
			isOpen = true
			refreshAll()
			modal.Show()
		end,
		Close = function(_self: Types.Screen)
			isOpen = false
			modal.Hide()
		end,
		Destroy = function(_self: Types.Screen)
			trove:Destroy()
		end,
	}
end

return IndexScreen
