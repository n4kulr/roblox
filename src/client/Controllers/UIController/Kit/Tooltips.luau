--!strict

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local Labels = require(script.Parent.Labels)
local Primitives = require(script.Parent.Primitives)
local Theme = require(script.Parent.Theme)

type TroveInstance = typeof(Trove.new())

local colors = Theme.Colors

local Tooltips = {}

function Tooltips.Build(root: GuiObject, text: string, side: string): Frame
	local tip = Instance.new("Frame")
	tip.Name = "Tooltip"
	tip.BackgroundColor3 = colors.Ink
	tip.BorderSizePixel = 0
	tip.AutomaticSize = Enum.AutomaticSize.X
	tip.Size = UDim2.fromOffset(0, 34)
	tip.ZIndex = Theme.ZIndex.Tooltip
	tip.Visible = false
	if side == "Left" then
		tip.AnchorPoint = Vector2.new(1, 0.5)
		tip.Position = UDim2.new(0, -12, 0.5, 0)
	elseif side == "Above" then
		tip.AnchorPoint = Vector2.new(0.5, 1)
		tip.Position = UDim2.new(0.5, 0, 0, -10)
	elseif side == "Below" then
		tip.AnchorPoint = Vector2.new(0.5, 0)
		tip.Position = UDim2.new(0.5, 0, 1, 10)
	else
		tip.AnchorPoint = Vector2.new(0, 0.5)
		tip.Position = UDim2.new(1, 12, 0.5, 0)
	end
	Primitives.Corner(tip, 10)
	local edge = Primitives.Stroke(tip, colors.Text, Theme.Stroke.Thin)
	edge.Transparency = Theme.Transparency.Heavy
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, Theme.Space.M)
	padding.PaddingRight = UDim.new(0, Theme.Space.M)
	padding.Parent = tip
	local label = Labels.Label({
		Parent = tip,
		Name = "Text",
		Text = text,
		Size = UDim2.fromOffset(0, 34),
		TextSize = Theme.Text.Note,
		Outline = false,
		Align = Enum.TextXAlignment.Center,
	})
	label.AutomaticSize = Enum.AutomaticSize.X
	label.TextTruncate = Enum.TextTruncate.None
	label.ZIndex = Theme.ZIndex.TooltipText
	tip.Parent = root
	return tip
end

function Tooltips.Tooltip(trove: TroveInstance, target: GuiObject, text: string, side: string?): Frame
	local tip = Tooltips.Build(target, text, side or "Above")
	local hit = Instance.new("TextButton")
	hit.Name = "Hover"
	hit.AutoButtonColor = false
	hit.BackgroundTransparency = 1
	hit.BorderSizePixel = 0
	hit.Text = ""
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = Theme.ZIndex.Hit
	hit.Parent = target
	trove:Connect(hit.MouseEnter, function()
		if UserInputService:GetLastInputType() == Enum.UserInputType.MouseMovement then
			tip.Visible = true
		end
	end)
	trove:Connect(hit.MouseLeave, function()
		tip.Visible = false
	end)
	return tip
end

return Tooltips
