--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Keys = require(ReplicatedStorage.Config.Keys)
local Config = require(script.Parent.Parent.Parent.Parent.Config.Admin)
local Types = require(script.Parent.Parent.Types)
local Lookup = require(script.Parent.Lookup)
local Support = require(script.Parent.Support)

local dataOf = Support.DataOf
local reward = Support.Reward
local clampCount = Support.ClampCount
local noun = Support.Noun
local maxStack = Config.MaxStack
local maxRevealed = Config.MaxRevealed

local Items = {}

function Items.Register(builder: Types.Builder)
	local simple, withCount = builder.Simple, builder.WithCount

	withCount(
		"givekey",
		"givekey <keyId|rarity> [count] [player|all]",
		"Give a key by id, or a random key of a rarity",
		function(context, _admin, target, args, count)
			local services = context.Services
			local exact = Lookup.Key(args[1])
			local rarity = if exact then nil else Lookup.Rarity(args[1])
			local pool: { Keys.Key } = if rarity then Keys.ByRarity[rarity] else {}
			if not exact and #pool == 0 then
				return false, `Unknown key or rarity "{args[1]}"`
			end
			local random = Random.new()
			local given: { [string]: number } = {}
			local revealed: { string } = {}
			local total = 0
			for _ = 1, clampCount(count) do
				local key = exact or pool[random:NextInteger(1, #pool)]
				if services.KeyboardService:AddKey(target, key.Id) then
					given[key.Id] = (given[key.Id] or 0) + 1
					total += 1
					if #revealed < maxRevealed then
						table.insert(revealed, key.Id)
					end
				end
			end
			local data = dataOf(context, target)
			local names: { string } = {}
			for keyId, amount in given do
				if data then
					services.DataService:Set(
						target,
						{ "Discovered", keyId },
						(data.Discovered[keyId] or 0) + amount
					)
				end
				table.insert(names, `{amount}x {Keys.ById[keyId].Name}`)
			end
			if #names == 0 then
				return false, "No keys were given"
			end
			table.sort(names)
			services.DataService:RequestSave(target)
			reward(target, "Key", table.concat(revealed, ","), total)
			return true, `Gave {table.concat(names, ", ")}`
		end
	)

	withCount(
		"giveegg",
		"giveegg <eggId> [count] [player|all]",
		"Give eggs (the first is held, the rest queue up)",
		function(context, _admin, target, args, count)
			local egg = Lookup.Egg(args[1])
			if not egg then
				return false, `Unknown egg "{args[1]}"`
			end
			local data = dataOf(context, target)
			if not data then
				return false, "Data not loaded"
			end
			local added = 0
			for _ = 1, clampCount(count) do
				if context.Services.EggService:GrantEgg(target, egg.Id) then
					added += 1
				end
			end
			if added < 1 then
				return false, `Already holding the maximum {egg.Name}`
			end
			context.Services.DataService:RequestSave(target)
			reward(target, "Egg", egg.Id, added)
			return true, `Gave {added}x {egg.Name}`
		end
	)

	withCount(
		"givepet",
		"givepet <petId> [count] [player|all]",
		"Give pets",
		function(context, _admin, target, args, count)
			local pet = Lookup.Pet(args[1])
			if not pet then
				return false, `Unknown pet "{args[1]}"`
			end
			local data = dataOf(context, target)
			if not data then
				return false, "Data not loaded"
			end
			local have = data.Charms[pet.Id] or 0
			local added = math.min(clampCount(count), maxStack - have)
			if added < 1 then
				return false, `Already holding the maximum {pet.Name}`
			end
			context.Services.DataService:Set(target, { "Charms", pet.Id }, have + added)
			context.Services.EggService:Sync(target)
			context.Services.DataService:RequestSave(target)
			reward(target, "Pet", pet.Id, added)
			return true, `Gave {added}x {pet.Name}`
		end
	)

	simple("removepets", "removepets [player|all]", "Remove every pet", function(context, _admin, target)
		local services = context.Services
		local data = dataOf(context, target)
		if not data then
			return false, "Data not loaded"
		end
		local removed = 0
		for _, owned in data.Charms do
			removed += owned
		end
		services.DataService:Set(target, { "Charms" }, {})
		services.DataService:Set(target, { "EquippedCharms" }, {})
		services.EggService:Sync(target)
		services.DataService:RequestSave(target)
		return true, `Removed {noun(removed, "pet")}`
	end)

	simple("readyeggs", "readyeggs [player|all]", "Finish every placed egg", function(context, _admin, target)
		local count = context.Services.EggService:ReadyEggs(target)
		return true, `Readied {noun(count, "egg")}`
	end)

	simple("hatchall", "hatchall [player|all]", "Hatch every placed egg", function(context, _admin, target)
		local count = #context.Services.EggService:HatchAll(target)
		return true, `Hatched {noun(count, "egg")}`
	end)
end

return Items
