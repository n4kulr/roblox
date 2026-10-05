--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Trove = require(ReplicatedStorage.Packages.Trove)
local WaitFor = require(ReplicatedStorage.Packages.WaitFor)
local Obby = require(ReplicatedStorage.Rules.Obby)

type TroveInstance = typeof(Trove.new())
type KeyState = {
	Part: BasePart,
	Rest: CFrame,
	IsSolid: boolean,
	LastPress: number,
	Tween: Tween?,
}
type State = {
	Name: string,
	_trove: TroveInstance?,
}

local config = GameConfig.Obby
local viewRange = 70
local lowViewRange = 30
local maxCharacters = 8
local debounceSeconds = 0.1
local pressSwitch = "CreamTravel"
local pressVolume = 0.6

local ObbyController = {
	Name = "ObbyController",
	_trove = nil :: TroveInstance?,
}
local controllers: { [string]: any } = {}
local keys: { [BasePart]: KeyState } = {}
local standingOn: { [Player]: KeyState } = {}
local isLowGraphics = false
local label: TextLabel? = nil

local function releaseTween(key: KeyState)
	local tween = key.Tween
	if tween then
		key.Tween = nil
		tween:Cancel()
		tween:Destroy()
	end
end

local function pressKey(key: KeyState)
	if not key.IsSolid then
		return
	end
	releaseTween(key)
	local part = key.Part
	local down = TweenService:Create(
		part,
		TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = key.Rest * CFrame.new(0, -config.Key.PressDepth, 0) }
	)
	key.Tween = down
	down.Completed:Once(function(playbackState: Enum.PlaybackState)
		if playbackState ~= Enum.PlaybackState.Completed or key.Tween ~= down then
			return
		end
		local up = TweenService:Create(
			part,
			TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ CFrame = key.Rest }
		)
		key.Tween = up
		up.Completed:Once(function()
			if key.Tween == up then
				key.Tween = nil
			end
			up:Destroy()
		end)
		down:Destroy()
		up:Play()
	end)
	down:Play()
end

local function playKey(key: KeyState, player: Player, kind: "Press" | "Release")
	local category = if player == Players.LocalPlayer then "Board" else "Other"
	controllers.SoundController:PlaySwitch(pressSwitch, kind, 1, pressVolume, key.Part.Position, category)
end

local function addKey(part: Instance)
	if not part:IsA("BasePart") or keys[part] then
		return
	end
	local role = part:GetAttribute("ObbyRole")
	if role ~= "TapKey" and role ~= "PopUpKey" then
		return
	end
	keys[part] = { Part = part, Rest = part.CFrame, IsSolid = role == "TapKey", LastPress = 0, Tween = nil }
end

local function removeKey(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local key = keys[part]
	if not key then
		return
	end
	releaseTween(key)
	keys[part] = nil
	for player, standing in standingOn do
		if standing == key then
			standingOn[player] = nil
		end
	end
end

local function findKey(position: Vector3): KeyState?
	for part, key in keys do
		local center = part.CFrame.Position
		local size = part.Size
		local radius = math.max(size.X, size.Z) * 0.75
		if math.abs(center.X - position.X) <= radius and math.abs(center.Z - position.Z) <= radius then
			if Obby.KeyContains(part.CFrame, size, position) then
				return key
			end
		end
	end
	return nil
end

local function getRoot(player: Player): (BasePart?, boolean)
	local character = player.Character
	if not character then
		return nil, false
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid then
		return nil, false
	end
	return root, humanoid.FloorMaterial ~= Enum.Material.Air
end

local function update()
	local camera = workspace.CurrentCamera
	local localPlayer = Players.LocalPlayer
	if not camera or next(keys) == nil or not localPlayer then
		return
	end
	local cameraPosition = camera.CFrame.Position
	local seen: { [Player]: boolean } = {}
	local count = 0
	local candidates: { Player } = { localPlayer }
	if not isLowGraphics then
		for _, player in Players:GetPlayers() do
			if player ~= localPlayer then
				table.insert(candidates, player)
			end
		end
	end
	local range = if isLowGraphics then lowViewRange else viewRange
	for _, player in candidates do
		if count >= maxCharacters then
			break
		end
		local root, isGrounded = getRoot(player)
		if root and (root.Position - cameraPosition).Magnitude <= range then
			seen[player] = true
			count += 1
			local key = if isGrounded then findKey(root.Position) else nil
			local previous = standingOn[player]
			if key ~= previous then
				if previous and previous.Part.Parent and previous.IsSolid then
					playKey(previous, player, "Release")
				end
				if not key then
					standingOn[player] = nil
				else
					standingOn[player] = key
					local now = os.clock()
					if now - key.LastPress >= debounceSeconds then
						key.LastPress = now
						pressKey(key)
						playKey(key, player, "Press")
					end
				end
			end
		end
	end
	for player in standingOn do
		if not seen[player] then
			standingOn[player] = nil
		end
	end
end

local function refreshLabel(character: Model?)
	local text = label
	if not text then
		return
	end
	local taps = if character then character:GetAttribute("ObbyTaps") else nil
	if type(taps) == "number" then
		text.Text = string.format("SPEED %d", Obby.SpeedFor(taps))
		text.Visible = true
	else
		text.Visible = false
	end
end

local function buildLabel(trove: TroveInstance)
	local localPlayer = Players.LocalPlayer
	if not localPlayer then
		return
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "ObbySpeed"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = localPlayer:WaitForChild("PlayerGui")
	trove:Add(gui)
	local text = Instance.new("TextLabel")
	text.Name = "Speed"
	text.AnchorPoint = Vector2.new(0.5, 0)
	text.Position = UDim2.new(0.5, 0, 0, 70)
	text.Size = UDim2.fromOffset(180, 40)
	text.BackgroundColor3 = Color3.fromRGB(32, 34, 42)
	text.BackgroundTransparency = 0.25
	text.TextColor3 = Color3.fromRGB(240, 244, 250)
	text.FontFace = Font.fromEnum(Enum.Font.GothamBold)
	text.TextSize = 24
	text.Visible = false
	text.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = text
	label = text
	local characterTrove = Trove.new()
	trove:Add(characterTrove)
	local function bind(character: Model?)
		characterTrove:Clean()
		refreshLabel(character)
		if character then
			characterTrove:Connect(character:GetAttributeChangedSignal("ObbyTaps"), function()
				refreshLabel(character)
			end)
		end
	end
	trove:Connect(localPlayer.CharacterAdded, bind)
	bind(localPlayer.Character)
end

function ObbyController.Init(self: State, registry: { [string]: any })
	controllers = registry
	self._trove = Trove.new()
end

function ObbyController.Start(self: State)
	local trove = self._trove :: TroveInstance
	trove:Add(controllers.DataController:Observe({ "Settings", "LowGraphics" }, function(value: any)
		isLowGraphics = value == true
	end))
	buildLabel(trove)
	local promise = WaitFor.Child(workspace, "Obby", 30)
		:andThen(function(model: Instance)
			local courseTrove = Trove.new()
			trove:Add(courseTrove)
			for _, descendant in model:GetDescendants() do
				addKey(descendant)
			end
			courseTrove:Connect(model.DescendantAdded, addKey)
			courseTrove:Connect(model.DescendantRemoving, removeKey)
			courseTrove:Connect(RunService.Heartbeat, update)
		end)
		:catch(function(problem: any)
			warn(`[ObbyController] workspace.Obby not found: {tostring(problem)}`)
		end)
	trove:Add(function()
		promise:cancel()
	end)
end

function ObbyController.Destroy(self: State)
	isLowGraphics = false
	label = nil
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
	for _, key in keys do
		releaseTween(key)
	end
	table.clear(keys)
	table.clear(standingOn)
end

return ObbyController
