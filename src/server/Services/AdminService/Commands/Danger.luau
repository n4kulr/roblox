--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local PlayerData = require(script.Parent.Parent.Parent.Parent.Data.PlayerData)
local Types = require(script.Parent.Parent.Types)
local Support = require(script.Parent.Support)

local dataOf = Support.DataOf
local normalize = Support.Normalize
local protectedFields: { [string]: boolean } = { SchemaVersion = true, Receipts = true, LastSeenAt = true }

local Danger = {}

function Danger.Register(builder: Types.Builder)
	builder.Define({
		Name = "resetdata",
		Usage = "resetdata confirm [player]",
		Summary = "Wipe all data to the template",
		Positional = 1,
		OptionalCount = false,
		AllowAll = false,
		Run = function(context, _admin, target, args)
			if string.lower(args[1]) ~= "confirm" then
				return false, "Type resetdata confirm to wipe data"
			end
			local services = context.Services
			if not dataOf(context, target) then
				return false, "Data not loaded"
			end
			for field, value in PlayerData.Template :: any do
				if not protectedFields[field] then
					services.DataService:Set(
						target,
						{ field },
						if type(value) == "table" then TableUtil.Copy(value, true) else value
					)
				end
			end
			services.DataService:Set(target, { "IncomeAt" }, os.time())
			normalize(context, target)
			services.EggService:Sync(target)
			services.DataService:RequestSave(target)
			return true, "Data reset"
		end,
	})
end

return Danger
