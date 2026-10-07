--!strict

local Kit = require(script.Parent.Parent.Parent.Kit)
local Layout = require(script.Parent.Parent.Parent.HudLayout)
local PlayerState = require(script.Parent.Parent.Parent.PlayerState)
local Types = require(script.Parent.Types)

local SideMenu = {}

function SideMenu.Build(env: Types.Env): Types.SideMenu
	local trove = env.Trove
	local root = env.Root
	local context = env.Context
	local dataController = env.DataController
	local toggleScreen = env.Toggle
	local theme = Kit.Theme
	local margin = Layout.Margin
	local cell = Layout.Cell
	local cellGap = Layout.CellGap
	local menuWidth = Layout.MenuWidth
	local menuHeight = Layout.MenuHeight
	local settingsSize = Layout.SettingsSize
	local devGap = Layout.DevGap
	local statsHeight = Layout.StatsHeight
	local statClearance = Layout.StatClearance
	local menu = Instance.new("Frame")
	menu.Name = "Menu"
	menu.BackgroundTransparency = 1
	menu.AnchorPoint = Vector2.new(0, 0.5)
	menu.Position = UDim2.new(0, margin, 0.5, 0)
	menu.Size = UDim2.fromOffset(menuWidth, menuHeight)
	local menuGrid = Instance.new("UIGridLayout")
	menuGrid.SortOrder = Enum.SortOrder.LayoutOrder
	menuGrid.CellSize = UDim2.fromOffset(cell, cell)
	menuGrid.CellPadding = UDim2.fromOffset(cellGap, cellGap)
	menuGrid.FillDirection = Enum.FillDirection.Horizontal
	menuGrid.Parent = menu
	menu.Parent = root

	local function squareButton(
		parent: Instance,
		name: string,
		glyph: string,
		label: string,
		color: Color3,
		order: number,
		tip: string,
		side: string,
		callback: () -> ()
	): Kit.Button
		return Kit.Button(trove, {
			Parent = parent,
			Name = name,
			Glyph = glyph,
			Text = label,
			Color = color,
			Size = UDim2.fromOffset(cell, cell),
			LayoutOrder = order,
			TextSize = Kit.Text.Body,
			IconScale = 0.6,
			Tooltip = tip,
			TooltipSide = side,
			Callback = callback,
		})
	end
	local function leftButton(
		name: string,
		glyph: string,
		label: string,
		color: Color3,
		order: number,
		tip: string,
		target: string
	): Kit.Button
		return squareButton(menu, name, glyph, label, color, order, tip, "Right", function()
			toggleScreen(target)
		end)
	end

	local upgradesButton =
		leftButton("Upgrades", "Upgrades", "UPGRADES", theme.Green, 2, "Make your keys stronger!", "Upgrades")
	leftButton("Keys", "Keys", "KEYS", theme.Purple, 1, "See and equip your keys!", "Keys")
	leftButton("Index", "Index", "INDEX", theme.Blue, 3, "Every key you can find!", "Index")
	local rebirthButton =
		leftButton("Rebirth", "Rebirth", "REBIRTH", theme.Pink, 4, "Start over for a big bonus!", "Rebirth")
	local dailyButton =
		leftButton("DailyRewards", "Gift", "GIFTS", theme.Teal, 5, "Free gifts for playing!", "Daily")
	local petsButton =
		leftButton("Pets", "Heart", "PETS", theme.Gold, 6, "See your pets and what they do!", "Pets")

	local side = Instance.new("Frame")
	side.Name = "Side"
	side.BackgroundTransparency = 1
	side.AnchorPoint = Vector2.new(1, 1)
	side.Position = UDim2.new(1, -margin, 1, -(margin + statsHeight + statClearance))
	side.Size = UDim2.fromOffset(cell, cell * 4 + cellGap * 3)
	local sideList = Instance.new("UIListLayout")
	sideList.VerticalAlignment = Enum.VerticalAlignment.Bottom
	sideList.SortOrder = Enum.SortOrder.LayoutOrder
	sideList.Padding = UDim.new(0, cellGap)
	sideList.Parent = side
	side.Parent = root
	local function sideButton(
		name: string,
		glyph: string,
		label: string,
		color: Color3,
		order: number,
		tip: string,
		target: string
	): Kit.Button
		return squareButton(side, name, glyph, label, color, order, tip, "Left", function()
			toggleScreen(target)
		end)
	end
	local giftButton = squareButton(
		side,
		"StarterPack",
		"Gift",
		"STARTER",
		theme.Orange,
		0,
		"A special one-time deal!",
		"Left",
		function()
			context.Open("StarterOffer")
		end
	)
	giftButton.SetGlow(true)
	trove:Add(dataController:Observe({ "StarterPackBought" }, function(value: any)
		giftButton.Instance.Visible = value ~= true
	end))
	sideButton("Store", "Store", "STORE", theme.Red, 1, "Get boosts and goodies!", "Shop")
	sideButton(
		"Leaderboard",
		"Leaderboard",
		"RANKS",
		theme.Purple,
		2,
		"See the best players!",
		"Leaderboards"
	)
	local passButton = sideButton("Pass", "Pass", "PASS", theme.Gold, 3, "Season rewards to claim!", "Season")

	Kit.Button(trove, {
		Parent = root,
		Name = "Settings",
		Glyph = "Settings",
		Size = UDim2.fromOffset(settingsSize, settingsSize),
		Position = UDim2.new(0, margin, 1, -margin),
		AnchorPoint = Vector2.new(0, 1),
		Color = theme.Grey,
		Tooltip = "Settings",
		TooltipSide = "Right",
		Callback = function()
			toggleScreen("Settings")
		end,
	})

	local devButton = Kit.Button(trove, {
		Parent = root,
		Name = "Dev",
		Glyph = "Code",
		Size = UDim2.fromOffset(settingsSize, settingsSize),
		Position = UDim2.new(0, margin + settingsSize + devGap, 1, -margin),
		AnchorPoint = Vector2.new(0, 1),
		Color = theme.Grey,
		Tooltip = "Dev tools",
		TooltipSide = "Right",
		Callback = function()
			toggleScreen("Cheats")
		end,
	})
	local function refreshDevButton()
		devButton.Instance.Visible = PlayerState.IsDeveloper()
	end
	refreshDevButton()
	local developerChanged = PlayerState.DeveloperChanged()
	if developerChanged then
		trove:Connect(developerChanged, refreshDevButton)
	end
	return {
		Menu = menu,
		Upgrades = upgradesButton,
		Rebirth = rebirthButton,
		Daily = dailyButton,
		Pets = petsButton,
		Pass = passButton,
		Gift = giftButton,
	}
end

return SideMenu
