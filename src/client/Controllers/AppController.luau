--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)
local Packets = require(ReplicatedStorage.Packets)
local Trove = require(ReplicatedStorage.Packages.Trove)
type TroveInstance = typeof(Trove.new())

type State = {
	Name: string,
	_trove: TroveInstance?,
}

local AppController = {
	Name = "AppController",
	_trove = nil :: TroveInstance?,
}

local function placeJump(root: Instance)
	local jump = root:FindFirstChild("JumpButton", true)
	if jump and jump:IsA("GuiObject") then
		jump.AnchorPoint = Vector2.new(0, 0)
		jump.Position = UDim2.new(0, 18, 0, 72)
		jump.Size = UDim2.fromOffset(70, 70)
	end
end

local function watchTouchGui(trove: TroveInstance, playerGui: PlayerGui)
	local function bind(gui: Instance)
		placeJump(gui)
		trove:Add(gui.DescendantAdded:Connect(function(child)
			if child.Name == "JumpButton" and child:IsA("GuiObject") then
				placeJump(gui)
			end
		end))
	end
	local existing = playerGui:FindFirstChild("TouchGui")
	if existing then
		bind(existing)
	end
	trove:Add(playerGui.ChildAdded:Connect(function(child)
		if child.Name == "TouchGui" then
			bind(child)
		end
	end))
end

function AppController.Init(self: State, _controllers: { [string]: any })
	self._trove = Trove.new()
end

function AppController.Start(self: State)
	print(`[{GameConfig.Name}] Client controllers ready`)
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
	end)
	local trove = self._trove
	local player = Players.LocalPlayer
	if trove and player then
		local playerGui = player:FindFirstChildOfClass("PlayerGui") or player:WaitForChild("PlayerGui")
		if playerGui:IsA("PlayerGui") then
			watchTouchGui(trove, playerGui)
		end
	end
	task.spawn(function()
		local sentAt = os.clock()
		local serverTime = Packets.Ping:Fire()
		if serverTime then
			print(`[{GameConfig.Name}] Packet round trip {math.round((os.clock() - sentAt) * 1000)} ms`)
		end
	end)
end

function AppController.Destroy(self: State)
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
end

return AppController
