--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Trove = require(ReplicatedStorage.Packages.Trove)
local WaitFor = require(ReplicatedStorage.Packages.WaitFor)
local Toast = require(script.Toast)
local Types = require(script.Types)

local modules: { [string]: Types.ScreenModule } = {
	Hud = require(script.Screens.Hud),
	Upgrades = require(script.Screens.Upgrades),
	Keys = require(script.Screens.Keys),
	Index = require(script.Screens.Index),
	Settings = require(script.Screens.Settings),
	Offers = require(script.Screens.Offers),
	StarterOffer = require(script.Screens.StarterOffer),
	Daily = require(script.Screens.Daily),
	Market = require(script.Screens.Market),
	Shop = require(script.Screens.Shop),
	Trade = require(script.Screens.Trade),
	TradePrompt = require(script.Screens.TradePrompt),
	Rebirth = require(script.Screens.Rebirth),
	Season = require(script.Screens.Season),
	Leaderboards = require(script.Screens.Leaderboards),
	Hatch = require(script.Screens.Hatch),
}

local legacyGuiName = "Hud"

type TroveInstance = typeof(Trove.new())

local UIController = { Name = "UIController" }
local registry: { [string]: any } = {}
local screens: { [string]: Types.Screen } = {}
local opened: { [string]: boolean } = {}
local pending: { any } = {}
local trove: TroveInstance? = nil
local destroyed = false
local showToast: ((text: string, kind: string?) -> ())? = nil

function UIController.Init(_self: any, controllers: { [string]: any })
	registry = controllers
	trove = Trove.new()
end

function UIController.Open(_self: any, name: string)
	local screen = screens[name]
	if not screen or opened[name] then
		return
	end
	if screen.Modal then
		for otherName in opened do
			if screens[otherName].Modal then
				UIController:Close(otherName)
			end
		end
	end
	opened[name] = true
	screen:Open()
end

function UIController.Close(_self: any, name: string)
	local screen = screens[name]
	if not screen or not opened[name] then
		return
	end
	opened[name] = nil
	screen:Close()
end

function UIController.Toast(_self: any, text: string, kind: string?)
	local show = showToast
	if show then
		show(text, kind)
	end
end

function UIController.IsOpen(_self: any, name: string): boolean
	return opened[name] == true
end

local function closeModals()
	for name in opened do
		if screens[name].Modal then
			UIController:Close(name)
		end
	end
end

local function createScreens(playerGui: PlayerGui)
	local legacy = playerGui:FindFirstChild(legacyGuiName)
	if legacy and legacy:IsA("ScreenGui") then
		legacy.Enabled = false
	end
	local toast = Toast.new(playerGui, trove :: TroveInstance)
	showToast = toast
	local context: Types.Context = {
		Controllers = registry,
		PlayerGui = playerGui,
		Open = function(name: string)
			UIController:Open(name)
		end,
		Close = function(name: string)
			UIController:Close(name)
		end,
		Toast = toast,
		IsOpen = function(name: string): boolean
			return UIController:IsOpen(name)
		end,
	}
	for name, module in modules do
		local created, result = pcall(module.new, context)
		if created then
			local screen = result :: Types.Screen
			screens[name] = screen
			if screen.StartsOpen then
				UIController:Open(name)
			else
				screen:Close()
			end
		else
			warn(`[UIController] {name} screen failed: {tostring(result)}`)
		end
	end
end

function UIController.Start(_self: any)
	local own = trove :: TroveInstance
	own:Connect(UserInputService.InputBegan, function(input: InputObject)
		if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
			closeModals()
		end
	end)
	local promise = WaitFor.Child(Players.LocalPlayer, "PlayerGui", 15)
		:andThen(function(playerGui: Instance)
			if destroyed or not playerGui:IsA("PlayerGui") then
				return
			end
			createScreens(playerGui)
		end)
		:catch(function(problem: any)
			warn(`[UIController] PlayerGui not found: {tostring(problem)}`)
		end)
	table.insert(pending, promise)
end

function UIController.Destroy(_self: any)
	destroyed = true
	showToast = nil
	for _, promise in pending do
		promise:cancel()
	end
	table.clear(pending)
	for _, screen in screens do
		screen:Destroy()
	end
	table.clear(screens)
	table.clear(opened)
	if trove then
		trove:Destroy()
		trove = nil
	end
end

return UIController
