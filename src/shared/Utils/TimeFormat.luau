--!strict

local TimeFormat = {}

function TimeFormat.Clock(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", math.floor(whole / 60), whole % 60)
end

function TimeFormat.Hours(seconds: number): string
	local minutes = math.max(0, math.ceil(seconds / 60))
	if minutes >= 60 then
		return string.format("%dh %dm", math.floor(minutes / 60), minutes % 60)
	end
	return string.format("%dm", minutes)
end

return table.freeze(TimeFormat)
