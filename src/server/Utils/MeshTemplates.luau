--!strict

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Meshes = require(ReplicatedStorage.Config.Meshes)
local Signal = require(ReplicatedStorage.Packages.Signal)

export type Name = "Keycap" | "RollKey" | "KeyboardCase"

local names: { Name } = { "Keycap", "RollKey", "KeyboardCase" }
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
	for _, name in names do
		local meshId = ids[name]
		if meshId ~= "" then
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

function MeshTemplates.Destroy()
	generation += 1
	pending = 0
	for name, template in templates do
		template:Destroy()
		templates[name] = nil
	end
end

return MeshTemplates
