--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Trove = require(ReplicatedStorage.Packages.Trove)

type TroveInstance = typeof(Trove.new())

local Poll = {
	Seconds = table.freeze({ Fast = 0.2, Relaxed = 0.25 }),
}

function Poll.Start(
	trove: TroveInstance,
	seconds: number,
	isActive: (() -> boolean)?,
	step: (dt: number) -> ()
)
	local elapsed = 0
	trove:Connect(RunService.Heartbeat, function(dt: number)
		if isActive and not isActive() then
			return
		end
		elapsed += dt
		if elapsed >= seconds then
			elapsed = 0
			step(dt)
		end
	end)
end

return Poll
