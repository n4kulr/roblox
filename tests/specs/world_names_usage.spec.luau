local fs = require("@lune/fs")

local H = require("../harness/Harness")

local describe, it, expect = H.describe, H.it, H.expect

local roots = { "src/server", "src/shared" }
local excluded = { "obby", "src/shared/Packet/", "src/shared/Config/WorldNames.luau" }
local patterns = {
	'SetAttribute%("',
	'GetAttribute%("',
	'GetAttributeChangedSignal%("',
}

local function isExcluded(path: string): boolean
	local lowered = string.lower(path)
	for _, part in excluded do
		if string.find(lowered, string.lower(part), 1, true) then
			return true
		end
	end
	return false
end

local function collect(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			collect(path, out)
		elseif string.sub(name, -5) == ".luau" and not isExcluded(path) then
			table.insert(out, path)
		end
	end
end

describe("World names", function()
	it("keeps raw attribute name literals out of server and shared source", function()
		local files: { string } = {}
		for _, root in roots do
			collect(root, files)
		end
		expect(#files > 0):toBe(true)

		local offenders: { string } = {}
		for _, path in files do
			local lineNumber = 0
			for line in string.gmatch(fs.readFile(path) .. "\n", "([^\n]*)\n") do
				lineNumber += 1
				for _, pattern in patterns do
					if string.find(line, pattern) then
						table.insert(offenders, `{path}:{lineNumber}`)
						break
					end
				end
			end
		end
		expect(table.concat(offenders, ", ")):toBe("")
	end)
end)
