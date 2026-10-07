--!strict

export type Page = { Name: string, Scroll: ScrollingFrame, Tab: TextButton, Order: number }

local confirmSeconds = 3
local confirmText = "CONFIRM?"
local windowWidth = 300
local minWindowWidth = 240
local minWindowHeight = 180
local screenMargin = 16
local gripSize = 14
local edgeThickness = 6
local gripLineLength = 10
local gripLineThickness = 1
local titleHeight = 24
local pad = 4
local inputHeight = 22
local tabHeight = 20
local defaultPageHeight = 236
local statusHeight = 18
local rowHeight = 22
local sectionHeight = 14
local gap = 4
local textSize = 13
local smallTextSize = 12
local radius = 4
local strokeThickness = 1
local scrollBarThickness = 3
local fieldInset = 6
local backgroundTransparency = 0.06
local startLeft = 220
local startTop = 96
local minVisible = 40
local defaultCount = "1"
local defaultStatus = "ready"
local noResponseText = "No response"
local amountPrompt = "Enter an amount"
local errorPrefixes = { "Not allowed", "No response", "Bad", "Usage", "Unknown", "Enter" }
local tabNames = { "MONEY", "PROGRESS", "ITEMS", "DANGER" }
local font = Enum.Font.Code

local palette = {
	Background = Color3.fromRGB(14, 15, 18),
	Bar = Color3.fromRGB(24, 25, 30),
	Stroke = Color3.fromRGB(58, 60, 68),
	Button = Color3.fromRGB(34, 36, 43),
	Hover = Color3.fromRGB(48, 51, 60),
	Selected = Color3.fromRGB(62, 66, 78),
	Field = Color3.fromRGB(10, 11, 13),
	Text = Color3.fromRGB(208, 212, 220),
	Dim = Color3.fromRGB(128, 133, 144),
	Good = Color3.fromRGB(122, 190, 140),
	Bad = Color3.fromRGB(214, 112, 112),
	Warn = Color3.fromRGB(196, 150, 86),
}

local function trim(text: string): string
	return (string.gsub(text, "^%s*(.-)%s*$", "%1"))
end

local function isError(text: string): boolean
	for _, prefix in errorPrefixes do
		if string.sub(text, 1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local function round(target: Instance)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = target
end

local function outline(target: Instance)
	local stroke = Instance.new("UIStroke")
	stroke.Color = palette.Stroke
	stroke.Thickness = strokeThickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = target
end

local function newLabel(parent: Instance, name: string, text: string, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = font
	label.TextSize = textSize
	label.TextColor3 = color
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextTruncate = Enum.TextTruncate.AtEnd
	label.Text = text
	label.Parent = parent
	return label
end

local function newButton(parent: Instance, name: string, text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = false
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Font = font
	button.TextSize = smallTextSize
	button.TextColor3 = palette.Text
	button.TextTruncate = Enum.TextTruncate.AtEnd
	button.Text = text
	button.Parent = parent
	round(button)
	return button
end

local function newBox(parent: Instance, name: string, placeholder: string, text: string): TextBox
	local box = Instance.new("TextBox")
	box.Name = name
	box.BackgroundColor3 = palette.Field
	box.BorderSizePixel = 0
	box.Font = font
	box.TextSize = smallTextSize
	box.TextColor3 = palette.Text
	box.PlaceholderText = placeholder
	box.PlaceholderColor3 = palette.Dim
	box.TextXAlignment = Enum.TextXAlignment.Left
	box.ClearTextOnFocus = false
	box.Text = text
	box.Parent = parent
	round(box)
	outline(box)
	local inset = Instance.new("UIPadding")
	inset.PaddingLeft = UDim.new(0, fieldInset)
	inset.PaddingRight = UDim.new(0, fieldInset)
	inset.Parent = box
	return box
end

return table.freeze({
	Style = table.freeze({
		ConfirmSeconds = confirmSeconds,
		ConfirmText = confirmText,
		WindowWidth = windowWidth,
		MinWindowWidth = minWindowWidth,
		MinWindowHeight = minWindowHeight,
		ScreenMargin = screenMargin,
		GripSize = gripSize,
		EdgeThickness = edgeThickness,
		GripLineLength = gripLineLength,
		GripLineThickness = gripLineThickness,
		TitleHeight = titleHeight,
		Pad = pad,
		InputHeight = inputHeight,
		TabHeight = tabHeight,
		DefaultPageHeight = defaultPageHeight,
		StatusHeight = statusHeight,
		RowHeight = rowHeight,
		SectionHeight = sectionHeight,
		Gap = gap,
		TextSize = textSize,
		SmallTextSize = smallTextSize,
		Radius = radius,
		StrokeThickness = strokeThickness,
		ScrollBarThickness = scrollBarThickness,
		FieldInset = fieldInset,
		BackgroundTransparency = backgroundTransparency,
		StartLeft = startLeft,
		StartTop = startTop,
		MinVisible = minVisible,
		DefaultCount = defaultCount,
		DefaultStatus = defaultStatus,
		NoResponseText = noResponseText,
		AmountPrompt = amountPrompt,
		TabNames = tabNames,
	}),
	Palette = palette,
	Font = font,
	Trim = trim,
	IsError = isError,
	Round = round,
	Outline = outline,
	NewLabel = newLabel,
	NewButton = newButton,
	NewBox = newBox,
})
