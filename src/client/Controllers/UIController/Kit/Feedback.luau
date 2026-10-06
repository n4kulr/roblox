--!strict

local TweenService = game:GetService("TweenService")
local Core = require(script.Parent.Core)
local Theme = require(script.Parent.Theme)

export type Flash = {
	Instance: Frame,
	Fire: (peak: number, info: TweenInfo?) -> (),
}

export type FlashProps = {
	Parent: Instance,
	Radius: number,
	ZIndex: number,
	Color: Color3?,
}

export type CountUp = {
	SetTarget: (value: number?) -> (),
	Step: (dt: number) -> (),
	Shown: () -> number?,
}

export type CountUpProps = {
	Label: TextLabel,
	Format: (value: number) -> string,
	Rate: number?,
	Placeholder: string?,
}

local Feedback = {
	CountRate = 9,
}

function Feedback.Flash(props: FlashProps): Flash
	local frame = Instance.new("Frame")
	frame.Name = "Flash"
	frame.BackgroundColor3 = props.Color or Theme.Colors.White
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = props.ZIndex
	Core.Corner(frame, props.Radius)
	frame.Parent = props.Parent
	return {
		Instance = frame,
		Fire = function(peak: number, info: TweenInfo?)
			frame.BackgroundTransparency = peak
			TweenService:Create(frame, info or Theme.Motion.Slow, { BackgroundTransparency = 1 }):Play()
		end,
	}
end

function Feedback.CountUp(props: CountUpProps): CountUp
	local rate = props.Rate or Feedback.CountRate
	local placeholder = props.Placeholder or "..."
	local target = 0
	local shown: number? = nil
	local lastText = ""
	local function write(text: string)
		if text ~= lastText then
			lastText = text
			props.Label.Text = text
		end
	end
	return {
		SetTarget = function(value: number?)
			if value == nil then
				shown = nil
				return
			end
			target = value
			if shown == nil then
				shown = value
			end
		end,
		Step = function(dt: number)
			local current = shown
			if current == nil then
				write(placeholder)
				return
			end
			local gap = target - current
			if math.abs(gap) < 1 then
				current = target
			else
				current += gap * math.min(1, dt * rate)
			end
			shown = current
			write(props.Format(current))
		end,
		Shown = function()
			return shown
		end,
	}
end

return Feedback
