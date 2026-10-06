--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Charms = require(ReplicatedStorage.Config.Charms)
local Eggs = require(ReplicatedStorage.Config.Eggs)
local Keys = require(ReplicatedStorage.Config.Keys)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)

type TroveInstance = typeof(Trove.new())
type Page = { Name: string, Scroll: ScrollingFrame, Tab: TextButton, Order: number }

local developerAttribute = "IsDeveloper"
local confirmSeconds = 3
local confirmText = "CONFIRM?"
local displayOrder = Kit.Layer.Debug
local windowWidth = 300
local minWindowWidth = 240
local minWindowHeight = 180
local screenMargin = 16
local gripSize = 14
local edgeThickness = 6
local gripLineLength = 10
local gripLineThickness = 1
local titleHeight = 24
local pad = 4
local inputHeight = 22
local tabHeight = 20
local defaultPageHeight = 236
local statusHeight = 18
local rowHeight = 22
local sectionHeight = 14
local gap = 4
local textSize = 13
local smallTextSize = 12
local radius = 4
local strokeThickness = 1
local scrollBarThickness = 3
local fieldInset = 6
local backgroundTransparency = 0.06
local startLeft = 220
local startTop = 96
local minVisible = 40
local defaultCount = "1"
local defaultStatus = "ready"
local noResponseText = "No response"
local amountPrompt = "Enter an amount"
local errorPrefixes = { "Not allowed", "No response", "Bad", "Usage", "Unknown", "Enter" }
local tabNames = { "MONEY", "PROGRESS", "ITEMS", "DANGER" }
local font = Enum.Font.Code

local palette = {
	Background = Color3.fromRGB(14, 15, 18),
	Bar = Color3.fromRGB(24, 25, 30),
	Stroke = Color3.fromRGB(58, 60, 68),
	Button = Color3.fromRGB(34, 36, 43),
	Hover = Color3.fromRGB(48, 51, 60),
	Selected = Color3.fromRGB(62, 66, 78),
	Field = Color3.fromRGB(10, 11, 13),
	Text = Color3.fromRGB(208, 212, 220),
	Dim = Color3.fromRGB(128, 133, 144),
	Good = Color3.fromRGB(122, 190, 140),
	Bad = Color3.fromRGB(214, 112, 112),
	Warn = Color3.fromRGB(196, 150, 86),
}

local CheatsScreen = {}

local function trim(text: string): string
	return (string.gsub(text, "^%s*(.-)%s*$", "%1"))
end

local function isError(text: string): boolean
	for _, prefix in errorPrefixes do
		if string.sub(text, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local function round(target: Instance)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = target
end

local function outline(target: Instance)
	local stroke = Instance.new("UIStroke")
	stroke.Color = palette.Stroke
	stroke.Thickness = strokeThickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = target
end

local function newLabel(parent: Instance, name: string, text: string, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = font
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = text
	label.Parent = parent
	return label
end

local function newButton(parent: Instance, name: string, text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = false
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Font = font
	button.TextSize = smallTextSize
	button.TextColor3 = palette.Text
	button.TextTruncate = Enum.TextTruncate.AtEnd
	button.Text = text
	button.Parent = parent
	round(button)
	return button
end

local function newBox(parent: Instance, name: string, placeholder: string, text: string): TextBox
	local box = Instance.new("TextBox")
	box.Name = name
	box.BackgroundColor3 = palette.Field
	box.BorderSizePixel = 0
	box.Font = font
	box.TextSize = smallTextSize
	box.TextColor3 = palette.Text
	box.PlaceholderText = placeholder
	box.PlaceholderColor3 = palette.Dim
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.ClearTextOnFocus = false
	box.Text = text
	box.Parent = parent
	round(box)
	outline(box)
	local inset = Instance.new("UIPadding")
	inset.PaddingLeft = UDim.new(0, fieldInset)
	inset.PaddingRight = UDim.new(0, fieldInset)
	inset.Parent = box
	return box
end

function CheatsScreen.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local localPlayer = Players.LocalPlayer
	local playUi = Kit.UiSound(context.Controllers)
	local panelTrove: TroveInstance? = nil
	local gui: ScreenGui? = nil
	local panel: Frame? = nil
	local content: Frame? = nil
	local rootFrame: Frame? = nil
	local statusLabel: TextLabel? = nil
	local targetBox: TextBox? = nil
	local countBox: TextBox? = nil
	local pages: { Page } = {}
	local position: Vector2? = nil
	local windowSize: Vector2? = nil
	local resizeHandles: { GuiObject } = {}
	local isBusy = false
	local isMinimized = false

	local function isDeveloper(): boolean
		return localPlayer ~= nil and localPlayer:GetAttribute(developerAttribute) == true
	end

	local function setStatus(text: string)
		local label = statusLabel
		if not label then
			return
		end
		label.Text = text
		label.TextColor3 = if isError(text) then palette.Bad else palette.Good
	end

	local function send(command: string, args: string)
		if isBusy then
			return
		end
		isBusy = true
		task.spawn(function()
			local suffix = if targetBox then trim(targetBox.Text) else ""
			local argument = args
			if suffix ~= "" then
				argument = if args == "" then suffix else `{args} {suffix}`
			end
			local result = Packets.AdminCommand:Fire(command, argument)
			isBusy = false
			if type(result) ~= "string" or result == "" then
				playUi("Error")
				setStatus(noResponseText)
				return
			end
			playUi(if isError(result) then "Error" else "Confirm")
			setStatus(result)
		end)
	end

	local function viewScale(): number
		local root = rootFrame
		local scale = if root then root:FindFirstChild("ViewportScale") else nil
		if scale and scale:IsA("UIScale") and scale.Scale > 0 then
			return scale.Scale
		end
		return 1
	end

	local function placeAt(target: Vector2)
		local window = panel
		local root = rootFrame
		if not window or not root then
			return
		end
		local size = root.AbsoluteSize / viewScale()
		local height = window.Size.Y.Offset
		local width = window.Size.X.Offset
		local clamped = Vector2.new(
			math.clamp(target.X, minVisible - width, math.max(size.X - minVisible, 0)),
			math.clamp(target.Y, 0, math.max(size.Y - math.min(height, titleHeight + minVisible), 0))
		)
		position = clamped
		window.Position = UDim2.fromOffset(clamped.X, clamped.Y)
	end

	local function selectPage(name: string)
		for _, page in pages do
			local isActive = page.Name == name
			page.Scroll.Visible = isActive
			page.Tab.BackgroundColor3 = if isActive then palette.Selected else palette.Button
			page.Tab.TextColor3 = if isActive then palette.Text else palette.Dim
		end
	end

	local function applyLayout()
		local window = panel
		local body = content
		local current = windowSize
		if not window or not body or not current then
			return
		end
		body.Visible = not isMinimized
		for _, handle in resizeHandles do
			handle.Visible = not isMinimized
		end
		local height = if isMinimized then titleHeight else current.Y
		window.Size = UDim2.fromOffset(current.X, height)
	end

	local function sizeLimits(): (Vector2, Vector2)
		local root = rootFrame
		local screen = if root then root.AbsoluteSize / viewScale() else Vector2.zero
		local minimum = Vector2.new(minWindowWidth, minWindowHeight)
		local maximum = Vector2.new(
			math.max(screen.X - 2 * screenMargin, minimum.X),
			math.max(screen.Y - 2 * screenMargin, minimum.Y)
		)
		return minimum, maximum
	end

	local function resizeTo(target: Vector2)
		local minimum, maximum = sizeLimits()
		windowSize = Vector2.new(
			math.clamp(target.X, minimum.X, maximum.X),
			math.clamp(target.Y, minimum.Y, maximum.Y)
		)
		applyLayout()
		local current = position
		if current then
			placeAt(current)
		end
	end

	local function build()
		local own = Trove.new()
		panelTrove = own
		local screenGui, root = Kit.ScreenGui("ThockCheats", displayOrder, context.PlayerGui, own, true)
		gui = screenGui
		rootFrame = root
		screenGui.Enabled = false

		local pagesTop = pad + inputHeight + gap + tabHeight + gap
		local pagesBottom = gap + statusHeight + pad
		local contentHeight = pagesTop + defaultPageHeight + pagesBottom
		windowSize = windowSize or Vector2.new(windowWidth, titleHeight + contentHeight)
		local initial = windowSize :: Vector2
		local window = Instance.new("Frame")
		window.Name = "Window"
		window.Active = true
		window.BackgroundColor3 = palette.Background
		window.BackgroundTransparency = backgroundTransparency
		window.BorderSizePixel = 0
		window.Size = UDim2.fromOffset(initial.X, initial.Y)
		window.Parent = root
		round(window)
		outline(window)
		panel = window

		local titleBar = Instance.new("Frame")
		titleBar.Name = "TitleBar"
		titleBar.BackgroundColor3 = palette.Bar
		titleBar.BorderSizePixel = 0
		titleBar.Size = UDim2.new(1, 0, 0, titleHeight)
		titleBar.Parent = window
		round(titleBar)
		local title = newLabel(titleBar, "Title", "THOCK DEV", palette.Text)
		title.Position = UDim2.fromOffset(8, 0)
		title.Size = UDim2.new(1, -(2 * titleHeight + 8), 1, 0)

		local closeButton = newButton(titleBar, "Close", "x", palette.Bar)
		closeButton.Position = UDim2.new(1, -titleHeight, 0, 0)
		closeButton.Size = UDim2.fromOffset(titleHeight, titleHeight)
		closeButton.TextColor3 = palette.Bad
		own:Connect(closeButton.Activated, function()
			context.Close("Cheats")
		end)
		table.clear(resizeHandles)
		local minimizeButton = newButton(titleBar, "Minimize", "-", palette.Bar)
		minimizeButton.Position = UDim2.new(1, -2 * titleHeight, 0, 0)
		minimizeButton.Size = UDim2.fromOffset(titleHeight, titleHeight)
		own:Connect(minimizeButton.Activated, function()
			isMinimized = not isMinimized
			minimizeButton.Text = if isMinimized then "+" else "-"
			applyLayout()
		end)

		local body = Instance.new("Frame")
		body.Name = "Content"
		body.BackgroundTransparency = 1
		body.BorderSizePixel = 0
		body.Position = UDim2.fromOffset(0, titleHeight)
		body.Size = UDim2.new(1, 0, 1, -titleHeight)
		body.Parent = window
		content = body

		local target = newBox(body, "TargetInput", "target: blank = me | name | all", "")
		target.Position = UDim2.fromOffset(pad, pad)
		target.Size = UDim2.new(1, -2 * pad, 0, inputHeight)
		targetBox = target

		local tabStrip = Instance.new("Frame")
		tabStrip.Name = "Tabs"
		tabStrip.BackgroundTransparency = 1
		tabStrip.BorderSizePixel = 0
		tabStrip.Position = UDim2.fromOffset(pad, pad + inputHeight + gap)
		tabStrip.Size = UDim2.new(1, -2 * pad, 0, tabHeight)
		tabStrip.Parent = body
		local tabLayout = Instance.new("UIListLayout")
		tabLayout.FillDirection = Enum.FillDirection.Horizontal
		tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
		tabLayout.Padding = UDim.new(0, gap)
		tabLayout.Parent = tabStrip

		local area = Instance.new("Frame")
		area.Name = "Pages"
		area.BackgroundTransparency = 1
		area.BorderSizePixel = 0
		area.Position = UDim2.fromOffset(pad, pagesTop)
		area.Size = UDim2.new(1, -2 * pad, 1, -(pagesTop + pagesBottom))
		area.Parent = body

		local status = newLabel(body, "Status", defaultStatus, palette.Dim)
		status.TextSize = smallTextSize
		status.Position = UDim2.new(0, pad + 2, 1, -(pad + statusHeight))
		status.Size = UDim2.new(1, -2 * pad - 4 - gripSize, 0, statusHeight)
		statusLabel = status

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
			own:Connect(tab.Activated, function()
				selectPage(name)
			end)
			local page: Page = { Name = name, Scroll = scroll, Tab = tab, Order = 0 }
			table.insert(pages, page)
			return page
		end

		local function addSection(page: Page, text: string)
			page.Order += 1
			local label =
				newLabel(page.Scroll, `Section{string.gsub(text, "%W", "")}`, `-- {text}`, palette.Dim)
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
			layout.CellSize = UDim2.new(1 / columns, -gap * (columns - 1) / columns, 0, rowHeight)
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
			own:Connect(button.MouseEnter, function()
				button.BackgroundColor3 = palette.Hover
			end)
			own:Connect(button.MouseLeave, function()
				button.BackgroundColor3 = palette.Button
			end)
			own:Connect(button.Activated, callback)
			return button
		end

		local function command(grid: Frame, name: string, text: string, cmd: string, args: string)
			addAction(grid, name, text, function()
				send(cmd, args)
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
				playUi("Error")
				setStatus(amountPrompt)
				return nil
			end
			return text
		end
		local addAmount = newButton(customHolder, "AddAmount", "ADD", palette.Button)
		addAmount.Position = UDim2.fromScale(0.5, 0)
		addAmount.Size = UDim2.new(0.25, -gap, 1, 0)
		own:Connect(addAmount.Activated, function()
			local text = amountText()
			if text then
				send("money", text)
			end
		end)
		local setAmount = newButton(customHolder, "SetAmount", "SET", palette.Button)
		setAmount.Position = UDim2.fromScale(0.75, 0)
		setAmount.Size = UDim2.new(0.25, 0, 1, 0)
		own:Connect(setAmount.Activated, function()
			local text = amountText()
			if text then
				send("setmoney", text)
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
				send("givekey", `{rarity.Name} {readCount()}`)
			end, rarity.Color:Lerp(palette.Text, 0.35))
		end
		addSection(items, "KEYS")
		local keyGrid = addGrid(items, 2)
		for _, key in Keys.Catalog do
			addAction(keyGrid, `GiveKey{key.Id}`, key.Name, function()
				send("givekey", `{key.Id} {readCount()}`)
			end, nil)
		end
		addSection(items, "EGG ITEMS")
		local eggGrid = addGrid(items, 2)
		for _, egg in Eggs.Catalog do
			addAction(eggGrid, `GiveEgg{egg.Id}`, egg.Name, function()
				send("giveegg", `{egg.Id} {readCount()}`)
			end, nil)
		end
		addSection(items, "PETS")
		local petGrid = addGrid(items, 2)
		for _, charm in Charms.Catalog do
			addAction(petGrid, `GivePet{charm.Id}`, charm.Name, function()
				send("givepet", `{charm.Id} {readCount()}`)
			end, nil)
		end

		addSection(danger, "DANGER (press twice)")
		local dangerGrid = addGrid(danger, 2)
		local function addConfirmed(name: string, label: string, cmd: string, args: string)
			local armed = false
			local armToken = 0
			local button: TextButton? = nil
			button = addAction(dangerGrid, name, label, function()
				local face = button :: TextButton
				if not armed then
					armed = true
					armToken += 1
					local mine = armToken
					face.Text = confirmText
					task.delay(confirmSeconds, function()
						if armed and armToken == mine then
							armed = false
							face.Text = label
						end
					end)
					return
				end
				armed = false
				armToken += 1
				face.Text = label
				send(cmd, args)
			end, palette.Warn)
		end
		addConfirmed("ResetData", "reset data", "resetdata", "confirm")
		addConfirmed("RemovePets", "remove all pets", "removepets", "")

		selectPage(tabNames[1])

		local function isPress(input: InputObject): boolean
			return input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
		end

		local function isMove(input: InputObject): boolean
			return input.UserInputType == Enum.UserInputType.MouseMovement
				or input.UserInputType == Enum.UserInputType.Touch
		end

		local dragOrigin: Vector2? = nil
		local dragStart = Vector2.zero
		local resizeOrigin: Vector2? = nil
		local resizeAxes = Vector2.zero

		local function addHandle(name: string, at: UDim2, extent: UDim2, axes: Vector2): Frame
			local handle = Instance.new("Frame")
			handle.Name = name
			handle.Active = true
			handle.BackgroundTransparency = 1
			handle.BorderSizePixel = 0
			handle.Position = at
			handle.Size = extent
			handle.ZIndex = Kit.ZIndex.Badge
			handle.Parent = window
			table.insert(resizeHandles, handle)
			own:Connect(handle.InputBegan, function(input: InputObject)
				if isPress(input) and not isMinimized then
					resizeOrigin = windowSize
					resizeAxes = axes
					dragStart = Vector2.new(input.Position.X, input.Position.Y)
				end
			end)
			return handle
		end

		addHandle(
			"ResizeRight",
			UDim2.new(1, -edgeThickness, 0, titleHeight),
			UDim2.new(0, edgeThickness, 1, -(titleHeight + gripSize)),
			Vector2.new(1, 0)
		)
		addHandle(
			"ResizeBottom",
			UDim2.new(0, 0, 1, -edgeThickness),
			UDim2.new(1, -gripSize, 0, edgeThickness),
			Vector2.new(0, 1)
		)
		local grip = addHandle(
			"ResizeGrip",
			UDim2.new(1, -gripSize, 1, -gripSize),
			UDim2.fromOffset(gripSize, gripSize),
			Vector2.new(1, 1)
		)
		for index = 0, 2 do
			local line = Instance.new("Frame")
			line.Name = `GripLine{index + 1}`
			line.AnchorPoint = Vector2.new(0.5, 0.5)
			line.BackgroundColor3 = palette.Dim
			line.BorderSizePixel = 0
			line.Rotation = -45
			line.Size = UDim2.fromOffset(gripLineLength - 3 * index, gripLineThickness)
			line.Position = UDim2.fromOffset(3 + 3 * index, 3 + 3 * index)
			line.Parent = grip
		end

		own:Connect(titleBar.InputBegan, function(input: InputObject)
			if isPress(input) then
				dragOrigin = position
				dragStart = Vector2.new(input.Position.X, input.Position.Y)
			end
		end)
		own:Connect(UserInputService.InputChanged, function(input: InputObject)
			if not isMove(input) then
				return
			end
			local delta = (Vector2.new(input.Position.X, input.Position.Y) - dragStart) / viewScale()
			local origin = dragOrigin
			if origin then
				placeAt(origin + delta)
			end
			local base = resizeOrigin
			if base then
				resizeTo(base + delta * resizeAxes)
			end
		end)
		own:Connect(UserInputService.InputEnded, function(input: InputObject)
			if isPress(input) then
				dragOrigin = nil
				resizeOrigin = nil
			end
		end)

		local size = root.AbsoluteSize / viewScale()
		placeAt(position or Vector2.new(math.min(startLeft, math.max(size.X - initial.X, 0)), startTop))
		resizeTo(initial)
	end

	if localPlayer then
		trove:Connect(localPlayer:GetAttributeChangedSignal(developerAttribute), function()
			if not isDeveloper() then
				context.Close("Cheats")
			end
		end)
	end

	return {
		Modal = false,
		StartsOpen = false,
		Open = function(_self: Types.Screen)
			if not isDeveloper() then
				return
			end
			if not gui then
				build()
			end
			local screenGui = gui :: ScreenGui
			screenGui.Enabled = true
		end,
		Close = function(_self: Types.Screen)
			local screenGui = gui
			if screenGui then
				screenGui.Enabled = false
			end
		end,
		Destroy = function(_self: Types.Screen)
			trove:Destroy()
			local own = panelTrove
			if own then
				own:Destroy()
				panelTrove = nil
			end
			gui = nil
			panel = nil
			content = nil
		end,
	}
end

return CheatsScreen
