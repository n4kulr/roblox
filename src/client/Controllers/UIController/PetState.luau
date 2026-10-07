--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharmConfig = require(ReplicatedStorage.Config.Charms)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Types = require(script.Parent.Types)

type TroveInstance = typeof(Trove.new())

export type State = Types.PetState

local PetState = {}

function PetState.Track(dataController: any, trove: TroveInstance): State
	local owned: { [string]: number } = {}
	local total = 0
	local isLoaded = false
	local listeners: { [number]: () -> () } = {}
	local nextId = 0

	trove:Add(dataController:Observe({ "Charms" }, function(value: any)
		local copy: { [string]: number } = {}
		local sum = 0
		if type(value) == "table" then
			isLoaded = true
			for id, count in value do
				if
					type(id) == "string"
					and CharmConfig.ById[id]
					and type(count) == "number"
					and count > 0
				then
					local whole = math.floor(count)
					copy[id] = whole
					sum += whole
				end
			end
		end
		owned = copy
		total = sum
		for _, listener in listeners do
			listener()
		end
	end))

	return {
		Owned = function()
			return owned
		end,
		Total = function()
			return total
		end,
		IsLoaded = function()
			return isLoaded
		end,
		Subscribe = function(listener: () -> ()): () -> ()
			nextId += 1
			local id = nextId
			listeners[id] = listener
			return function()
				listeners[id] = nil
			end
		end,
	}
end

function PetState.For(context: Types.Context, trove: TroveInstance): State
	local shared = context.Pets
	if shared then
		return shared
	end
	return PetState.Track(context.Controllers.DataController, trove)
end

return PetState
