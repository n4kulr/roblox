--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Trove = require(ReplicatedStorage.Packages.Trove)
local WaitFor = require(ReplicatedStorage.Packages.WaitFor)
local WorldNames = require(ReplicatedStorage.Config.WorldNames)
local CapRegistry = require(script.CapRegistry)
local Config = require(script.Config)
local Detection = require(script.Detection)
local Press = require(script.Press)

local Attributes = WorldNames.Attributes
local Folders = WorldNames.Folders

type TroveInstance = typeof(Trove.new())
type State = {
	Name: string,
	_trove: TroveInstance?,
}

local KeyPressController = {
	Name = "KeyPressController",
	_trove = nil :: TroveInstance?,
}
local controllers: { [string]: any } = {}
local registry = CapRegistry.new()
local destroyed = false
local isLowGraphics = false
local seenPlayers: { [Player]: boolean } = {}
local candidates: { Player } = {}

local function update()
	local camera = workspace.CurrentCamera
	if not camera or (next(registry.Plots) == nil and registry.Cosmetic == nil) then
		return
	end
	local cameraPosition = camera.CFrame.Position
	local localPlayer = Players.LocalPlayer
	local standingOn = registry.StandingOn
	table.clear(seenPlayers)
	local count = 0
	local range = if isLowGraphics then Config.LowViewRange else Config.ViewRange
	table.clear(candidates)
	candidates[1] = localPlayer
	if not isLowGraphics then
		for _, player in Players:GetPlayers() do
			if player ~= localPlayer then
				table.insert(candidates, player)
			end
		end
	end
	for _, player in candidates do
		if count >= Config.MaxCharacters then
			break
		end
		local root, isGrounded = Detection.GetRoot(player)
		if root and (root.Position - cameraPosition).Magnitude <= range then
			seenPlayers[player] = true
			count += 1
			local cap = if isGrounded then Detection.FindCap(registry, root.Position) else nil
			local previous = standingOn[player]
			if cap ~= previous then
				if
					previous
					and previous.Part.Parent
					and previous.Part:GetAttribute(Attributes.Locked) ~= true
				then
					Press.Play(controllers, previous, player, "Release")
				end
				if cap then
					standingOn[player] = cap
					Press.Trigger(controllers, cap, player)
				else
					standingOn[player] = nil
				end
				if previous then
					Press.Raise(registry, previous)
				end
			end
		end
	end
	for player, standing in standingOn do
		if not seenPlayers[player] then
			standingOn[player] = nil
			Press.Raise(registry, standing)
		end
	end
end

function KeyPressController.Init(self: State, registryOfControllers: { [string]: any })
	controllers = registryOfControllers
	destroyed = false
	self._trove = Trove.new()
end

function KeyPressController.Start(self: State)
	local trove = self._trove :: TroveInstance
	trove:Add(controllers.DataController:Observe({ "Settings", "LowGraphics" }, function(value: any)
		isLowGraphics = value == true
	end))
	trove:Connect(RunService.Heartbeat, update)
	local existing = workspace:FindFirstChild(Folders.CosmeticKeys)
	if existing then
		CapRegistry.BindCosmetic(registry, existing, trove)
	end
	trove:Connect(workspace.ChildAdded, function(child: Instance)
		if child.Name == Folders.CosmeticKeys then
			CapRegistry.BindCosmetic(registry, child, trove)
		end
	end)
	local promise = WaitFor.Child(workspace, Folders.Plots, 30)
		:andThen(function(folder: Instance)
			if destroyed then
				return
			end
			local plotsTrove = Trove.new()
			trove:Add(plotsTrove)
			CapRegistry.WatchPlots(registry, folder, plotsTrove)
		end)
		:catch(function(problem: any)
			warn(`[KeyPressController] workspace.Plots not found: {tostring(problem)}`)
		end)
	trove:Add(function()
		promise:cancel()
	end)
end

function KeyPressController.Destroy(self: State)
	destroyed = true
	isLowGraphics = false
	if self._trove then
		self._trove:Destroy()
		self._trove = nil
	end
	CapRegistry.Clear(registry)
	table.clear(seenPlayers)
	table.clear(candidates)
end

return KeyPressController
