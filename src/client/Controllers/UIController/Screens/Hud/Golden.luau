--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Kit = require(script.Parent.Parent.Parent.Kit)
local Layout = require(script.Parent.Parent.Parent.HudLayout)
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Charms = require(ReplicatedStorage.Rules.Charms)
local Stats = require(ReplicatedStorage.Rules.Stats)
local Types = require(script.Parent.Types)

local Golden = {}

function Golden.Build(env: Types.Env, bottom: Frame)
	local trove = env.Trove
	local dataController = env.DataController
	local theme = Kit.Theme
	local cell = Layout.Cell
	local rollWidth = Layout.RollWidth
	local barGap = Layout.BarGap
	local goldenHolder = Instance.new("Frame")
	goldenHolder.Name = "GoldenHolder"
	goldenHolder.BackgroundTransparency = 1
	goldenHolder.AnchorPoint = Vector2.new(0, 1)
	goldenHolder.Position = UDim2.new(0, rollWidth / 2 + barGap, 1, 0)
	goldenHolder.Size = UDim2.fromOffset(cell, cell)
	local goldenBreath = Instance.new("UIScale")
	goldenBreath.Name = "IdleScale"
	goldenBreath.Parent = goldenHolder
	goldenHolder.Parent = bottom
	local golden = Kit.Panel({
		Parent = goldenHolder,
		Name = "Golden",
		Size = UDim2.fromOffset(cell, cell),
		Color = theme.Track,
		Radius = Kit.Radius.L,
		Flat = true,
	})
	golden.ClipsDescendants = true
	local goldenFill = Instance.new("Frame")
	goldenFill.Name = "Fill"
	goldenFill.BackgroundTransparency = 1
	goldenFill.BorderSizePixel = 0
	goldenFill.ClipsDescendants = true
	goldenFill.AnchorPoint = Vector2.new(0, 1)
	goldenFill.Position = UDim2.fromScale(0, 1)
	goldenFill.Size = UDim2.fromScale(1, 0)
	local goldenBody = Instance.new("Frame")
	goldenBody.Name = "Body"
	goldenBody.BorderSizePixel = 0
	goldenBody.AnchorPoint = Vector2.new(0, 1)
	goldenBody.Position = UDim2.fromScale(0, 1)
	goldenBody.Size = UDim2.fromOffset(cell, cell)
	Kit.Corner(goldenBody, Kit.Radius.L)
	Kit.Paint(goldenBody, theme.GoldenBody)
	Kit.Gloss(goldenBody, Kit.Radius.L)
	goldenBody.Parent = goldenFill
	goldenFill.Parent = golden
	local goldenIcon = Kit.Icon({
		Parent = golden,
		Name = "Icon",
		Glyph = "Golden",
		Size = UDim2.fromScale(1, 0.56),
		Position = UDim2.fromScale(0, 0.06),
	})
	goldenIcon.ZIndex = Kit.ZIndex.Mark
	local goldenLabel = Kit.Label({
		Parent = golden,
		Name = "Progress",
		Text = `0/{GameConfig.GoldenRollEvery}`,
		Position = UDim2.fromScale(0, 0.6),
		Size = UDim2.fromScale(1, 0.34),
		TextSize = Kit.Text.Strong,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	goldenLabel.ZIndex = Kit.ZIndex.Mark
	Kit.Tooltip(trove, golden, "Every few rolls is a Golden key!", "Above")
	local goldenStroke = Kit.StrokeOf(golden)
	local goldenShimmer = Kit.Shimmer(trove, golden, Kit.Radius.L, 1.1)
	goldenShimmer.Visible = false
	local goldenPulse: Tween? = nil
	local isGoldenNext = false
	local function setGoldenNext(value: boolean)
		if value == isGoldenNext then
			return
		end
		isGoldenNext = value
		if goldenPulse then
			goldenPulse:Cancel()
			goldenPulse:Destroy()
			goldenPulse = nil
		end
		goldenStroke.Thickness = Kit.StrokeSize.Normal
		goldenStroke.Color = theme.Ink
		goldenShimmer.Visible = value
		goldenBreath.Scale = 1
		if value then
			goldenStroke.Color = theme.Ring
			goldenPulse = Kit.Tween(goldenBreath, Kit.Motion.Beat, { Scale = 1.08 })
		end
	end
	trove:Add(function()
		if goldenPulse then
			goldenPulse:Cancel()
			goldenPulse:Destroy()
			goldenPulse = nil
		end
	end)
	local function refreshGolden()
		local progress = dataController:Get({ "GoldenProgress" })
		local count = if type(progress) == "number" then progress else 0
		local every = Stats.GoldenEvery(
			dataController:Get({ "Upgrades" }),
			Charms.Effects(dataController:Get({ "EquippedCharms" })).GoldenReduction
		)
		count = math.min(count, every - 1)
		local isNext = count >= every - 1
		goldenLabel.Text = if isNext then "NEXT!" else `{count}/{every}`
		goldenFill.Size = UDim2.fromScale(1, if isNext then 1 else count / every)
		setGoldenNext(isNext)
	end
	trove:Add(dataController:Observe({ "GoldenProgress" }, refreshGolden))
	trove:Add(dataController:Observe({ "Upgrades", "Golden" }, refreshGolden))
	trove:Add(dataController:Observe({ "EquippedCharms" }, refreshGolden))
end

return Golden
