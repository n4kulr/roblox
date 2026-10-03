--!strict

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Meshes = require(ReplicatedStorage.Config.Meshes)
local Signal = require(ReplicatedStorage.Packages.Signal)

export type Name = "Keycap" | "RollKey" | "KeyboardCase"

local names: { Name } = { "Keycap", "RollKey", "KeyboardCase" }
local templates: { [string]: MeshPart } = {}
local generation = 0

local MeshTemplates = {
	Changed = Signal.new() :: any,
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
	if not ok then
		warn(`[MeshTemplates] {name} mesh {meshId} failed to load, using plain parts: {result}`)
		return
	end
	local template = result :: MeshPart
	template.Name = name
	template.Anchored = true
	templates[name] = template
	MeshTemplates.Changed:Fire(name)
end

function MeshTemplates.Load()
	generation += 1
	local current = generation
	local ids = Meshes :: { [string]: string }
	for _, name in names do
		local meshId = ids[name]
		if meshId ~= "" then
			task.spawn(create, name, meshId, current)
		end
	end
end

function MeshTemplates.Get(name: Name): MeshPart?
	return templates[name]
end

function MeshTemplates.Destroy()
	generation += 1
	for name, template in templates do
		template:Destroy()
		templates[name] = nil
	end
end

return MeshTemplates
