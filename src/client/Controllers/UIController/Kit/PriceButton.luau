--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local Controls = require(script.Parent.Controls)
local Sound = require(script.Parent.Sound)

type TroveInstance = typeof(Trove.new())

export type PriceGate = {
	CanAfford: (() -> boolean)?,
	DeniedText: string?,
	Toast: ((text: string, kind: string?) -> ())?,
}

local PriceButton = {}

function PriceButton.new(trove: TroveInstance, props: Controls.ButtonProps, gate: PriceGate): Controls.Button
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
	return Controls.Button(trove, copy)
end

return PriceButton
