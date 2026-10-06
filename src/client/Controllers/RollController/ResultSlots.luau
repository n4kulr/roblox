--!strict

export type Slot = "Center" | "Left" | "Right"

export type Action = {
	Kind: "Show" | "Fade",
	Slot: Slot,
	IsRare: boolean,
	Payload: any?,
	Fast: boolean?,
}

export type ResultSlots = {
	_endAt: number?,
	Push: (self: ResultSlots, payload: any, hold: number, now: number) -> { Action },
	Tick: (self: ResultSlots, now: number) -> { Action },
}

local ResultSlots = {}
ResultSlots.__index = ResultSlots

function ResultSlots.new(): ResultSlots
	return setmetatable({ _endAt = nil }, ResultSlots) :: any
end

function ResultSlots.Tick(self: ResultSlots, now: number): { Action }
	local out: { Action } = {}
	local endAt = self._endAt
	if endAt and now >= endAt then
		self._endAt = nil
		table.insert(out, { Kind = "Fade", Slot = "Center", IsRare = false })
	end
	return out
end

function ResultSlots.Push(self: ResultSlots, payload: any, hold: number, now: number): { Action }
	local out = ResultSlots.Tick(self, now)
	self._endAt = now + hold
	table.insert(out, { Kind = "Show", Slot = "Center", IsRare = false, Payload = payload })
	return out
end

return ResultSlots
