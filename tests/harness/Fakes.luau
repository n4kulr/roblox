local roblox = require("@lune/roblox")

local Fakes = {}

function Fakes.press(button: any)
	button.Activated:Fire({ UserInputType = roblox.Enum.UserInputType.MouseButton1 })
end

function Fakes.installTweens(world: any): { any }
	local Signal = world:require("ReplicatedStorage.Packages.Signal")
	local log: { any } = {}
	world.fakeServices.TweenService = {
		Create = function(_self: any, target: any, info: any, goal: { [string]: any })
			local tween: any = {
				Completed = Signal.new(),
				Cancelled = false,
				Played = false,
				Target = target,
				Goal = goal,
				Seconds = info[1],
				Style = info[2],
				Direction = info[3],
			}
			table.insert(log, tween)
			function tween.Play()
				tween.Played = true
				for key, value in goal do
					pcall(function()
						target[key] = value
					end)
				end
				world.task.defer(function()
					tween.Completed:Fire()
				end)
			end
			function tween.Pause() end
			function tween.Cancel()
				tween.Cancelled = true
			end
			function tween.Destroy() end
			return tween
		end,
	}
	return log
end

local function readPath(values: any, path: { any }): any
	local value = values
	for _, key in path do
		if type(value) ~= "table" then
			return nil
		end
		value = value[key]
	end
	return value
end

local function overlaps(changed: { any }, path: { any }): boolean
	for index = 1, math.min(#changed, #path) do
		if changed[index] ~= path[index] then
			return false
		end
	end
	return true
end

function Fakes.fakeDataController(values: { [string]: any }?)
	local controller: any = { Values = values or {}, Observers = {}, Loaded = true }

	function controller.IsLoaded(_self: any)
		return controller.Loaded
	end

	function controller.Get(_self: any, path: { any }?)
		if path == nil then
			return controller.Values
		end
		return readPath(controller.Values, path)
	end

	function controller.Observe(_self: any, path: { any }, callback: (value: any) -> ())
		local observer = { Path = path, Callback = callback, Active = true }
		table.insert(controller.Observers, observer)
		callback(readPath(controller.Values, path))
		return {
			Disconnect = function()
				observer.Active = false
			end,
		}
	end

	function controller.Set(_self: any, path: { any }, value: any)
		local target = controller.Values
		for index = 1, #path - 1 do
			local key = path[index]
			if type(target[key]) ~= "table" then
				target[key] = {}
			end
			target = target[key]
		end
		target[path[#path]] = value
		for _, observer in table.clone(controller.Observers) do
			if observer.Active and overlaps(path, observer.Path) then
				observer.Callback(readPath(controller.Values, observer.Path))
			end
		end
	end

	function controller.Active(_self: any, path: { any }): number
		local count = 0
		for _, observer in controller.Observers do
			if observer.Active and #observer.Path == #path and overlaps(observer.Path, path) then
				count += 1
			end
		end
		return count
	end

	return controller
end

function Fakes.fakeSound()
	local sound: any = { Calls = {}, Switches = {} }
	setmetatable(sound, {
		__index = function(_t, name: string)
			return function(_self: any, ...)
				table.insert(sound.Calls, { Method = name, Args = table.pack(...) })
				if name == "PlaySwitch" then
					local switchId, kind, speed, volume, position, category = ...
					table.insert(sound.Switches, {
						Switch = switchId,
						Kind = kind,
						Speed = speed,
						Volume = volume,
						Position = position,
						Category = category,
					})
				end
			end
		end,
	})
	function sound.CountOf(_self: any, method: string): number
		local count = 0
		for _, call in sound.Calls do
			if call.Method == method then
				count += 1
			end
		end
		return count
	end
	return sound
end

return Fakes
