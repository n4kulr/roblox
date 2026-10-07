--!strict

local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WorldNames = require(ReplicatedStorage.Config.WorldNames)

local EditorOnly = {}

EditorOnly.Tag = WorldNames.Tags.EditorOnly

function EditorOnly.Strip()
	local tagged = CollectionService:GetTagged(EditorOnly.Tag)
	if #tagged == 0 then
		return
	end
	local storage = ServerStorage:FindFirstChild(EditorOnly.Tag)
	if not storage then
		storage = Instance.new("Folder")
		storage.Name = EditorOnly.Tag
		storage.Parent = ServerStorage
	end
	for _, instance in tagged do
		if not instance:IsDescendantOf(ServerStorage) then
			instance.Parent = storage
		end
	end
end

return EditorOnly
