--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Keys = require(ReplicatedStorage.Config.Keys)
local Kit = require(script.Parent.Parent.Parent.UIController.Kit)
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

type View = Types.View
type ResultCards = Types.ResultCards
local cardHeight = Config.CardHeight
local bottomOffset = Config.BottomOffset
local gravity = Config.Gravity
local white = Config.White
local legendaryRank = Config.LegendaryRank
local goldColor = Kit.Theme.Gold
local slotAnchor = Config.SlotAnchor
local slotOffset = Config.SlotOffset

local Confetti = {}

function Confetti.Spawn(self: ResultCards, view: View, rarity: Keys.Rarity, rank: number)
	local count = if rank >= legendaryRank + 2 then 30 elseif rank >= legendaryRank + 1 then 24 else 18
	local palette =
		{ Kit.Shade(rarity.Color, 0.25), white, goldColor, Kit.Theme.Pink, Kit.Theme.Blue, Kit.Theme.Good }
	local originX = slotOffset[view.Slot] + (0.5 - slotAnchor[view.Slot]) * 2 * (view.Width / 2)
	local spawned = 0
	for _, piece in self._pieces do
		if spawned >= count then
			break
		end
		if not piece.Active then
			spawned += 1
			local angle = math.rad(-90 + (math.random() - 0.5) * 140)
			local speed = 380 + math.random() * 460
			piece.Active = true
			piece.X = originX + (math.random() - 0.5) * view.Width * 0.5
			piece.Y = -bottomOffset - cardHeight / 2
			piece.VX = math.cos(angle) * speed
			piece.VY = math.sin(angle) * speed
			piece.Rotation = math.random() * 360
			piece.Spin = (math.random() - 0.5) * 900
			piece.Age = 0
			piece.Life = 1.3 + math.random() * 0.6
			piece.Frame.BackgroundColor3 = palette[math.random(1, #palette)]
			piece.Frame.BackgroundTransparency = 0
			piece.Frame.Size = UDim2.fromOffset(math.random(8, 12), math.random(12, 18))
			piece.Frame.Visible = true
		end
	end
end

function Confetti.Step(self: ResultCards, dt: number)
	for _, piece in self._pieces do
		if piece.Active then
			piece.Age += dt
			if piece.Age >= piece.Life then
				piece.Active = false
				piece.Frame.Visible = false
			else
				piece.VY += gravity * dt
				piece.VX *= 1 - math.min(dt * 1.2, 1)
				piece.X += piece.VX * dt
				piece.Y += piece.VY * dt
				piece.Rotation += piece.Spin * dt
				local frame = piece.Frame
				frame.Position = UDim2.new(0.5, piece.X, 1, piece.Y)
				frame.Rotation = piece.Rotation
				local remaining = piece.Life - piece.Age
				frame.BackgroundTransparency = if remaining < 0.4 then 1 - remaining / 0.4 else 0
			end
		end
	end
end

return Confetti
