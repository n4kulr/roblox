--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local TimeFormat = require(ReplicatedStorage.Utils.TimeFormat)
local Economy = require(script.Parent.Parent.Economy)
local Kit = require(script.Parent.Parent.Kit)
local Types = require(script.Parent.Parent.Types)

type TroveInstance = typeof(Trove.new())

local theme = Kit.Theme
local config = GameConfig.GroupChest
local chestName = "GroupChest"
local promptName = "ChestPrompt"
local subtitleName = "Subtitle"
local refreshSeconds = 0.5
local memberCacheSeconds = 20
local joinMessage = "Join our group to open the chest!"
local soonMessage = "Group coming soon!"
local fallbackHint = "Search THOCK group on Roblox"
local confettiColors =
	{ theme.Gold, theme.Green, theme.Blue, theme.Pink, theme.Orange, theme.Purple, theme.Teal }
local confettiCount = 30
local confettiSeconds = 1.1
local flyInfo = TweenInfo.new(confettiSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local GroupChest = {}

local function countdownText(seconds: number): string
	local whole = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d:%02d", math.floor(whole / 3600), math.floor(whole / 60) % 60, whole % 60)
end

function GroupChest.new(context: Types.Context): Types.Screen
	local trove = Trove.new()
	local playUi = Kit.UiSound(context.Controllers)
	local dataController = context.Controllers.DataController
	local tracker = Economy.Track(dataController, trove)
	local isBusy = false
	local isJoining = false
	local isOpen = false
	local memberAt = -math.huge
	local isMember = false
	local boundPrompt: Instance? = nil
	local promptTrove = Trove.new()
	local rng = Random.new()
	trove:Add(promptTrove)

	local modal = Kit.Modal(trove, {
		Parent = context.PlayerGui,
		Name = "GroupChest",
		Title = "GROUP CHEST",
		Glyph = "Gift",
		MaxSize = Vector2.new(560, 460),
		HeaderColor = theme.Orange,
		OnClose = function()
			context.Close("GroupChest")
		end,
		Sound = playUi,
	})

	Kit.Icon({
		Parent = modal.Body,
		Name = "ChestIcon",
		Glyph = "Gift",
		Position = UDim2.new(0.5, 0, 0, 20),
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(96, 96),
	})
	local message = Kit.Label({
		Parent = modal.Body,
		Name = "Message",
		Text = joinMessage,
		Position = UDim2.new(0.5, 0, 0, 126),
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.new(1, -48, 0, 80),
		TextSize = 34,
		Align = Enum.TextXAlignment.Center,
		Wrapped = true,
		Scaled = true,
	})
	local joinGroup: () -> () = function() end
	local join = Kit.Button(trove, {
		Parent = modal.Body,
		Name = "Join",
		Text = "JOIN",
		Title = true,
		Lip = 9,
		Size = UDim2.fromOffset(300, 80),
		Position = UDim2.new(0.5, 0, 0, 220),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = theme.Green,
		TextSize = 42,
		Callback = function()
			task.spawn(joinGroup)
		end,
		Sound = playUi,
	})
	join.SetGlow(true)
	local hint = Kit.Label({
		Parent = modal.Body,
		Name = "Hint",
		Text = "",
		Position = UDim2.new(0.5, 0, 0, 316),
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.new(1, -48, 0, 40),
		TextSize = 24,
		Align = Enum.TextXAlignment.Center,
		Wrapped = true,
		Scaled = true,
		Color = theme.Subtext,
	})

	local function now(): number
		return workspace:GetServerTimeNow()
	end

	local function setPopup(text: string, canJoin: boolean, hintText: string?)
		message.Text = text
		hint.Text = hintText or ""
		local joinInstance = join.Instance
		joinInstance.Visible = canJoin
	end

	local function showPopup(text: string, canJoin: boolean, hintText: string?)
		setPopup(text, canJoin, hintText)
		context.Open("GroupChest")
	end

	local function secondsLeft(): number
		local at = dataController:Get({ "GroupChestAt" })
		if type(at) ~= "number" or at <= 0 then
			return 0
		end
		return math.max(0, at + config.CooldownSeconds - now())
	end

	local function checkMember(): boolean
		if os.clock() - memberAt < memberCacheSeconds then
			return isMember
		end
		local player = Players.LocalPlayer
		local ok, result = pcall(function()
			return player:IsInGroup(config.GroupId)
		end)
		if ok then
			isMember = result == true
			memberAt = os.clock()
		end
		return isMember
	end

	local function confetti()
		local gui, root = Kit.ScreenGui("ThockGroupChestFx", 30, context.PlayerGui, trove)
		local glow = Kit.Burst({
			Parent = root,
			Diameter = 380,
			Color = theme.Gold,
			Position = UDim2.fromScale(0.5, 0.45),
		})
		for index = 1, confettiCount do
			local piece = Instance.new("Frame")
			piece.Name = `Piece{index}`
			piece.BackgroundColor3 = confettiColors[rng:NextInteger(1, #confettiColors)]
			piece.BorderSizePixel = 0
			piece.AnchorPoint = Vector2.new(0.5, 0.5)
			piece.Size = UDim2.fromOffset(rng:NextInteger(10, 18), rng:NextInteger(7, 12))
			piece.Position = UDim2.fromScale(0.5, 0.45)
			piece.Rotation = rng:NextInteger(0, 90)
			piece.Parent = root
			local angle = rng:NextNumber(0, math.pi * 2)
			local reach = rng:NextNumber(140, 380)
			Kit.Tween(piece, flyInfo, {
				Position = UDim2.new(0.5, math.cos(angle) * reach, 0.45, math.sin(angle) * reach * 0.7 + 140),
				Rotation = piece.Rotation + rng:NextInteger(-360, 360),
				BackgroundTransparency = 1,
			})
		end
		task.delay(confettiSeconds + 0.2, function()
			glow:Destroy()
			gui:Destroy()
		end)
	end

	local function claim(isRetry: boolean)
		if isBusy then
			return
		end
		if config.GroupId <= 0 then
			playUi("Error")
			showPopup(soonMessage, false)
			return
		end
		isBusy = true
		local rate = tracker.GetStats().Rate
		local amount = math.max(config.MinCash, math.floor(config.IncomeSeconds * rate))
		local result = Packets.ClaimGroupChest:Fire()
		isBusy = false
		if result == 0 then
			playUi("Confirm")
			context.Close("GroupChest")
			confetti()
			context.Toast(
				`+{NumberFormat.Compact(amount)} Clicks + {math.floor(config.LuckPotionSeconds / 60)} min Luck Potion!`,
				"Gold"
			)
		elseif result == 1 then
			playUi("Error")
			memberAt = -math.huge
			if isRetry then
				showPopup(joinMessage, true, "Not a member yet. Join the group, then tap JOIN!")
			else
				showPopup(joinMessage, true)
			end
		elseif result == 2 then
			playUi("Error")
			context.Close("GroupChest")
			context.Toast(`Chest opens again in {TimeFormat.Hours(secondsLeft())}`, "Info")
		elseif result == 3 then
			playUi("Error")
			showPopup(soonMessage, false)
		else
			playUi("Error")
			context.Toast("Oops, couldn't open the chest!", "Bad")
		end
	end

	joinGroup = function()
		if isJoining or isBusy then
			return
		end
		isJoining = true
		local ok = pcall(function()
			local groupService = game:GetService("GroupService") :: any
			groupService:PromptJoinAsync(config.GroupId)
		end)
		isJoining = false
		if not ok then
			hint.Text = fallbackHint
			return
		end
		memberAt = -math.huge
		claim(true)
	end

	local function refreshSign(model: Instance)
		local label = model:FindFirstChild(subtitleName, true)
		if not label or not label:IsA("TextLabel") then
			return
		end
		if config.GroupId <= 0 then
			label.Text = soonMessage
		elseif not checkMember() then
			label.Text = "Join the group to claim!"
		else
			local left = secondsLeft()
			label.Text = if left > 0 then `Ready in {countdownText(left)}` else "READY!"
		end
	end

	local function refreshChest()
		local model = workspace:FindFirstChild(chestName)
		if not model then
			return
		end
		local prompt = model:FindFirstChild(promptName, true)
		if prompt and prompt ~= boundPrompt and prompt:IsA("ProximityPrompt") then
			promptTrove:Clean()
			boundPrompt = prompt
			promptTrove:Connect(prompt.Triggered, function()
				task.spawn(claim, false)
			end)
		end
		refreshSign(model)
	end

	local elapsed = refreshSeconds
	trove:Connect(RunService.Heartbeat, function(dt: number)
		elapsed += dt
		if elapsed >= refreshSeconds then
			elapsed = 0
			refreshChest()
		end
	end)

	return {
		Modal = true,
		StartsOpen = false,
		Open = function(_self: Types.Screen)
			isOpen = true
			if config.GroupId <= 0 then
				setPopup(soonMessage, false)
			end
			modal.Show()
		end,
		Close = function(_self: Types.Screen)
			if isOpen then
				isOpen = false
				modal.Hide()
			end
		end,
		Destroy = function(_self: Types.Screen)
			trove:Destroy()
		end,
	}
end

return GroupChest
