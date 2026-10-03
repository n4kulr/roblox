--!strict

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Packets = require(ReplicatedStorage.Packets)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)

type TroveInstance = typeof(Trove.new())
type Entry = { KeyId: string, Count: number }
export type TradeState = {
	Phase: number,
	Partner: string,
	Mine: { Entry },
	Theirs: { Entry },
	MyReady: boolean,
	TheirReady: boolean,
	Seconds: number,
}
type State = {
	Name: string,
	_trove: TroveInstance?,
	StateChanged: Signal.Signal<TradeState?>,
	InviteReceived: Signal.Signal<(string, number)>,
	TargetPicked: Signal.Signal<Player>,
}

local pickRange = 60
local rayLength = 400
local phaseDone, phaseCancelled = 3, 4

local TradeController = {
	Name = "TradeController",
	StateChanged = Signal.new() :: Signal.Signal<TradeState?>,
	InviteReceived = Signal.new() :: Signal.Signal<(string, number)>,
	TargetPicked = Signal.new() :: Signal.Signal<Player>,
	_trove = nil :: TroveInstance?,
}
local controllers: { [string]: any } = {}
local current: TradeState? = nil

local function toast(text: string, kind: string)
	local ui = controllers.UIController
	if ui then
		ui:Toast(text, kind)
	end
end

local function playerFromHit(hit: Instance): Player?
	local model = hit:FindFirstAncestorOfClass("Model")
	while model do
		local player = Players:GetPlayerFromCharacter(model)
		if player then
			return player
		end
		model = model.Parent and model.Parent:FindFirstAncestorOfClass("Model")
	end
	return nil
end

local function pickAt(screenPoint: Vector2): Player?
	local camera = workspace.CurrentCamera
	local own = Players.LocalPlayer
	if not camera or not own.Character then
		return nil
	end
	local ray = camera:ViewportPointToRay(screenPoint.X, screenPoint.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { own.Character }
	local result = workspace:Raycast(ray.Origin, ray.Direction * rayLength, params)
	if not result then
		return nil
	end
	local target = playerFromHit(result.Instance)
	local ownRoot = own.Character:FindFirstChild("HumanoidRootPart")
	local targetCharacter = if target then target.Character else nil
	local targetRoot = if targetCharacter then targetCharacter:FindFirstChild("HumanoidRootPart") else nil
	if
		not target
		or target == own
		or not ownRoot
		or not ownRoot:IsA("BasePart")
		or not targetRoot
		or not targetRoot:IsA("BasePart")
	then
		return nil
	end
	if (ownRoot.Position - targetRoot.Position).Magnitude > pickRange then
		return nil
	end
	return target
end

local function onInput(input: InputObject, isProcessed: boolean)
	if isProcessed or current ~= nil then
		return
	end
	local point: Vector2
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		point = UserInputService:GetMouseLocation()
	elseif input.UserInputType == Enum.UserInputType.Touch then
		point = Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset()
	else
		return
	end
	local target = pickAt(point)
	if target then
		TradeController.TargetPicked:Fire(target)
	end
end

local function onState(
	phase: number,
	partner: string,
	mine: { Entry },
	theirs: { Entry },
	myReady: boolean,
	theirReady: boolean,
	seconds: number
)
	if phase == phaseDone then
		current = nil
		TradeController.StateChanged:Fire(nil)
		toast("✅ Trade complete!", "Good")
		return
	end
	if phase == phaseCancelled then
		current = nil
		TradeController.StateChanged:Fire(nil)
		toast(partner, "Bad")
		return
	end
	local next: TradeState = {
		Phase = phase,
		Partner = partner,
		Mine = mine,
		Theirs = theirs,
		MyReady = myReady,
		TheirReady = theirReady,
		Seconds = seconds,
	}
	current = next
	TradeController.StateChanged:Fire(next)
end

function TradeController.Init(self: State, registry: { [string]: any })
	controllers = registry
	self._trove = Trove.new()
end

function TradeController.Start(self: State)
	local trove = self._trove :: TroveInstance
	trove:Connect(UserInputService.InputBegan, onInput)
	trove:Add(Packets.TradeState.OnClientEvent:Connect(onState), "Disconnect")
	trove:Add(
		Packets.TradeInvite.OnClientEvent:Connect(function(name: string, userId: number)
			TradeController.InviteReceived:Fire(name, userId)
		end),
		"Disconnect"
	)
end

function TradeController.GetState(_self: State): TradeState?
	return current
end

function TradeController.Request(_self: State, player: Player)
	task.spawn(function()
		local isSent = Packets.TradeRequest:Fire(player.UserId)
		if isSent == true then
			toast(`🤝 Trade request sent to {player.DisplayName}!`, "Info")
		else
			toast("They can't trade right now!", "Bad")
		end
	end)
end

function TradeController.Respond(_self: State, userId: number, isAccepted: boolean)
	Packets.TradeRespond:Fire(userId, isAccepted)
end

function TradeController.SetOffer(_self: State, keyId: string, count: number)
	Packets.TradeOffer:Fire(keyId, count)
end

function TradeController.SetReady(_self: State, isReady: boolean)
	Packets.TradeReady:Fire(isReady)
end

function TradeController.Cancel(_self: State)
	if current ~= nil then
		Packets.TradeCancel:Fire()
	end
end

function TradeController.Destroy(self: State)
	current = nil
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return TradeController
