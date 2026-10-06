local roblox = require("@lune/roblox")
local Tree = require("../../tests/harness/Tree")
local Text = require("./Text")

local Layout = {}

local topInset = 58

local guiClasses: { [string]: boolean } = {
	Frame = true,
	TextLabel = true,
	TextButton = true,
	TextBox = true,
	ImageLabel = true,
	ImageButton = true,
	ScrollingFrame = true,
	CanvasGroup = true,
}
local textClasses: { [string]: boolean } = { TextLabel = true, TextButton = true, TextBox = true }
local imageClasses: { [string]: boolean } = { ImageLabel = true, ImageButton = true }

local zeroUdim2 = roblox.UDim2.new(0, 0, 0, 0)
local zeroVector = roblox.Vector2.new(0, 0)
local zeroUdim = roblox.UDim.new(0, 0)

local function read(node: any, key: string, default: any): any
	local ok, value = pcall(function()
		return node[key]
	end)
	if not ok or value == nil or Tree.isNode(value) then
		return default
	end
	return value
end

local function enumName(value: any): string
	if type(value) == "string" then
		return value
	end
	return value.Name
end

local function round(value: number): number
	if value ~= value or value == math.huge or value == -math.huge then
		return 0
	end
	return math.floor(value * 100 + 0.5) / 100
end

local function rgb(color: any): { number }
	return { math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5) }
end

local function modifiersOf(node: any)
	local mods: any = { Strokes = {}, Gradients = {}, Children = {} }
	for _, child in node:GetChildren() do
		local class = child.ClassName
		if class == "UICorner" then
			mods.Corner = mods.Corner or child
		elseif class == "UIStroke" then
			table.insert(mods.Strokes, child)
		elseif class == "UIGradient" then
			table.insert(mods.Gradients, child)
		elseif class == "UIPadding" then
			mods.Padding = mods.Padding or child
		elseif class == "UIListLayout" then
			mods.List = mods.List or child
		elseif class == "UIGridLayout" then
			mods.Grid = mods.Grid or child
		elseif class == "UIAspectRatioConstraint" then
			mods.Aspect = mods.Aspect or child
		elseif class == "UISizeConstraint" then
			mods.SizeLimit = mods.SizeLimit or child
		elseif class == "UITextSizeConstraint" then
			mods.TextLimit = mods.TextLimit or child
		elseif class == "UIScale" then
			mods.Scale = mods.Scale or child
		elseif guiClasses[class] then
			table.insert(mods.Children, child)
		end
	end
	return mods
end

local function constrain(mods: any, width: number, height: number, k: number): (number, number)
	local aspect = mods.Aspect
	if aspect then
		local ratio = read(aspect, "AspectRatio", 1)
		local axis = enumName(read(aspect, "DominantAxis", "Width"))
		local kind = enumName(read(aspect, "AspectType", "FitWithinMaxSize"))
		if kind == "ScaleWithParentSize" then
			if axis == "Height" then
				width = height * ratio
			else
				height = width / ratio
			end
		elseif width <= 0 then
			width = height * ratio
		elseif height <= 0 then
			height = width / ratio
		elseif width / height > ratio then
			width = height * ratio
		else
			height = width / ratio
		end
	end
	local limit = mods.SizeLimit
	if limit then
		local minimum = read(limit, "MinSize", zeroVector)
		local maximum = read(limit, "MaxSize", roblox.Vector2.new(math.huge, math.huge))
		width = math.clamp(width, minimum.X * k, math.max(maximum.X * k, minimum.X * k))
		height = math.clamp(height, minimum.Y * k, math.max(maximum.Y * k, minimum.Y * k))
	end
	return width, height
end

local function alignmentFraction(name: string): number
	if name == "Center" then
		return 0.5
	elseif name == "Right" or name == "Bottom" then
		return 1
	end
	return 0
end

local function sortItems(items: { any }, order: string)
	local indexed = {}
	for index, item in items do
		table.insert(indexed, { Node = item, Index = index })
	end
	table.sort(indexed, function(a: any, b: any)
		if order == "Name" then
			if a.Node.Name ~= b.Node.Name then
				return a.Node.Name < b.Node.Name
			end
		elseif order ~= "Custom" then
			local la = read(a.Node, "LayoutOrder", 0)
			local lb = read(b.Node, "LayoutOrder", 0)
			if la ~= lb then
				return la < lb
			end
		end
		return a.Index < b.Index
	end)
	for index, entry in indexed do
		items[index] = entry.Node
	end
end

local buildNode

local function paddingOf(mods: any, w: number, h: number, k: number): (number, number, number, number)
	local pad = mods.Padding
	if not pad then
		return 0, 0, 0, 0
	end
	local function side(key: string, basis: number): number
		local value = read(pad, key, zeroUdim)
		return value.Scale * basis + value.Offset * k
	end
	return side("PaddingLeft", w), side("PaddingRight", w), side("PaddingTop", h), side("PaddingBottom", h)
end

local function layoutChildren(mods: any, w: number, h: number, k: number, scrollAxisX: boolean?, scrollAxisY: boolean?)
	local padL, padR, padT, padB = paddingOf(mods, w, h, k)
	local innerW = math.max(0, w - padL - padR)
	local innerH = math.max(0, h - padT - padB)
	local items = {}
	for _, child in mods.Children do
		if read(child, "Visible", true) then
			table.insert(items, child)
		end
	end
	local records: { any } = {}
	local naturalW, naturalH = 0, 0

	if mods.List then
		local list = mods.List
		sortItems(items, enumName(read(list, "SortOrder", "LayoutOrder")))
		local isHorizontal = enumName(read(list, "FillDirection", "Vertical")) == "Horizontal"
		local gap = read(list, "Padding", zeroUdim)
		local gapPx = gap.Scale * (if isHorizontal then innerW else innerH) + gap.Offset * k
		local horizontalAlign = alignmentFraction(enumName(read(list, "HorizontalAlignment", "Left")))
		local verticalAlign = alignmentFraction(enumName(read(list, "VerticalAlignment", "Top")))
		local mainTotal = 0
		local crossMax = 0
		for index, child in items do
			local record = buildNode(child, innerW, innerH, k)
			table.insert(records, record)
			mainTotal += if isHorizontal then record.w else record.h
			if index > 1 then
				mainTotal += gapPx
			end
			crossMax = math.max(crossMax, if isHorizontal then record.h else record.w)
		end
		local cursor = if isHorizontal then (innerW - mainTotal) * horizontalAlign else (innerH - mainTotal) * verticalAlign
		for _, record in records do
			if isHorizontal then
				record.x = padL + cursor
				record.y = padT + (innerH - record.h) * verticalAlign
				cursor += record.w + gapPx
			else
				record.y = padT + cursor
				record.x = padL + (innerW - record.w) * horizontalAlign
				cursor += record.h + gapPx
			end
		end
		if isHorizontal then
			naturalW, naturalH = mainTotal, crossMax
		else
			naturalW, naturalH = crossMax, mainTotal
		end
		naturalW += padL + padR
		naturalH += padT + padB
	elseif mods.Grid then
		local grid = mods.Grid
		sortItems(items, enumName(read(grid, "SortOrder", "LayoutOrder")))
		local cell = read(grid, "CellSize", roblox.UDim2.new(0, 100, 0, 100))
		local gap = read(grid, "CellPadding", roblox.UDim2.new(0, 5, 0, 5))
		local cellW = cell.X.Scale * innerW + cell.X.Offset * k
		local cellH = cell.Y.Scale * innerH + cell.Y.Offset * k
		local gapX = gap.X.Scale * innerW + gap.X.Offset * k
		local gapY = gap.Y.Scale * innerH + gap.Y.Offset * k
		local isHorizontal = enumName(read(grid, "FillDirection", "Horizontal")) == "Horizontal"
		local horizontalAlign = alignmentFraction(enumName(read(grid, "HorizontalAlignment", "Left")))
		local verticalAlign = alignmentFraction(enumName(read(grid, "VerticalAlignment", "Top")))
		local columns = math.max(1, math.floor((innerW + gapX) / (cellW + gapX) + 1e-6))
		local rows = math.max(1, math.floor((innerH + gapY) / (cellH + gapY) + 1e-6))
		local count = #items
		local usedColumns, usedRows
		if isHorizontal then
			usedColumns = math.min(count, columns)
			usedRows = math.ceil(count / columns)
		else
			usedRows = math.min(count, rows)
			usedColumns = math.ceil(count / rows)
		end
		local blockW = usedColumns * cellW + math.max(usedColumns - 1, 0) * gapX
		local blockH = usedRows * cellH + math.max(usedRows - 1, 0) * gapY
		local originX = padL + (innerW - blockW) * horizontalAlign
		local originY = padT + (innerH - blockH) * verticalAlign
		for index, child in items do
			local column, row
			if isHorizontal then
				column = (index - 1) % columns
				row = math.floor((index - 1) / columns)
			else
				row = (index - 1) % rows
				column = math.floor((index - 1) / rows)
			end
			local record = buildNode(child, innerW, innerH, k, cellW, cellH)
			record.x = originX + column * (cellW + gapX)
			record.y = originY + row * (cellH + gapY)
			table.insert(records, record)
		end
		naturalW = blockW + padL + padR
		naturalH = blockH + padT + padB
	else
		for _, child in items do
			local record = buildNode(child, innerW, innerH, k)
			local position = read(child, "Position", zeroUdim2)
			local anchor = read(child, "AnchorPoint", zeroVector)
			record.x = padL + position.X.Scale * innerW + position.X.Offset * k - anchor.X * record.w
			record.y = padT + position.Y.Scale * innerH + position.Y.Offset * k - anchor.Y * record.h
			table.insert(records, record)
			naturalW = math.max(naturalW, record.x + record.w)
			naturalH = math.max(naturalH, record.y + record.h)
		end
		naturalW += padR
		naturalH += padB
	end
	return records, naturalW, naturalH
end

local function gradientRecord(gradient: any): any
	local colors = {}
	for _, keypoint in read(gradient, "Color", roblox.ColorSequence.new(roblox.Color3.new(1, 1, 1))).Keypoints do
		local color = rgb(keypoint.Value)
		table.insert(colors, { round(keypoint.Time), color[1], color[2], color[3] })
	end
	local alphas = {}
	for _, keypoint in read(gradient, "Transparency", roblox.NumberSequence.new(0)).Keypoints do
		table.insert(alphas, { round(keypoint.Time), round(keypoint.Value) })
	end
	local offset = read(gradient, "Offset", zeroVector)
	return {
		rotation = read(gradient, "Rotation", 0),
		offsetX = offset.X,
		offsetY = offset.Y,
		colors = colors,
		alphas = alphas,
	}
end

local function strokeRecord(stroke: any, k: number): any
	local record: any = {
		color = rgb(read(stroke, "Color", roblox.Color3.new(0, 0, 0))),
		thickness = round(read(stroke, "Thickness", 1) * k),
		alpha = read(stroke, "Transparency", 0),
		mode = enumName(read(stroke, "ApplyStrokeMode", "Contextual")),
	}
	for _, child in stroke:GetChildren() do
		if child.ClassName == "UIGradient" then
			record.gradient = gradientRecord(child)
		end
	end
	return record
end

local function textRecord(node: any, class: string, mods: any, w: number, h: number, k: number, strokes: { any }): any?
	local content = read(node, "Text", "")
	if class == "TextBox" and content == "" then
		content = read(node, "PlaceholderText", "")
	end
	if content == "" then
		return nil
	end
	local fontName = enumName(read(node, "Font", "SourceSans"))
	local size = read(node, "TextSize", 14) * k
	local isScaled = read(node, "TextScaled", false)
	local isWrapped = read(node, "TextWrapped", false)
	local isRich = read(node, "RichText", false)
	local plain = if isRich then Text.Strip(content) else content
	local padL, padR, padT, padB = paddingOf(mods, w, h, k)
	local areaW = w - padL - padR
	local areaH = h - padT - padB
	local lines: { string }
	if isScaled then
		local limit = mods.TextLimit
		local maximum = if limit then read(limit, "MaxTextSize", 100) * k else 100 * k
		local minimum = if limit then read(limit, "MinTextSize", 1) * k else 1
		size, lines = Text.Fit(plain, fontName, areaW, areaH, maximum, minimum)
	elseif isWrapped then
		lines = Text.Wrap(plain, size, fontName, areaW)
	else
		lines = {}
		for line in string.gmatch(plain .. "\n", "(.-)\n") do
			table.insert(lines, line)
		end
	end
	local truncate = enumName(read(node, "TextTruncate", "None")) == "AtEnd"
	local widest = 0
	for index, line in lines do
		local width = Text.Width(line, size, fontName)
		if truncate and not isWrapped and not isScaled and width > areaW then
			local cut = line
			while #cut > 1 and Text.Width(cut .. "...", size, fontName) > areaW do
				cut = string.sub(cut, 1, #cut - 1)
			end
			lines[index] = cut .. "..."
			width = Text.Width(lines[index], size, fontName)
		end
		widest = math.max(widest, width)
	end
	local record: any = {
		lines = if isRich then { content } else lines,
		rich = isRich,
		size = round(size),
		font = fontName,
		color = rgb(read(node, "TextColor3", roblox.Color3.fromRGB(27, 42, 53))),
		alpha = read(node, "TextTransparency", 0),
		xAlign = enumName(read(node, "TextXAlignment", "Center")),
		yAlign = enumName(read(node, "TextYAlignment", "Center")),
		padL = round(padL),
		padR = round(padR),
		padT = round(padT),
		padB = round(padB),
		overflow = widest > areaW + 1 or #lines * size > areaH + 1,
		scaled = isScaled,
	}
	for _, stroke in strokes do
		if stroke.mode == "Contextual" then
			record.stroke = stroke
		end
	end
	local legacy = read(node, "TextStrokeTransparency", 1)
	if not record.stroke and legacy < 1 then
		record.stroke = {
			color = rgb(read(node, "TextStrokeColor3", roblox.Color3.new(0, 0, 0))),
			thickness = 1,
			alpha = legacy,
			mode = "Contextual",
		}
	end
	return record
end

local function textBounds(node: any, mods: any, availableW: number, k: number): (number, number)
	local content = read(node, "Text", "")
	local fontName = enumName(read(node, "Font", "SourceSans"))
	local size = read(node, "TextSize", 14) * k
	local plain = if read(node, "RichText", false) then Text.Strip(content) else content
	local lines
	if read(node, "TextWrapped", false) and availableW > 0 then
		lines = Text.Wrap(plain, size, fontName, availableW)
	else
		lines = {}
		for line in string.gmatch(plain .. "\n", "(.-)\n") do
			table.insert(lines, line)
		end
	end
	local widest = 0
	for _, line in lines do
		widest = math.max(widest, Text.Width(line, size, fontName))
	end
	return widest, #lines * size
end

function buildNode(node: any, parentW: number, parentH: number, k: number, forcedW: number?, forcedH: number?): any
	local mods = modifiersOf(node)
	local class = node.ClassName
	local scale = if mods.Scale then read(mods.Scale, "Scale", 1) else 1
	local w, h
	if forcedW and forcedH then
		w, h = forcedW, forcedH
	else
		local size = read(node, "Size", zeroUdim2)
		w = size.X.Scale * parentW + size.X.Offset * k
		h = size.Y.Scale * parentH + size.Y.Offset * k
		w, h = constrain(mods, w, h, k)
		w, h = w * scale, h * scale
	end
	local kn = k * scale
	local auto = enumName(read(node, "AutomaticSize", "None"))
	local autoX = auto == "X" or auto == "XY"
	local autoY = auto == "Y" or auto == "XY"
	local isScroll = class == "ScrollingFrame"
	local direction = if isScroll then enumName(read(node, "ScrollingDirection", "XY")) else "XY"
	local canAutoCanvas = if isScroll then enumName(read(node, "AutomaticCanvasSize", "None")) else "None"
	local thickness = if isScroll then read(node, "ScrollBarThickness", 12) * kn else 0

	local records, naturalW, naturalH = layoutChildren(mods, w, h, kn)
	if (autoX or autoY) and not forcedW then
		if textClasses[class] then
			local padL, padR, padT, padB = paddingOf(mods, w, h, kn)
			local textW, textH = textBounds(node, mods, if autoX then math.huge else w - padL - padR, kn)
			naturalW = math.max(naturalW, textW + padL + padR)
			naturalH = math.max(naturalH, textH + padT + padB)
		end
		local newW = if autoX then naturalW else w
		local newH = if autoY then naturalH else h
		newW, newH = constrain({ SizeLimit = mods.SizeLimit }, newW, newH, kn)
		if newW ~= w or newH ~= h then
			w, h = newW, newH
			records, naturalW, naturalH = layoutChildren(mods, w, h, kn)
		end
	end

	local record: any = {
		class = class,
		name = node.Name,
		w = w,
		h = h,
		x = 0,
		y = 0,
		z = read(node, "ZIndex", 1),
		rot = read(node, "Rotation", 0),
	}

	if isScroll then
		local canvas = read(node, "CanvasSize", zeroUdim2)
		local canvasW = canvas.X.Scale * w + canvas.X.Offset * kn
		local canvasH = canvas.Y.Scale * h + canvas.Y.Offset * kn
		if canAutoCanvas == "Y" or canAutoCanvas == "XY" then
			canvasH = naturalH
		end
		if canAutoCanvas == "X" or canAutoCanvas == "XY" then
			canvasW = naturalW
		end
		local needsY = direction ~= "X" and canvasH > h + 0.5
		if needsY and thickness > 0 then
			records, naturalW, naturalH = layoutChildren(mods, w - thickness, h, kn)
			if canAutoCanvas == "Y" or canAutoCanvas == "XY" then
				canvasH = naturalH
			end
		end
		local needsX = direction ~= "Y" and canvasW > w + 0.5
		local position = read(node, "CanvasPosition", zeroVector)
		for _, child in records do
			child.x -= position.X
			child.y -= position.Y
		end
		record.scroll = {
			canvasW = round(canvasW),
			canvasH = round(canvasH),
			thickness = round(thickness),
			color = rgb(read(node, "ScrollBarImageColor3", roblox.Color3.new(0, 0, 0))),
			needsX = needsX,
			needsY = needsY,
			posX = position.X,
			posY = position.Y,
		}
		record.clip = true
	elseif read(node, "ClipsDescendants", false) then
		record.clip = true
	end

	local bgAlpha = read(node, "BackgroundTransparency", 0)
	if bgAlpha < 1 then
		record.bg = rgb(read(node, "BackgroundColor3", roblox.Color3.fromRGB(163, 162, 165)))
		record.bgAlpha = bgAlpha
	end
	local border = read(node, "BorderSizePixel", 1)
	if border > 0 and bgAlpha < 1 then
		record.border = { size = round(border), color = rgb(read(node, "BorderColor3", roblox.Color3.fromRGB(27, 42, 53))) }
	end

	local gradients = {}
	for _, gradient in mods.Gradients do
		if read(gradient, "Enabled", true) then
			table.insert(gradients, gradientRecord(gradient))
		end
	end
	if #gradients > 0 then
		record.gradient = gradients[1]
	end

	local strokes = {}
	for _, stroke in mods.Strokes do
		if read(stroke, "Enabled", true) then
			table.insert(strokes, strokeRecord(stroke, kn))
		end
	end
	if textClasses[class] then
		record.text = textRecord(node, class, mods, w, h, kn, strokes)
		local rest = {}
		for _, stroke in strokes do
			if stroke.mode == "Border" then
				table.insert(rest, stroke)
			end
		end
		strokes = rest
	end
	if #strokes > 0 then
		record.strokes = strokes
	end

	if mods.Corner then
		local radius = read(mods.Corner, "CornerRadius", roblox.UDim.new(0, 8))
		record.corner = round(math.min(radius.Scale * math.min(w, h) + radius.Offset * kn, math.min(w, h) / 2))
	end

	if imageClasses[class] then
		local image = read(node, "Image", "")
		if image ~= "" then
			local tile = read(node, "TileSize", roblox.UDim2.new(1, 0, 1, 0))
			record.image = {
				id = image,
				color = rgb(read(node, "ImageColor3", roblox.Color3.new(1, 1, 1))),
				alpha = read(node, "ImageTransparency", 0),
				scaleType = enumName(read(node, "ScaleType", "Stretch")),
				rectX = read(node, "ImageRectOffset", roblox.Vector2.new(0, 0)).X,
				rectY = read(node, "ImageRectOffset", roblox.Vector2.new(0, 0)).Y,
				rectW = read(node, "ImageRectSize", roblox.Vector2.new(0, 0)).X,
				rectH = read(node, "ImageRectSize", roblox.Vector2.new(0, 0)).Y,
				tileW = round(tile.X.Scale * w + tile.X.Offset * kn),
				tileH = round(tile.Y.Scale * h + tile.Y.Offset * kn),
			}
		end
	end

	local ordered = {}
	local indexed = {}
	for index, child in records do
		table.insert(indexed, { Record = child, Index = index })
	end
	table.sort(indexed, function(a: any, b: any)
		if a.Record.z ~= b.Record.z then
			return a.Record.z < b.Record.z
		end
		return a.Index < b.Index
	end)
	for _, entry in indexed do
		table.insert(ordered, entry.Record)
	end
	record.children = ordered
	return record
end

local function round2(record: any)
	record.x = round(record.x)
	record.y = round(record.y)
	record.w = round(record.w)
	record.h = round(record.h)
	record.rot = round(record.rot)
	for _, child in record.children do
		round2(child)
	end
end

function Layout.Gui(gui: any, viewport: any): any
	local inset = if read(gui, "IgnoreGuiInset", false) then 0 else topInset
	local w = viewport.X
	local h = viewport.Y - inset
	local mods = modifiersOf(gui)
	local records = layoutChildren(mods, w, h, 1)
	local ordered = {}
	local indexed = {}
	for index, child in records do
		table.insert(indexed, { Record = child, Index = index })
	end
	table.sort(indexed, function(a: any, b: any)
		if a.Record.z ~= b.Record.z then
			return a.Record.z < b.Record.z
		end
		return a.Index < b.Index
	end)
	for _, entry in indexed do
		round2(entry.Record)
		table.insert(ordered, entry.Record)
	end
	return {
		name = gui.Name,
		order = read(gui, "DisplayOrder", 0),
		inset = inset,
		w = w,
		h = h,
		children = ordered,
	}
end

return Layout
