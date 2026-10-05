--!strict

local Types = require(script.Parent.Types)

local Finder = {}

Finder.RoleAttribute = "ObbyRole"

function Finder.MarketPosition(): Vector3?
	local market = workspace:FindFirstChild("Market")
	if not market then
		return nil
	end
	local counter = market:FindFirstChild("Counter", true)
	if counter and counter:IsA("BasePart") then
		return counter.CFrame.Position
	end
	if market:IsA("Model") and market.PrimaryPart then
		return market.PrimaryPart.CFrame.Position
	end
	for _, descendant in market:GetDescendants() do
		if descendant:IsA("BasePart") then
			return descendant.CFrame.Position
		end
	end
	return nil
end

function Finder.Collect(model: Model): Types.Info?
	local zone: BasePart? = nil
	local tapKeys: { BasePart } = {}
	local kills: { BasePart } = {}
	local checkpoints: { BasePart } = {}
	local homes: { BasePart } = {}
	local spawns: { Types.SpawnPoint } = {}
	local gates: { BasePart } = {}
	local popUps: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		local role = descendant:GetAttribute(Finder.RoleAttribute)
		if descendant:IsA("BasePart") and type(role) == "string" then
			if role == "Zone" then
				zone = descendant
			elseif role == "TapKey" then
				table.insert(tapKeys, descendant)
			elseif role == "PopUpKey" then
				table.insert(tapKeys, descendant)
				table.insert(popUps, descendant)
			elseif role == "Kill" then
				table.insert(kills, descendant)
			elseif role == "Checkpoint" then
				table.insert(checkpoints, descendant)
			elseif role == "Home" then
				table.insert(homes, descendant)
			elseif role == "SpeedGate" then
				table.insert(gates, descendant)
			elseif role == "KeySpawn" then
				local rarities = descendant:GetAttribute("Rarities")
				table.insert(
					spawns,
					{ Part = descendant, Rarities = if type(rarities) == "string" then rarities else "Rare" }
				)
			end
		end
	end
	if not zone then
		return nil
	end
	return {
		Model = model,
		Zone = zone,
		TapKeys = tapKeys,
		Kills = kills,
		Checkpoints = checkpoints,
		Homes = homes,
		Spawns = spawns,
		Gates = gates,
		PopUps = popUps,
	}
end

function Finder.FindAuthored(name: string): Types.Info?
	local found = workspace:FindFirstChild(name)
	if not found or not found:IsA("Model") then
		return nil
	end
	return Finder.Collect(found)
end

return Finder
