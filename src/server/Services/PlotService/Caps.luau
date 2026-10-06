--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Keys = require(ReplicatedStorage.Config.Keys)
local UiAssets = require(ReplicatedStorage.Config.UiAssets)
local FloorGrid = require(ReplicatedStorage.Rules.FloorGrid)
local KeyModels = require(ReplicatedStorage.Utils.KeyModels)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local MeshTemplates = require(script.Parent.Parent.Parent.Utils.MeshTemplates)
local PlayerData = require(script.Parent.Parent.Parent.Data.PlayerData)
local Legend = require(script.Parent.Legend)
local Types = require(script.Parent.Types)

local Caps = {
	FillerSink = 0.35,
	SlotRaise = 0.6,
	FillerPress = 0.75,
	FillerLighten = 0.45,
	EmptyLighten = 0.25,
	EmptyTransparency = 0.4,
	LockedColor = Color3.fromRGB(26, 26, 30),
	LockedTransparency = 0.45,
	IncomeMaxDistance = 45,
	SurfaceMaxDistance = 70,
}

local capHeight = FloorGrid.CapHeight
local white = Color3.new(1, 1, 1)
local strokeColor = Color3.fromRGB(20, 18, 28)
local emptyRimColor = Color3.fromRGB(235, 244, 255)
local lockedRimColor = Color3.fromRGB(70, 70, 78)
local rimLighten = 0.45
local textLighten = 0.3
local noState = "None"
local emptyState = "Empty"
local lockedState = "Locked"

function Caps.FillerColor(base: Color3): Color3
	return base:Lerp(white, Caps.FillerLighten)
end

function Caps.EmptyColor(base: Color3): Color3
	return base:Lerp(white, Caps.EmptyLighten)
end

local function applyFiller(cap: BasePart, color: Color3)
	cap.Color = color
	cap.Material = Enum.Material.SmoothPlastic
	cap.Reflectance = 0
	cap.Transparency = 0
end

function Caps.Blank(cframe: CFrame, color: Color3): BasePart
	local template = MeshTemplates.Get("Keycap")
	local cap: BasePart = if template then template:Clone() else Instance.new("Part")
	local capSize = FloorGrid.CapSize()
	cap.Anchored = true
	cap.CanCollide = false
	cap.CanQuery = false
	cap.CanTouch = false
	cap.CastShadow = false
	cap.Size = Vector3.new(capSize, capHeight, capSize)
	cap.CFrame = cframe
	applyFiller(cap, color)
	return cap
end

local function fenceColor(model: Instance, fallback: Color3): Color3
	local fence = model:FindFirstChild("Fence")
	if not fence then
		return fallback
	end
	local counts: { [string]: number } = {}
	local colors: { [string]: Color3 } = {}
	local best: string? = nil
	local parts: { Instance } = table.clone(fence:GetDescendants())
	if fence:IsA("BasePart") then
		table.insert(parts, fence)
	end
	for _, part in parts do
		local color: Color3? = if part:IsA("BasePart") then (part :: any).Color else nil
		local size: Vector3? = if part:IsA("BasePart") then (part :: any).Size else nil
		if color and size and (part :: BasePart).Transparency < 1 then
			local key = string.format(
				"%d,%d,%d",
				math.floor(color.R * 255 + 0.5),
				math.floor(color.G * 255 + 0.5),
				math.floor(color.B * 255 + 0.5)
			)
			counts[key] = (counts[key] or 0) + size.X * size.Y * size.Z
			colors[key] = color
			if best == nil or counts[key] > counts[best] then
				best = key
			end
		end
	end
	return if best then colors[best] else fallback
end

function Caps.ThemeColor(model: Instance, fallback: Color3): Color3
	local ok, result = pcall(fenceColor, model, fallback)
	return if ok then result else fallback
end

function Caps.FloorTop(): number
	return capHeight - Caps.FillerSink - Caps.FillerPress
end

function Caps.Create(info: Types.PlotInfo, cell: FloorGrid.Cell): BasePart
	local slot = cell.Slot
	local sink = if slot then Caps.FillerSink - Caps.SlotRaise else Caps.FillerSink
	local baseColor = Caps.ThemeColor(info.Model, info.Base.Color)
	local cap = Caps.Blank(
		info.Base.CFrame * CFrame.new(cell.X, info.Base.Size.Y / 2 + capHeight / 2 - sink, cell.Z),
		Caps.FillerColor(baseColor)
	)
	cap:SetAttribute("Cell", cell.Index)
	cap:SetAttribute("PressDepth", capHeight - sink - Caps.FloorTop())
	if slot then
		cap.Name = `Slot{slot}`
		cap:SetAttribute("Slot", slot)
	else
		cap.Name = `Floor{cell.Index}`
		cap:SetAttribute("Filler", true)
		Legend.Attach(cap, Legend.SeedOf(info.Model.Name, cell.Index), Legend.ColorFor(baseColor))
	end
	return cap
end

local function newLabel(parent: Instance, name: string, text: string, size: UDim2): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.5)
	label.Size = size
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextColor3 = white
	label.TextScaled = true
	label.Parent = parent
	return label
end

local function newVisual(cap: BasePart): Types.CapVisual
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Income"
	billboard.Adornee = cap
	billboard.Size = UDim2.fromOffset(110, 30)
	billboard.StudsOffset = Vector3.new(0, 2.4, 0)
	billboard.AlwaysOnTop = false
	billboard.LightInfluence = 0
	billboard.MaxDistance = Caps.IncomeMaxDistance
	billboard.Enabled = false
	local income = newLabel(billboard, "Amount", "", UDim2.fromScale(1, 1))
	income.TextStrokeColor3 = strokeColor
	income.TextStrokeTransparency = 0.15
	billboard.Parent = cap

	local surface = Instance.new("SurfaceGui")
	surface.Name = "Top"
	surface.Face = Enum.NormalId.Top
	surface.Adornee = cap
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 40
	surface.LightInfluence = 0
	surface.AlwaysOnTop = false
	surface.MaxDistance = Caps.SurfaceMaxDistance
	local rim = Instance.new("Frame")
	rim.Name = "Rim"
	rim.BackgroundTransparency = 1
	rim.Size = UDim2.fromScale(1, 1)
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = rim
	rim.Parent = surface
	local plus = newLabel(surface, "Plus", "+", UDim2.fromScale(0.5, 0.5))
	plus.TextTransparency = 0.45
	local letter = newLabel(surface, "Letter", "", UDim2.fromScale(0.62, 0.62))
	letter.TextStrokeColor3 = strokeColor
	letter.TextStrokeTransparency = 0.2
	letter.Visible = false
	local lock = Instance.new("ImageLabel")
	lock.Name = "Lock"
	lock.BackgroundTransparency = 1
	lock.AnchorPoint = Vector2.new(0.5, 0.5)
	lock.Position = UDim2.fromScale(0.5, 0.5)
	lock.Size = UDim2.fromScale(0.5, 0.5)
	lock.Image = UiAssets.IconAtlas
	lock.ImageRectOffset = UiAssets.LockIcon
	lock.ImageRectSize = Vector2.new(UiAssets.IconCell, UiAssets.IconCell)
	lock.ImageTransparency = 0.15
	lock.ScaleType = Enum.ScaleType.Fit
	lock.Parent = surface
	surface.Parent = cap

	return {
		State = noState,
		Billboard = billboard,
		Amount = income,
		Surface = surface,
		Rim = rim,
		Stroke = stroke,
		Plus = plus,
		Letter = letter,
		Lock = lock,
		Decor = nil,
	}
end

local function visualOf(info: Types.PlotInfo, cap: BasePart): Types.CapVisual
	local visual = info.Visuals[cap]
	if not visual then
		visual = newVisual(cap)
		info.Visuals[cap] = visual
	end
	return visual
end

local function clearDecor(visual: Types.CapVisual)
	local decor = visual.Decor
	if decor then
		visual.Decor = nil
		decor:Destroy()
	end
end

local function showKey(cap: BasePart, visual: Types.CapVisual, keyId: string, key: Keys.Key)
	local rarity = Keys.GetRarity(key)
	Keys.ApplyVariantFinish(cap, keyId)
	cap.Transparency = 0
	cap:SetAttribute("KeyId", keyId)
	cap:SetAttribute("Locked", nil)
	visual.Amount.Text = `+{NumberFormat.Compact(Keys.GetIncome(keyId))}/s`
	visual.Amount.TextColor3 = rarity.Color:Lerp(white, textLighten)
	visual.Billboard.Enabled = true
	visual.Surface.Enabled = true
	visual.Rim.Visible = true
	visual.Stroke.Color = rarity.Color:Lerp(white, rimLighten)
	visual.Stroke.Transparency = 0.1
	visual.Plus.Visible = false
	visual.Lock.Visible = false
	visual.Letter.Text = string.upper(string.sub(key.Name, 1, 1))
	visual.Letter.Visible = true
	clearDecor(visual)
	visual.Decor = KeyModels.Mount(cap, key.Id)
end

local function showEmpty(cap: BasePart, visual: Types.CapVisual, base: Color3)
	clearDecor(visual)
	cap.Color = Caps.EmptyColor(base)
	cap.Material = Enum.Material.SmoothPlastic
	cap.Reflectance = 0
	cap.Transparency = Caps.EmptyTransparency
	cap:SetAttribute("KeyId", nil)
	cap:SetAttribute("Locked", nil)
	visual.Billboard.Enabled = false
	visual.Surface.Enabled = true
	visual.Rim.Visible = true
	visual.Stroke.Color = emptyRimColor
	visual.Stroke.Transparency = 0.3
	visual.Plus.Visible = true
	visual.Letter.Visible = false
	visual.Lock.Visible = false
end

local function showLocked(cap: BasePart, visual: Types.CapVisual, hasOwner: boolean)
	clearDecor(visual)
	cap.Color = Caps.LockedColor
	cap.Material = Enum.Material.SmoothPlastic
	cap.Reflectance = 0
	cap.Transparency = Caps.LockedTransparency
	cap:SetAttribute("KeyId", nil)
	cap:SetAttribute("Locked", if hasOwner then true else nil)
	visual.Billboard.Enabled = false
	visual.Surface.Enabled = hasOwner
	visual.Rim.Visible = true
	visual.Stroke.Color = lockedRimColor
	visual.Stroke.Transparency = 0.4
	visual.Plus.Visible = false
	visual.Letter.Visible = false
	visual.Lock.Visible = hasOwner
end

function Caps.Render(info: Types.PlotInfo, data: PlayerData.Data?, unlocked: number)
	for slot, cap in info.Caps do
		local boardId = if data and slot <= unlocked then data.Board[slot] else nil
		local key = Keys.Resolve(boardId)
		local state = if key and boardId
			then boardId
			elseif not data then noState
			elseif slot > unlocked then lockedState
			else emptyState
		local visual = visualOf(info, cap)
		if visual.State ~= state then
			visual.State = state
			if key and boardId then
				showKey(cap, visual, boardId, key)
			elseif state == emptyState then
				showEmpty(cap, visual, Caps.ThemeColor(info.Model, info.Base.Color))
			else
				showLocked(cap, visual, data ~= nil)
			end
		end
	end
end

return Caps
