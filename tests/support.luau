local Harness = require("./harness/Harness")

local Support = {}

function Support.totals(data: any): { [string]: number }
	local out: { [string]: number } = {}
	for _, keyId in data.Board do
		if keyId ~= "" then
			out[keyId] = (out[keyId] or 0) + 1
		end
	end
	for keyId, count in data.Inventory do
		out[keyId] = (out[keyId] or 0) + count
	end
	return out
end

function Support.snapshot(data: any): any
	return Harness.deepCopy(data)
end

function Support.board(...: string): { [number]: string }
	local out = {}
	for index, keyId in { ... } do
		out[index] = keyId
	end
	return out
end

function Support.fill(keyId: string, count: number): { [number]: string }
	local out = {}
	for index = 1, count do
		out[index] = keyId
	end
	return out
end

function Support.nan(): number
	return 0 / 0
end

return Support
