local Metrics = require("./FontMetrics")

local Text = {}

local fallbackWidth = 0.6
local fontFamilies: { [string]: string } = {
	FredokaOne = "FredokaOne",
	LuckiestGuy = "LuckiestGuy",
}

function Text.Family(fontName: string): string
	return fontFamilies[fontName] or "Gotham"
end

function Text.Strip(text: string): string
	local stripped = string.gsub(text, "<[^>]+>", "")
	return stripped
end

function Text.Width(text: string, size: number, fontName: string): number
	local family = Metrics[Text.Family(fontName)]
	local total = 0
	for _, code in utf8.codes(text) do
		local width = family.Widths[code - 31]
		total += if width then width / 1000 else fallbackWidth
	end
	return total * size
end

function Text.Wrap(text: string, size: number, fontName: string, width: number): { string }
	local lines: { string } = {}
	for paragraph in string.gmatch(text .. "\n", "(.-)\n") do
		local current = ""
		for word in string.gmatch(paragraph, "%S+") do
			local candidate = if current == "" then word else current .. " " .. word
			if Text.Width(candidate, size, fontName) <= width or current == "" then
				current = candidate
			else
				table.insert(lines, current)
				current = word
			end
		end
		table.insert(lines, current)
	end
	return lines
end

function Text.Fit(
	text: string,
	fontName: string,
	width: number,
	height: number,
	maxSize: number,
	minSize: number
): (number, { string })
	local size = math.floor(maxSize)
	while size > minSize do
		local lines = Text.Wrap(text, size, fontName, width)
		local widest = 0
		for _, line in lines do
			widest = math.max(widest, Text.Width(line, size, fontName))
		end
		if #lines * size <= height and widest <= width then
			return size, lines
		end
		size -= 1
	end
	return minSize, Text.Wrap(text, minSize, fontName, width)
end

return Text
