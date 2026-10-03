--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Keys = require(ReplicatedStorage.Config.Keys)
local Trove = require(ReplicatedStorage.Packages.Trove)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)
local Types = require(script.Parent.Parent.Types)

local refreshSeconds = 0.1

local Hud = {}

local function findLabel(gui: ScreenGui, name: string): TextLabel?
	local label = gui:FindFirstChild(name, true)
	return if label and label:IsA("TextLabel") then label else nil
end

function Hud.new(context: Types.Context, gui: ScreenGui): Types.Screen
	local trove = Trove.new()
	local dataController = context.Controllers.DataController
	local cashLabel = findLabel(gui, "Cash")
	local incomeLabel = findLabel(gui, "Income")
	local cash: number? = nil
	local incomeAt = 0
	local rate = 0

	if not cashLabel then
		warn(`[Hud] {gui:GetFullName()} needs a TextLabel named Cash`)
	end
	if not incomeLabel then
		warn(`[Hud] {gui:GetFullName()} needs a TextLabel named Income`)
	end

	local function refresh()
		local balance = cash
		if cashLabel then
			if balance then
				local elapsed = math.max(0, workspace:GetServerTimeNow() - incomeAt)
				local predicted = if incomeAt > 0 then balance + math.floor(rate * elapsed) else balance
				cashLabel.Text = NumberFormat.Compact(predicted)
			else
				cashLabel.Text = "..."
			end
		end
		if incomeLabel then
			incomeLabel.Text = if balance then `+{NumberFormat.Compact(rate)}/s` else "..."
		end
	end

	trove:Add(dataController:Observe({ "Cash" }, function(value: any)
		cash = if type(value) == "number" then value else nil
	end))
	trove:Add(dataController:Observe({ "IncomeAt" }, function(value: any)
		incomeAt = if type(value) == "number" then value else 0
	end))
	trove:Add(dataController:Observe({ "Board" }, function(value: any)
		local total = 0
		if type(value) == "table" then
			for _, keyId in value do
				if type(keyId) == "string" then
					total += Keys.GetIncome(keyId)
				end
			end
		end
		rate = total
	end))

	local elapsedSinceRefresh = 0
	trove:Connect(RunService.Heartbeat, function(dt: number)
		elapsedSinceRefresh += dt
		if elapsedSinceRefresh >= refreshSeconds then
			elapsedSinceRefresh = 0
			refresh()
		end
	end)
	refresh()

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
			trove:Destroy()
		end,
	}
end

return Hud
