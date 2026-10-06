--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Keys = require(ReplicatedStorage.Config.Keys)
local UiAssets = require(ReplicatedStorage.Config.UiAssets)
local FloorGrid = require(ReplicatedStorage.Rules.FloorGrid)
local Gui = require(ReplicatedStorage.Utils.Gui)
local KeyLegend = require(ReplicatedStorage.Utils.KeyLegend)
local KeyModels = require(ReplicatedStorage.Utils.KeyModels)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local FloorKeys = require(script.Parent.Parent.Parent.Utils.FloorKeys)
local Legend = require(script.Parent.Parent.Parent.Utils.Legend)
local PlayerData = require(script.Parent.Parent.Parent.Data.PlayerData)
local Types = require(script.Parent.Types)

local Caps = {
	SlotRaise = 0.6,
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

function Caps.EmptyColor(base: Color3): Color3
	return base:Lerp(white, Caps.EmptyLighten)
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

function Caps.Create(info: Types.PlotInfo, cell: FloorGrid.Cell): BasePart
	local slot = cell.Slot
	local sink = if slot then FloorKeys.Sink - Caps.SlotRaise else FloorKeys.Sink
	local baseColor = Caps.ThemeColor(info.Model, info.Base.Color)
	local cap = FloorKeys.Blank(
		info.Base.CFrame * CFrame.new(cell.X, info.Base.Size.Y / 2 + capHeight / 2 - sink, cell.Z),
		FloorKeys.Color(baseColor)
	)
	cap:SetAttribute("Cell", cell.Index)
	cap:SetAttribute("PressDepth", capHeight - sink - FloorKeys.Top())
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

local function newVisual(cap: BasePart): Types.CapVisual
	local surface = Gui.Surface(nil, {
		Name = "Top",
		Face = Enum.NormalId.Top,
		Adornee = cap,
		PixelsPerStud = KeyLegend.PixelsPerStud,
		LightInfluence = 0,
		AlwaysOnTop = false,
		MaxDistance = Caps.SurfaceMaxDistance,
	})
	local rim, stroke = KeyLegend.Rim(surface)
	surface.Parent = cap
	return {
		State = noState,
		Billboard = nil,
		Amount = nil,
		Surface = surface,
		Rim = rim,
		Stroke = stroke,
		Plus = nil,
		Letter = nil,
		Lock = nil,
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

local function amountOf(cap: BasePart, visual: Types.CapVisual): TextLabel
	local amount = visual.Amount
	if amount then
		return amount
	end
	local billboard = Gui.Billboard(nil, {
		Name = "Income",
		Adornee = cap,
		Size = UDim2.fromOffset(110, 30),
		Offset = Vector3.new(0, 2.4, 0),
		AlwaysOnTop = false,
		LightInfluence = 0,
		MaxDistance = Caps.IncomeMaxDistance,
		Enabled = false,
	})
	local created = Gui.Label(billboard, {
		Name = "Amount",
		Centered = true,
		Color = white,
		TextStrokeColor = strokeColor,
		TextStrokeTransparency = 0.15,
	})
	billboard.Parent = cap
	visual.Billboard = billboard
	visual.Amount = created
	return created
end

local function plusOf(visual: Types.CapVisual): TextLabel
	local plus = visual.Plus
	if plus then
		return plus
	end
	local created = Gui.Label(visual.Surface, {
		Name = "Plus",
		Text = "+",
		Centered = true,
		Size = UDim2.fromScale(0.5, 0.5),
		Color = white,
		Transparency = 0.45,
	})
	visual.Plus = created
	return created
end

local function letterOf(visual: Types.CapVisual): TextLabel
	local letter = visual.Letter
	if letter then
		return letter
	end
	local created = KeyLegend.Letter(visual.Surface, { Text = "", StrokeColor = strokeColor })
	visual.Letter = created
	return created
end

local function lockOf(visual: Types.CapVisual): ImageLabel
	local lock = visual.Lock
	if lock then
		return lock
	end
	local created = Instance.new("ImageLabel")
	created.Name = "Lock"
	created.BackgroundTransparency = 1
	created.AnchorPoint = Vector2.new(0.5, 0.5)
	created.Position = UDim2.fromScale(0.5, 0.5)
	created.Size = UDim2.fromScale(0.5, 0.5)
	created.Image = UiAssets.IconAtlas
	created.ImageRectOffset = UiAssets.LockIcon
	created.ImageRectSize = Vector2.new(UiAssets.IconCell, UiAssets.IconCell)
	created.ImageTransparency = 0.15
	created.ScaleType = Enum.ScaleType.Fit
	created.Parent = visual.Surface
	visual.Lock = created
	return created
end

local function setVisible(item: GuiObject?, isVisible: boolean)
	if item then
		item.Visible = isVisible
	end
end

local function hideBillboard(visual: Types.CapVisual)
	local billboard = visual.Billboard
	if billboard then
		billboard.Enabled = false
	end
end

local function paintCap(cap: BasePart, color: Color3, transparency: number, isLocked: boolean)
	cap.Color = color
	cap.Material = Enum.Material.SmoothPlastic
	cap.Reflectance = 0
	cap.Transparency = transparency
	cap:SetAttribute("KeyId", nil)
	cap:SetAttribute("Locked", if isLocked then true else nil)
end

local function showKey(cap: BasePart, visual: Types.CapVisual, keyId: string, key: Keys.Key)
	local rarity = Keys.GetRarity(key)
	Keys.ApplyVariantFinish(cap, keyId)
	cap.Transparency = 0
	cap:SetAttribute("KeyId", keyId)
	cap:SetAttribute("Locked", nil)
	local amount = amountOf(cap, visual)
	amount.Text = `+{NumberFormat.Compact(Keys.GetIncome(keyId))}/s`
	amount.TextColor3 = rarity.Color:Lerp(white, textLighten)
	local billboard = visual.Billboard :: BillboardGui
	billboard.Enabled = true
	visual.Surface.Enabled = true
	visual.Rim.Visible = true
	visual.Stroke.Color = rarity.Color:Lerp(white, rimLighten)
	visual.Stroke.Transparency = 0.1
	setVisible(visual.Plus, false)
	setVisible(visual.Lock, false)
	local letter = letterOf(visual)
	letter.Text = string.upper(string.sub(key.Name, 1, 1))
	letter.Visible = true
	clearDecor(visual)
	visual.Decor = KeyModels.Mount(cap, key.Id)
end

local function showEmpty(cap: BasePart, visual: Types.CapVisual, base: Color3)
	clearDecor(visual)
	paintCap(cap, Caps.EmptyColor(base), Caps.EmptyTransparency, false)
	hideBillboard(visual)
	visual.Surface.Enabled = true
	visual.Rim.Visible = true
	visual.Stroke.Color = emptyRimColor
	visual.Stroke.Transparency = 0.3
	plusOf(visual).Visible = true
	setVisible(visual.Letter, false)
	setVisible(visual.Lock, false)
end

local function showLocked(cap: BasePart, visual: Types.CapVisual)
	clearDecor(visual)
	paintCap(cap, Caps.LockedColor, Caps.LockedTransparency, true)
	hideBillboard(visual)
	visual.Surface.Enabled = true
	visual.Rim.Visible = true
	visual.Stroke.Color = lockedRimColor
	visual.Stroke.Transparency = 0.4
	setVisible(visual.Plus, false)
	setVisible(visual.Letter, false)
	lockOf(visual).Visible = true
end

local function showUnowned(info: Types.PlotInfo, cap: BasePart)
	local visual = info.Visuals[cap]
	if visual then
		info.Visuals[cap] = nil
		clearDecor(visual)
		visual.Surface:Destroy()
		if visual.Billboard then
			visual.Billboard:Destroy()
		end
	end
	paintCap(cap, Caps.LockedColor, Caps.LockedTransparency, false)
end

function Caps.Render(info: Types.PlotInfo, data: PlayerData.Data?, unlocked: number)
	for slot, cap in info.Caps do
		if not data then
			showUnowned(info, cap)
		else
			local boardId = if slot <= unlocked then data.Board[slot] else nil
			local key = Keys.Resolve(boardId)
			local state = if key and boardId
				then boardId
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
					showLocked(cap, visual)
				end
			end
		end
	end
end

return Caps
