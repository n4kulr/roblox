--!strict

local Config = require(script.Parent.Config)

export type Cap = {
	Root: Frame,
	Face: Frame,
	Label: TextLabel,
	Index: number,
	IsLit: boolean,
}

export type Options = {
	Parent: Instance,
	Letter: string,
	Index: number,
	LayoutOrder: number,
	WidthScale: number,
}

local Keycap = {}

local white = Color3.new(1, 1, 1)

local function create(className: string, props: { [string]: any }): any
	local item: any = Instance.new(className :: any)
	for key, value in props do
		item[key] = value
	end
	return item
end

function Keycap.new(options: Options): Cap
	local root = create("Frame", {
		Name = `Key_{options.Index}`,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(options.WidthScale, 1),
		LayoutOrder = options.LayoutOrder,
		Parent = options.Parent,
	})
	local face = create("Frame", {
		Name = "Face",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Config.Unlit,
		BorderSizePixel = 0,
		Parent = root,
	})
	create("UICorner", { CornerRadius = UDim.new(0, 6), Parent = face })
	create("UIStroke", {
		Color = Config.Outline,
		Thickness = 2,
		Transparency = 0.15,
		Parent = face,
	})
	local label = create("TextLabel", {
		Name = "Letter",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Text = options.Letter,
		Font = Enum.Font.FredokaOne,
		TextColor3 = white,
		TextScaled = true,
		Parent = face,
	})
	create("UIPadding", {
		PaddingTop = UDim.new(0.18, 0),
		PaddingBottom = UDim.new(0.18, 0),
		PaddingLeft = UDim.new(0.08, 0),
		PaddingRight = UDim.new(0.08, 0),
		Parent = label,
	})
	create("UIStroke", {
		Color = Config.Outline,
		Thickness = 1.5,
		Transparency = 0.25,
		Parent = label,
	})
	return {
		Root = root,
		Face = face,
		Label = label,
		Index = options.Index,
		IsLit = false,
	}
end

function Keycap.SetLit(cap: Cap, isLit: boolean, color: Color3)
	cap.IsLit = isLit
	cap.Face.BackgroundColor3 = if isLit then color else Config.Unlit
	cap.Label.TextTransparency = if isLit then 0 else 0.35
end

return Keycap
