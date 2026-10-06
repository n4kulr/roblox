--!strict

export type Player = (name: string) -> ()

local current: Player? = nil

local Sound = {
	Click = "Click",
	Confirm = "Confirm",
	Error = "Error",
}

function Sound.Set(player: Player?)
	current = player
end

function Sound.Play(name: string)
	local player = current
	if player then
		player(name)
	end
end

function Sound.Resolve(override: Player?, isSilent: boolean?): Player?
	if isSilent == true then
		return nil
	end
	return override or Sound.Play
end

return Sound
