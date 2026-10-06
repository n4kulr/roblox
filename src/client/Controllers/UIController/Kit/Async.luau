--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)

type TroveInstance = typeof(Trove.new())

export type Guard = {
	IsBusy: () -> boolean,
	Run: (call: () -> any, onDone: ((isOk: boolean, result: any) -> ())?) -> boolean,
}

export type Confirm = {
	IsArmed: () -> boolean,
	Press: (needsConfirm: boolean, action: () -> ()) -> boolean,
	Reset: () -> (),
}

local Async = {}

function Async.Later(trove: TroveInstance, seconds: number, step: () -> ())
	local isFinished = false
	local thread: thread? = nil
	local cleaner = function()
		isFinished = true
		local pending = thread
		if pending then
			task.cancel(pending)
		end
	end
	trove:Add(cleaner)
	thread = task.delay(seconds, function()
		if isFinished then
			return
		end
		isFinished = true
		trove:Pop(cleaner)
		step()
	end)
end

function Async.Request(trove: TroveInstance): Guard
	local isBusy = false
	local isDestroyed = false
	trove:Add(function()
		isDestroyed = true
	end)
	return {
		IsBusy = function()
			return isBusy
		end,
		Run = function(call: () -> any, onDone: ((isOk: boolean, result: any) -> ())?): boolean
			if isBusy or isDestroyed then
				return false
			end
			isBusy = true
			task.spawn(function()
				local isOk, result = pcall(call)
				isBusy = false
				if isDestroyed then
					return
				end
				if not isOk then
					warn(`[UIController] request failed: {tostring(result)}`)
				end
				if onDone then
					onDone(isOk, result)
				end
			end)
			return true
		end,
	}
end

function Async.Confirm(trove: TroveInstance, seconds: number, onChange: (isArmed: boolean) -> ()): Confirm
	local isArmed = false
	local stamp = 0
	return {
		IsArmed = function()
			return isArmed
		end,
		Press = function(needsConfirm: boolean, action: () -> ()): boolean
			if needsConfirm and not isArmed then
				isArmed = true
				stamp += 1
				local mine = stamp
				onChange(true)
				Async.Later(trove, seconds, function()
					if isArmed and stamp == mine then
						isArmed = false
						onChange(false)
					end
				end)
				return false
			end
			isArmed = false
			stamp += 1
			action()
			return true
		end,
		Reset = function()
			isArmed = false
			stamp += 1
		end,
	}
end

return Async
