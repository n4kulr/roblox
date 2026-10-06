--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Eggs = require(ReplicatedStorage.Config.Eggs)
local FloorGrid = require(ReplicatedStorage.Rules.FloorGrid)
local EggModel = require(ReplicatedStorage.Utils.EggModel)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

export type Ghost = {
	Folder: Folder,
	Model: Model?,
	Parts: { BasePart },
	EggId: string,
	Color: Color3?,
}

local Ghost = {}

function Ghost.new(folder: Folder): Ghost
	return { Folder = folder, Model = nil, Parts = {}, EggId = "", Color = nil }
end

function Ghost.Clear(self: Ghost)
	if self.Model then
		self.Model:Destroy()
	end
	self.Model = nil
	table.clear(self.Parts)
	self.EggId = ""
	self.Color = nil
end

local function ensure(self: Ghost, eggId: string): boolean
	if self.Model and self.EggId == eggId then
		return true
	end
	Ghost.Clear(self)
	local egg = Eggs.ById[eggId]
	if not egg then
		return false
	end
	local model = Instance.new("Model")
	model.Name = "EggGhost"
	local parts = EggModel.Build(model, egg, {
		Scale = EggModel.PlacedScale,
		Anchored = true,
		Ghost = Config.ValidColor,
	})
	model.PrimaryPart = parts[1]
	model.Parent = self.Folder
	self.Model = model
	self.Parts = parts
	self.EggId = eggId
	self.Color = Config.ValidColor
	return true
end

function Ghost.Show(
	self: Ghost,
	eggId: string,
	plot: Types.Plot,
	x: number,
	z: number,
	isValid: boolean
): boolean
	if not ensure(self, eggId) then
		return false
	end
	local color = if isValid then Config.ValidColor else Config.InvalidColor
	if color ~= self.Color then
		self.Color = color
		EggModel.Tint(self.Parts, color)
	end
	local height = EggModel.HeightOf(EggModel.PlacedScale)
	local floorY = plot.Base.Size.Y / 2 + FloorGrid.CapHeight
	local center = plot.Base.CFrame * CFrame.new(x, floorY + height / 2, z)
	local model = self.Model :: Model
	model:PivotTo(center * CFrame.new(EggModel.PivotOffset(EggModel.PlacedScale)))
	return true
end

return Ghost
