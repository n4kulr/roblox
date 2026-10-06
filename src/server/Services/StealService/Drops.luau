--!strict

local CollectionService = game:GetService("CollectionService")
local KeyVisual = require(script.Parent.Parent.Parent.Utils.KeyVisual)
local Prompts = require(script.Parent.Prompts)

local capSize = Vector3.new(2.4, 1.2, 2.4)
local groundProbe = 12
local hipHeight = 3
local spinSpeed = 120
local lift = 0.4
local spinnerTag = "Spinner"

local Drops = {
	PartName = "DroppedKey",
}

local function groundPosition(root: BasePart, character: Model?): Vector3
	local position = root.CFrame.Position
	local fallback = position - Vector3.new(0, hipHeight - capSize.Y / 2 - lift, 0)
	local ok, result = pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = if character then { character } else {}
		return workspace:Raycast(position, Vector3.new(0, -groundProbe, 0), params)
	end)
	if ok and result then
		return result.Position + Vector3.new(0, capSize.Y / 2 + lift, 0)
	end
	return fallback
end

function Drops.Build(
	keyId: string,
	ownerUserId: number,
	ownerName: string,
	root: BasePart,
	character: Model?
): (BasePart?, ProximityPrompt?)
	local part = KeyVisual.NewCap(keyId, Drops.PartName, capSize)
	if not part then
		return nil, nil
	end
	part.Anchored = true
	part.CanCollide = false
	part.Massless = false
	part.CFrame = CFrame.new(groundPosition(root, character))
	part:SetAttribute("OwnerUserId", ownerUserId)
	part:SetAttribute("KeyId", keyId)
	part:SetAttribute("SpinSpeed", spinSpeed)
	local gui = Instance.new("BillboardGui")
	gui.Name = "OwnerTag"
	gui.Size = UDim2.fromOffset(220, 44)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.Name = "Owner"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 236, 140)
	label.TextStrokeTransparency = 0
	label.Text = `OWNER: {ownerName}`
	label.Parent = gui
	gui.Parent = part
	local prompt = Prompts.CreateTakeBack(part, ownerUserId, keyId)
	CollectionService:AddTag(part, spinnerTag)
	return part, prompt
end

function Drops.Release(part: BasePart)
	pcall(function()
		CollectionService:RemoveTag(part, spinnerTag)
	end)
	part:Destroy()
end

return Drops
