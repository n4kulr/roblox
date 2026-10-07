--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Charms = require(ReplicatedStorage.Config.Charms)
local Eggs = require(ReplicatedStorage.Config.Eggs)
local Keys = require(ReplicatedStorage.Config.Keys)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Kit = require(script.Parent.Parent.Parent.Kit)
local Widgets = require(script.Parent.Widgets)

type Page = Widgets.Page

export type Env = {
	Trove: typeof(Trove.new()),
	Tabs: Frame,
	Area: Frame,
	Select: (name: string) -> (),
	Send: (command: string, args: string) -> (),
	SetStatus: (text: string) -> (),
	PlayUi: (name: string) -> (),
}

export type Built = {
	Pages: { Page },
}

local style = Widgets.Style
local palette = Widgets.Palette
local newLabel = Widgets.NewLabel
local newButton = Widgets.NewButton
local newBox = Widgets.NewBox

local gap = style.Gap
local rowHeight = style.RowHeight
local sectionHeight = style.SectionHeight
local scrollBarThickness = style.ScrollBarThickness
local smallTextSize = style.SmallTextSize
local defaultCount = style.DefaultCount
local confirmSeconds = style.ConfirmSeconds
local confirmText = style.ConfirmText
local amountPrompt = style.AmountPrompt
local tabNames = style.TabNames

local Pages = {}

function Pages.Build(env: Env): Built
	local trove = env.Trove
	local tabStrip = env.Tabs
	local area = env.Area
	local pages: { Page } = {}
	local countBox: TextBox? = nil
	local function addPage(name: string): Page
		local scroll = Instance.new("ScrollingFrame")
		scroll.Name = `Page{name}`
		scroll.BackgroundTransparency = 1
		scroll.BorderSizePixel = 0
		scroll.Size = UDim2.fromScale(1, 1)
		scroll.CanvasSize = UDim2.new()
		scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
		scroll.ScrollBarThickness = scrollBarThickness
		scroll.ScrollBarImageColor3 = palette.Stroke
		scroll.ScrollingDirection = Enum.ScrollingDirection.Y
		scroll.Visible = false
		scroll.Parent = area
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, gap)
		layout.Parent = scroll
		local inset = Instance.new("UIPadding")
		inset.PaddingRight = UDim.new(0, scrollBarThickness + 2)
		inset.Parent = scroll
		local tab = newButton(tabStrip, `Tab{name}`, name, palette.Button)
		tab.TextColor3 = palette.Dim
		tab.LayoutOrder = #pages + 1
		tab.Size = UDim2.new(1 / #tabNames, -gap * (#tabNames - 1) / #tabNames, 1, 0)
		trove:Connect(tab.Activated, function()
			env.Select(name)
		end)
		local page: Page = { Name = name, Scroll = scroll, Tab = tab, Order = 0 }
		table.insert(pages, page)
		return page
	end

	local function addSection(page: Page, text: string)
		page.Order += 1
		local label = newLabel(page.Scroll, `Section{string.gsub(text, "%W", "")}`, `-- {text}`, palette.Dim)
		label.TextSize = smallTextSize
		label.Size = UDim2.new(1, 0, 0, sectionHeight)
		label.LayoutOrder = page.Order
	end

	local function addGrid(page: Page, columns: number): Frame
		page.Order += 1
		local grid = Instance.new("Frame")
		grid.Name = `Grid{page.Name}{page.Order}`
		grid.BackgroundTransparency = 1
		grid.BorderSizePixel = 0
		grid.AutomaticSize = Enum.AutomaticSize.Y
		grid.Size = UDim2.new(1, 0, 0, 0)
		grid.LayoutOrder = page.Order
		local layout = Instance.new("UIGridLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.CellSize = UDim2.new(1 / columns, -math.ceil(gap * (columns - 1) / columns), 0, rowHeight)
		layout.CellPadding = UDim2.fromOffset(gap, gap)
		layout.Parent = grid
		grid.Parent = page.Scroll
		return grid
	end

	local function addAction(
		grid: Frame,
		name: string,
		text: string,
		callback: () -> (),
		textColor: Color3?
	): TextButton
		local button = newButton(grid, name, text, palette.Button)
		if textColor then
			button.TextColor3 = textColor
		end
		trove:Connect(button.MouseEnter, function()
			button.BackgroundColor3 = palette.Hover
		end)
		trove:Connect(button.MouseLeave, function()
			button.BackgroundColor3 = palette.Button
		end)
		trove:Connect(button.Activated, callback)
		return button
	end

	local function command(grid: Frame, name: string, text: string, cmd: string, args: string)
		addAction(grid, name, text, function()
			env.Send(cmd, args)
		end, nil)
	end

	local function readCount(): string
		local box = countBox
		local text = if box then (string.gsub(box.Text, "%s", "")) else ""
		return if text == "" then defaultCount else text
	end

	local money = addPage(tabNames[1])
	local progress = addPage(tabNames[2])
	local items = addPage(tabNames[3])
	local danger = addPage(tabNames[4])

	addSection(money, "ADD")
	local moneyGrid = addGrid(money, 4)
	command(moneyGrid, "Money1K", "+1K", "money", "1k")
	command(moneyGrid, "Money1M", "+1M", "money", "1m")
	command(moneyGrid, "Money1B", "+1B", "money", "1b")
	command(moneyGrid, "Money1T", "+1T", "money", "1t")
	addSection(money, "SET")
	local setGrid = addGrid(money, 2)
	command(setGrid, "MaxMoney", "MAX", "maxmoney", "")
	command(setGrid, "ResetMoney", "RESET", "resetmoney", "")
	addSection(money, "CUSTOM")
	local customRow = addGrid(money, 1)
	customRow.Name = "CustomAmount"
	local customHolder = Instance.new("Frame")
	customHolder.Name = "Holder"
	customHolder.BackgroundTransparency = 1
	customHolder.BorderSizePixel = 0
	customHolder.Size = UDim2.fromScale(1, 1)
	customHolder.Parent = customRow
	local amount = newBox(customHolder, "AmountInput", "amount (2.5m)", "")
	amount.Size = UDim2.new(0.5, -gap, 1, 0)
	local function amountText(): string?
		local text = (string.gsub(amount.Text, "%s", ""))
		if text == "" then
			env.PlayUi("Error")
			env.SetStatus(amountPrompt)
			return nil
		end
		return text
	end
	local addAmount = newButton(customHolder, "AddAmount", "ADD", palette.Button)
	addAmount.Position = UDim2.fromScale(0.5, 0)
	addAmount.Size = UDim2.new(0.25, -gap, 1, 0)
	trove:Connect(addAmount.Activated, function()
		local text = amountText()
		if text then
			env.Send("money", text)
		end
	end)
	local setAmount = newButton(customHolder, "SetAmount", "SET", palette.Button)
	setAmount.Position = UDim2.fromScale(0.75, 0)
	setAmount.Size = UDim2.new(0.25, 0, 1, 0)
	trove:Connect(setAmount.Activated, function()
		local text = amountText()
		if text then
			env.Send("setmoney", text)
		end
	end)

	addSection(progress, "PROGRESS")
	local progressGrid = addGrid(progress, 2)
	command(progressGrid, "Rolls100", "+100 rolls", "rolls", "100")
	command(progressGrid, "NextGolden", "next golden", "golden", "")
	command(progressGrid, "Income1h", "+1h income", "income", "3600")
	command(progressGrid, "ForceRebirth", "force rebirth", "rebirth", "")
	command(progressGrid, "MaxUpgrades", "max upgrades", "maxupgrades", "")
	command(progressGrid, "ResetUpgrades", "reset upgrades", "resetupgrades", "")
	addSection(progress, "BOOSTS")
	local boostGrid = addGrid(progress, 2)
	command(boostGrid, "LuckPotion", "luck 10m", "luckpotion", "10")
	command(boostGrid, "ClicksPotion", "clicks 10m", "clickspotion", "10")

	addSection(items, "COUNT")
	local countRow = addGrid(items, 1)
	countRow.Name = "CountRow"
	local count = newBox(countRow, "CountInput", "count", defaultCount)
	count.Size = UDim2.new(0.5, -gap, 1, 0)
	countBox = count
	addSection(items, "EGGS")
	local eggReady = addGrid(items, 2)
	command(eggReady, "ReadyEggs", "ready eggs", "readyeggs", "")
	command(eggReady, "HatchAll", "hatch all", "hatchall", "")
	addSection(items, "KEYS BY RARITY")
	local rarityGrid = addGrid(items, 3)
	for _, rarity in Keys.Rarities do
		addAction(rarityGrid, `GiveRarity{rarity.Name}`, string.lower(rarity.Name), function()
			env.Send("givekey", `{rarity.Name} {readCount()}`)
		end, rarity.Color:Lerp(palette.Text, 0.35))
	end
	addSection(items, "KEYS")
	local keyGrid = addGrid(items, 2)
	for _, key in Keys.Catalog do
		addAction(keyGrid, `GiveKey{key.Id}`, key.Name, function()
			env.Send("givekey", `{key.Id} {readCount()}`)
		end, nil)
	end
	addSection(items, "EGG ITEMS")
	local eggGrid = addGrid(items, 2)
	for _, egg in Eggs.Catalog do
		addAction(eggGrid, `GiveEgg{egg.Id}`, egg.Name, function()
			env.Send("giveegg", `{egg.Id} {readCount()}`)
		end, nil)
	end
	addSection(items, "PETS")
	local petGrid = addGrid(items, 2)
	for _, charm in Charms.Catalog do
		addAction(petGrid, `GivePet{charm.Id}`, charm.Name, function()
			env.Send("givepet", `{charm.Id} {readCount()}`)
		end, nil)
	end

	addSection(danger, "DANGER (press twice)")
	local dangerGrid = addGrid(danger, 2)
	local function addConfirmed(name: string, label: string, cmd: string, args: string)
		local button: TextButton? = nil
		local confirm = Kit.Confirm(trove, confirmSeconds, function(isArmed: boolean)
			local face = button :: TextButton
			face.Text = if isArmed then confirmText else label
		end)
		button = addAction(dangerGrid, name, label, function()
			confirm.Press(true, function()
				(button :: TextButton).Text = label
				env.Send(cmd, args)
			end)
		end, palette.Warn)
	end
	addConfirmed("ResetData", "reset data", "resetdata", "confirm")
	addConfirmed("RemovePets", "remove all pets", "removepets", "")

	return { Pages = pages }
end

return Pages
