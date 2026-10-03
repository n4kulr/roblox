--!strict

local Packet = require(script.Parent.Packet)

local Packets = {
	Roll = Packet("Roll"):Response(Packet.NumberU16, Packet.Boolean8):RateLimit(15, 1),
	RareRoll = Packet("RareRoll", Packet.String, Packet.NumberU16),
	BuyUpgrade = Packet("BuyUpgrade", Packet.String):Response(Packet.Boolean8):RateLimit(5, 1),
	PlaceKey = Packet("PlaceKey", Packet.NumberU8, Packet.String):Response(Packet.Boolean8):RateLimit(10, 1),
	ClearSlot = Packet("ClearSlot", Packet.NumberU8):Response(Packet.Boolean8):RateLimit(10, 1),
	EquipBest = Packet("EquipBest"):Response(Packet.Boolean8):RateLimit(2, 1),
	SellKey = Packet("SellKey", Packet.String, Packet.NumberU16):Response(Packet.Boolean8):RateLimit(5, 1),
	SetSetting = Packet("SetSetting", Packet.String, Packet.NumberF32):RateLimit(10, 1),
	StealAlert = Packet("StealAlert", Packet.String, Packet.NumberU16, Packet.NumberU8),
	StealFeed = Packet("StealFeed", Packet.String, Packet.String, Packet.NumberU16),
	TagThief = Packet("TagThief", Packet.NumberF64):Response(Packet.Boolean8):RateLimit(4, 1),
	ClaimDaily = Packet("ClaimDaily"):Response(Packet.NumberU8):RateLimit(2, 1),
	Ping = Packet("Ping"):Response(Packet.NumberF64):RateLimit(5, 1),
}

return Packets
