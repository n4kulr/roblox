--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Trove = require(ReplicatedStorage.Packages.Trove)
local WaitFor = require(ReplicatedStorage.Packages.WaitFor)
local Economy = require(script.Economy)
local Kit = require(script.Kit)
local PetState = require(script.PetState)
local Toast = require(script.Toast)
local Types = require(script.Types)

type Registration = { Name: string, Module: Types.ScreenModule }

local registrations: { Registration } = {
	{ Name = "Hud", Module = require(script.Screens.Hud) },
	{ Name = "Upgrades", Module = require(script.Screens.Upgrades) },
	{ Name = "Keys", Module = require(script.Screens.Keys) },
	{ Name = "Index", Module = require(script.Screens.Index) },
	{ Name = "Settings", Module = require(script.Screens.Settings) },
	{ Name = "Offers", Module = require(script.Screens.Offers) },
	{ Name = "StarterOffer", Module = require(script.Screens.StarterOffer) },
	{ Name = "Daily", Module = require(script.Screens.Daily) },
	{ Name = "Market", Module = require(script.Screens.Market) },
	{ Name = "Shop", Module = require(script.Screens.Shop) },
	{ Name = "Trade", Module = require(script.Screens.Trade) },
	{ Name = "TradePrompt", Module = require(script.Screens.TradePrompt) },
	{ Name = "Rebirth", Module = require(script.Screens.Rebirth) },
	{ Name = "Season", Module = require(script.Screens.Season) },
	{ Name = "Leaderboards", Module = require(script.Screens.Leaderboards) },
	{ Name = "Hatch", Module = require(script.Screens.Hatch) },
	{ Name = "Pets", Module = require(script.Screens.Pets) },
	{ Name = "Cheats", Module = require(script.Screens.Cheats) },
}

local legacyGuiName = "Hud"

type TroveInstance = typeof(Trove.new())

local UIController = { Name = "UIController" }
local registry: { [string]: any } = {}
local screens: { [string]: Types.Screen } = {}
local failures: { string } = {}
local anchors: { [string]: GuiObject } = {}
local opened: { [string]: boolean } = {}
local pending: { any } = {}
local trove: TroveInstance? = nil
local destroyed = false
local showToast: ((text: string, kind: Types.ToastKind?) -> ())? = nil

function UIController.Init(_self: any, controllers: { [string]: any })
	registry = controllers
	trove = Trove.new()
end

function UIController.Open(_self: any, name: string)
	local screen = screens[name]
	if not screen or opened[name] then
		return
	end
	local canOpen = screen.CanOpen
	if canOpen and not canOpen(screen) then
		return
	end
	if screen.Modal then
		for _, registration in registrations do
			local otherName = registration.Name
			local other = screens[otherName]
			if opened[otherName] and other and other.Modal then
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

function UIController.Toast(_self: any, text: string, kind: Types.ToastKind?)
	local show = showToast
	if show then
		show(text, kind)
	end
end

function UIController.IsOpen(_self: any, name: string): boolean
	return opened[name] == true
end

function UIController.GetFailures(_self: any): { string }
	return table.clone(failures)
end

local function closeModals()
	for _, registration in registrations do
		local screen = screens[registration.Name]
		if opened[registration.Name] and screen and screen.Modal then
			UIController:Close(registration.Name)
		end
	end
end

local function createScreens(playerGui: PlayerGui)
	local own = trove :: TroveInstance
	local legacy = playerGui:FindFirstChild(legacyGuiName)
	if legacy and legacy:IsA("ScreenGui") then
		legacy.Enabled = false
	end
	Kit.SetSound(Kit.UiSound(registry))
	local toast = Toast.new(playerGui, own)
	showToast = toast
	local dataController = registry.DataController
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
		Economy = if dataController then Economy.Track(dataController, own) else nil,
		Pets = if dataController then PetState.Track(dataController, own) else nil,
		SetAnchor = function(name: string, anchor: GuiObject?)
			if anchor then
				anchors[name] = anchor
			else
				anchors[name] = nil
			end
		end,
		GetAnchor = function(name: string): GuiObject?
			return anchors[name]
		end,
	}
	for _, registration in registrations do
		local name = registration.Name
		local created, result = pcall(registration.Module.new, context)
		if created then
			local screen = result :: Types.Screen
			screens[name] = screen
			if screen.StartsOpen then
				UIController:Open(name)
			else
				screen:Close()
			end
		else
			table.insert(failures, name)
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
	Kit.SetSound(nil)
	for _, promise in pending do
		promise:cancel()
	end
	table.clear(pending)
	for _, screen in screens do
		screen:Destroy()
	end
	table.clear(screens)
	table.clear(opened)
	table.clear(failures)
	table.clear(anchors)
	if trove then
		trove:Destroy()
		trove = nil
	end
end

return UIController
