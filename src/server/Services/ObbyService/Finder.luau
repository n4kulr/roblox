--!strict

local Types = require(script.Parent.Types)

local Finder = {}

Finder.RoleAttribute = "ObbyRole"

local canonical: { [string]: string } = {
	Zone = "Zone",
	Kill = "Kill",
	Checkpoint = "Checkpoint",
	Finish = "Finish",
	Return = "Return",
	Home = "Return",
	Tap = "Tap",
	TapKey = "Tap",
	Popup = "Popup",
	PopUpKey = "Popup",
	Gate = "Gate",
	SpeedGate = "Gate",
	KeySpawn = "KeySpawn",
}

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

local function numberAttribute(part: BasePart, name: string, fallback: number): number
	local value = part:GetAttribute(name)
	return if type(value) == "number" then value else fallback
end

function Finder.Collect(model: Model): Types.Info?
	local zone: BasePart? = nil
	local kills: { BasePart } = {}
	local checkpoints: { BasePart } = {}
	local returns: { BasePart } = {}
	local taps: { Types.TapPart } = {}
	local popups: { Types.PopupPart } = {}
	local gates: { Types.GatePart } = {}
	local spawns: { Types.SpawnPoint } = {}
	for _, descendant in model:GetDescendants() do
		local raw = descendant:GetAttribute(Finder.RoleAttribute)
		local role = if type(raw) == "string" then canonical[raw] else nil
		if descendant:IsA("BasePart") and role then
			if role == "Zone" then
				zone = descendant
			elseif role == "Kill" then
				table.insert(kills, descendant)
			elseif role == "Checkpoint" or role == "Finish" then
				table.insert(checkpoints, descendant)
			elseif role == "Return" then
				table.insert(returns, descendant)
			elseif role == "Tap" or role == "Popup" then
				local letter = descendant:GetAttribute("Letter")
				local cap: BasePart? = nil
				local faceName = string.gsub(descendant.Name, "Body$", "Top")
				local parent = descendant.Parent
				if faceName ~= descendant.Name and parent then
					local found = parent:FindFirstChild(faceName)
					if found and found:IsA("BasePart") then
						cap = found
					end
				end
				table.insert(taps, {
					Part = descendant,
					Rest = descendant.CFrame,
					Letter = if type(letter) == "string" then letter else "",
					Face = cap,
					FaceRest = if cap then cap.CFrame else nil,
				})
				if role == "Popup" then
					local upSeconds = numberAttribute(descendant, "PopupUp", 2.2)
					local downSeconds = numberAttribute(descendant, "PopupDown", 1.6)
					local phase = numberAttribute(descendant, "PopupPhase", 0)
					local depth = numberAttribute(descendant, "PopupDepth", 6)
					table.insert(popups, {
						Part = descendant,
						Up = descendant.CFrame,
						Down = descendant.CFrame * CFrame.new(0, -depth, 0),
						UpSeconds = upSeconds,
						DownSeconds = downSeconds,
						Phase = phase,
						IsUp = true,
					})
				end
			elseif role == "Gate" then
				table.insert(gates, {
					Part = descendant,
					SpeedNeeded = numberAttribute(descendant, "SpeedNeeded", 40),
					PushD = numberAttribute(descendant, "PushD", 0),
				})
			elseif role == "KeySpawn" then
				local section = descendant:GetAttribute("Section")
				local stage = descendant:GetAttribute("Stage")
				local value = if type(section) == "number"
					then section
					elseif type(stage) == "number" then stage
					else 1
				table.insert(spawns, { Part = descendant, Section = value })
			end
		end
	end
	if not zone then
		return nil
	end
	return {
		Model = model,
		Zone = zone,
		Kills = kills,
		Checkpoints = checkpoints,
		Returns = returns,
		Taps = taps,
		Popups = popups,
		Gates = gates,
		Spawns = spawns,
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
