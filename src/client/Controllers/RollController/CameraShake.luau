--!strict

type Entry = {
	Base: Vector3,
	Sources: { [any]: Vector3 },
}

local entries: { [Humanoid]: Entry } = setmetatable({}, { __mode = "k" }) :: any

local CameraShake = {}

local function apply(humanoid: Humanoid, entry: Entry)
	local total = entry.Base
	for _, offset in entry.Sources do
		total += offset
	end
	humanoid.CameraOffset = total
end

function CameraShake.Set(humanoid: Humanoid, source: any, offset: Vector3)
	local entry = entries[humanoid]
	if not entry then
		entry = { Base = humanoid.CameraOffset, Sources = {} }
		entries[humanoid] = entry
	end
	local active = entry :: Entry
	active.Sources[source] = offset
	apply(humanoid, active)
end

function CameraShake.Clear(humanoid: Humanoid, source: any)
	local entry = entries[humanoid]
	if not entry or (entry.Sources :: { [any]: Vector3? })[source] == nil then
		return
	end
	entry.Sources[source] = nil
	if next(entry.Sources) == nil then
		entries[humanoid] = nil
		humanoid.CameraOffset = entry.Base
	else
		apply(humanoid, entry)
	end
end

function CameraShake.IsShaking(humanoid: Humanoid): boolean
	return entries[humanoid] ~= nil
end

return CameraShake
