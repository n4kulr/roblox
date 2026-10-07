--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local WorldNames = require(ReplicatedStorage.Config.WorldNames)
local FloorGrid = require(ReplicatedStorage.Rules.FloorGrid)
local Trove = require(ReplicatedStorage.Packages.Trove)
local FloorKeys = require(script.Parent.Parent.Parent.Utils.FloorKeys)
local OwnerSign = require(script.Parent.Parent.Parent.Utils.OwnerSign)
local Caps = require(script.Parent.Caps)
local Lock = require(script.Parent.Lock)
local Present = require(script.Parent.Present)
local Types = require(script.Parent.Types)
local Walls = require(script.Parent.Walls)
local Parts = require(ReplicatedStorage.Utils.Parts)

type TroveInstance = typeof(Trove.new())
type PlotInfo = Types.PlotInfo

local walkwayThickness = 0.2

local Build = {}

local function findPart(model: Model, name: string): BasePart?
	local child = model:FindFirstChild(name)
	return if child and child:IsA("BasePart") then child else nil
end

local function createCaps(context: Types.Context, info: PlotInfo, trove: TroveInstance)
	local existing = info.Model:FindFirstChild(WorldNames.Folders.Keys)
	if existing then
		existing:Destroy()
	end
	local layout = info.Layout
	local folder = Instance.new("Folder")
	folder.Name = WorldNames.Folders.Keys
	table.clear(info.Caps)
	table.clear(info.FloorCaps)
	table.clear(info.Visuals)
	for _, cell in layout.Cells do
		local cap = Caps.Create(info, cell)
		cap.Parent = folder
		table.insert(info.FloorCaps, cap)
		local slot = cell.Slot
		if slot then
			info.Caps[slot] = cap
		end
	end
	if #info.Caps < GameConfig.BoardSlots and not context.HasWarnedSlots then
		context.HasWarnedSlots = true
		warn(
			`[PlotService] {info.Model:GetFullName()} only fits {#info.Caps} of {GameConfig.BoardSlots} slot keys`
		)
	end
	local baseSize = info.Base.Size
	local walkway = Parts.New({
		Name = WorldNames.Parts.Walkway,
		Parent = folder,
		Anchored = true,
		CanCollide = true,
		CanQuery = true,
		CanTouch = false,
		Transparency = 1,
		Size = Vector3.new(baseSize.X, walkwayThickness, baseSize.Z),
		CFrame = info.Base.CFrame * CFrame.new(0, baseSize.Y / 2 + FloorKeys.Top() - walkwayThickness / 2, 0),
	})
	info.Walkway = walkway
	info.Model:SetAttribute(WorldNames.Attributes.FloorCell, FloorGrid.CellSize)
	info.Model:SetAttribute(WorldNames.Attributes.FloorGap, FloorGrid.CellGap)
	info.Model:SetAttribute(WorldNames.Attributes.FloorColumns, layout.Columns)
	info.Model:SetAttribute(WorldNames.Attributes.FloorRows, layout.Rows)
	folder.Parent = info.Model
	trove:Add(folder)
end

local function skinRollKey(context: Types.Context, info: PlotInfo)
	local template = context.Services.MeshService:Get("RollKey")
	local old = info.RollKey
	if not template or old:IsA("MeshPart") then
		return
	end
	local key = template:Clone()
	key.Name = WorldNames.Parts.RollKey
	key.Anchored = true
	key.Size = old.Size
	key.CFrame = old.CFrame
	key.Color = old.Color
	key.Material = old.Material
	key.Transparency = old.Transparency
	key.Parent = old.Parent
	old:Destroy()
	info.RollKey = key
end

function Build.Collect(context: Types.Context, folder: Instance, trove: TroveInstance, isPlaceholder: boolean)
	local models: { Model } = {}
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			table.insert(models, child)
		end
	end
	table.sort(models, function(a: Model, b: Model)
		return a.Name < b.Name
	end)
	for _, model in models do
		local base = findPart(model, WorldNames.Parts.Base)
		local rollKey = findPart(model, WorldNames.Parts.RollKey)
		local board = findPart(model, "Board")
		if base and rollKey and board then
			local useMeshes = isPlaceholder or model:GetAttribute(WorldNames.Attributes.UseMeshes) == true
			model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			local info: PlotInfo = {
				Model = model,
				Base = base,
				RollKey = rollKey,
				Board = board,
				Caps = {},
				FloorCaps = {},
				Visuals = {},
				Layout = nil :: any,
				Owner = nil,
				Placeholder = useMeshes,
				Walkway = nil,
				Sign = nil,
				GlassWalls = nil,
				GlassParts = {},
				FenceRise = 0,
				Frame = nil,
				WallHeight = 0,
				WallLevel = 0,
				Defense = nil,
			}
			if useMeshes then
				skinRollKey(context, info)
			end
			board.Transparency = 1
			board.CanCollide = false
			info.Layout = FloorGrid.ForPlot(base, info.RollKey, board)
			createCaps(context, info, trove)
			Walls.Build(info, 0)
			info.Defense = Lock.Build()
			Present.Lock(info)
			info.Sign = OwnerSign.new(model, base, trove)
			table.insert(context.Plots, info)
		else
			warn(
				`[PlotService] {model:GetFullName()} needs BasePart children Base, RollKey and Board; skipped`
			)
		end
	end
end

return Build
