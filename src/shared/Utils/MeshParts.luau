--!strict

local AssetService = game:GetService("AssetService")

local templates: { [string]: MeshPart } = {}

local MeshParts = {}

function MeshParts.IdOf(ids: { [string]: string }, id: string): string?
	local meshId = ids[id]
	if type(meshId) == "string" and meshId ~= "" then
		return meshId
	end
	return nil
end

function MeshParts.Template(meshId: string): MeshPart?
	local cached = templates[meshId]
	if cached then
		return cached
	end
	local ok, result = pcall(function()
		return AssetService:CreateMeshPartAsync(Content.fromUri(meshId), {
			CollisionFidelity = Enum.CollisionFidelity.Box,
			RenderFidelity = Enum.RenderFidelity.Precise,
		})
	end)
	if not ok then
		warn(`[MeshParts] mesh {meshId} failed to load: {result}`)
		return nil
	end
	local template = result :: MeshPart
	template.Anchored = true
	template.CanCollide = false
	template.CanQuery = false
	template.CanTouch = false
	template.Massless = true
	template.CastShadow = false
	template.Material = Enum.Material.SmoothPlastic
	templates[meshId] = template
	return template
end

function MeshParts.Clone(meshId: string, name: string): MeshPart?
	local template = MeshParts.Template(meshId)
	if not template then
		return nil
	end
	local part = template:Clone()
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	return part
end

return table.freeze(MeshParts)
