--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Keys = require(ReplicatedStorage.Config.Keys)
local Trove = require(ReplicatedStorage.Packages.Trove)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)

type TroveInstance = typeof(Trove.new())
type PlotInfo = {
	Model: Model,
	Base: BasePart,
	RollKey: BasePart,
	Board: BasePart,
	Caps: { BasePart },
	Owner: Player?,
}
type State = {
	Name: string,
	_trove: TroveInstance?,
}

local PlotService = {
	Name = "PlotService",
	_trove = nil :: TroveInstance?,
}
local services: { [string]: any } = {}
local plots: { PlotInfo } = {}
local plotByPlayer: { [Player]: PlotInfo } = {}
local playerTroves: { [Player]: TroveInstance } = {}

local function newPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.Parent = parent
	return part
end

local function buildPlaceholderPlots(folder: Folder)
	local count = GameConfig.PlotCount
	for index = 1, count do
		local angle = (index - 1) / count * math.pi * 2
		local position = Vector3.new(math.cos(angle) * 80, 0.5, math.sin(angle) * 80)
		local origin = CFrame.lookAt(position, Vector3.new(0, position.Y, 0))
		local model = Instance.new("Model")
		model.Name = `Plot{index}`
		local base = newPart(model, "Base", Vector3.new(44, 1, 44), origin, Color3.fromRGB(70, 74, 86))
		newPart(
			model,
			"Stem",
			Vector3.new(3, 2, 3),
			origin * CFrame.new(0, 1.5, -10),
			Color3.fromRGB(60, 60, 66)
		)
		newPart(
			model,
			"RollKey",
			Vector3.new(8, 3, 8),
			origin * CFrame.new(0, 4, -10),
			Color3.fromRGB(215, 215, 220)
		)
		newPart(
			model,
			"Board",
			Vector3.new(24, 1.5, 10),
			origin * CFrame.new(0, 1.25, 12),
			Color3.fromRGB(35, 36, 42)
		)
		model.PrimaryPart = base
		model.Parent = folder
	end
end

local function findPart(model: Model, name: string): BasePart?
	local child = model:FindFirstChild(name)
	return if child and child:IsA("BasePart") then child else nil
end

local emptyCapColor = Color3.fromRGB(40, 41, 48)
local emptyCapTransparency = 0.6

local function createCaps(info: PlotInfo, trove: TroveInstance)
	local existing = info.Model:FindFirstChild("Keys")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Keys"
	local columns = GameConfig.BoardColumns
	local rows = math.ceil(GameConfig.BoardSlots / columns)
	local size = info.Board.Size
	local cellWidth = size.X / columns
	local cellDepth = size.Z / rows
	for slot = 1, GameConfig.BoardSlots do
		local column = (slot - 1) % columns
		local row = (slot - 1) // columns
		local cap = Instance.new("Part")
		cap.Name = `Slot{slot}`
		cap.Anchored = true
		cap.CanCollide = false
		cap.CanQuery = false
		cap.CanTouch = false
		cap.Size = Vector3.new(cellWidth * 0.8, 1, cellDepth * 0.8)
		cap.Color = emptyCapColor
		cap.Material = Enum.Material.SmoothPlastic
		cap.Transparency = emptyCapTransparency
		cap:SetAttribute("Slot", slot)
		cap.CFrame = info.Board.CFrame
			* CFrame.new(
				-size.X / 2 + cellWidth * (column + 0.5),
				size.Y / 2 + 0.5,
				-size.Z / 2 + cellDepth * (row + 0.5)
			)
		cap.Parent = folder
		info.Caps[slot] = cap
	end
	local walkway = Instance.new("Part")
	walkway.Name = "Walkway"
	walkway.Anchored = true
	walkway.CanCollide = true
	walkway.CanTouch = false
	walkway.Transparency = 1
	walkway.Size = Vector3.new(size.X, 0.2, size.Z)
	walkway.CFrame = info.Board.CFrame * CFrame.new(0, size.Y / 2 + 1 - 0.1, 0)
	walkway.Parent = folder
	folder.Parent = info.Model
	trove:Add(folder)
end

local function render(info: PlotInfo, board: { string }?)
	for slot, cap in info.Caps do
		local key = if board then Keys.ById[board[slot]] else nil
		if key then
			local rarity = Keys.GetRarity(key)
			cap.Color = rarity.Color
			cap.Material = if rarity.IsNeon then Enum.Material.Neon else Enum.Material.SmoothPlastic
			cap.Transparency = 0
			cap:SetAttribute("KeyId", key.Id)
		else
			cap.Transparency = 1
			cap:SetAttribute("KeyId", nil)
		end
	end
end

local function teleport(player: Player, character: Model)
	task.spawn(function()
		local root = character:WaitForChild("HumanoidRootPart", 10)
		local info = plotByPlayer[player]
		if not root or not info or character.Parent == nil then
			return
		end
		character:PivotTo(info.Base.CFrame * CFrame.new(0, info.Base.Size.Y / 2 + 3, 0))
	end)
end

local function release(player: Player)
	local playerTrove = playerTroves[player]
	playerTroves[player] = nil
	if playerTrove then
		playerTrove:Destroy()
	end
	local info = plotByPlayer[player]
	plotByPlayer[player] = nil
	if info then
		info.Owner = nil
		info.Model:SetAttribute("Owner", nil)
		render(info, nil)
	end
end

local function assign(player: Player, data: PlayerData.Data)
	if plotByPlayer[player] then
		return
	end
	local free: PlotInfo? = nil
	for _, info in plots do
		if not info.Owner then
			free = info
			break
		end
	end
	if not free then
		warn(`[PlotService] No free plot for {player.Name}`)
		return
	end
	free.Owner = player
	plotByPlayer[player] = free
	free.Model:SetAttribute("Owner", player.UserId)
	render(free, data.Board)
	local playerTrove = Trove.new()
	playerTroves[player] = playerTrove
	playerTrove:Connect(player.CharacterAdded, function(character: Model)
		teleport(player, character)
	end)
	if player.Character then
		teleport(player, player.Character)
	end
end

local function collectPlots(folder: Instance, trove: TroveInstance)
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
		local base = findPart(model, "Base")
		local rollKey = findPart(model, "RollKey")
		local board = findPart(model, "Board")
		if base and rollKey and board then
			model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			local info: PlotInfo = {
				Model = model,
				Base = base,
				RollKey = rollKey,
				Board = board,
				Caps = {},
				Owner = nil,
			}
			createCaps(info, trove)
			table.insert(plots, info)
		else
			warn(
				`[PlotService] {model:GetFullName()} needs BasePart children Base, RollKey and Board; skipped`
			)
		end
	end
end

function PlotService.Init(self: State, registry: { [string]: any })
	services = registry
	self._trove = Trove.new()
end

function PlotService.Start(self: State)
	local trove = self._trove :: TroveInstance
	local folder = workspace:FindFirstChild("Plots")
	if not folder then
		warn("[PlotService] workspace.Plots not found; building placeholder plots")
		local placeholder = Instance.new("Folder")
		placeholder.Name = "Plots"
		buildPlaceholderPlots(placeholder)
		placeholder.Parent = workspace
		trove:Add(placeholder)
		folder = placeholder
	end
	collectPlots(folder :: Instance, trove)
	services.DataService.PlayerLoaded:Connect(function(player: Player, data: PlayerData.Data)
		assign(player, data)
	end)
	services.DataService.PlayerReleasing:Connect(function(player: Player, _data: PlayerData.Data)
		release(player)
	end)
	services.KeyboardService.BoardChanged:Connect(function(player: Player)
		local info = plotByPlayer[player]
		local data = services.DataService:GetData(player) :: PlayerData.Data?
		if info and data then
			render(info, data.Board)
		end
	end)
	for _, player in Players:GetPlayers() do
		local data = services.DataService:GetData(player) :: PlayerData.Data?
		if data then
			assign(player, data)
		end
	end
end

function PlotService.GetPlot(_self: State, player: Player): Model?
	local info = plotByPlayer[player]
	return if info then info.Model else nil
end

function PlotService.Destroy(self: State)
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return PlotService
