local Test = {}

type Node = {
	Name: string,
	Parent: Node?,
	Children: { Node },
	Tests: { { Name: string, Fn: () -> () } },
	BeforeEach: { () -> () },
	AfterEach: { () -> () },
}

local root: Node = { Name = "", Children = {}, Tests = {}, BeforeEach = {}, AfterEach = {} } :: any
local current = root

local function deepEqual(a: any, b: any, seen: { [any]: any }?): boolean
	if a ~= a and b ~= b then
		return true
	end
	if type(a) ~= type(b) then
		return false
	end
	if type(a) ~= "table" then
		return a == b
	end
	if a == b then
		return true
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function show(value: any, depth: number?): string
	depth = depth or 0
	if type(value) == "string" then
		return string.format("%q", value)
	elseif type(value) ~= "table" then
		return tostring(value)
	elseif (depth :: number) > 3 then
		return "{...}"
	end
	local keys = {}
	for k in value do
		table.insert(keys, k)
	end
	table.sort(keys, function(x, y)
		return tostring(x) < tostring(y)
	end)
	local parts = {}
	for _, k in keys do
		table.insert(parts, `{tostring(k)} = {show(value[k], (depth :: number) + 1)}`)
	end
	return "{ " .. table.concat(parts, ", ") .. " }"
end

local Expectation = {}
Expectation.__index = Expectation

local function fail(message: string)
	error(message, 3)
end

local function check(self, passed: boolean, positive: string, negative: string)
	if self._never then
		passed = not passed
	end
	if not passed then
		fail(if self._never then negative else positive)
	end
end

function Expectation.toBe(self, expected: any)
	check(self, self._value == expected, `expected {show(expected)}, got {show(self._value)}`, `expected value not to be {show(expected)}`)
end

function Expectation.toEqual(self, expected: any)
	check(self, deepEqual(self._value, expected), `expected {show(expected)}, got {show(self._value)}`, `expected value not to equal {show(expected)}`)
end

function Expectation.toBeTruthy(self)
	check(self, not not self._value, `expected truthy, got {show(self._value)}`, `expected falsy, got {show(self._value)}`)
end

function Expectation.toBeFalsy(self)
	check(self, not self._value, `expected falsy, got {show(self._value)}`, `expected truthy, got {show(self._value)}`)
end

function Expectation.toBeNil(self)
	check(self, self._value == nil, `expected nil, got {show(self._value)}`, `expected non-nil value`)
end

function Expectation.toBeCloseTo(self, expected: number, tolerance: number?)
	local tol = tolerance or 1e-9
	local ok = type(self._value) == "number" and math.abs(self._value - expected) <= tol
	check(self, ok, `expected {show(self._value)} within {tol} of {expected}`, `expected {show(self._value)} not within {tol} of {expected}`)
end

function Expectation.toBeGreaterThan(self, bound: number)
	check(self, type(self._value) == "number" and self._value > bound, `expected {show(self._value)} > {bound}`, `expected {show(self._value)} <= {bound}`)
end

function Expectation.toBeLessThan(self, bound: number)
	check(self, type(self._value) == "number" and self._value < bound, `expected {show(self._value)} < {bound}`, `expected {show(self._value)} >= {bound}`)
end

function Expectation.toContain(self, item: any)
	local found = false
	if type(self._value) == "string" then
		found = string.find(self._value, item, 1, true) ~= nil
	elseif type(self._value) == "table" then
		for _, v in self._value do
			if deepEqual(v, item) then
				found = true
				break
			end
		end
	end
	check(self, found, `expected {show(self._value)} to contain {show(item)}`, `expected {show(self._value)} not to contain {show(item)}`)
end

function Expectation.toHaveLength(self, length: number)
	check(self, #self._value == length, `expected length {length}, got {#self._value}`, `expected length not {length}`)
end

function Expectation.toThrow(self, substring: string?)
	local ok, err = pcall(self._value)
	local message = tostring(err)
	local matches = not ok and (substring == nil or string.find(message, substring, 1, true) ~= nil)
	check(self, matches, if ok then "expected function to throw" else `expected error containing {show(substring)}, got {show(message)}`, "expected function not to throw")
end

function Test.expect(value: any)
	local e = setmetatable({ _value = value, _never = false }, Expectation)
	e.never = setmetatable({ _value = value, _never = true }, Expectation)
	return e
end

function Test.describe(name: string, body: () -> ())
	local node: Node = { Name = name, Parent = current, Children = {}, Tests = {}, BeforeEach = {}, AfterEach = {} }
	table.insert(current.Children, node)
	local previous = current
	current = node
	body()
	current = previous
end

function Test.it(name: string, fn: () -> ())
	table.insert(current.Tests, { Name = name, Fn = fn })
end

function Test.beforeEach(fn: () -> ())
	table.insert(current.BeforeEach, fn)
end

function Test.afterEach(fn: () -> ())
	table.insert(current.AfterEach, fn)
end

function Test.reset()
	root = { Name = "", Children = {}, Tests = {}, BeforeEach = {}, AfterEach = {} } :: any
	current = root
end

function Test.run(): { Passed: number, Failed: number, Failures: { string } }
	local passed, failed = 0, 0
	local failures = {}

	local function runNode(node: Node, chain: { Node }, depth: number)
		if node.Name ~= "" then
			print(`{string.rep("  ", depth - 1)}{node.Name}`)
		end
		table.insert(chain, node)
		for _, test in node.Tests do
			local ok, err = pcall(function()
				for _, n in chain do
					for _, hook in n.BeforeEach do
						hook()
					end
				end
				test.Fn()
			end)
			for index = #chain, 1, -1 do
				for _, hook in chain[index].AfterEach do
					pcall(hook)
				end
			end
			local indent = string.rep("  ", depth)
			if ok then
				passed += 1
				print(`{indent}ok   {test.Name}`)
			else
				failed += 1
				print(`{indent}FAIL {test.Name}`)
				local names = {}
				for _, n in chain do
					if n.Name ~= "" then
						table.insert(names, n.Name)
					end
				end
				table.insert(failures, `{table.concat(names, " > ")} > {test.Name}\n    {tostring(err)}`)
			end
		end
		for _, child in node.Children do
			runNode(child, chain, depth + 1)
		end
		table.remove(chain)
	end

	runNode(root, {}, 0)
	return { Passed = passed, Failed = failed, Failures = failures }
end

return Test
