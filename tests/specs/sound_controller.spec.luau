local roblox = require("@lune/roblox")
local H = require("../harness/Harness")

local Vector3 = roblox.Vector3
local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

describe("SoundController", function()
	local world, controller, data, soundService, SwitchSounds, Keys

	local function pooled(): { any }
		return soundService:FindFirstChild("ThockSounds"):GetChildren()
	end

	local function playing(): { any }
		local out = {}
		local function visit(sound: any)
			if sound.IsPlaying then
				table.insert(out, sound)
			end
		end
		for _, sound in pooled() do
			visit(sound)
		end
		for _, attachment in world.workspace.Terrain:GetChildren() do
			for _, sound in attachment:GetChildren() do
				visit(sound)
			end
		end
		return out
	end

	local function revealRarity(): any
		for _, rarity in Keys.Rarities do
			if rarity.Reveal then
				return rarity
			end
		end
		return nil
	end

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
		Keys = world:require("ReplicatedStorage.Config.Keys")
		SwitchSounds = world:require("ReplicatedStorage.Config.SwitchSounds")
		soundService = world:newInstance("Folder")
		world.fakeServices.SoundService = soundService
		local terrain = world:newInstance("Part")
		terrain.Name = "Terrain"
		terrain.Parent = world.workspace
		H.installTweens(world)
		data = H.fakeDataController({ Settings = {} })
		controller = world:require("StarterPlayer.StarterPlayerScripts.Controllers.SoundController")
		controller:Init({ DataController = data })
		controller:Start()
		world:flush()
	end)

	afterEach(function()
		controller:Destroy()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	it("builds a pool of twenty voices", function()
		expect(#pooled()):toBe(20)
	end)

	it("plays a switch press from the sprite sheet", function()
		controller:PlaySwitch("MxBrown", "Press", 1, 1, nil, "Board")
		local active = playing()
		expect(#active):toBe(1)
		expect(active[1].SoundId):toBe(SwitchSounds.SpriteId)
		expect(active[1].PlaybackRegionsEnabled):toBe(true)
		expect(active[1].RollOffMaxDistance):toBe(0)
	end)

	it("places positional sounds on a voice attachment with a roll off distance", function()
		controller:PlaySwitch("MxBrown", "Press", 1, 1, Vector3.new(5, 0, 5), "Board")
		local sound = playing()[1]
		expect(sound.Parent.Name:sub(1, 5)):toBe("Voice")
		expect(sound.RollOffMaxDistance):toBe(60)
	end)

	it("ignores unknown switches", function()
		controller:PlaySwitch("NoSuchSwitch", "Press", 1, 1, nil, "Board")
		expect(#playing()):toBe(0)
	end)

	it("scales volume by the category setting and mutes at zero", function()
		controller:PlaySwitch("MxBrown", "Press", 1, 1, nil, "Roll")
		local full = playing()[1].Volume
		controller:Destroy()
		controller = world:require("StarterPlayer.StarterPlayerScripts.Controllers.SoundController")
		data:Set({ "Settings", "RollVolume" }, 0.5)
		controller:Init({ DataController = data })
		controller:Start()
		controller:PlaySwitch("MxBrown", "Press", 1, 1, nil, "Roll")
		local half
		for _, sound in playing() do
			if sound.Volume < full then
				half = sound.Volume
			end
		end
		expect(half ~= nil):toBe(true)
		expect(half):toBeCloseTo(full * 0.5, 1e-6)
		data:Set({ "Settings", "RollVolume" }, 0)
		local before = #playing()
		controller:PlaySwitch("MxBrown", "Press", 1, 1, nil, "Roll")
		expect(#playing()):toBe(before)
	end)

	it("clamps volume settings into zero to one", function()
		data:Set({ "Settings", "OtherVolume" }, 9)
		controller:PlaySwitch("MxBrown", "Press", 1, 1, nil, "Other")
		expect(playing()[1].Volume <= 1):toBe(true)
	end)

	it("refuses to start more than sixteen voices at once", function()
		for _ = 1, 20 do
			controller:PlaySwitch("MxBrown", "Press", 1, 1, nil, "Board")
		end
		expect(#playing()):toBe(16)
	end)

	it("reuses voices once they stop", function()
		for _ = 1, 16 do
			controller:PlaySwitch("MxBrown", "Press", 1, 1, nil, "Board")
		end
		playing()[1]:Stop()
		controller:PlaySwitch("MxBrown", "Press", 1, 1, nil, "Board")
		expect(#playing()):toBe(16)
	end)

	it("plays the confirm and error ui sounds and the click through the sprite sheet", function()
		controller:PlayUi("Confirm")
		controller:PlayUi("Error")
		controller:PlayUi("Click")
		controller:PlayUi("Nope")
		expect(#playing()):toBe(3)
	end)

	it("plays every layer of a reveal and nothing for rarities without one", function()
		local rarity = revealRarity()
		expect(rarity ~= nil):toBe(true)
		controller:PlayReveal(rarity, "Roll")
		local immediate = 0
		local delayed = 0
		for _, layer in rarity.Reveal.Layers do
			if layer.Delay and layer.Delay > 0 then
				delayed += 1
			else
				immediate += 1
			end
		end
		expect(#playing()):toBe(immediate)
		world:advance(10)
		expect(#playing()):toBe(immediate + delayed)
		local before = #playing()
		controller:PlayReveal({ Name = "None" }, "Roll")
		expect(#playing()):toBe(before)
	end)

	it("swells a looped voice that stops when the tween ends", function()
		local rarity = revealRarity()
		controller:PlaySwell(rarity, 1, "Roll")
		world:flush()
		expect(#playing()):toBe(0)
	end)

	it("resets volumes and empties the pool on destroy", function()
		controller:Destroy()
		controller:PlaySwitch("MxBrown", "Press", 1, 1, nil, "Board")
		expect(#world.workspace.Terrain:GetChildren()):toBe(0)
		expect(soundService:FindFirstChild("ThockSounds")):toBeNil()
	end)
end)
