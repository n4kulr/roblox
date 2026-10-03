--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
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
local hintSub: TextLabel? = nil
local shownText = ""
local sinceScan = scanSeconds
local elapsed = 0

local function hintText(): (string?, string?)
	if step == 0 then
		if UserInputService.KeyboardEnabled then
			return "TAP THE KEY!", "OR PRESS E"
		end
		return "TAP THE KEY!", nil
	elseif step == 1 then
		return "ROLL AGAIN!", nil
	end
	return nil, nil
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
	local sub = hintSub
	if not gui or not label or not sub then
		return
	end
	local text, subText = hintText()
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
	local combined = `{text}|{subText or ""}`
	if combined ~= shownText then
		shownText = combined
		label.Text = text
		sub.Text = subText or ""
		sub.Visible = subText ~= nil
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
	gui.Size = UDim2.fromOffset(260, 64)
	gui.StudsOffset = Vector3.new(0, baseHeight, 0)
	gui.Enabled = false
	gui.ResetOnSpawn = false
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 4)
	list.Parent = gui
	local label = Kit.Label({
		Parent = gui,
		Name = "Hint",
		Size = UDim2.new(1, 0, 0, 28),
		TextSize = 22,
		Align = Enum.TextXAlignment.Center,
		LayoutOrder = 1,
		Outline = true,
	})
	label.TextTruncate = Enum.TextTruncate.None
	local sub = Kit.Label({
		Parent = gui,
		Name = "Sub",
		Size = UDim2.new(1, 0, 0, 16),
		TextSize = 13,
		Align = Enum.TextXAlignment.Center,
		LayoutOrder = 2,
		Outline = true,
		Body = true,
	})
	gui.Parent = workspace
	hint = gui
	hintLabel = label
	hintSub = sub
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
	hintSub = nil
	shownText = ""
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return TutorialController
