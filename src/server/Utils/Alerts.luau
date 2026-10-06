--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Packets)

local Alerts = {
	Phase = {
		Grab = 1,
		Carry = 2,
		Returned = 3,
		Delivered = 4,
		Rejected = 9,
		Good = 11,
	},
}

function Alerts.Send(player: Player, text: string, keyIndex: number, phase: number)
	Packets.StealAlert:FireClient(player, text, keyIndex, phase)
end

function Alerts.Bad(player: Player, text: string)
	Alerts.Send(player, text, 0, Alerts.Phase.Rejected)
end

function Alerts.Good(player: Player, text: string)
	Alerts.Send(player, text, 0, Alerts.Phase.Good)
end

return table.freeze(Alerts)
