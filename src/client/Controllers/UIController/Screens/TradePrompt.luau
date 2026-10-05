--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)

local theme = Kit.Theme
local popupSize = Vector2.new(400, 160)
local bottomOffset = -150

local TradePrompt = {}

function TradePrompt.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local controller = context.Controllers.TradeController
	local playUi = Kit.UiSound(context.Controllers)
	local gui, root = Kit.ScreenGui("ThockTradePrompt", 9, context.PlayerGui, trove)
	local sendToken = 0
	local inviteToken = 0
	local pendingTarget: Player? = nil
	local pendingUserId = 0

	local function popup(name: string, title: string): (Frame, TextLabel)
		local frame = Kit.Panel({
			Parent = root,
			Name = name,
			Size = UDim2.fromOffset(popupSize.X, popupSize.Y),
			Position = UDim2.new(0.5, 0, 1, bottomOffset),
			AnchorPoint = Vector2.new(0.5, 1),
			Color = theme.Panel,
			Radius = Kit.Radius.Panel,
			StrokeThickness = 4,
			Shards = true,
		})
		Kit.Icon({
			Parent = frame,
			Name = "Icon",
			Glyph = "Trade",
			Position = UDim2.fromOffset(Kit.Space.M, Kit.Space.M),
			Size = UDim2.fromOffset(48, 48),
		})
		frame.Visible = false
		local label = Kit.Label({
			Parent = frame,
			Name = "Title",
			Text = title,
			Position = UDim2.fromOffset(68, 10),
			Size = UDim2.new(1, -80, 0, 48),
			TextSize = 28,
			Align = Enum.TextXAlignment.Center,
			Scaled = true,
		})
		return frame, label
	end

	local sendFrame, sendTitle = popup("Send", "Trade with ?")
	local inviteFrame, inviteTitle = popup("Invite", "Someone wants to trade!")
	inviteFrame.Position = UDim2.new(0.5, 0, 1, bottomOffset - popupSize.Y - 12)

	local function hideSend()
		sendToken += 1
		pendingTarget = nil
		sendFrame.Visible = false
	end

	local function hideInvite()
		inviteToken += 1
		inviteFrame.Visible = false
	end

	Kit.Button(trove, {
		Parent = sendFrame,
		Name = "SendButton",
		Text = "SEND",
		Glyph = "Arrow",
		IconLeft = true,
		Size = UDim2.fromOffset(190, 56),
		Position = UDim2.new(0, 14, 1, -14),
		AnchorPoint = Vector2.new(0, 1),
		Color = theme.Green,
		TextSize = 28,
		Callback = function()
			local target = pendingTarget
			hideSend()
			if target then
				controller:Request(target)
			end
		end,
		Sound = playUi,
	})
	Kit.Button(trove, {
		Parent = sendFrame,
		Name = "CancelButton",
		Glyph = "Close",
		Size = UDim2.fromOffset(Kit.TouchSize + 20, 56),
		Position = UDim2.new(1, -14, 1, -14),
		AnchorPoint = Vector2.new(1, 1),
		Color = theme.Red,
		TextSize = 30,
		Callback = hideSend,
		Sound = playUi,
	})
	Kit.Button(trove, {
		Parent = inviteFrame,
		Name = "AcceptButton",
		Text = "ACCEPT",
		Glyph = "Check",
		IconLeft = true,
		Size = UDim2.fromOffset(170, 56),
		Position = UDim2.new(0, 14, 1, -14),
		AnchorPoint = Vector2.new(0, 1),
		Color = theme.Green,
		TextSize = 26,
		Callback = function()
			hideInvite()
			controller:Respond(pendingUserId, true)
		end,
		Sound = playUi,
	})
	Kit.Button(trove, {
		Parent = inviteFrame,
		Name = "DeclineButton",
		Text = "DECLINE",
		Glyph = "Close",
		IconLeft = true,
		Size = UDim2.fromOffset(170, 56),
		Position = UDim2.new(1, -14, 1, -14),
		AnchorPoint = Vector2.new(1, 1),
		Color = theme.Red,
		TextSize = 26,
		Callback = function()
			hideInvite()
			controller:Respond(pendingUserId, false)
		end,
		Sound = playUi,
	})

	trove:Add(
		controller.TargetPicked:Connect(function(player: Player)
			if controller:GetState() ~= nil then
				return
			end
			sendToken += 1
			local token = sendToken
			pendingTarget = player
			sendTitle.Text = `Trade with {player.DisplayName}?`
			sendFrame.Visible = true
			playUi("Click")
			task.delay(GameConfig.Trade.RequestTimeoutSeconds, function()
				if token == sendToken then
					hideSend()
				end
			end)
		end),
		"Disconnect"
	)
	trove:Add(
		controller.InviteReceived:Connect(function(name: string, userId: number)
			if controller:GetState() ~= nil then
				controller:Respond(userId, false)
				return
			end
			inviteToken += 1
			local token = inviteToken
			pendingUserId = userId
			inviteTitle.Text = `{name} wants to trade!`
			inviteFrame.Visible = true
			playUi("Confirm")
			task.delay(GameConfig.Trade.RequestTimeoutSeconds, function()
				if token == inviteToken then
					hideInvite()
				end
			end)
		end),
		"Disconnect"
	)
	trove:Add(
		controller.StateChanged:Connect(function(state: any)
			if state ~= nil then
				hideSend()
				hideInvite()
			end
		end),
		"Disconnect"
	)

	return {
		Modal = false,
		StartsOpen = true,
		Open = function(_self: Types.Screen)
			gui.Enabled = true
		end,
		Close = function(_self: Types.Screen)
			gui.Enabled = false
		end,
		Destroy = function(_self: Types.Screen)
			sendToken += 1
			inviteToken += 1
			trove:Destroy()
		end,
	}
end

return TradePrompt
