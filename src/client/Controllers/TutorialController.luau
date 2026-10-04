--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Keys = require(ReplicatedStorage.Config.Keys)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Kit = require(script.Parent.UIController.Kit)

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	_trove: TroveInstance?,
}

local scanSeconds = 0.5
local baseHeight = 3
local bounceHeight = 0.8
local bounceSpeed = 5

local TutorialController = {
	Name = "TutorialController",
	_trove = nil :: TroveInstance?,
}
local noHintStep = 99
local step = noHintStep
local controllers: { [string]: any } = {}
local rollKey: BasePart? = nil
local hint: BillboardGui? = nil
local hintLabel: TextLabel? = nil
local shownText = ""
local sinceScan = scanSeconds
local elapsed = 0

local function hintText(): string?
	if step == 0 then
		if UserInputService.KeyboardEnabled then
			return "TAP THE KEY!\nor press E"
		end
		return "TAP THE KEY!"
	elseif step == 1 then
		return "ROLL AGAIN!"
	end
	return nil
end

local function findRollKey(): BasePart?
	local plots = workspace:FindFirstChild("Plots")
	if not plots then
		return nil
	end
	for _, model in plots:GetChildren() do
		if model:IsA("Model") and model:GetAttribute("Owner") == Players.LocalPlayer.UserId then
			local key = model:FindFirstChild("RollKey")
			if key and key:IsA("BasePart") then
				return key
			end
		end
	end
	return nil
end

local function isKeyValid(key: BasePart?): boolean
	if not key or not key:IsDescendantOf(workspace) then
		return false
	end
	local model = key.Parent
	return model ~= nil and model:GetAttribute("Owner") == Players.LocalPlayer.UserId
end

local function update(dt: number)
	local gui = hint
	local label = hintLabel
	if not gui or not label then
		return
	end
	local text = hintText()
	if not text then
		gui.Enabled = false
		return
	end
	sinceScan += dt
	if sinceScan >= scanSeconds or not isKeyValid(rollKey) then
		sinceScan = 0
		rollKey = findRollKey()
	end
	local key = rollKey
	if not key then
		gui.Enabled = false
		return
	end
	if text ~= shownText then
		shownText = text
		label.Text = text
	end
	if gui.Adornee ~= key then
		gui.Adornee = key
	end
	elapsed += dt
	gui.StudsOffset = Vector3.new(0, baseHeight + math.abs(math.sin(elapsed * bounceSpeed)) * bounceHeight, 0)
	gui.Enabled = true
end

function TutorialController.Init(self: State, registry: { [string]: any })
	controllers = registry
	self._trove = Trove.new()
end

function TutorialController.Start(self: State)
	local trove = self._trove :: TroveInstance
	local gui = Instance.new("BillboardGui")
	gui.Name = "ThockRollHint"
	gui.AlwaysOnTop = true
	gui.Size = UDim2.fromOffset(260, 90)
	gui.StudsOffset = Vector3.new(0, baseHeight, 0)
	gui.Enabled = false
	gui.ResetOnSpawn = false
	local label = Instance.new("TextLabel")
	label.Name = "Hint"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Keys.RarityByName.Legendary.Color
	label.Text = ""
	local stroke = Instance.new("UIStroke")
	stroke.Color = Kit.Theme.TextInk
	stroke.Thickness = 3.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = label
	label.Parent = gui
	gui.Parent = workspace
	hint = gui
	hintLabel = label
	trove:Add(gui)
	trove:Add(controllers.DataController:Observe({ "Tutorial" }, function(value: any)
		step = if type(value) == "number" then value else noHintStep
	end))
	trove:Connect(RunService.Heartbeat, update)
end

function TutorialController.Destroy(self: State)
	step = noHintStep
	rollKey = nil
	hint = nil
	hintLabel = nil
	shownText = ""
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return TutorialController
