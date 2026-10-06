--!strict

local TweenService = game:GetService("TweenService")
local Tweens = require(script.Parent.Tweens)
local Primitives = require(script.Parent.Primitives)
local Theme = require(script.Parent.Theme)

local colors = Theme.Colors
local motion = Theme.Motion

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
	Primitives.Corner(frame, props.Radius)
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

function Feedback.Pulse(target: GuiObject, color: Color3?, peak: number?)
	local top = peak or 1.04
	local settle = motion.Fast
	if top ~= 1 then
		local existing = target:FindFirstChild("PulseScale")
		local scale: UIScale
		if existing and existing:IsA("UIScale") then
			scale = existing
		else
			scale = Instance.new("UIScale")
			scale.Name = "PulseScale"
			scale.Parent = target
		end
		local rise = Tweens.Tween(scale, motion.SpringQuick, { Scale = top })
		rise.Completed:Once(function()
			Tweens.Tween(scale, settle, { Scale = 1 })
		end)
	end
	local stroke = target:FindFirstChild("Stroke")
	if stroke and stroke:IsA("UIStroke") then
		local base = stroke:GetAttribute("PulseBase")
		if typeof(base) ~= "Color3" then
			base = stroke.Color
			stroke:SetAttribute("PulseBase", base)
		end
		local rest = base :: Color3
		local flash = Tweens.Tween(stroke, settle, { Color = color or colors.Good })
		flash.Completed:Once(function()
			Tweens.Tween(stroke, motion.Fade, { Color = rest })
		end)
	end
end

function Feedback.Shake(target: GuiObject)
	task.spawn(function()
		for _, rotation in { 3, -3, 2, -2, 0 } do
			if not target.Parent then
				return
			end
			target.Rotation = rotation
			task.wait(0.035)
		end
	end)
end

return Feedback
