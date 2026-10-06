--!strict

local TweenService = game:GetService("TweenService")

local Tweens = {}

function Tweens.Tween(target: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local created = TweenService:Create(target, info, goal)
	created:Play()
	return created
end

return Tweens
