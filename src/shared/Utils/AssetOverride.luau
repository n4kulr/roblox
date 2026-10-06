--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AssetOverride = {}

function AssetOverride.Find(category: string, id: string): Model?
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local folder = if assets then assets:FindFirstChild(category) else nil
	local source = if folder then folder:FindFirstChild(id) else nil
	if not source then
		return nil
	end
	if source:IsA("Model") then
		local model = source:Clone()
		model.Name = id
		return model
	end
	if source:IsA("BasePart") then
		local model = Instance.new("Model")
		model.Name = id
		local part = source:Clone()
		part.Parent = model
		model.PrimaryPart = part
		return model
	end
	return nil
end

return AssetOverride
