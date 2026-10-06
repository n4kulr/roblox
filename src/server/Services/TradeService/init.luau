--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Packets = require(ReplicatedStorage.Packets)
local Trade = require(ReplicatedStorage.Rules.Trade)
local Trove = require(ReplicatedStorage.Packages.Trove)
local PlayerData = require(script.Parent.Parent.Data.PlayerData)
local Execution = require(script.Execution)
local Types = require(script.Types)

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	_trove: TroveInstance?,
}

local config = GameConfig.Trade
local watchSeconds = 0.5
local phaseOpen, phaseCountdown, phaseDone, phaseCancelled = 1, 2, 3, 4
local itemsChanged = "Trade cancelled: items changed"
local busyMessage = "Trade cancelled: someone is busy"

local TradeService = {
	Name = "TradeService",
	_trove = nil :: TroveInstance?,
}
local context: Types.Context = { Services = {} }
local sessions: { [Player]: Types.Session } = {}
local requests: { [Player]: Types.Request } = {}
local isRunning = false

local function getData(player: Player): PlayerData.Data?
	return context.Services.DataService:GetData(player) :: PlayerData.Data?
end

local function isBusy(player: Player): boolean
	local character = player.Character
	if not character then
		return false
	end
	local carried = character:GetAttribute("CarryingKey")
	local keyfall = character:GetAttribute("KeyfallCount")
	return carried ~= nil or (type(keyfall) == "number" and keyfall > 0)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function isInRange(first: Player, second: Player): boolean
	if config.MaxRange <= 0 then
		return true
	end
	local firstRoot, secondRoot = rootOf(first), rootOf(second)
	if not firstRoot or not secondRoot then
		return false
	end
	return (firstRoot.CFrame.Position - secondRoot.CFrame.Position).Magnitude <= config.MaxRange
end

local function partnerOf(session: Types.Session, player: Player): Player
	return if session.Players[1] == player then session.Players[2] else session.Players[1]
end

local function listOf(offer: Types.Offer): { { KeyId: string, Count: number } }
	local ids: { string } = {}
	for keyId, count in offer do
		if count > 0 then
			table.insert(ids, keyId)
		end
	end
	table.sort(ids)
	local out: { { KeyId: string, Count: number } } = {}
	for _, keyId in ids do
		table.insert(out, { KeyId = keyId, Count = offer[keyId] })
	end
	return out
end

local function sendState(session: Types.Session, phase: number, notes: { [Player]: string }?)
	for _, player in session.Players do
		local partner = partnerOf(session, player)
		local note = if notes then notes[player] else nil
		Packets.TradeState:FireClient(
			player,
			phase,
			note or partner.DisplayName,
			listOf(session.Offers[player]),
			listOf(session.Offers[partner]),
			session.Ready[player],
			session.Ready[partner],
			session.Remaining
		)
	end
end

local function currentPhase(session: Types.Session): number
	return if session.Remaining > 0 then phaseCountdown else phaseOpen
end

local function stopCountdown(session: Types.Session)
	session.Token += 1
	session.Remaining = 0
end

local function closeSession(session: Types.Session, phase: number, notes: { [Player]: string }?)
	if session.IsClosed then
		return
	end
	session.IsClosed = true
	stopCountdown(session)
	for _, player in session.Players do
		if sessions[player] == session then
			sessions[player] = nil
		end
	end
	for _, player in session.Players do
		local note = if notes then notes[player] else nil
		if phase == phaseDone or note ~= nil then
			local partner = partnerOf(session, player)
			Packets.TradeState:FireClient(
				player,
				phase,
				note or partner.DisplayName,
				listOf(session.Offers[player]),
				listOf(session.Offers[partner]),
				session.Ready[player],
				session.Ready[partner],
				0
			)
		end
	end
end

local function cancelAll(session: Types.Session, text: string)
	local notes: { [Player]: string } = {}
	for _, player in session.Players do
		notes[player] = text
	end
	closeSession(session, phaseCancelled, notes)
end

local function finish(session: Types.Session)
	if session.IsClosed then
		return
	end
	local isSuccess = Execution.Run(context, session)
	if isSuccess then
		closeSession(session, phaseDone, nil)
	else
		cancelAll(session, itemsChanged)
	end
end

local function startCountdown(session: Types.Session)
	stopCountdown(session)
	local token = session.Token
	session.Remaining = config.ConfirmCountdownSeconds
	sendState(session, phaseCountdown)
	task.spawn(function()
		while true do
			task.wait(1)
			if session.IsClosed or session.Token ~= token then
				return
			end
			session.Remaining -= 1
			if not Execution.CanRun(context, session) then
				cancelAll(session, itemsChanged)
				return
			end
			if session.Remaining <= 0 then
				session.Remaining = 0
				finish(session)
				return
			end
			sendState(session, phaseCountdown)
		end
	end)
end

local function canTrade(player: Player): boolean
	return getData(player) ~= nil
		and sessions[player] == nil
		and requests[player] == nil
		and not isBusy(player)
end

local function dropRequestsOf(player: Player)
	requests[player] = nil
	for sender, request in table.clone(requests) do
		if request.Target == player then
			requests[sender] = nil
		end
	end
end

local function onRequest(sender: Player, userId: number): boolean
	if type(userId) ~= "number" or userId ~= userId then
		return false
	end
	local target = Players:GetPlayerByUserId(userId)
	if not target or target == sender or not canTrade(sender) then
		return false
	end
	if
		getData(target) == nil
		or sessions[target] ~= nil
		or isBusy(target)
		or not isInRange(sender, target)
	then
		return false
	end
	local request: Types.Request = { Sender = sender, Target = target }
	requests[sender] = request
	Packets.TradeInvite:FireClient(target, sender.DisplayName, sender.UserId)
	task.delay(config.RequestTimeoutSeconds, function()
		if requests[sender] == request then
			requests[sender] = nil
		end
	end)
	return true
end

local function openSession(first: Player, second: Player)
	local session: Types.Session = {
		Players = { first, second },
		Offers = { [first] = {}, [second] = {} },
		Ready = { [first] = false, [second] = false },
		Remaining = 0,
		Token = 0,
		IsClosed = false,
	}
	sessions[first] = session
	sessions[second] = session
	sendState(session, phaseOpen)
end

local function onRespond(responder: Player, userId: number, isAccepted: boolean)
	if type(userId) ~= "number" then
		return
	end
	local sender = Players:GetPlayerByUserId(userId)
	local request = if sender then requests[sender] else nil
	if not sender or not request or request.Target ~= responder then
		return
	end
	requests[sender] = nil
	if not isAccepted then
		Packets.TradeState:FireClient(
			sender,
			phaseCancelled,
			`{responder.DisplayName} said no thanks`,
			{},
			{},
			false,
			false,
			0
		)
		return
	end
	requests[responder] = nil
	if
		getData(sender) == nil
		or getData(responder) == nil
		or sessions[sender] ~= nil
		or sessions[responder] ~= nil
		or isBusy(sender)
		or isBusy(responder)
		or not isInRange(sender, responder)
	then
		Packets.TradeState:FireClient(
			responder,
			phaseCancelled,
			"Can't trade right now",
			{},
			{},
			false,
			false,
			0
		)
		Packets.TradeState:FireClient(
			sender,
			phaseCancelled,
			"Can't trade right now",
			{},
			{},
			false,
			false,
			0
		)
		return
	end
	openSession(sender, responder)
end

local function onOffer(player: Player, keyId: string, count: number)
	local session = sessions[player]
	local data = getData(player)
	if not session or not data then
		return
	end
	local offer = session.Offers[player]
	local isValid = Trade.ValidateOffer(data.Inventory, offer, keyId, count)
	if not isValid then
		sendState(session, currentPhase(session))
		return
	end
	if (offer[keyId] or 0) == count then
		return
	end
	if count > 0 then
		offer[keyId] = count
	else
		offer[keyId] = nil
	end
	for _, member in session.Players do
		session.Ready[member] = false
	end
	stopCountdown(session)
	sendState(session, phaseOpen)
end

local function onReady(player: Player, isReady: boolean)
	local session = sessions[player]
	if not session or type(isReady) ~= "boolean" then
		return
	end
	local partner = partnerOf(session, player)
	if isReady and Trade.IsEmpty(session.Offers[player]) and Trade.IsEmpty(session.Offers[partner]) then
		sendState(session, currentPhase(session))
		return
	end
	if session.Ready[player] == isReady then
		return
	end
	session.Ready[player] = isReady
	if not isReady then
		stopCountdown(session)
		sendState(session, phaseOpen)
		return
	end
	if session.Ready[partner] then
		if Execution.CanRun(context, session) then
			startCountdown(session)
		else
			cancelAll(session, itemsChanged)
		end
		return
	end
	sendState(session, phaseOpen)
end

local function onCancel(player: Player)
	local session = sessions[player]
	if session then
		closeSession(session, phaseCancelled, {
			[player] = "Trade cancelled",
			[partnerOf(session, player)] = `{player.DisplayName} cancelled the trade`,
		})
	end
end

local function onLeft(player: Player)
	local session = sessions[player]
	dropRequestsOf(player)
	if session then
		closeSession(
			session,
			phaseCancelled,
			{ [partnerOf(session, player)] = `{player.DisplayName} left the trade` }
		)
	end
end

local function watch()
	while isRunning do
		task.wait(watchSeconds)
		for _, session in table.clone(sessions) do
			if not session.IsClosed and (isBusy(session.Players[1]) or isBusy(session.Players[2])) then
				cancelAll(session, busyMessage)
			end
		end
	end
end

function TradeService.Init(self: State, registry: { [string]: any })
	context.Services = registry
	self._trove = Trove.new()
end

function TradeService.Start(self: State)
	local trove = self._trove :: TroveInstance
	isRunning = true
	trove:Connect(Players.PlayerRemoving, onLeft)
	trove:Add(task.spawn(watch))
	Packets.TradeRequest.OnServerInvoke = onRequest
	trove:Add(Packets.TradeRespond.OnServerEvent:Connect(onRespond), "Disconnect")
	trove:Add(Packets.TradeOffer.OnServerEvent:Connect(onOffer), "Disconnect")
	trove:Add(Packets.TradeReady.OnServerEvent:Connect(onReady), "Disconnect")
	trove:Add(Packets.TradeCancel.OnServerEvent:Connect(onCancel), "Disconnect")
end

function TradeService.IsTrading(_self: State, player: Player): boolean
	return sessions[player] ~= nil
end

function TradeService.Destroy(self: State)
	isRunning = false
	Packets.TradeRequest.OnServerInvoke = nil
	for _, session in table.clone(sessions) do
		session.IsClosed = true
		session.Token += 1
	end
	table.clear(sessions)
	table.clear(requests)
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return TradeService
