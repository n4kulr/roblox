--!strict

local Amount = {}

local multipliers: { [string]: number } = { k = 1e3, m = 1e6, b = 1e9, t = 1e12 }

function Amount.Parse(text: any): number?
	if type(text) ~= "string" then
		return nil
	end
	local cleaned = string.lower(string.gsub(text, "[%s,_]", "") :: string)
	local body, suffix = string.match(cleaned, "^%+?([%d%.e]+)([kmbt]?)$")
	if not body then
		return nil
	end
	local value = tonumber(body)
	if not value or value ~= value or value < 0 or value == math.huge then
		return nil
	end
	local scaled = value * (multipliers[suffix or ""] or 1)
	if scaled == math.huge then
		return nil
	end
	return math.floor(scaled + 1e-6)
end

return Amount
