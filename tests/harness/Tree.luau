local fs = require("@lune/fs")
local serde = require("@lune/serde")

local Tree = {}

local state: { [any]: any } = setmetatable({}, { __mode = "k" }) :: any
local methods: { [string]: (any, ...any) -> ...any } = {}
local nodeMeta: { [string]: any } = { __rbxtype = "Instance" }

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

function methods.GetAttribute(self, name: string)
	return state[self].Attributes[name]
end

function methods.SetAttribute(self, name: string, value: any)
	state[self].Attributes[name] = value
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
	nodeMeta.__newindex(self, "Parent", nil)
end

function methods.Clone(self)
	return Tree.node(state[self].ClassName, state[self].Name, state[self].File)
end

nodeMeta.__index = function(self, key)
	local s = state[self]
	if key == "Name" or key == "ClassName" or key == "Parent" then
		return s[key]
	end
	local method = methods[key]
	if method then
		return method
	end
	local prop = s.Props[key]
	if prop ~= nil then
		return prop
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
		if s.Parent then
			local siblings = state[s.Parent].Children
			table.remove(siblings, table.find(siblings, self))
		end
		s.Parent = value
		if value then
			table.insert(state[value].Children, self)
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

function Tree.node(className: string, name: string, file: string?)
	local node = setmetatable({}, nodeMeta)
	state[node] = {
		ClassName = className,
		Name = name,
		Parent = nil,
		Children = {},
		Props = {},
		Attributes = {},
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
