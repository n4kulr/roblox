local fs = require("@lune/fs")
local process = require("@lune/process")

local Test = require("./harness/Test")

local function collect(dir: string, out: { string })
	for _, name in fs.readDir(dir) do
		local path = `{dir}/{name}`
		if fs.isDir(path) then
			collect(path, out)
		elseif string.match(name, "%.spec%.luau$") then
			table.insert(out, path)
		end
	end
end

local specs: { string } = {}
collect("tests", specs)
table.sort(specs)

local filter = process.args[1]
for _, path in specs do
	if not filter or string.find(path, filter, 1, true) then
		local name = string.gsub(string.gsub(path, "^tests/", ""), "%.luau$", "")
		require(`./{name}`)
	end
end

local started = os.clock()
local result = Test.run()
print("")
for _, failure in result.Failures do
	print(`FAILED: {failure}\n`)
end
print(`{result.Passed} passed, {result.Failed} failed ({string.format("%.2f", os.clock() - started)}s)`)
if result.Failed > 0 or result.Passed == 0 then
	process.exit(1)
end
