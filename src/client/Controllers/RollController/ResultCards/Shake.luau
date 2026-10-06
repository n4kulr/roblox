--!strict

local Players = game:GetService("Players")
local CameraShake = require(script.Parent.Parent.CameraShake)
local Types = require(script.Parent.Types)

type ResultCards = Types.ResultCards

local Shake = {}

function Shake.Start(self: ResultCards, strength: number)
	if self._shakeLeft <= 0 then
		local player = Players.LocalPlayer
		local character = if player then player.Character else nil
		local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
		if not humanoid then
			return
		end
		self._humanoid = humanoid
	end
	self._shakeTotal = 0.32
	self._shakeLeft = 0.32
	self._shakeStrength = strength
end

function Shake.Step(self: ResultCards, dt: number)
	if self._shakeLeft <= 0 then
		return
	end
	local humanoid = self._humanoid
	self._shakeLeft -= dt
	if not humanoid then
		self._shakeLeft = 0
		return
	end
	if self._shakeLeft <= 0 then
		self._shakeLeft = 0
		CameraShake.Clear(humanoid, self)
		return
	end
	local amplitude = self._shakeStrength * (self._shakeLeft / self._shakeTotal)
	CameraShake.Set(
		humanoid,
		self,
		Vector3.new((math.random() - 0.5) * 2 * amplitude, (math.random() - 0.5) * 2 * amplitude, 0)
	)
end

return Shake
