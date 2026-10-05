--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)

local config = GameConfig.Obby.PopUp

local PopUps = {}

export type State = {
	Part: BasePart,
	Rest: CFrame,
	IsRaised: boolean,
	Tween: Tween?,
}

local function number(part: BasePart, name: string, default: number): number
	local value = part:GetAttribute(name)
	return if type(value) == "number" then value else default
end

function PopUps.New(part: BasePart): State
	return { Part = part, Rest = part.CFrame, IsRaised = false, Tween = nil }
end

function PopUps.IsRaisedAt(part: BasePart, now: number): boolean
	local period = math.max(0.1, number(part, "PeriodSeconds", config.PeriodSeconds))
	local phase = number(part, "PhaseSeconds", 0)
	return (now + phase) % period < number(part, "UpSeconds", config.UpSeconds)
end

local function cancel(state: State)
	local tween = state.Tween
	if tween then
		state.Tween = nil
		tween:Cancel()
		tween:Destroy()
	end
end

function PopUps.Step(state: State, now: number)
	local raised = PopUps.IsRaisedAt(state.Part, now)
	if raised == state.IsRaised then
		return
	end
	state.IsRaised = raised
	state.Part:SetAttribute("Raised", raised)
	local rise = number(state.Part, "RiseHeight", config.RiseHeight)
	local goal = if raised then state.Rest * CFrame.new(0, rise, 0) else state.Rest
	cancel(state)
	local tween = TweenService:Create(
		state.Part,
		TweenInfo.new(config.TweenSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ CFrame = goal }
	)
	state.Tween = tween
	tween:Play()
end

function PopUps.Reset(state: State)
	cancel(state)
	state.Part.CFrame = state.Rest
	state.Part:SetAttribute("Raised", nil)
	state.IsRaised = false
end

return PopUps
