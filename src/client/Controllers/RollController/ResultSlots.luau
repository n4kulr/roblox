--!strict

export type Slot = "Center" | "Left" | "Right"

export type Action = {
	Kind: "Show" | "Slide" | "Fade" | "Hide",
	Slot: Slot,
	IsRare: boolean,
	Payload: any?,
	Fast: boolean?,
}

type Phase = "Pause" | "Slide" | "Left" | "Fading"

type Pinned = {
	Phase: Phase,
	SlideAt: number,
	SettleAt: number,
	EndAt: number,
	ReleaseAt: number,
}

type Queued = {
	Payload: any,
	Hold: number,
}

export type Options = {
	PauseSeconds: number?,
	SlideSeconds: number?,
	FadeSeconds: number?,
}

export type ResultSlots = {
	_pauseSeconds: number,
	_slideSeconds: number,
	_fadeSeconds: number,
	_pinned: Pinned?,
	_commonEndAt: number?,
	_commonSlot: Slot,
	_queued: Queued?,
	Push: (
		self: ResultSlots,
		payload: any,
		isRare: boolean,
		hold: number,
		now: number,
		isLowGraphics: boolean
	) -> { Action },
	Tick: (self: ResultSlots, now: number) -> { Action },
	HasPinned: (self: ResultSlots) -> boolean,
}

local ResultSlots = {}
ResultSlots.__index = ResultSlots

function ResultSlots.new(options: Options?): ResultSlots
	local settings: Options = options or {}
	return setmetatable({
		_pauseSeconds = settings.PauseSeconds or 1,
		_slideSeconds = settings.SlideSeconds or 0.3,
		_fadeSeconds = settings.FadeSeconds or 0.25,
		_pinned = nil,
		_commonEndAt = nil,
		_commonSlot = "Center",
		_queued = nil,
	}, ResultSlots) :: any
end

local function advance(self: ResultSlots, now: number, out: { Action })
	local commonEndAt = self._commonEndAt
	if commonEndAt and now >= commonEndAt then
		table.insert(out, { Kind = "Fade", Slot = self._commonSlot, IsRare = false })
		self._commonEndAt = nil
	end
	local changed = true
	while changed do
		changed = false
		local pinned = self._pinned
		if not pinned then
			break
		end
		if pinned.Phase == "Pause" and now >= pinned.SlideAt then
			pinned.Phase = "Slide"
			table.insert(out, { Kind = "Slide", Slot = "Left", IsRare = true })
			changed = true
		elseif pinned.Phase == "Slide" and now >= pinned.SettleAt then
			pinned.Phase = "Left"
			local queued = self._queued
			if queued then
				self._queued = nil
				self._commonSlot = "Right"
				self._commonEndAt = now + queued.Hold
				table.insert(out, { Kind = "Show", Slot = "Right", IsRare = false, Payload = queued.Payload })
			end
			changed = true
		elseif pinned.Phase == "Left" and now >= pinned.EndAt then
			pinned.Phase = "Fading"
			pinned.ReleaseAt = pinned.EndAt + self._fadeSeconds
			table.insert(out, { Kind = "Fade", Slot = "Left", IsRare = true })
			changed = true
		elseif pinned.Phase == "Fading" and now >= pinned.ReleaseAt then
			self._pinned = nil
			changed = true
		end
	end
end

function ResultSlots.Tick(self: ResultSlots, now: number): { Action }
	local out: { Action } = {}
	advance(self, now, out)
	return out
end

function ResultSlots.HasPinned(self: ResultSlots): boolean
	return self._pinned ~= nil
end

function ResultSlots.Push(
	self: ResultSlots,
	payload: any,
	isRare: boolean,
	hold: number,
	now: number,
	isLowGraphics: boolean
): { Action }
	local out: { Action } = {}
	advance(self, now, out)
	local pinned = self._pinned
	if isRare then
		if pinned and pinned.Phase ~= "Fading" then
			local slot: Slot = if pinned.Phase == "Left" then "Left" else "Center"
			table.insert(out, { Kind = "Fade", Slot = slot, IsRare = true, Fast = true })
		end
		if self._commonEndAt then
			table.insert(out, { Kind = "Hide", Slot = self._commonSlot, IsRare = false })
			self._commonEndAt = nil
		end
		self._queued = nil
		if isLowGraphics then
			self._pinned = {
				Phase = "Left",
				SlideAt = now,
				SettleAt = now,
				EndAt = now + hold,
				ReleaseAt = now,
			}
			table.insert(out, { Kind = "Show", Slot = "Left", IsRare = true, Payload = payload })
		else
			local slideAt = now + self._pauseSeconds
			local settleAt = slideAt + self._slideSeconds
			self._pinned = {
				Phase = "Pause",
				SlideAt = slideAt,
				SettleAt = settleAt,
				EndAt = settleAt + hold,
				ReleaseAt = settleAt + hold,
			}
			table.insert(out, { Kind = "Show", Slot = "Center", IsRare = true, Payload = payload })
		end
		return out
	end
	if pinned and (pinned.Phase == "Pause" or pinned.Phase == "Slide") then
		self._queued = { Payload = payload, Hold = hold }
		return out
	end
	local slot: Slot = if pinned then "Right" else "Center"
	self._commonSlot = slot
	self._commonEndAt = now + hold
	table.insert(out, { Kind = "Show", Slot = slot, IsRare = false, Payload = payload })
	return out
end

return ResultSlots
