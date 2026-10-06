--!strict

local PlayerData = require(script.Parent.Parent.Parent.Data.PlayerData)
local Types = require(script.Parent.Types)

local Inventory = {}

function Inventory.Add(context: Types.Context, player: Player, keyId: string, amount: number)
	local data = context.Services.DataService:GetData(player) :: PlayerData.Data?
	if data then
		context.Services.DataService:Set(
			player,
			{ "Inventory", keyId },
			(data.Inventory[keyId] or 0) + amount
		)
	end
end

function Inventory.Remove(
	context: Types.Context,
	player: Player,
	data: PlayerData.Data,
	keyId: string,
	amount: number
)
	local remaining = (data.Inventory[keyId] or 0) - amount
	context.Services.DataService:Set(player, { "Inventory", keyId }, if remaining > 0 then remaining else nil)
end

function Inventory.SetTag(context: Types.Context, player: Player, slot: number, tag: string)
	local data = context.Services.DataService:GetData(player) :: PlayerData.Data?
	if not data or type(data.BoardTags) ~= "table" then
		return
	end
	if (data.BoardTags[slot] or "") ~= tag then
		local path: { string | number } = { "BoardTags", slot }
		context.Services.DataService:Set(player, path, tag)
	end
end

function Inventory.SetSlot(context: Types.Context, player: Player, slot: number, keyId: string)
	local path: { string | number } = { "Board", slot }
	context.Services.DataService:Set(player, path, keyId)
	Inventory.SetTag(context, player, slot, "")
end

return Inventory
