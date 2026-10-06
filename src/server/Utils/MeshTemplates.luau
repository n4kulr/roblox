--!strict

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Meshes = require(ReplicatedStorage.Config.Meshes)
local Signal = require(ReplicatedStorage.Packages.Signal)

export type Name = "Keycap" | "RollKey"

local names: { Name } = { "Keycap", "RollKey" }
local templates: { [string]: MeshPart } = {}
local generation = 0
local pending = 0

local MeshTemplates = {
	Changed = Signal.new() :: any,
	Settled = Signal.new() :: any,
}

local function create(name: string, meshId: string, current: number)
	local ok, result = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromUri(meshId), {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Precise,
		})
	end)
	if generation ~= current then
		if ok then
			(result :: MeshPart):Destroy()
		end
		return
	end
	pending -= 1
	if ok then
		local template = result :: MeshPart
		template.Name = name
		template.Anchored = true
		templates[name] = template
		MeshTemplates.Changed:Fire(name)
	else
		warn(`[MeshTemplates] {name} mesh {meshId} failed to load, using plain parts: {result}`)
	end
	if pending == 0 then
		MeshTemplates.Settled:Fire()
	end
end

function MeshTemplates.Load()
	generation += 1
	local current = generation
	local ids = Meshes :: { [string]: string }
	local toLoad: { { Name: string, Id: string } } = {}
	local authored = ServerStorage:FindFirstChild("Meshes")
	for _, name in names do
		local source = if authored then authored:FindFirstChild(name) else nil
		local meshId = ids[name]
		if source and source:IsA("BasePart") then
			local template = source:Clone()
			template.Name = name
			template.Anchored = true
			templates[name] = template :: any
		elseif meshId ~= "" then
			table.insert(toLoad, { Name = name, Id = meshId })
		end
	end
	pending = #toLoad
	for _, entry in toLoad do
		task.spawn(create, entry.Name, entry.Id, current)
	end
end

function MeshTemplates.Wait(timeout: number)
	if pending == 0 then
		return
	end
	local thread = coroutine.running()
	local isResumed = false
	local connection: any = nil
	local timer: thread? = nil
	connection = MeshTemplates.Settled:Connect(function()
		if isResumed then
			return
		end
		isResumed = true
		connection:Disconnect()
		if timer then
			task.cancel(timer)
		end
		task.spawn(thread)
	end)
	timer = task.delay(timeout, function()
		if isResumed then
			return
		end
		isResumed = true
		connection:Disconnect()
		task.spawn(thread)
	end)
	coroutine.yield()
end

function MeshTemplates.Get(name: Name): MeshPart?
	return templates[name]
end

local function folderIn(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

function MeshTemplates.Replicate()
	local meshes = folderIn(folderIn(ReplicatedStorage, "Assets"), "Meshes")
	for _, name in names do
		local template = templates[name]
		local old = meshes:FindFirstChild(name)
		if old then
			old:Destroy()
		end
		if template then
			local copy = template:Clone()
			copy.Name = name
			copy.Anchored = true
			copy.Parent = meshes
		end
	end
end

function MeshTemplates.Destroy()
	generation += 1
	pending = 0
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local meshes = if assets then assets:FindFirstChild("Meshes") else nil
	if meshes then
		for _, name in names do
			local copy = meshes:FindFirstChild(name)
			if copy then
				copy:Destroy()
			end
		end
	end
	for name, template in templates do
		template:Destroy()
		templates[name] = nil
	end
end

return MeshTemplates
