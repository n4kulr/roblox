--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Monetization = require(ReplicatedStorage.Config.Monetization)
local SeasonLevels = require(ReplicatedStorage.Config.Season)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Season = require(ReplicatedStorage.Rules.Season)
local BoostState = require(script.Parent.Parent.BoostState)
local Kit = require(script.Parent.Parent.Kit)
local Purchases = require(script.Parent.Parent.Purchases)
local Types = require(script.Parent.Parent.Types)

type Tile = {
	Level: number,
	Premium: boolean,
	Panel: Frame,
	Mark: GuiObject,
}

local theme = Kit.Theme
local refreshSeconds = 0.25
local columnWidth = 112
local claimDelay = 0.3
local lockedColor = Color3.fromRGB(58, 64, 80)
local reachedColor = Color3.fromRGB(88, 96, 120)

local rewardGlyph: { [string]: string } = {
	Clicks = "Coin",
	LuckPotion = "Flask",
	ClicksPotion = "Flask",
	Key = "Keys",
}
local rewardTint: { [string]: Color3? } = {
	ClicksPotion = Color3.fromRGB(255, 190, 40),
}

local SeasonScreen = {}

function SeasonScreen.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local playUi = Kit.UiSound(context.Controllers)
	local dataController = context.Controllers.DataController
	local boostState = BoostState.Track(dataController, trove)
	local premiumPass = Monetization.PassById[GameConfig.Season.PremiumPassId]
	local tiles: { Tile } = {}
	local isOpen = false
	local isBusy = false

	local modal = Kit.Modal(trove, {
		Parent = context.PlayerGui,
		Name = "Season",
		Title = "SEASON PASS",
		Glyph = "Pass",
		MaxSize = Vector2.new(1000, 620),
		HeaderColor = theme.Orange,
		OnClose = function()
			context.Close("Season")
		end,
		Sound = playUi,
	})

	local passButton = Kit.Button(trove, {
		Parent = modal.HeaderRight,
		Name = "PremiumPass",
		Text = "Premium Pass",
		Glyph = "Crown",
		IconLeft = true,
		Size = UDim2.fromOffset(230, 46),
		Color = theme.Purple,
		TextSize = 20,
		Callback = function()
			if boostState.Owns(GameConfig.Season.PremiumPassId) then
				return
			end
			if not premiumPass or not Purchases.PromptPass(premiumPass) then
				playUi("Error")
				context.Toast("Coming soon!", "Info")
			end
		end,
		Sound = playUi,
	})

	local trackLabels = Instance.new("Frame")
	trackLabels.Name = "TrackLabels"
	trackLabels.BackgroundTransparency = 1
	trackLabels.Position = UDim2.fromOffset(10, 10)
	trackLabels.Size = UDim2.new(0, 84, 1, -96)
	trackLabels.Parent = modal.Body
	local function trackLabel(name: string, text: string, top: number, height: number, color: Color3)
		local panel = Kit.Panel({
			Parent = trackLabels,
			Name = name,
			Position = UDim2.fromScale(0, top),
			Size = UDim2.fromScale(1, height),
			Color = color,
			Shards = true,
		})
		Kit.Label({
			Parent = panel,
			Name = "Text",
			Text = text,
			Size = UDim2.fromScale(1, 1),
			TextSize = 20,
			Align = Enum.TextXAlignment.Center,
			Scaled = true,
		})
	end
	trackLabel("Free", "FREE", 0.14, 0.41, theme.Green)
	trackLabel("Premium", "PREMIUM", 0.58, 0.41, theme.Purple)

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Levels"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(102, 10)
	scroll.Size = UDim2.new(1, -112, 1, -96)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.X
	scroll.CanvasSize = UDim2.new()
	scroll.ScrollingDirection = Enum.ScrollingDirection.X
	scroll.ScrollBarThickness = 8
	scroll.ScrollBarImageColor3 = theme.Gold
	local columns = Instance.new("UIListLayout")
	columns.FillDirection = Enum.FillDirection.Horizontal
	columns.SortOrder = Enum.SortOrder.LayoutOrder
	columns.Padding = UDim.new(0, 8)
	columns.Parent = scroll
	scroll.Parent = modal.Body

	local function addTile(column: Frame, entry: SeasonLevels.Level, premium: boolean)
		local reward = if premium then entry.Premium else entry.Free
		local panel = Kit.Panel({
			Parent = column,
			Name = if premium then "Premium" else "Free",
			Position = UDim2.fromScale(0, if premium then 0.58 else 0.14),
			Size = UDim2.fromScale(1, 0.38),
			Color = lockedColor,
			Shards = true,
		})
		Kit.Icon({
			Parent = panel,
			Name = "Icon",
			Glyph = rewardGlyph[reward.Kind] or "Gift",
			Color = rewardTint[reward.Kind],
			Position = UDim2.fromScale(0.2, 0.08),
			Size = UDim2.fromScale(0.6, 0.42),
		})
		Kit.Label({
			Parent = panel,
			Name = "Reward",
			Text = reward.Label,
			Position = UDim2.fromScale(0.04, 0.55),
			Size = UDim2.fromScale(0.92, 0.4),
			TextSize = 16,
			Align = Enum.TextXAlignment.Center,
			Wrapped = true,
			Scaled = true,
		})
		local mark = Kit.Icon({
			Parent = panel,
			Name = "Mark",
			Glyph = "Lock",
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -4, 0, 4),
			Size = UDim2.fromOffset(30, 30),
		})
		table.insert(tiles, { Level = entry.Level, Premium = premium, Panel = panel, Mark = mark })
	end

	for _, entry in SeasonLevels.Levels do
		local column = Instance.new("Frame")
		column.Name = `Level{entry.Level}`
		column.BackgroundTransparency = 1
		column.LayoutOrder = entry.Level
		column.Size = UDim2.new(0, columnWidth, 1, -12)
		column.Parent = scroll
		Kit.Label({
			Parent = column,
			Name = "Level",
			Text = `LVL {entry.Level}`,
			Size = UDim2.fromScale(1, 0.12),
			TextSize = 22,
			Color = theme.Gold,
			Align = Enum.TextXAlignment.Center,
			Scaled = true,
		})
		addTile(column, entry, false)
		addTile(column, entry, true)
	end

	local footer = Instance.new("Frame")
	footer.Name = "Footer"
	footer.BackgroundTransparency = 1
	footer.AnchorPoint = Vector2.new(0, 1)
	footer.Position = UDim2.new(0, 10, 1, -10)
	footer.Size = UDim2.new(1, -20, 0, 66)
	footer.Parent = modal.Body
	local levelLabel = Kit.Label({
		Parent = footer,
		Name = "Level",
		Text = "Lvl 0",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(0, 120, 1, 0),
		TextSize = 36,
		Color = theme.Gold,
		Scaled = true,
	})
	local bar = Kit.Bar({
		Parent = footer,
		Name = "Xp",
		Position = UDim2.new(0, 130, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Size = UDim2.new(1, -130 - 190, 0, 40),
		Color = theme.Orange,
		TextSize = 24,
	})

	local claimButton: Kit.Button

	local function ownsPremium(): boolean
		return boostState.Owns(GameConfig.Season.PremiumPassId)
	end

	local function currentSeason(): Season.Progress
		local value = dataController:Get({ "Season" })
		return if type(value) == "table" then value else {}
	end

	local function refresh()
		local season = currentSeason()
		local owns = ownsPremium()
		local xp = if type(season.Xp) == "number" then season.Xp else 0
		local level = Season.Level(xp)
		local claimable = #Season.Claimable(season, owns)
		levelLabel.Text = `Lvl {level}`
		if level >= Season.MaxLevel() then
			bar.SetValue(1)
			bar.SetText("MAX")
		else
			local into = xp % GameConfig.Season.XpPerLevel
			bar.SetValue(into / GameConfig.Season.XpPerLevel)
			bar.SetText(`{into}/{GameConfig.Season.XpPerLevel} XP`)
		end
		for _, tile in tiles do
			local isClaimed = tile.Level <= Season.Claimed(season, tile.Premium)
			local isReached = tile.Level <= level
			local isLockedByPass = tile.Premium and not owns
			if isClaimed then
				Kit.Paint(tile.Panel, theme.Grey)
				tile.Mark.Visible = true
				tile.Mark:Destroy()
				tile.Mark = Kit.Icon({
					Parent = tile.Panel,
					Name = "Mark",
					Glyph = "Check",
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.new(1, -4, 0, 4),
					Size = UDim2.fromOffset(30, 30),
				})
			elseif isLockedByPass then
				Kit.Paint(tile.Panel, lockedColor)
				tile.Mark.Visible = true
			elseif isReached then
				local isNext = tile.Level == Season.Claimed(season, tile.Premium) + 1
				Kit.Paint(tile.Panel, if isNext then theme.Green else reachedColor)
				tile.Mark.Visible = false
			else
				Kit.Paint(tile.Panel, lockedColor)
				tile.Mark.Visible = true
			end
		end
		passButton.SetText(
			if owns
				then "OWNED"
				elseif premiumPass and Purchases.IsAvailable(premiumPass) then "Premium Pass"
				else "SOON"
		)
		passButton.SetColor(if owns then theme.Green else theme.Purple)
		claimButton.SetDisabled(claimable == 0 and not isBusy)
		claimButton.SetGlow(claimable > 0)
	end

	claimButton = Kit.Button(trove, {
		Parent = footer,
		Name = "Claim",
		Text = "CLAIM",
		Position = UDim2.new(1, 0, 0.5, 0),
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.fromOffset(180, 56),
		Color = theme.Green,
		TextSize = 30,
		Callback = function()
			if isBusy then
				return
			end
			local claims = Season.Claimable(currentSeason(), ownsPremium())
			if #claims == 0 then
				playUi("Error")
				context.Toast("Nothing to claim yet!", "Bad")
				return
			end
			isBusy = true
			task.spawn(function()
				local granted = 0
				for _, claim in claims do
					local ok = Packets.ClaimSeason:Fire(claim.Level, claim.Premium)
					if ok ~= true then
						break
					end
					granted += 1
					task.wait(claimDelay)
				end
				isBusy = false
				if granted > 0 then
					playUi("Confirm")
					context.Toast(`Claimed {granted} reward{if granted == 1 then "" else "s"}!`, "Good")
				else
					playUi("Error")
					context.Toast("Couldn't claim that!", "Bad")
				end
				refresh()
			end)
		end,
		Sound = playUi,
	})

	trove:Add(dataController:Observe({ "Season" }, function(_value: any)
		if isOpen then
			refresh()
		end
	end))

	local elapsed = 0
	trove:Connect(RunService.Heartbeat, function(dt: number)
		if not isOpen then
			return
		end
		elapsed += dt
		if elapsed >= refreshSeconds then
			elapsed = 0
			refresh()
		end
	end)

	return {
		Modal = true,
		StartsOpen = false,
		Open = function(_self: Types.Screen)
			isOpen = true
			refresh()
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

return SeasonScreen
