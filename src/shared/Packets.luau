--!strict

local Packet = require(script.Parent.Packet)

local Packets = {
	Roll = Packet("Roll"):Response(Packet.NumberU16):RateLimit(10, 1),
	RareRoll = Packet("RareRoll", Packet.String, Packet.NumberU16),
	Ping = Packet("Ping"):Response(Packet.NumberF64):RateLimit(5, 1),
}

return Packets
