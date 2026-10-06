local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local Enum = roblox.Enum
local UDim2 = roblox.UDim2
local Color3 = roblox.Color3
local serde = require("@lune/serde")

local H = require("../../tests/harness/Harness")
local Layout = require("./Layout")

local outDir = process.args[1] or "ui-preview"
local width = tonumber(process.args[2]) or 1280
local height = tonumber(process.args[3]) or 720
local only = process.args[4]
local useAtlas = process.env.PREVIEW_ATLAS == "1"

local screensPath = "StarterPlayer.StarterPlayerScripts.Controllers.UIController"
local viewport = roblox.Vector2.new(width, height)

local owned = { "DoubleLuck", "Vip" }
local boardIds = {
	"PlainClack",
	"CreamyThock",
	"GlassTink",
	"CrystalChime",
	"ThunderKey",
	"CloverCap",
	"TurboSwitch",
	"LavaKey",
	"PlainClack",
	"MintLinear",
}
local spareIds = {
	CreamyThock = 3,
	GlassTink = 2,
	TopazTap = 1,
	AmethystPop = 1,
	SunburstKey = 1,
	OfficeTap = 12,
	["GlassTink@Gold"] = 2,
	["LavaKey@Rainbow"] = 1,
	["CrystalChime@Mythical"] = 1,
	LavaKey = 5,
}
local leaderboardRows = {
	{ Name = "KeebKing", Value = 98234100 },
	{ Name = "ThockLord", Value = 72110400 },
	{ Name = "ClackQueen", Value = 55200000 },
	{ Name = "PixelPete", Value = 21400000 },
	{ Name = "You", Value = 12950000 },
	{ Name = "SwitchSage", Value = 8120000 },
	{ Name = "MxMaster", Value = 5320000 },
	{ Name = "LinearLuke", Value = 2100000 },
}

local function newScenario(world: any)
	if useAtlas then
		world.tree.ReplicatedStorage:SetAttribute("IconAtlasPreview", "rbxassetid://preview-atlas")
	end
	local Signal = world:require("ReplicatedStorage.Packages.Signal")
	local Trove = world:require("ReplicatedStorage.Packages.Trove")
	local Keys = world:require("ReplicatedStorage.Config.Keys")
	local now = world.now

	local player = world:newPlayer({ Name = "You", DisplayName = "You" })
	player.GetAttributeChangedSignal = function()
		return Signal.new()
	end
	for _, passId in owned do
		player:SetAttribute(`Pass_{passId}`, true)
	end
	player:SetAttribute("PlaytimeStart", now - 130)
	player:SetAttribute("PlaytimeClaimed", 1)
	world.Players.LocalPlayer = player
	world.tree.ReplicatedStorage.GetAttributeChangedSignal = function()
		return Signal.new()
	end

	local board = {}
	for index = 1, 60 do
		board[index] = boardIds[index] or ""
	end
	local boardTags = {}
	for index = 1, 60 do
		boardTags[index] = ""
	end
	boardTags[2] = "PixelPete"
	local discovered = {}
	for index, key in Keys.Catalog do
		if index % 3 ~= 0 then
			discovered[key.Id] = 1
		end
	end
	local market = world:require("ReplicatedStorage.Rules.Market")
	local data: any = {
		Cash = 184500,
		IncomeAt = now,
		Board = board,
		BoardTags = boardTags,
		Inventory = spareIds,
		Discovered = discovered,
		Rolls = 4210,
		GoldenProgress = 37,
		Upgrades = { Luck = 12, Speed = 3, Slots = 2, Income = 8, Walls = 1, LockTime = 0, Golden = 1 },
		Settings = { LowGraphics = false, AutoPlace = true, RollVolume = 0.8, BoardVolume = 1, OtherVolume = 0.35, MusicVolume = 0.5, EffectsMinRarity = 5 },
		Tutorial = 5,
		Boosts = { LuckUntil = now + 620, ClicksUntil = 0 },
		Daily = { Streak = 2, LastClaim = now - 90000 },
		StarterPackBought = false,
		Rebirths = 1,
		TotalEarned = 5200000,
		Season = { Id = 1, Xp = 345, ClaimedFree = 2, ClaimedPremium = 0 },
		Market = { Slot = market.Slot(now), Bought = { ["2"] = 1 } },
	}

	local function lookup(path: { any }): any
		local node: any = data
		for _, part in path do
			if type(node) ~= "table" then
				return nil
			end
			node = node[part]
		end
		return node
	end

	local dataController = {
		Get = function(_self: any, path: { any }?)
			return lookup(path or {})
		end,
		Observe = function(_self: any, path: { any }, callback: any)
			callback(lookup(path))
			return function() end
		end,
	}
	local rollController = {
		AutoChanged = Signal.new(),
		InBaseChanged = Signal.new(),
		InBase = true,
		IsInBase = function(self)
			return self.InBase
		end,
		IsAuto = function()
			return false
		end,
		SetAuto = function() end,
		TeleportToBase = function()
			return true
		end,
		TeleportToMarket = function()
			return true
		end,
		RequestRoll = function() end,
	}
	local tradeState: any = {
		Partner = "PixelPete",
		Phase = 1,
		Seconds = 0,
		MyReady = false,
		TheirReady = true,
		Mine = { { KeyId = "GlassTink", Count = 1 }, { KeyId = "CreamyThock", Count = 2 } },
		Theirs = { { KeyId = "CrystalChime", Count = 1 } },
	}
	local tradeController = {
		StateChanged = Signal.new(),
		TargetPicked = Signal.new(),
		InviteReceived = Signal.new(),
		GetState = function()
			return tradeState
		end,
		SetReady = function() end,
		SetOffer = function() end,
		Cancel = function() end,
		Request = function() end,
		Respond = function() end,
	}
	local packets = world:packets()
	packets.GetLeaderboard.Fire = function()
		return leaderboardRows
	end

	local playerGui = world:newInstance("Folder")
	local controllers = {
		DataController = dataController,
		RollController = rollController,
		TradeController = tradeController,
	}
	local context = {
		Controllers = controllers,
		PlayerGui = playerGui,
		Open = function() end,
		Close = function() end,
		IsOpen = function()
			return false
		end,
		Toast = function() end,
	}
	local trove = Trove.new()
	local toast = world:require(`{screensPath}.Toast`).new(playerGui, trove)
	context.Toast = toast
	return {
		World = world,
		Context = context,
		PlayerGui = playerGui,
		Toast = toast,
		Data = data,
		TradeState = tradeState,
		Screens = {},
	}
end

local function boot(scene: any, names: { string })
	for _, name in names do
		local module = scene.World:require(`{screensPath}.Screens.{name}`)
		scene.Screens[name] = module.new(scene.Context)
	end
end

local function tick(scene: any, seconds: number)
	local heartbeat = scene.World.fakeServices.RunService.Heartbeat
	for _ = 1, 6 do
		heartbeat:Fire(seconds / 6)
	end
	scene.World:flush()
end

local function find(scene: any, name: string): any
	return scene.PlayerGui:FindFirstChild(name, true)
end

local function press(button: any)
	button.Activated:Fire({ UserInputType = roblox.Enum.UserInputType.MouseButton1 })
end

local function openModal(scene: any, name: string)
	scene.Screens[name]:Open()
	tick(scene, 0.6)
end

local function scroll(scene: any, guiName: string, scrollName: string, y: number)
	local gui = scene.PlayerGui:FindFirstChild(guiName)
	local frame = gui:FindFirstChild(scrollName, true)
	frame.CanvasPosition = roblox.Vector2.new(0, y)
end

local base = { "Hud", "Offers" }

local function glyphSheet(scene: any, size: number)
	local world = scene.World
	local Glyphs = world:require(`{screensPath}.Glyphs`)
	local gui = world:newInstance("ScreenGui")
	gui.Name = "GlyphSheet"
	gui.IgnoreGuiInset = true
	local board = world:newInstance("Frame")
	board.Size = UDim2.fromScale(1, 1)
	board.BackgroundColor3 = Color3.fromRGB(60, 66, 140)
	board.BorderSizePixel = 0
	board.Parent = gui
	local grid = world:newInstance("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(size + 40, size + 30)
	grid.CellPadding = UDim2.fromOffset(4, 4)
	grid.Parent = board
	for _, name in Glyphs.Names do
		local cell = world:newInstance("Frame")
		cell.BackgroundTransparency = 1
		cell.BorderSizePixel = 0
		cell.Parent = board
		Glyphs.Build(name, {
			Parent = cell,
			Size = UDim2.fromOffset(size, size),
			Position = UDim2.fromOffset(20, 0),
		})
		local label = world:newInstance("TextLabel")
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.Text = name
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextSize = 14
		label.Font = Enum.Font.FredokaOne
		label.Position = UDim2.fromOffset(0, size + 4)
		label.Size = UDim2.new(1, 0, 0, 18)
		label.Parent = cell
	end
	gui.Parent = scene.PlayerGui
end

local scenarios: { { Name: string, Screens: { string }, NoBase: boolean?, Run: (any) -> () } } = {
	{
		Name = "glyphs",
		Screens = {},
		NoBase = true,
		Run = function(scene)
			glyphSheet(scene, 72)
		end,
	},
	{
		Name = "hud",
		Screens = {},
		Run = function() end,
	},
	{
		Name = "toasts",
		Screens = {},
		Run = function(scene)
			scene.Toast("Bought Lucky Charm!", "Good")
			scene.Toast("Need 4.2K more Clicks!", "Bad")
			scene.Toast("PixelPete is stealing your Lava Key!", "Bad")
		end,
	},
	{
		Name = "upgrades",
		Screens = { "Upgrades" },
		Run = function(scene)
			openModal(scene, "Upgrades")
		end,
	},
	{
		Name = "upgrades_x10",
		Screens = { "Upgrades" },
		Run = function(scene)
			openModal(scene, "Upgrades")
			press(find(scene, "x10"))
			tick(scene, 0.3)
		end,
	},
	{
		Name = "upgrades_max",
		Screens = { "Upgrades" },
		Run = function(scene)
			openModal(scene, "Upgrades")
			press(find(scene, "MAX"))
			tick(scene, 0.3)
		end,
	},
	{
		Name = "upgrades_defense",
		Screens = { "Upgrades" },
		Run = function(scene)
			openModal(scene, "Upgrades")
			scroll(scene, "ThockUpgrades", "List", 520)
		end,
	},
	{
		Name = "keys",
		Screens = { "Keys" },
		Run = function(scene)
			openModal(scene, "Keys")
		end,
	},
	{
		Name = "keys_detail",
		Screens = { "Keys" },
		Run = function(scene)
			openModal(scene, "Keys")
			local cell = find(scene, "GlassTink")
			press(cell.Hit)
			tick(scene, 0.4)
		end,
	},
	{
		Name = "keys_detail_variant",
		Screens = { "Keys" },
		Run = function(scene)
			openModal(scene, "Keys")
			local cell = find(scene, "LavaKey")
			press(cell.Hit)
			tick(scene, 0.4)
		end,
	},
	{
		Name = "keys_detail_mythical",
		Screens = { "Keys" },
		Run = function(scene)
			openModal(scene, "Keys")
			local cell = find(scene, "CrystalChime@Mythical")
			press(cell.Hit)
			tick(scene, 0.4)
		end,
	},
	{
		Name = "index",
		Screens = { "Index" },
		Run = function(scene)
			openModal(scene, "Index")
		end,
	},
	{
		Name = "market",
		Screens = { "Market" },
		Run = function(scene)
			openModal(scene, "Market")
		end,
	},
	{
		Name = "shop",
		Screens = { "Shop" },
		Run = function(scene)
			openModal(scene, "Shop")
		end,
	},
	{
		Name = "shop_products",
		Screens = { "Shop" },
		Run = function(scene)
			openModal(scene, "Shop")
			scroll(scene, "ThockShop", "List", 900)
		end,
	},
	{
		Name = "season",
		Screens = { "Season" },
		Run = function(scene)
			openModal(scene, "Season")
		end,
	},
	{
		Name = "daily",
		Screens = { "Daily" },
		Run = function(scene)
			openModal(scene, "Daily")
		end,
	},
	{
		Name = "rebirth",
		Screens = { "Rebirth" },
		Run = function(scene)
			scene.Data.Cash = 3200000
			openModal(scene, "Rebirth")
		end,
	},
	{
		Name = "leaderboards",
		Screens = { "Leaderboards" },
		Run = function(scene)
			openModal(scene, "Leaderboards")
		end,
	},
	{
		Name = "settings",
		Screens = { "Settings" },
		Run = function(scene)
			openModal(scene, "Settings")
		end,
	},
	{
		Name = "trade",
		Screens = { "Trade" },
		Run = function(scene)
			openModal(scene, "Trade")
		end,
	},
	{
		Name = "trade_prompt",
		Screens = { "TradePrompt" },
		Run = function(scene)
			scene.Context.Controllers.TradeController.GetState = function()
				return nil
			end
			scene.Context.Controllers.TradeController.TargetPicked:Fire({ DisplayName = "PixelPete" })
			scene.Context.Controllers.TradeController.InviteReceived:Fire("ClackQueen", 2002)
			tick(scene, 0.2)
		end,
	},
	{
		Name = "starter_offer",
		Screens = { "StarterOffer" },
		Run = function(scene)
			openModal(scene, "StarterOffer")
		end,
	},
}

for _, extra in require("./scenarios_roll") do
	table.insert(scenarios, extra)
end
for _, extra in require("./scenarios_eggs") do
	table.insert(scenarios, extra)
end
for _, extra in require("./scenarios_pets") do
	table.insert(scenarios, extra)
end
for _, extra in require("./scenarios_fixes") do
	table.insert(scenarios, extra)
end

fs.writeDir(outDir)
local failures = 0
for _, scenario in scenarios do
	if not only or only == "" or only == scenario.Name then
		local world = H.newWorld({ GuiSize = roblox.Vector2.new(width, height - 36), PrintErrors = true })
		local ok, problem = pcall(function()
			local scene = newScenario(world)
			if not scenario.NoBase then
				boot(scene, base)
			end
			boot(scene, scenario.Screens)
			tick(scene, 0.3)
			scenario.Run(scene)
			tick(scene, 0.3)
			local guis = {}
			for _, gui in scene.PlayerGui:GetChildren() do
				if gui.ClassName == "ScreenGui" then
					local isEnabled = true
					pcall(function()
						isEnabled = gui.Enabled
					end)
					if isEnabled then
						table.insert(guis, Layout.Gui(gui, viewport))
					end
				end
			end
			table.sort(guis, function(a: any, b: any)
				return a.order < b.order
			end)
			local payload = {
				name = scenario.Name,
				width = width,
				height = height,
				guis = guis,
				errors = world.errors,
			}
			fs.writeFile(`{outDir}/{scenario.Name}.json`, serde.encode("json", payload))
		end)
		if not ok then
			failures += 1
			print(`[ui_preview] {scenario.Name} failed: {tostring(problem)}`)
		elseif #world.errors > 0 then
			print(`[ui_preview] {scenario.Name}: {#world.errors} harness errors, first: {world.errors[1]}`)
		else
			print(`[ui_preview] {scenario.Name} ok`)
		end
	end
end
if failures > 0 then
	process.exit(1)
end
