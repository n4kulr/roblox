--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.Config.GameConfig)

export type Data = {
	SchemaVersion: number,
	Cash: number,
	IncomeAt: number,
	Board: { string },
	Inventory: { [string]: number },
	Discovered: { [string]: number },
	Rolls: number,
	GoldenProgress: number,
	Upgrades: {
		Luck: number,
		Speed: number,
		Slots: number,
		Income: number,
		Walls: number,
		LockTime: number,
		Golden: number,
	},
	Settings: {
		LowGraphics: boolean,
		AutoPlace: boolean,
		RollVolume: number,
		BoardVolume: number,
		OtherVolume: number,
		MusicVolume: number,
		EffectsMinRarity: number,
	},
	Tutorial: number,
	BoardTags: { string },
	PlaySeconds: number,
	TheftLessonDone: boolean,
	Boosts: { LuckUntil: number, ClicksUntil: number },
	Daily: { Streak: number, LastClaim: number },
	GroupChestAt: number,
	Incubators: { string },
	IncubatorReadyAt: { number },
	Charms: { [string]: number },
	EquippedCharms: { string },
	EggInventory: { [string]: number },
	PlacedEggs: { { Id: string, ReadyAt: number, X: number, Z: number } },
	StarterPackBought: boolean,
	Rebirths: number,
	TotalEarned: number,
	RedeemedCodes: { [string]: boolean },
	Season: { Id: number, Xp: number, ClaimedFree: number, ClaimedPremium: number },
	Market: { Slot: number, Bought: { [string]: number } },
	LastSeenAt: number,
	Receipts: { [string]: number },
}

local PlayerData = {}

local function emptyBoard(): { string }
	local board = {}
	for index = 1, GameConfig.BoardSlots do
		board[index] = ""
	end
	return board
end

PlayerData.Template = {
	SchemaVersion = 1,
	Cash = 0,
	IncomeAt = 0,
	Board = emptyBoard(),
	Inventory = {},
	Discovered = {},
	Rolls = 0,
	GoldenProgress = 0,
	Upgrades = { Luck = 0, Speed = 0, Slots = 0, Income = 0, Walls = 0, LockTime = 0, Golden = 0 },
	Settings = {
		LowGraphics = false,
		AutoPlace = true,
		RollVolume = 1,
		BoardVolume = 1,
		OtherVolume = 1,
		MusicVolume = 0.5,
		EffectsMinRarity = 5,
	},
	Tutorial = 0,
	BoardTags = emptyBoard(),
	PlaySeconds = 0,
	TheftLessonDone = false,
	Boosts = { LuckUntil = 0, ClicksUntil = 0 },
	Daily = { Streak = 0, LastClaim = 0 },
	GroupChestAt = 0,
	Incubators = { "", "", "" },
	IncubatorReadyAt = { 0, 0, 0 },
	Charms = {},
	EquippedCharms = {},
	EggInventory = {},
	PlacedEggs = {},
	StarterPackBought = false,
	Rebirths = 0,
	TotalEarned = 0,
	RedeemedCodes = {},
	Season = { Id = 0, Xp = 0, ClaimedFree = 0, ClaimedPremium = 0 },
	Market = { Slot = 0, Bought = {} },
	LastSeenAt = 0,
	Receipts = {},
} :: Data

local function natural(value: any): boolean
	return type(value) == "number"
		and value == value
		and math.abs(value) < math.huge
		and value >= 0
		and value % 1 == 0
end

function PlayerData.Validate(data: any): boolean
	if type(data) ~= "table" or (data.SchemaVersion ~= nil and data.SchemaVersion ~= 1) then
		return false
	end
	for _, key in
		{
			"Cash",
			"IncomeAt",
			"Rolls",
			"GoldenProgress",
			"GroupChestAt",
			"Tutorial",
			"PlaySeconds",
			"Rebirths",
			"TotalEarned",
			"LastSeenAt",
		}
	do
		if data[key] ~= nil and not natural(data[key]) then
			return false
		end
	end
	if data.Receipts ~= nil then
		if type(data.Receipts) ~= "table" then
			return false
		end
		for purchaseId, grantedAt in data.Receipts do
			if type(purchaseId) ~= "string" or #purchaseId == 0 or not natural(grantedAt) then
				return false
			end
		end
	end
	if data.Board ~= nil then
		if type(data.Board) ~= "table" then
			return false
		end
		for index, keyId in data.Board do
			if type(index) ~= "number" or type(keyId) ~= "string" then
				return false
			end
		end
	end
	if data.Inventory ~= nil then
		if type(data.Inventory) ~= "table" then
			return false
		end
		for keyId, count in data.Inventory do
			if type(keyId) ~= "string" or not natural(count) then
				return false
			end
		end
	end
	if data.Discovered ~= nil then
		if type(data.Discovered) ~= "table" then
			return false
		end
		for keyId, count in data.Discovered do
			if type(keyId) ~= "string" or not natural(count) then
				return false
			end
		end
	end
	for _, key in { "TheftLessonDone", "StarterPackBought" } do
		if data[key] ~= nil and type(data[key]) ~= "boolean" then
			return false
		end
	end
	if data.BoardTags ~= nil then
		if type(data.BoardTags) ~= "table" then
			return false
		end
		for index, tag in data.BoardTags do
			if type(index) ~= "number" or type(tag) ~= "string" then
				return false
			end
		end
	end
	if data.Market ~= nil then
		if type(data.Market) ~= "table" or (data.Market.Slot ~= nil and not natural(data.Market.Slot)) then
			return false
		end
		if data.Market.Bought ~= nil then
			if type(data.Market.Bought) ~= "table" then
				return false
			end
			for offer, count in data.Market.Bought do
				if type(offer) ~= "string" or not natural(count) then
					return false
				end
			end
		end
	end
	if data.RedeemedCodes ~= nil then
		if type(data.RedeemedCodes) ~= "table" then
			return false
		end
		for code, used in data.RedeemedCodes do
			if type(code) ~= "string" or type(used) ~= "boolean" then
				return false
			end
		end
	end
	for _, group in { "Boosts", "Daily", "Season" } do
		local value = data[group]
		if value ~= nil then
			if type(value) ~= "table" then
				return false
			end
			for name, amount in value do
				if type(name) ~= "string" or not natural(amount) then
					return false
				end
			end
		end
	end
	if data.Upgrades ~= nil then
		if type(data.Upgrades) ~= "table" then
			return false
		end
		for name, level in data.Upgrades do
			if type(name) ~= "string" or not natural(level) then
				return false
			end
		end
	end
	if data.Settings ~= nil then
		if type(data.Settings) ~= "table" then
			return false
		end
		for name, value in data.Settings do
			if type(name) ~= "string" or (type(value) ~= "boolean" and type(value) ~= "number") then
				return false
			end
		end
	end
	return true
end

function PlayerData.Migrate(_data: any) end

return PlayerData
