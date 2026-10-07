--!strict

local Config = require(script.Parent.Config)

export type Cap = {
	Root: any,
	Face: any,
	Skirt: any,
	Label: any,
	Scale: any,
	Travel: number,
	Height: number,
	Width: number,
}

export type Options = {
	Parent: any,
	Size: Vector2,
	Color: Color3,
	Letter: string,
	Position: UDim2,
	Stroke: number,
	Travel: number,
}

local Keycap = {}

local white = Color3.new(1, 1, 1)
local black = Color3.new(0, 0, 0)
local pressedTint = Color3.fromRGB(150, 150, 172)

local function create(className: string, props: { [string]: any }): any
	local item: any = Instance.new(className :: any)
	for key, value in props do
		item[key] = value
	end
	return item
end

local function outline(parent: any, thickness: number)
	create("UIStroke", { Color = Config.Outline, Thickness = thickness, Parent = parent })
end

function Keycap.Depth(t: number): number
	if t < 0 then
		return 0
	end
	if t < Config.PressDown then
		return t / Config.PressDown
	end
	local u = t - Config.PressDown
	if u > 0.45 then
		return 0
	end
	return math.max(math.exp(-9 * u) * math.cos(16 * u), -0.25)
end

function Keycap.new(options: Options): Cap
	local width, height = options.Size.X, options.Size.Y
	local lip = math.max(2, math.round(height * 0.1))
	local radius = UDim.new(0, math.max(5, math.round(width * 0.14)))
	local root = create("Frame", {
		Name = "Key",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = options.Position,
		Size = UDim2.fromOffset(width, height + lip),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Parent = options.Parent,
	})
	local scale = create("UIScale", { Scale = 1, Parent = root })
	local skirt = create("Frame", {
		Name = "Skirt",
		Position = UDim2.fromOffset(0, lip),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = options.Color:Lerp(black, 0.45),
		BorderSizePixel = 0,
		Parent = root,
	})
	create("UICorner", { CornerRadius = radius, Parent = skirt })
	outline(skirt, options.Stroke)
	local face = create("Frame", {
		Name = "Face",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(width, height),
		BackgroundColor3 = white,
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = root,
	})
	create("UICorner", { CornerRadius = radius, Parent = face })
	outline(face, options.Stroke)
	create("UIGradient", {
		Name = "Shade",
		Rotation = 90,
		Color = ColorSequence.new(options.Color:Lerp(white, 0.4), options.Color),
		Parent = face,
	})
	local gloss = create("Frame", {
		Name = "Gloss",
		Position = UDim2.fromScale(0.12, 0.07),
		Size = UDim2.fromScale(0.76, 0.26),
		BackgroundColor3 = white,
		BackgroundTransparency = 0.72,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = face,
	})
	create("UICorner", { CornerRadius = UDim.new(0, math.round(width * 0.14)), Parent = gloss })
	local label = create("TextLabel", {
		Name = "Letter",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = options.Letter,
		Font = Enum.Font.FredokaOne,
		TextColor3 = white,
		TextSize = math.round(height * 0.6),
		ZIndex = 4,
		Parent = face,
	})
	outline(label, math.max(2, options.Stroke - 0.5))
	return {
		Root = root,
		Face = face,
		Skirt = skirt,
		Label = label,
		Scale = scale,
		Travel = options.Travel,
		Height = height,
		Width = width,
	}
end

function Keycap.SetPress(cap: Cap, depth: number)
	cap.Face.Position = UDim2.fromOffset(0, math.round(depth * cap.Travel))
	cap.Face.BackgroundColor3 = white:Lerp(pressedTint, math.clamp(depth, 0, 1) * 0.5)
	cap.Skirt.Size = UDim2.fromOffset(cap.Width, cap.Height - math.round(math.max(depth, 0) * 3))
end

function Keycap.SetColor(cap: Cap, color: Color3)
	cap.Face.Shade.Color = ColorSequence.new(color:Lerp(white, 0.4), color)
	cap.Skirt.BackgroundColor3 = color:Lerp(black, 0.45)
end

return Keycap
