--!strict

local Kit = require(script.Parent.Parent.Parent.Kit)
local Layout = require(script.Parent.Parent.Parent.HudLayout)
local Types = require(script.Parent.Types)

local RollBar = {}

function RollBar.Build(env: Types.Env, myBaseButton: Kit.Button): Frame
	local trove = env.Trove
	local root = env.Root
	local context = env.Context
	local rollController = env.RollController
	local theme = Kit.Theme
	local margin = Layout.Margin
	local cell = Layout.Cell
	local rollWidth = Layout.RollWidth
	local rollHeight = Layout.RollHeight
	local barGap = Layout.BarGap
	local barHalfWidth = Layout.BarHalfWidth
	local sideReserve = Layout.SideReserve
	local bottom = Instance.new("Frame")
	bottom.Name = "Bottom"
	bottom.BackgroundTransparency = 1
	bottom.AnchorPoint = Vector2.new(0.5, 1)
	bottom.Position = UDim2.new(0.5, 0, 1, -margin)
	bottom.Size = UDim2.fromOffset(0, rollHeight)
	local fitScale = Instance.new("UIScale")
	fitScale.Name = "FitScale"
	fitScale.Parent = bottom
	bottom.Parent = root
	local function fit()
		local viewport = root:FindFirstChild("ViewportScale")
		local factor = if viewport
				and viewport:IsA("UIScale")
				and viewport.Scale > 0
			then viewport.Scale
			else 1
		local available = root.AbsoluteSize.X / factor - 2 * sideReserve
		fitScale.Scale = math.clamp(available / (2 * barHalfWidth), 0.5, 1)
	end
	fit()
	trove:Connect(root:GetPropertyChangedSignal("AbsoluteSize"), fit)

	local pulseSeconds = 1.8
	local pulseToken = 0
	local function pulseMyBase()
		pulseToken += 1
		local mine = pulseToken
		myBaseButton.SetGlow(true)
		Kit.Pulse(myBaseButton.Instance)
		Kit.Later(trove, pulseSeconds, function()
			if pulseToken == mine then
				myBaseButton.SetGlow(false)
			end
		end)
	end

	local rollHolder = Instance.new("Frame")
	rollHolder.Name = "RollHolder"
	rollHolder.BackgroundTransparency = 1
	rollHolder.AnchorPoint = Vector2.new(0.5, 1)
	rollHolder.Position = UDim2.new(0, 0, 1, 0)
	rollHolder.Size = UDim2.fromOffset(rollWidth, rollHeight)
	local rollBreath = Instance.new("UIScale")
	rollBreath.Name = "IdleScale"
	rollBreath.Parent = rollHolder
	rollHolder.Parent = bottom
	Kit.Breathe(trove, rollBreath, 0.035, 0.9)
	local rollButton = Kit.Button(trove, {
		Parent = rollHolder,
		Name = "Roll",
		Text = "ROLL!",
		Size = UDim2.fromScale(1, 1),
		Color = theme.Gold,
		TextSize = Kit.Text.Hero,
		Title = true,
		Lip = 10,
		Immediate = true,
		Callback = function()
			if not rollController:IsInBase() then
				context.Toast("Go to your base to roll!", "Bad")
				pulseMyBase()
				return
			end
			rollController:RequestRoll()
		end,
	})
	local baseTag = Kit.Panel({
		Parent = rollHolder,
		Name = "BaseTag",
		Size = UDim2.fromOffset(150, 24),
		Position = UDim2.new(0.5, 0, 0, -12),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = theme.Red,
		StrokeThickness = Kit.StrokeSize.Thin,
		Pill = true,
	})
	baseTag.ZIndex = Kit.ZIndex.BadgeText
	baseTag.Visible = false
	local baseTagText = Kit.Label({
		Parent = baseTag,
		Name = "Text",
		Text = "GO TO YOUR BASE",
		Size = UDim2.fromScale(1, 1),
		TextSize = Kit.Text.Small,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	baseTagText.ZIndex = Kit.ZIndex.Float
	local function showBaseState(isInBase: boolean)
		rollButton.SetColor(if isInBase then theme.Gold else theme.Grey)
		baseTag.Visible = not isInBase
	end
	showBaseState(rollController:IsInBase())
	trove:Add(rollController.InBaseChanged:Connect(showBaseState))
	local hint = Kit.Panel({
		Parent = rollHolder,
		Name = "KeyHint",
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.fromOffset(-10, -12),
		Color = theme.Track,
		StrokeColor = theme.Text,
		StrokeThickness = Kit.StrokeSize.Thin,
		Radius = Kit.Radius.M,
		Flat = true,
	})
	hint.ZIndex = Kit.ZIndex.BadgeText
	local hintLabel = Kit.Label({
		Parent = hint,
		Name = "Key",
		Text = "E",
		Size = UDim2.fromScale(1, 1),
		TextSize = Kit.Text.Subhead,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	hintLabel.ZIndex = Kit.ZIndex.Float

	local autoButton = Kit.Button(trove, {
		Parent = bottom,
		Name = "Auto",
		Glyph = "Auto",
		Text = "AUTO",
		Size = UDim2.fromOffset(cell, cell),
		Position = UDim2.new(0, -(rollWidth / 2 + barGap), 1, 0),
		AnchorPoint = Vector2.new(1, 1),
		Color = theme.Grey,
		TextSize = Kit.Text.Label,
		IconScale = 0.6,
		Tooltip = "Roll over and over by itself!",
		TooltipSide = "Above",
		Callback = function()
			rollController:SetAuto(not rollController:IsAuto())
		end,
	})
	local autoChip = Kit.Panel({
		Parent = autoButton.Instance,
		Name = "State",
		Size = UDim2.fromOffset(44, 24),
		Position = UDim2.new(0.5, 0, 0, -10),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = theme.Grey,
		StrokeThickness = Kit.StrokeSize.Thin,
		Pill = true,
	})
	autoChip.ZIndex = Kit.ZIndex.Badge
	local autoChipText = Kit.Label({
		Parent = autoChip,
		Name = "Text",
		Text = "OFF",
		Size = UDim2.fromScale(1, 1),
		TextSize = Kit.Text.Small,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	autoChipText.ZIndex = Kit.ZIndex.BadgeText
	local function showAuto(isOn: boolean)
		autoButton.SetColor(if isOn then theme.Green else theme.Grey)
		autoButton.SetGlow(isOn)
		autoChipText.Text = if isOn then "ON" else "OFF"
		Kit.Paint(autoChip, if isOn then theme.Green else theme.Grey)
	end
	showAuto(rollController:IsAuto())
	trove:Add(rollController.AutoChanged:Connect(showAuto))
	return bottom
end

return RollBar
