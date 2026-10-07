local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")

local Tree = {}

local state: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any
local methods: { [string]: (any, ...any) -> ...any } = {}
local nodeMeta: { [string]: any } = { __rbxtype = "Instance" }
local autoSignalNames = {
	ChildAdded = true,
	ChildRemoved = true,
	DescendantAdded = true,
	DescendantRemoving = true,
	Destroying = true,
	AttributeChanged = true,
	AncestryChanged = true,
}

local function defaultSignal()
	local handlers: { { Fn: any, On: boolean } } = {}
	local signal = {}
	function signal.Connect(_self, fn: any)
		local entry = { Fn = fn, On = true }
		table.insert(handlers, entry)
		return {
			Disconnect = function()
				entry.On = false
			end,
		}
	end
	function signal.Fire(_self, ...)
		for _, entry in table.clone(handlers) do
			if entry.On then
				entry.Fn(...)
			end
		end
	end
	return signal
end

local function fire(node: any, name: string, ...)
	local s = state[node]
	if s and s.AutoSignals[name] then
		s.Props[name]:Fire(...)
	end
end

local function fireAttribute(node: any, name: string, ...)
	local found = state[node].AttributeSignals[name]
	if found then
		found:Fire(...)
	end
end

local function describe(node: any): string
	local s = state[node]
	return `{s.ClassName} "{s.Name}"`
end

function methods.GetChildren(self)
	return table.clone(state[self].Children)
end

function methods.GetDescendants(self)
	local out = {}
	local function walk(node)
		for _, child in state[node].Children do
			table.insert(out, child)
			walk(child)
		end
	end
	walk(self)
	return out
end

function methods.FindFirstChild(self, name: string, recursive: boolean?)
	for _, child in state[self].Children do
		if state[child].Name == name then
			return child
		end
	end
	if recursive then
		for _, child in state[self].Children do
			local found = methods.FindFirstChild(child, name, true)
			if found then
				return found
			end
		end
	end
	return nil
end

function methods.WaitForChild(self, name: string)
	local found = methods.FindFirstChild(self, name)
	if not found then
		error(`WaitForChild: {name} is not a child of {describe(self)} in the harness tree`, 2)
	end
	return found
end

function methods.FindFirstChildOfClass(self, className: string)
	for _, child in state[self].Children do
		if state[child].ClassName == className then
			return child
		end
	end
	return nil
end

function methods.IsA(self, className: string)
	local own = state[self].ClassName
	return own == className or className == "Instance" or (className == "BasePart" and (own == "Part" or own == "MeshPart")) or (className == "LuaSourceContainer" and (own == "ModuleScript" or own == "Script" or own == "LocalScript"))
end

function methods.PivotTo(self, cframe: any)
	state[self].Props.PivotCFrame = cframe
	local root = methods.FindFirstChild(self, "HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
end

function methods.GetBoundingBox(self)
	local low, high = nil, nil
	local function include(point: any)
		low = if low then roblox.Vector3.new(math.min(low.X, point.X), math.min(low.Y, point.Y), math.min(low.Z, point.Z)) else point
		high = if high then roblox.Vector3.new(math.max(high.X, point.X), math.max(high.Y, point.Y), math.max(high.Z, point.Z)) else point
	end
	for _, item in methods.GetDescendants(self) do
		local props = state[item].Props
		if props.Size ~= nil and props.CFrame ~= nil then
			local half = props.Size / 2
			local radius = math.max(half.X, half.Y, half.Z)
			include(props.CFrame.Position - roblox.Vector3.new(radius, radius, radius))
			include(props.CFrame.Position + roblox.Vector3.new(radius, radius, radius))
		end
	end
	if not low or not high then
		return roblox.CFrame.new(), roblox.Vector3.zero
	end
	return roblox.CFrame.new((low + high) / 2), high - low
end

function methods.GetExtentsSize(self)
	local _, size = methods.GetBoundingBox(self)
	return size
end

function methods.GetAttribute(self, name: string)
	return state[self].Attributes[name]
end

function methods.SetAttribute(self, name: string, value: any)
	local s = state[self]
	local changed = s.Attributes[name] ~= value
	s.Attributes[name] = value
	if changed then
		fireAttribute(self, name)
		fire(self, "AttributeChanged", name)
	end
end

function methods.GetAttributeChangedSignal(self, name: string)
	local s = state[self]
	if not s.NewSignal then
		error(`GetAttributeChangedSignal: {describe(self)} was not created with signal support`, 2)
	end
	local found = s.AttributeSignals[name]
	if not found then
		found = s.NewSignal()
		s.AttributeSignals[name] = found
	end
	return found
end

function methods.GetAttributes(self)
	return table.clone(state[self].Attributes)
end

function methods.GetFullName(self)
	local parts = {}
	local current = self
	while current do
		table.insert(parts, 1, state[current].Name)
		current = state[current].Parent
	end
	return table.concat(parts, ".")
end

function methods.IsDescendantOf(self, other)
	local current = state[self].Parent
	while current do
		if current == other then
			return true
		end
		current = state[current].Parent
	end
	return false
end

function methods.Destroy(self)
	fire(self, "Destroying")
	nodeMeta.__newindex(self, "Parent", nil)
end

function methods.Clone(self)
	local source = state[self]
	local clone = Tree.node(source.ClassName, source.Name, source.File, source.NewSignal)
	local cloned = state[clone]
	for key, value in source.Props do
		cloned.Props[key] = value
	end
	for key, value in source.Attributes do
		cloned.Attributes[key] = value
	end
	for _, child in source.Children do
		local childClone = methods.Clone(child)
		childClone.Parent = clone
	end
	return clone
end

nodeMeta.__index = function(self, key)
	local s = state[self]
	if key == "Name" or key == "ClassName" or key == "Parent" then
		return s[key]
	end
	local method = methods[key]
	if method then
		if key == "GetAttributeChangedSignal" and s.Props[key] ~= nil then
			return s.Props[key]
		end
		return method
	end
	local prop = s.Props[key]
	if prop ~= nil then
		return prop
	end
	if autoSignalNames[key] and s.NewSignal then
		local created = s.NewSignal()
		s.Props[key] = created
		s.AutoSignals[key] = true
		return created
	end
	local child = methods.FindFirstChild(self, key)
	if child then
		return child
	end
	error(`{key} is not a valid member of {describe(self)}`, 2)
end

nodeMeta.__newindex = function(self, key, value)
	local s = state[self]
	if key == "Parent" then
		local previous = s.Parent
		if previous then
			local siblings = if state[previous] then state[previous].Children else previous._children
			local at = table.find(siblings, self)
			if at then
				table.remove(siblings, at)
			end
		end
		s.Parent = value
		if value then
			local siblings = if state[value] then state[value].Children else value._children
			table.insert(siblings, self)
		end
		fire(self, "AncestryChanged", self, value)
		if previous and state[previous] then
			fire(previous, "ChildRemoved", self)
			local ancestor = previous
			while ancestor and state[ancestor] do
				fire(ancestor, "DescendantRemoving", self)
				ancestor = state[ancestor].Parent
			end
		end
		if value and state[value] then
			fire(value, "ChildAdded", self)
			local ancestor = value
			while ancestor and state[ancestor] do
				fire(ancestor, "DescendantAdded", self)
				ancestor = state[ancestor].Parent
			end
		end
	elseif key == "Name" then
		s.Name = value
	else
		s.Props[key] = value
	end
end

nodeMeta.__tostring = function(self)
	return state[self].Name
end

function Tree.node(className: string, name: string, file: string?, newSignal: (() -> any)?)
	local node = setmetatable({}, nodeMeta)
	state[node] = {
		ClassName = className,
		Name = name,
		Parent = nil,
		Children = {},
		Props = {},
		Attributes = {},
		AutoSignals = {},
		AttributeSignals = {},
		NewSignal = newSignal or defaultSignal,
		File = file,
	}
	return node
end

function Tree.fileOf(node: any): string?
	return state[node] and state[node].File
end

function Tree.isNode(value: any): boolean
	return state[value] ~= nil
end

function Tree.pathOf(node: any): string
	return methods.GetFullName(node)
end

local function build(entry: any, parent: any?)
	local node = Tree.node(entry.className, entry.name, if entry.filePaths then entry.filePaths[1] else nil)
	if parent then
		node.Parent = parent
	end
	for _, child in entry.children or {} do
		build(child, node)
	end
	return node
end

function Tree.fromSourcemap(path: string)
	if not fs.isFile(path) then
		error(`{path} not found. Run: rojo sourcemap default.project.json --output sourcemap.json`)
	end
	return build(serde.decode("json", fs.readFile(path)))
end

return Tree
