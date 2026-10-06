--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FloorGrid = require(ReplicatedStorage.Rules.FloorGrid)
local WorldNames = require(ReplicatedStorage.Config.WorldNames)
local Attributes = WorldNames.Attributes
local Parts = WorldNames.Parts

local Travel = {}

Travel.CarryAttribute = Attributes.CarryingKey
Travel.MarketDistance = 10
Travel.StandHeight = 3.5
Travel.CarryMessage = "Can't teleport while carrying a key!"
Travel.BaseMessage = "Your base isn't ready yet!"
Travel.MarketMessage = "The market isn't ready yet!"

local stallNames = { Parts.Market, Parts.MarketPlaceholder }

function Travel.IsCarrying(character: Instance?): boolean
	return character ~= nil and character:GetAttribute(Travel.CarryAttribute) ~= nil
end

function Travel.FindCounter(world: Instance): BasePart?
	for _, name in stallNames do
		local stall = world:FindFirstChild(name)
		local counter = if stall then stall:FindFirstChild(Parts.Counter, true) else nil
		if counter and counter:IsA("BasePart") then
			return counter
		end
	end
	return nil
end

function Travel.MarketSpot(counter: BasePart): CFrame
	local center = counter.Position
	local floorY = center.Y - counter.Size.Y / 2 + Travel.StandHeight
	local flatFront = Vector3.new(counter.CFrame.LookVector.X, 0, counter.CFrame.LookVector.Z)
	local direction = if flatFront.Magnitude > 0.001 then -flatFront.Unit else Vector3.new(0, 0, 1)
	local target = Vector3.new(center.X, floorY, center.Z)
	return CFrame.lookAt(target + direction * Travel.MarketDistance, target)
end

function Travel.ToBase(character: Model?, plot: Model?): (boolean, string?)
	if Travel.IsCarrying(character) then
		return false, Travel.CarryMessage
	end
	local base = if plot then plot:FindFirstChild(Parts.Base) else nil
	if not base or not base:IsA("BasePart") or not character then
		return false, Travel.BaseMessage
	end
	character:PivotTo(base.CFrame * CFrame.new(0, base.Size.Y / 2 + FloorGrid.CapHeight + 3, 0))
	return true, nil
end

function Travel.ToMarket(character: Model?, world: Instance): (boolean, string?)
	if Travel.IsCarrying(character) then
		return false, Travel.CarryMessage
	end
	local counter = Travel.FindCounter(world)
	if not counter or not character then
		return false, Travel.MarketMessage
	end
	character:PivotTo(Travel.MarketSpot(counter))
	return true, nil
end

return Travel
