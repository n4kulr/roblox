--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Keys = require(ReplicatedStorage.Config.Keys)
local UiAssets = require(ReplicatedStorage.Config.UiAssets)
local FloorGrid = require(ReplicatedStorage.Rules.FloorGrid)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local MeshTemplates = require(script.Parent.Parent.Parent.Utils.MeshTemplates)
local PlayerData = require(script.Parent.Parent.Parent.Data.PlayerData)
local Types = require(script.Parent.Types)

local Caps = {
	FillerColor = Color3.fromRGB(58, 56, 62),
	FillerSink = 0.35,
	EmptyColor = Color3.fromRGB(196, 210, 228),
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

local function applyFiller(cap: BasePart)
	cap.Color = Caps.FillerColor
	cap.Material = Enum.Material.SmoothPlastic
	cap.Reflectance = 0
	cap.Transparency = 0
end

function Caps.Create(info: Types.PlotInfo, cell: FloorGrid.Cell): BasePart
	local template = MeshTemplates.Get("Keycap")
	local cap: BasePart = if template then template:Clone() else Instance.new("Part")
	local capSize = FloorGrid.CapSize()
	local slot = cell.Slot
	local sink = if slot then 0 else Caps.FillerSink
	cap.Anchored = true
	cap.CanCollide = false
	cap.CanQuery = false
	cap.CanTouch = false
	cap.CastShadow = false
	cap.Size = Vector3.new(capSize, capHeight, capSize)
	cap.CFrame = info.Base.CFrame * CFrame.new(cell.X, info.Base.Size.Y / 2 + capHeight / 2 - sink, cell.Z)
	cap:SetAttribute("Cell", cell.Index)
	applyFiller(cap)
	if slot then
		cap.Name = `Slot{slot}`
		cap:SetAttribute("Slot", slot)
	else
		cap.Name = `Floor{cell.Index}`
		cap:SetAttribute("Filler", true)
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
		Lock = lock,
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

local function showKey(cap: BasePart, visual: Types.CapVisual, key: Keys.Key)
	local rarity = Keys.GetRarity(key)
	cap.Color = rarity.Color
	Keys.ApplyFinish(cap, rarity)
	cap.Transparency = 0
	cap:SetAttribute("KeyId", key.Id)
	cap:SetAttribute("Locked", nil)
	visual.Amount.Text = `+{NumberFormat.Compact(Keys.GetIncome(key.Id))}/s`
	visual.Amount.TextColor3 = rarity.Color:Lerp(white, textLighten)
	visual.Billboard.Enabled = true
	visual.Surface.Enabled = true
	visual.Rim.Visible = true
	visual.Stroke.Color = rarity.Color:Lerp(white, rimLighten)
	visual.Stroke.Transparency = 0.1
	visual.Plus.Visible = false
	visual.Lock.Visible = false
end

local function showEmpty(cap: BasePart, visual: Types.CapVisual)
	cap.Color = Caps.EmptyColor
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
	visual.Lock.Visible = false
end

local function showLocked(cap: BasePart, visual: Types.CapVisual, hasOwner: boolean)
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
	visual.Lock.Visible = hasOwner
end

function Caps.Render(info: Types.PlotInfo, data: PlayerData.Data?, unlocked: number)
	for slot, cap in info.Caps do
		local key = if data and slot <= unlocked then Keys.ById[data.Board[slot]] else nil
		local state = if key
			then key.Id
			elseif not data then noState
			elseif slot > unlocked then lockedState
			else emptyState
		local visual = visualOf(info, cap)
		if visual.State ~= state then
			visual.State = state
			if key then
				showKey(cap, visual, key)
			elseif state == emptyState then
				showEmpty(cap, visual)
			else
				showLocked(cap, visual, data ~= nil)
			end
		end
	end
end

return Caps
