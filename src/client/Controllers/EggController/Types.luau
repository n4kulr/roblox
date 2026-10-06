--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EggPlacement = require(ReplicatedStorage.Utils.EggPlacement)

export type Plot = {
	Model: Model,
	Base: BasePart,
	RollKey: EggPlacement.Rect?,
}

return {}
