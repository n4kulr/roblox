--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local Charms = require(ReplicatedStorage.Config.Charms)
local Eggs = require(ReplicatedStorage.Config.Eggs)
local Keys = require(ReplicatedStorage.Config.Keys)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)

type TroveInstance = typeof(Trove.new())

local theme = Kit.Theme
local openCommand = "/cheats"
local confirmSeconds = 3
local rowHeight = 56

local CheatsScreen = {}

local function usesTextChatService(): boolean
	local chat: any = TextChatService
	local ok, matches = pcall(function()
		return chat.ChatVersion == Enum.ChatVersion.TextChatService and chat.SendingMessage ~= nil
	end)
	return ok and matches == true
end

local function isOpenCommand(text: any): boolean
	if type(text) ~= "string" then
		return false
	end
	return string.lower((string.gsub(text, "^%s*(.-)%s*$", "%1"))) == openCommand
end

function CheatsScreen.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local localPlayer = Players.LocalPlayer
	local playUi = Kit.UiSound(context.Controllers)
	local panelTrove: TroveInstance? = nil
	local modal: Kit.Modal? = nil
	local targetBox: TextBox? = nil
	local amountBox: TextBox? = nil
	local countBox: TextBox? = nil
	local isBusy = false

	local function isAdmin(): boolean
		return localPlayer ~= nil and localPlayer:GetAttribute("IsAdmin") == true
	end

	local function targetSuffix(): string
		local box = targetBox
		if not box then
			return ""
		end
		return (string.gsub(box.Text, "^%s*(.-)%s*$", "%1"))
	end

	local function send(command: string, args: string)
		if isBusy then
			return
		end
		isBusy = true
		task.spawn(function()
			local suffix = targetSuffix()
			local argument = args
			if suffix ~= "" then
				argument = if args == "" then suffix else `{args} {suffix}`
			end
			local result = Packets.AdminCommand:Fire(command, argument)
			isBusy = false
			if type(result) ~= "string" or result == "" then
				playUi("Error")
				context.Toast("No response", "Bad")
				return
			end
			playUi(if result == "Not allowed" then "Error" else "Confirm")
			context.Toast(result, if result == "Not allowed" then "Bad" else "Info")
		end)
	end

	local function build()
		local own = Trove.new()
		panelTrove = own
		local window = Kit.Modal(own, {
			Parent = context.PlayerGui,
			Name = "Cheats",
			Title = "DEV CHEATS",
			Glyph = "Code",
			MaxSize = Vector2.new(860, 680),
			HeaderColor = theme.Red,
			OnClose = function()
				context.Close("Cheats")
			end,
			Sound = playUi,
		})
		modal = window

		local targetRow = Kit.Panel({
			Parent = window.Body,
			Name = "TargetRow",
			Position = UDim2.fromOffset(10, 8),
			Size = UDim2.new(1, -20, 0, 52),
			Color = theme.Track,
			Radius = Kit.Radius.M,
			Flat = true,
		})
		local function addBox(
			parent: GuiObject,
			name: string,
			placeholder: string,
			text: string,
			position: UDim2,
			size: UDim2
		): TextBox
			local field = Kit.Panel({
				Parent = parent,
				Name = `{name}Field`,
				Position = position,
				Size = size,
				Color = theme.Track,
				Radius = Kit.Radius.M,
				Flat = true,
			})
			local box = Instance.new("TextBox")
			box.Name = name
			box.BackgroundTransparency = 1
			box.BorderSizePixel = 0
			box.Position = UDim2.fromOffset(10, 0)
			box.Size = UDim2.new(1, -20, 1, 0)
			box.Font = Kit.Font
			box.TextSize = 22
			box.TextColor3 = theme.Text
			box.PlaceholderText = placeholder
			box.PlaceholderColor3 = theme.Disabled
			box.TextXAlignment = Enum.TextXAlignment.Left
			box.ClearTextOnFocus = false
			box.Text = text
			box.Parent = field
			return box
		end
		targetBox = addBox(
			targetRow,
			"TargetInput",
			"Target: blank = me, a player name, or all",
			"",
			UDim2.new(),
			UDim2.fromScale(1, 1)
		)

		local scroll = Kit.Scroll({
			Parent = window.Body,
			Name = "List",
			Position = UDim2.fromOffset(6, 68),
			Size = UDim2.new(1, -12, 1, -74),
			Padding = 10,
		})
		local order = 0

		local function addSection(text: string, color: Color3)
			order += 1
			Kit.Section({
				Parent = scroll,
				Name = `Section{string.gsub(text, "%s", "")}`,
				Text = text,
				Color = color,
				LayoutOrder = order,
			})
		end

		local function addGrid(columns: number): Frame
			order += 1
			local grid = Instance.new("Frame")
			grid.Name = `Grid{order}`
			grid.BackgroundTransparency = 1
			grid.BorderSizePixel = 0
			grid.AutomaticSize = Enum.AutomaticSize.Y
			grid.Size = UDim2.new(1, 0, 0, 0)
			grid.LayoutOrder = order
			local layout = Instance.new("UIGridLayout")
			layout.SortOrder = Enum.SortOrder.LayoutOrder
			layout.CellSize = UDim2.new(1 / columns, -8, 0, rowHeight)
			layout.CellPadding = UDim2.fromOffset(8, 10)
			layout.Parent = grid
			grid.Parent = scroll
			return grid
		end

		local function addAction(
			grid: Frame,
			name: string,
			text: string,
			color: Color3,
			callback: () -> ()
		): Kit.Button
			return Kit.Button(own, {
				Parent = grid,
				Name = name,
				Text = text,
				Color = color,
				TextSize = 20,
				Callback = callback,
				Sound = playUi,
			})
		end

		local function command(
			grid: Frame,
			name: string,
			text: string,
			color: Color3,
			cmd: string,
			args: string
		)
			addAction(grid, name, text, color, function()
				send(cmd, args)
			end)
		end

		local function readCount(): string
			local box = countBox
			local text = if box then (string.gsub(box.Text, "%s", "")) else ""
			return if text == "" then "1" else text
		end

		addSection("MONEY", theme.Gold)
		local money = addGrid(4)
		command(money, "Money1K", "+1K", theme.Green, "money", "1k")
		command(money, "Money1M", "+1M", theme.Green, "money", "1m")
		command(money, "Money1B", "+1B", theme.Green, "money", "1b")
		command(money, "Money1T", "+1T", theme.Green, "money", "1t")
		command(money, "MaxMoney", "MAX", theme.Gold, "maxmoney", "")
		command(money, "ResetMoney", "RESET", theme.Grey, "resetmoney", "")
		local customRow = addGrid(1)
		customRow.Name = "CustomAmount"
		local customHolder = Instance.new("Frame")
		customHolder.Name = "Holder"
		customHolder.BackgroundTransparency = 1
		customHolder.BorderSizePixel = 0
		customHolder.Size = UDim2.fromScale(1, 1)
		customHolder.Parent = customRow
		amountBox = addBox(
			customHolder,
			"AmountInput",
			"Custom amount (2.5m)",
			"",
			UDim2.new(),
			UDim2.new(0.5, -8, 1, 0)
		)
		local function amountText(): string?
			local box = amountBox
			local text = if box then (string.gsub(box.Text, "%s", "")) else ""
			if text == "" then
				context.Toast("Enter an amount", "Info")
				return nil
			end
			return text
		end
		Kit.Button(own, {
			Parent = customHolder,
			Name = "AddAmount",
			Text = "ADD",
			Color = theme.Green,
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.new(0.25, -8, 1, 0),
			TextSize = 20,
			Callback = function()
				local text = amountText()
				if text then
					send("money", text)
				end
			end,
			Sound = playUi,
		})
		Kit.Button(own, {
			Parent = customHolder,
			Name = "SetAmount",
			Text = "SET",
			Color = theme.Blue,
			Position = UDim2.fromScale(0.75, 0),
			Size = UDim2.new(0.25, 0, 1, 0),
			TextSize = 20,
			Callback = function()
				local text = amountText()
				if text then
					send("setmoney", text)
				end
			end,
			Sound = playUi,
		})

		addSection("PROGRESS", theme.Blue)
		local progress = addGrid(3)
		command(progress, "Rolls100", "+100 ROLLS", theme.Blue, "rolls", "100")
		command(progress, "NextGolden", "NEXT GOLDEN", theme.Gold, "golden", "")
		command(progress, "Income1h", "+1H INCOME", theme.Green, "income", "3600")
		command(progress, "MaxUpgrades", "MAX UPGRADES", theme.Purple, "maxupgrades", "")
		command(progress, "ResetUpgrades", "RESET UPGRADES", theme.Grey, "resetupgrades", "")
		command(progress, "ForceRebirth", "FORCE REBIRTH", theme.Orange, "rebirth", "")

		addSection("BOOSTS", theme.Green)
		local boosts = addGrid(2)
		command(boosts, "LuckPotion", "LUCK POTION 10M", theme.Green, "luckpotion", "10")
		command(boosts, "ClicksPotion", "CLICKS POTION 10M", theme.Gold, "clickspotion", "10")

		addSection("ITEMS", theme.Purple)
		local countRow = addGrid(1)
		countRow.Name = "CountRow"
		local countHolder = Instance.new("Frame")
		countHolder.Name = "Holder"
		countHolder.BackgroundTransparency = 1
		countHolder.BorderSizePixel = 0
		countHolder.Size = UDim2.fromScale(1, 1)
		countHolder.Parent = countRow
		countBox =
			addBox(countHolder, "CountInput", "Count (default 1)", "1", UDim2.new(), UDim2.new(0.5, -8, 1, 0))
		local eggReady = addGrid(2)
		command(eggReady, "ReadyEggs", "READY EGGS", theme.Teal, "readyeggs", "")
		command(eggReady, "HatchAll", "HATCH ALL", theme.Teal, "hatchall", "")

		addSection("KEYS BY RARITY", theme.Pink)
		local rarityGrid = addGrid(3)
		for _, rarity in Keys.Rarities do
			addAction(
				rarityGrid,
				`GiveRarity{rarity.Name}`,
				string.upper(rarity.Name),
				rarity.Color,
				function()
					send("givekey", `{rarity.Name} {readCount()}`)
				end
			)
		end

		addSection("KEYS", theme.Pink)
		local keyGrid = addGrid(3)
		for _, key in Keys.Catalog do
			addAction(keyGrid, `GiveKey{key.Id}`, key.Name, Keys.GetRarity(key).Color, function()
				send("givekey", `{key.Id} {readCount()}`)
			end)
		end

		addSection("EGGS", theme.Orange)
		local eggGrid = addGrid(3)
		for _, egg in Eggs.Catalog do
			addAction(eggGrid, `GiveEgg{egg.Id}`, egg.Name, egg.Color, function()
				send("giveegg", `{egg.Id} {readCount()}`)
			end)
		end

		addSection("PETS", theme.Teal)
		local petGrid = addGrid(3)
		for _, charm in Charms.Catalog do
			addAction(petGrid, `GivePet{charm.Id}`, charm.Name, charm.Color, function()
				send("givepet", `{charm.Id} {readCount()}`)
			end)
		end

		addSection("DANGER", theme.Red)
		local danger = addGrid(2)
		local function addConfirmed(name: string, label: string, cmd: string, args: string)
			local armed = false
			local armToken = 0
			local button: Kit.Button? = nil
			button = addAction(danger, name, label, theme.Red, function()
				local own = button :: Kit.Button
				if not armed then
					armed = true
					armToken += 1
					local mine = armToken
					own.SetText("TAP AGAIN TO CONFIRM")
					task.delay(confirmSeconds, function()
						if armed and armToken == mine then
							armed = false
							own.SetText(label)
						end
					end)
					return
				end
				armed = false
				armToken += 1
				own.SetText(label)
				send(cmd, args)
			end)
		end
		addConfirmed("ResetData", "RESET DATA", "resetdata", "confirm")
		addConfirmed("RemovePets", "REMOVE ALL PETS", "removepets", "")
	end

	local function toggle()
		if not isAdmin() then
			return
		end
		if context.IsOpen("Cheats") then
			context.Close("Cheats")
		else
			context.Open("Cheats")
		end
	end

	local function onChat(text: any)
		if isOpenCommand(text) then
			toggle()
		end
	end

	if usesTextChatService() then
		local chat: any = TextChatService
		trove:Connect(chat.SendingMessage, function(message: any)
			onChat(
				if type(message) == "table" or typeof(message) == "Instance" then message.Text else message
			)
		end)
	elseif localPlayer then
		trove:Connect(localPlayer.Chatted, onChat)
	end

	return {
		Modal = true,
		StartsOpen = false,
		Open = function(_self: Types.Screen)
			if not isAdmin() then
				return
			end
			if not modal then
				build()
			end
			local window = modal :: Kit.Modal
			window.Show()
		end,
		Close = function(_self: Types.Screen)
			local window = modal
			if window then
				window.Hide()
			end
		end,
		Destroy = function(_self: Types.Screen)
			trove:Destroy()
			local own = panelTrove
			if own then
				own:Destroy()
				panelTrove = nil
			end
			modal = nil
		end,
	}
end

return CheatsScreen
