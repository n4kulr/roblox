--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Packets = require(ReplicatedStorage.Packets)
local Codes = require(script.Parent.Parent.Config.Codes)
local Rewards = require(script.Parent.Parent.Utils.Rewards)
local ServerTypes = require(script.Parent.Parent.Types)

local CodeService = { Name = "CodeService" }
local services: ServerTypes.Registry = nil :: any

local maxLength = 32
local resultSuccess = 1
local resultInvalid = 2
local resultUsed = 3
local resultExpired = 4

local function normalize(text: any): string?
	if type(text) ~= "string" then
		return nil
	end
	local trimmed = string.match(text, "^%s*(.-)%s*$") :: string
	if #trimmed == 0 or #trimmed > maxLength or string.find(trimmed, "[^\32-\126]") then
		return nil
	end
	return string.upper(trimmed)
end

local function redeem(player: Player, text: string): number
	local code = normalize(text)
	if not code then
		return resultInvalid
	end
	local entry = Codes.ByCode[code]
	local data = services.DataService:GetData(player)
	if not entry or not data then
		return resultInvalid
	end
	if entry.ExpiresAt and os.time() >= entry.ExpiresAt then
		return resultExpired
	end
	if data.RedeemedCodes[code] then
		return resultUsed
	end
	if not Rewards.Grant(player, services, entry.Reward) then
		return resultInvalid
	end
	services.DataService:Set(player, { "RedeemedCodes", code }, true)
	services.DataService:RequestSave(player)
	return resultSuccess
end

function CodeService.Init(_self: any, registry: { [string]: any })
	services = registry :: any
end

function CodeService.Start(_self: any)
	Packets.RedeemCode.OnServerInvoke = redeem
end

function CodeService.Destroy(_self: any)
	Packets.RedeemCode.OnServerInvoke = nil
end

return CodeService
