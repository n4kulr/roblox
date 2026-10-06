--!strict

local Packet = require(script.Parent.Packet)

local Packets = {
	Roll = Packet("Roll"):Response(Packet.NumberU16, Packet.Boolean8):RateLimit(15, 1),
	RareRoll = Packet("RareRoll", Packet.String, Packet.NumberU16),
	BuyUpgrade = Packet("BuyUpgrade", Packet.String, Packet.NumberU8)
		:Response(Packet.Boolean8)
		:RateLimit(10, 1),
	PlaceKey = Packet("PlaceKey", Packet.NumberU8, Packet.String):Response(Packet.Boolean8):RateLimit(10, 1),
	ClearSlot = Packet("ClearSlot", Packet.NumberU8):Response(Packet.Boolean8):RateLimit(10, 1),
	EquipBest = Packet("EquipBest"):Response(Packet.Boolean8):RateLimit(2, 1),
	SellKey = Packet("SellKey", Packet.String, Packet.NumberU16):Response(Packet.Boolean8):RateLimit(5, 1),
	SetSetting = Packet("SetSetting", Packet.String, Packet.NumberF32):RateLimit(10, 1),
	StealAlert = Packet("StealAlert", Packet.String, Packet.NumberU16, Packet.NumberU8),
	StealFeed = Packet("StealFeed", Packet.String, Packet.String, Packet.NumberU16),
	TagThief = Packet("TagThief", Packet.NumberF64):Response(Packet.Boolean8):RateLimit(4, 1),
	Knock = Packet("Knock", Packet.NumberF64):Response(Packet.Boolean8):RateLimit(3, 1),
	KeyfallEvent = Packet("KeyfallEvent", Packet.NumberU8, Packet.String, Packet.NumberU16),
	Rebirth = Packet("Rebirth"):Response(Packet.Boolean8):RateLimit(1, 1),
	RedeemCode = Packet("RedeemCode", Packet.String):Response(Packet.NumberU8):RateLimit(2, 1),
	ClaimSeason = Packet("ClaimSeason", Packet.NumberU8, Packet.Boolean8)
		:Response(Packet.Boolean8)
		:RateLimit(5, 1),
	GetLeaderboard = Packet("GetLeaderboard", Packet.NumberU8)
		:Response({ { Name = Packet.String, Value = Packet.NumberF64 } })
		:RateLimit(2, 1),
	TradeRequest = Packet("TradeRequest", Packet.NumberF64):Response(Packet.Boolean8):RateLimit(2, 1),
	TradeInvite = Packet("TradeInvite", Packet.String, Packet.NumberF64),
	TradeRespond = Packet("TradeRespond", Packet.NumberF64, Packet.Boolean8):RateLimit(4, 1),
	TradeOffer = Packet("TradeOffer", Packet.String, Packet.NumberU16):RateLimit(10, 1),
	TradeReady = Packet("TradeReady", Packet.Boolean8):RateLimit(4, 1),
	TradeCancel = Packet("TradeCancel"):RateLimit(2, 1),
	TradeState = Packet(
		"TradeState",
		Packet.NumberU8,
		Packet.String,
		{ { KeyId = Packet.String, Count = Packet.NumberU16 } },
		{ { KeyId = Packet.String, Count = Packet.NumberU16 } },
		Packet.Boolean8,
		Packet.Boolean8,
		Packet.NumberU8
	),
	LockBase = Packet("LockBase"):Response(Packet.Boolean8):RateLimit(2, 1),
	MarketBuy = Packet("MarketBuy", Packet.NumberU8):Response(Packet.Boolean8):RateLimit(4, 1),
	ClaimDaily = Packet("ClaimDaily"):Response(Packet.NumberU8):RateLimit(2, 1),
	ClaimPlaytime = Packet("ClaimPlaytime", Packet.NumberU8):Response(Packet.Boolean8):RateLimit(5, 1),
	ClaimGroupChest = Packet("ClaimGroupChest"):Response(Packet.NumberU8):RateLimit(2, 1),
	HatchEgg = Packet("HatchEgg", Packet.NumberU8):Response(Packet.String):RateLimit(3, 1),
	PlaceEgg = Packet("PlaceEgg", Packet.String, Packet.NumberF32, Packet.NumberF32)
		:Response(Packet.Boolean8)
		:RateLimit(4, 1),
	EquipCharm = Packet("EquipCharm", Packet.String, Packet.Boolean8)
		:Response(Packet.Boolean8)
		:RateLimit(5, 1),
	Ping = Packet("Ping"):Response(Packet.NumberF64):RateLimit(5, 1),
}

Packets.BuyUpgrade.ResponseTimeout = 1.5
Packets.BuyUpgrade.ResponseTimeoutValue = false

return Packets
