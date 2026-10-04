--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Trove = require(ReplicatedStorage.Packages.Trove)
local Kit = require(script.Parent.UIController.Kit)

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	_trove: TroveInstance?,
}

local switchId = "MxBlack"
local hearRange = 80
local closeRange = 18
local openColor = Color3.fromRGB(96, 220, 120)
local shutColor = Color3.fromRGB(255, 120, 90)

local tapRoles: { [string]: boolean } = {
	Tap = true,
	TapKey = true,
	Popup = true,
	PopUpKey = true,
}

local gateRoles: { [string]: boolean } = {
	Gate = true,
	SpeedGate = true,
}

local ObbyController = {
	Name = "ObbyController",
	_trove = nil :: TroveInstance?,
}
local controllers: { [string]: any } = {}
local hooked: { [Instance]: boolean } = {}
local gates: { BasePart } = {}
local speedLabel: TextLabel? = nil
local speedGui: ScreenGui? = nil

local function rootPosition(): Vector3?
	local character = Players.LocalPlayer.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root and root:IsA("BasePart") then
		return root.Position
	end
	return nil
end

local function playPress(part: BasePart)
	local position = rootPosition()
	if not position then
		return
	end
	local distance = (position - part.Position).Magnitude
	if distance > hearRange then
		return
	end
	local category = if distance <= closeRange then "Board" else "Other"
	controllers.SoundController:PlaySwitch(switchId, "Press", 1, 0.85, part.Position, category)
end

local function hookPart(trove: TroveInstance, part: Instance)
	if not part:IsA("BasePart") or hooked[part] then
		return
	end
	local role = part:GetAttribute("ObbyRole")
	if type(role) ~= "string" then
		return
	end
	if tapRoles[role] then
		hooked[part] = true
		trove:Connect(part:GetAttributeChangedSignal("PressedAt"), function()
			playPress(part)
		end)
	elseif gateRoles[role] then
		hooked[part] = true
		table.insert(gates, part)
	end
end

local function hookModel(trove: TroveInstance, model: Instance)
	if not model:IsA("Model") or (model.Name ~= "Obby" and model.Name ~= "ObbyPlaceholder") then
		return
	end
	for _, descendant in model:GetDescendants() do
		hookPart(trove, descendant)
	end
	trove:Connect(model.DescendantAdded, function(descendant: Instance)
		hookPart(trove, descendant)
	end)
end

local function gateTarget(): number?
	local target: number? = nil
	for _, gate in gates do
		local needed = gate:GetAttribute("SpeedNeeded")
		if type(needed) == "number" and (target == nil or needed > target) then
			target = needed
		end
	end
	return target
end

local function tintGates(speed: number)
	for _, gate in gates do
		if gate.Parent then
			local needed = gate:GetAttribute("SpeedNeeded")
			if type(needed) == "number" then
				gate.Color = if speed >= needed then openColor else shutColor
			end
		end
	end
end

local function refreshSpeed()
	local gui = speedGui
	local label = speedLabel
	if not gui or not label then
		return
	end
	local character = Players.LocalPlayer.Character
	local taps = if character then character:GetAttribute("ObbyTaps") else nil
	if type(taps) ~= "number" then
		gui.Enabled = false
		return
	end
	gui.Enabled = true
	local raw = if character then character:GetAttribute("TapSpeed") else nil
	local speed = if type(raw) == "number" then math.floor(raw + 0.5) else 0
	local target = gateTarget()
	label.Text = if target then `SPEED {speed} / {target}` else `SPEED {speed}`
	tintGates(speed)
end

local function buildReadout(trove: TroveInstance, playerGui: Instance)
	local gui, root = Kit.ScreenGui("ThockSpeed", 6, playerGui, trove)
	gui.Enabled = false
	local pill = Kit.Panel({
		Parent = root,
		Name = "Speed",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(240, 48),
		Color = Kit.Theme.Ink,
		Radius = 8,
	})
	speedLabel = Kit.Label({
		Parent = pill,
		Name = "Value",
		Text = "SPEED 0",
		Size = UDim2.fromScale(1, 1),
		TextSize = 28,
		Align = Enum.TextXAlignment.Center,
		Scaled = true,
	})
	speedGui = gui
end

function ObbyController.Init(self: State, registry: { [string]: any })
	controllers = registry
	self._trove = Trove.new()
end

function ObbyController.Start(self: State)
	local trove = self._trove :: TroveInstance
	local playerGui = Players.LocalPlayer:FindFirstChildOfClass("PlayerGui")
	if playerGui then
		buildReadout(trove, playerGui)
	end
	local existing = workspace:FindFirstChild("Obby")
	if existing then
		hookModel(trove, existing)
	end
	local placeholder = workspace:FindFirstChild("ObbyPlaceholder")
	if placeholder then
		hookModel(trove, placeholder)
	end
	trove:Connect(workspace.ChildAdded, function(child: Instance)
		hookModel(trove, child)
	end)
	trove:Connect(RunService.Heartbeat, refreshSpeed)
end

function ObbyController.Destroy(self: State)
	table.clear(hooked)
	table.clear(gates)
	speedLabel = nil
	speedGui = nil
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return ObbyController
