--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Eggs = require(ReplicatedStorage.Config.Eggs)
local NumberFormat = require(ReplicatedStorage.Utils.NumberFormat)

export type Handlers = {
	Key: (keyId: string, order: number) -> (),
	Toast: (text: string, kind: string) -> (),
	Pop: () -> (),
}

local AdminRewards = {}

AdminRewards.MaxReveals = 3

local function revealKeys(handlers: Handlers, ids: string, count: number)
	local shown = 0
	for keyId in string.gmatch(ids, "[^,]+") do
		if shown >= AdminRewards.MaxReveals then
			break
		end
		shown += 1
		handlers.Key(keyId, shown)
	end
	if count > shown then
		handlers.Toast(`+{count - shown} more`, "Info")
	end
end

function AdminRewards.Dispatch(handlers: Handlers, kind: string, id: string, count: number): boolean
	if kind == "Key" then
		revealKeys(handlers, id, count)
		return true
	end
	if kind == "Egg" then
		local egg = Eggs.ById[id]
		if not egg then
			return false
		end
		handlers.Pop()
		handlers.Toast(`+{count} {egg.Name} added to your backpack!`, "Good")
		return true
	end
	if kind == "Cash" then
		local amount = tonumber(id)
		if not amount or amount < 1 then
			return false
		end
		handlers.Pop()
		handlers.Toast(`+{NumberFormat.Compact(amount)} Clicks`, "Good")
		return true
	end
	return false
end

return AdminRewards
