--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Eggs = require(ReplicatedStorage.Config.Eggs)
local Kit = require(script.Parent.Kit)

export type Art = {
	Root: Frame,
	Body: Frame,
	Crack: (stage: number) -> (),
}

local theme = Kit.Theme
local spots = {
	{ 0.30, 0.38, 0.17 },
	{ 0.66, 0.30, 0.12 },
	{ 0.58, 0.58, 0.2 },
	{ 0.26, 0.70, 0.12 },
	{ 0.72, 0.78, 0.1 },
}
local crackLines = {
	{ 0.5, 0.18, 0.62, 0.34, 25 },
	{ 0.62, 0.34, 0.44, 0.5, -30 },
	{ 0.44, 0.5, 0.6, 0.66, 28 },
	{ 0.6, 0.66, 0.5, 0.82, -22 },
}
local rainbow = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 120)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 200, 60)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 230, 140)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(80, 170, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(190, 110, 255)),
})

local EggArt = {}

function EggArt.Build(parent: Instance, egg: Eggs.Egg, height: number, name: string?): Art
	local root = Instance.new("Frame")
	root.Name = name or "EggArt"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(height, height)
	root.Parent = parent
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.5)
	body.Size = UDim2.fromOffset(height * 0.78, height)
	body.BorderSizePixel = 0
	body.BackgroundColor3 = egg.Color
	body.Parent = root
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.5, 0)
	corner.Parent = body
	local stroke = Instance.new("UIStroke")
	stroke.Color = theme.Ink
	stroke.Thickness = 4
	stroke.Parent = body
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 90
	if egg.Id == "Rainbow" then
		body.BackgroundColor3 = theme.White
		gradient.Color = rainbow
		gradient.Rotation = 60
	else
		gradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Kit.Shade(egg.Color, 0.3)),
			ColorSequenceKeypoint.new(0.5, egg.Color),
			ColorSequenceKeypoint.new(1, Kit.Shade(egg.Color, -0.2)),
		})
	end
	gradient.Parent = body
	for index, spot in spots do
		local dot = Instance.new("Frame")
		dot.Name = `Spot{index}`
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(spot[1], spot[2])
		dot.Size = UDim2.fromScale(spot[3], spot[3] / 0.78)
		dot.BorderSizePixel = 0
		dot.BackgroundColor3 = egg.SpotColor
		dot.BackgroundTransparency = 0.1
		dot.Parent = body
		local dotCorner = Instance.new("UICorner")
		dotCorner.CornerRadius = UDim.new(0.5, 0)
		dotCorner.Parent = dot
	end
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.Position = UDim2.fromScale(0.16, 0.12)
	shine.Size = UDim2.fromScale(0.14, 0.24)
	shine.BorderSizePixel = 0
	shine.BackgroundColor3 = theme.White
	shine.BackgroundTransparency = 0.45
	shine.Rotation = 18
	shine.Parent = body
	local shineCorner = Instance.new("UICorner")
	shineCorner.CornerRadius = UDim.new(0.5, 0)
	shineCorner.Parent = shine
	local cracks: { Frame } = {}
	for index, line in crackLines do
		local crack = Instance.new("Frame")
		crack.Name = `Crack{index}`
		crack.AnchorPoint = Vector2.new(0.5, 0.5)
		crack.Position = UDim2.fromScale((line[1] + line[3]) / 2, (line[2] + line[4]) / 2)
		crack.Size = UDim2.fromScale(0.08, 0.22)
		crack.Rotation = line[5]
		crack.BorderSizePixel = 0
		crack.BackgroundColor3 = theme.Ink
		crack.Visible = false
		crack.ZIndex = Kit.ZIndex.Fill
		crack.Parent = body
		table.insert(cracks, crack)
	end
	return {
		Root = root,
		Body = body,
		Crack = function(stage: number)
			for index, crack in cracks do
				crack.Visible = index <= stage
			end
		end,
	}
end

return EggArt
