--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local CharmConfig = require(ReplicatedStorage.Config.Charms)
local Eggs = require(ReplicatedStorage.Config.Eggs)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Charms = require(ReplicatedStorage.Rules.Charms)
local EggArt = require(script.Parent.Parent.EggArt)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)

type TroveInstance = typeof(Trove.new())

local theme = Kit.Theme
local crackTimes = { 0.7, 1.2, 1.7, 2.1 }
local wobbleEnd = 2.2
local flashEnd = 2.55
local revealSeconds = 0.5
local eggSize = 250

local HatchScreen = {}

local function backOut(alpha: number): number
	local c1 = 1.70158
	local c3 = c1 + 1
	local t = alpha - 1
	return 1 + c3 * t ^ 3 + c1 * t ^ 2
end

function HatchScreen.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local playUi = Kit.UiSound(context.Controllers)
	local elapsed = 0
	local isPlaying = false
	local lastStage = -1
	local playedPop = false

	local gui, root = Kit.ScreenGui("ThockHatch", 30, context.PlayerGui, trove)
	gui.Enabled = false
	local backdrop = Instance.new("Frame")
	backdrop.Name = "Backdrop"
	backdrop.BackgroundColor3 = theme.Ink
	backdrop.BackgroundTransparency = 0.25
	backdrop.BorderSizePixel = 0
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Active = true
	backdrop.Parent = root

	local rays = Kit.Burst({
		Parent = root,
		Diameter = 720,
		Position = UDim2.fromScale(0.5, 0.47),
		Color = Color3.new(1, 1, 1),
	})
	rays.Visible = false

	local eggHolder = Instance.new("Frame")
	eggHolder.Name = "EggStage"
	eggHolder.BackgroundTransparency = 1
	eggHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	eggHolder.Position = UDim2.fromScale(0.5, 0.47)
	eggHolder.Size = UDim2.fromOffset(eggSize, eggSize)
	eggHolder.Parent = root
	local eggScale = Instance.new("UIScale")
	eggScale.Parent = eggHolder
	local eggCluster = Instance.new("Frame")
	eggCluster.Name = "Cluster"
	eggCluster.BackgroundTransparency = 1
	eggCluster.AnchorPoint = Vector2.new(0.5, 0.5)
	eggCluster.Position = UDim2.fromScale(0.5, 0.5)
	eggCluster.Size = UDim2.fromScale(1, 1)
	eggCluster.Parent = eggHolder

	local flash = Instance.new("Frame")
	flash.Name = "Flash"
	flash.BackgroundColor3 = Color3.new(1, 1, 1)
	flash.BackgroundTransparency = 1
	flash.BorderSizePixel = 0
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 20
	flash.Parent = root

	local hint = Kit.Label({
		Parent = root,
		Name = "Hint",
		Align = Enum.TextXAlignment.Center,
		Text = "Hatching...",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.47, eggSize / 2 + 24),
		Size = UDim2.fromOffset(400, 44),
		TextSize = 34,
		Title = true,
		Scaled = true,
	})

	local card = Kit.Panel({
		Parent = root,
		Name = "RevealCard",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 360),
		Color = theme.Panel,
		StrokeColor = theme.Gold,
		StrokeThickness = 6,
		Radius = Kit.Radius.Panel,
		Shards = true,
	})
	card.Visible = false
	local cardScale = Instance.new("UIScale")
	cardScale.Parent = card
	local banner = Kit.Label({
		Parent = card,
		Name = "Banner",
		Align = Enum.TextXAlignment.Center,
		Text = "NEW CHARM!",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(1, -24, 0, 40),
		TextSize = 34,
		Title = true,
		Scaled = true,
	})
	local artHolder = Instance.new("Frame")
	artHolder.Name = "Art"
	artHolder.BackgroundTransparency = 1
	artHolder.AnchorPoint = Vector2.new(0.5, 0)
	artHolder.Position = UDim2.new(0.5, 0, 0, 58)
	artHolder.Size = UDim2.fromOffset(96, 96)
	artHolder.Parent = card
	local charmName = Kit.Label({
		Parent = card,
		Name = "CharmName",
		Align = Enum.TextXAlignment.Center,
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 160),
		Size = UDim2.new(1, -24, 0, 40),
		TextSize = 34,
		Title = true,
		Scaled = true,
	})
	local rarityChip = Kit.Chip({
		Parent = card,
		Name = "Rarity",
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 206),
		Size = UDim2.fromOffset(150, 30),
		TextSize = 22,
	})
	local effect = Kit.Label({
		Parent = card,
		Name = "Effect",
		Align = Enum.TextXAlignment.Center,
		Text = "",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 244),
		Size = UDim2.new(1, -24, 0, 48),
		TextSize = 40,
		Title = true,
		Scaled = true,
	})
	Kit.Button(trove, {
		Parent = card,
		Name = "Done",
		Text = "NICE!",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -12),
		Size = UDim2.fromOffset(200, 48),
		Color = theme.Green,
		TextSize = 26,
		Callback = function()
			context.Close("Hatch")
		end,
		Sound = playUi,
	})

	local art: EggArt.Art? = nil
	local currentEgg: Eggs.Egg? = nil
	local currentCharm: CharmConfig.Charm? = nil

	local function render(time: number)
		elapsed = time
		local egg = currentEgg
		local charm = currentCharm
		local current = art
		if not egg or not charm or not current then
			return
		end
		if time < wobbleEnd then
			local amplitude = 4 + 16 * (time / wobbleEnd)
			eggCluster.Rotation = math.sin(time * (9 + time * 4)) * amplitude
			eggScale.Scale = 1 + 0.04 * math.sin(time * 20)
			local stage = 0
			for index, mark in crackTimes do
				if time >= mark then
					stage = index
				end
			end
			if stage ~= lastStage then
				lastStage = stage
				current.Crack(stage)
				if stage > 0 then
					playUi("Click")
				end
			end
			eggHolder.Visible = true
			card.Visible = false
			rays.Visible = false
			hint.Visible = true
			flash.BackgroundTransparency = 1
			return
		end
		hint.Visible = false
		if time < flashEnd then
			local alpha = (time - wobbleEnd) / (flashEnd - wobbleEnd)
			eggCluster.Rotation = 0
			eggScale.Scale = 1 + 0.35 * alpha
			flash.BackgroundTransparency = 1 - math.sin(alpha * math.pi) * 0.95
			eggHolder.Visible = alpha < 0.5
			card.Visible = false
			return
		end
		if not playedPop then
			playedPop = true
			playUi("Confirm")
		end
		flash.BackgroundTransparency = 1
		eggHolder.Visible = false
		rays.Visible = true
		rays.Rotation = (time - flashEnd) * 20
		card.Visible = true
		local alpha = math.clamp((time - flashEnd) / revealSeconds, 0, 1)
		cardScale.Scale = math.max(0.05, 0.3 + 0.7 * backOut(alpha))
	end

	local function start(eggId: string, charmId: string)
		local egg = Eggs.ById[eggId]
		local charm = CharmConfig.ById[charmId]
		if not egg or not charm then
			return
		end
		currentEgg = egg
		currentCharm = charm
		for _, child in eggCluster:GetChildren() do
			child:Destroy()
		end
		art = EggArt.Build(eggCluster, egg, eggSize, "Egg")
		for _, child in artHolder:GetChildren() do
			child:Destroy()
		end
		local kind = CharmConfig.Kinds[charm.Kind]
		Kit.IconPlate({
			Parent = artHolder,
			Name = "Plate",
			Size = UDim2.fromScale(1, 1),
			Color = kind.Color,
			Glyph = kind.Glyph,
			Burst = true,
		})
		local rarity = CharmConfig.RarityByName[charm.Rarity]
		charmName.Text = charm.Name
		rarityChip.Text = rarity.Name
		Kit.Paint(rarityChip.Parent :: Frame, rarity.Color)
		effect.Text = Charms.Describe(charm.Id)
		effect.TextColor3 = kind.Color
		Kit.StrokeOf(card).Color = rarity.Color
		banner.Text = if rarity.Order >= 5 then "AMAZING CHARM!" else "NEW CHARM!"
		lastStage = -1
		playedPop = false
		isPlaying = true
		render(0)
		context.Open("Hatch")
	end

	local charmController = context.Controllers.CharmController
	if charmController then
		trove:Add(charmController.Hatched:Connect(start))
	end

	trove:Connect(RunService.Heartbeat, function(dt: number)
		if isPlaying and gui.Enabled then
			render(elapsed + dt)
		end
	end)

	local screen: any = {
		Modal = false,
		StartsOpen = false,
		Open = function(_self: Types.Screen)
			gui.Enabled = true
		end,
		Close = function(_self: Types.Screen)
			gui.Enabled = false
			isPlaying = false
		end,
		Destroy = function(_self: Types.Screen)
			trove:Destroy()
		end,
		Play = function(_self: any, eggId: string, charmId: string)
			start(eggId, charmId)
		end,
		Seek = function(_self: any, time: number)
			render(time)
		end,
	}
	return screen :: Types.Screen
end

return HatchScreen
