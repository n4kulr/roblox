--!strict

local suffixes = { "", "K", "M", "B", "T", "Qa", "Qi" }

local NumberFormat = {}

function NumberFormat.Compact(value: number): string
	local whole = math.max(0, math.floor(value))
	if whole < 1000 then
		return string.format("%d", whole)
	end
	local tier = math.min(#suffixes - 1, math.floor(math.log10(whole) / 3))
	local scaled = math.floor(whole / 10 ^ (tier * 3) * 10) / 10
	local text = string.format("%.1f", scaled)
	text = string.gsub(text, "%.0$", "")
	return text .. suffixes[tier + 1]
end

function NumberFormat.Commas(value: number): string
	local text = string.format("%d", math.floor(value))
	local reversed = string.gsub(string.reverse(text), "(%d%d%d)", "%1,")
	local formatted = string.reverse(reversed)
	if string.sub(formatted, 1, 1) == "," then
		formatted = string.sub(formatted, 2)
	end
	return formatted
end

return table.freeze(NumberFormat)
