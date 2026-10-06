local H = require("../harness/Harness")

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

describe("MusicController", function()
	local world, music, Music, Signal, soundService, tweens, observer, volumeObserver

	local function track(name: string, id: string)
		return { Name = name, SoundId = id }
	end

	local function setup(playlist: { any }, startVolume: number?)
		world = H.newWorld()
		Signal = world:require("ReplicatedStorage.Packages.Signal")
		local original = world:require("ReplicatedStorage.Config.Music")
		Music = H.deepCopy(original)
		Music.Playlist = playlist
		world.overrides[world:node("ReplicatedStorage.Config.Music")] = Music
		soundService = world:newInstance("Folder")
		world.fakeServices.SoundService = soundService
		tweens = H.installTweens(world)
		volumeObserver = nil
		local dataController = {
			Observe = function(_self: any, _path: any, callback: any)
				observer = callback
				callback(startVolume or 0.5)
				return function() end
			end,
		}
		music = world:require("StarterPlayer.StarterPlayerScripts.Controllers.MusicController")
		music:Init({ DataController = dataController })
		music:Start()
		table.insert(world.started, music)
	end

	afterEach(function()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	local function folder(): any
		return soundService:FindFirstChild("Music")
	end

	local function sounds(): { any }
		return folder():GetChildren()
	end

	local function play(sound: any, length: number, position: number)
		sound.TimeLength = length
		sound.TimePosition = position
	end

	it("does nothing and never errors when every id is empty", function()
		setup({ track("A", ""), track("B", "") })
		world.task.wait(5)
		expect(#sounds()):toBe(0)
		expect(music:GetCurrentName()):toBeNil()
		observer(0.2)
		music:SetDucked(true)
		world.task.wait(2)
		expect(#sounds()):toBe(0)
	end)

	it("skips empty ids and plays each remaining track once per shuffle", function()
		setup({ track("A", "rbxassetid://1"), track("B", ""), track("C", "rbxassetid://3") })
		local seen = {}
		for _ = 1, 2 do
			local sound = sounds()[#sounds()]
			table.insert(seen, sound.Name)
			expect(sound.SoundId ~= ""):toBe(true)
			expect(sound.Looped):toBe(false)
			play(sound, 100, 99)
			world.task.wait(0.3)
		end
		table.sort(seen)
		expect(seen):toEqual({ "A", "C" })
	end)

	it("reshuffles after a full pass without repeating back to back", function()
		setup({ track("A", "rbxassetid://1"), track("B", "rbxassetid://2") })
		local order = {}
		for _ = 1, 8 do
			local name = music:GetCurrentName()
			table.insert(order, name)
			for _, sound in sounds() do
				if sound.Name == name then
					play(sound, 100, 99)
				end
			end
			world.task.wait(0.3)
		end
		for index = 2, #order do
			expect(order[index] ~= order[index - 1]):toBe(true)
		end
	end)

	it("starts at base volume times the setting and fades in", function()
		setup({ track("A", "rbxassetid://1") }, 0.5)
		local sound = sounds()[1]
		expect(sound.Plays):toBe(1)
		expect(sound.Volume):toBeCloseTo(Music.BaseVolume * 0.5, 1e-9)
		expect(tweens[1].Goal.Volume):toBeCloseTo(0.175, 1e-9)
	end)

	it("crossfades over two seconds near the end of a track", function()
		setup({ track("A", "rbxassetid://1"), track("B", "rbxassetid://2") })
		local first = sounds()[1]
		world.task.wait(1)
		expect(#sounds()):toBe(1)
		play(first, 100, 97)
		world.task.wait(0.3)
		expect(#sounds()):toBe(1)
		play(first, 100, 98.5)
		local before = #tweens
		world.task.wait(0.3)
		expect(#tweens):toBe(before + 2)
		local incoming, outgoing = tweens[before + 1], tweens[before + 2]
		expect(incoming.Seconds):toBe(2)
		expect(outgoing.Seconds):toBe(2)
		expect(outgoing.Target):toBe(first)
		expect(outgoing.Goal.Volume):toBe(0)
		expect(incoming.Target ~= first):toBe(true)
		expect(incoming.Goal.Volume):toBeCloseTo(Music.BaseVolume * 0.5, 1e-9)
		world.task.wait(0.1)
		expect(#sounds()):toBe(1)
		expect(sounds()[1]):toBe(incoming.Target)
	end)

	it("skips a track that never loads", function()
		setup({ track("A", "rbxassetid://1"), track("B", "rbxassetid://2") })
		local first = music:GetCurrentName()
		world.task.wait(Music.LoadTimeoutSeconds + 1)
		expect(music:GetCurrentName() ~= first):toBe(true)
	end)

	it("follows the MusicVolume setting live", function()
		setup({ track("A", "rbxassetid://1") }, 0.5)
		local sound = sounds()[1]
		observer(1)
		expect(sound.Volume):toBeCloseTo(0.35, 1e-9)
		observer(0.2)
		expect(sound.Volume):toBeCloseTo(0.07, 1e-9)
	end)

	it("pauses at zero volume, does not start tracks, and resumes", function()
		setup({ track("A", "rbxassetid://1") }, 0)
		expect(#sounds()):toBe(0)
		world.task.wait(3)
		expect(#sounds()):toBe(0)
		observer(0.6)
		local sound = sounds()[1]
		expect(sound.Plays):toBe(1)
		observer(0)
		expect(sound.Pauses):toBe(1)
		play(sound, 100, 99.9)
		world.task.wait(1)
		expect(#sounds()):toBe(1)
		observer(0.6)
		expect(sound.Resumes):toBe(1)
	end)

	it("ducks to thirty percent and restores", function()
		setup({ track("A", "rbxassetid://1") }, 1)
		local sound = sounds()[1]
		music:SetDucked(true)
		expect(sound.Volume):toBeCloseTo(Music.BaseVolume * 0.3, 1e-9)
		music:SetDucked(false)
		expect(sound.Volume):toBeCloseTo(Music.BaseVolume, 1e-9)
	end)

	it("cleans up its sounds and loop on destroy", function()
		setup({ track("A", "rbxassetid://1") })
		music:Destroy()
		expect(soundService:FindFirstChild("Music")):toBeNil()
		world.task.wait(3)
		expect(music:GetCurrentName()):toBeNil()
	end)
end)
