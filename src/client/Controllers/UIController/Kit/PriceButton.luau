--!strict
local Buttons = require(script.Parent.Buttons)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local Sound = require(script.Parent.Sound)

type TroveInstance = typeof(Trove.new())

export type PriceGate = {
	CanAfford: (() -> boolean)?,
	DeniedText: string?,
	Toast: ((text: string, kind: string?) -> ())?,
}

local PriceButton = {}

function PriceButton.new(trove: TroveInstance, props: Buttons.ButtonProps, gate: PriceGate): Buttons.Button
	local callback = props.Callback
	local copy = table.clone(props)
	copy.Callback = function()
		local canAfford = gate.CanAfford
		if canAfford and not canAfford() then
			Sound.Play(Sound.Error)
			local toast = gate.Toast
			if toast and gate.DeniedText then
				toast(gate.DeniedText, "Bad")
			end
			return
		end
		if callback then
			callback()
		end
	end
	return Buttons.Button(trove, copy)
end

return PriceButton
