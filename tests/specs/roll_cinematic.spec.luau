local H = require("../harness/Harness")
local roblox = require("@lune/roblox")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

local controllerPath = "StarterPlayer.StarterPlayerScripts.Controllers.RollController"
local screensPath = "StarterPlayer.StarterPlayerScripts.Controllers.UIController.Screens"

describe("Roll cinematic", function()
	local world, Keys, Trove, Cinematic, Tiers, playerGui, trove, isLow, controllers, log, humanoid

	local function payload(rarityName: string): any
		local pick = Keys.ByRarity[rarityName][1]
		return { Key = pick, Rarity = Keys.GetRarity(pick), IsGolden = false }
	end

	local function build()
		trove = Trove.new()
		return Cinematic.new(playerGui, trove, function()
			return isLow
		end, function()
			return controllers
		end)
	end

	local function run(cine: any, seconds: number)
		local steps = math.ceil(seconds / 0.05)
		for _ = 1, steps do
			cine:Step(0.05)
		end
	end

	local function tapAnywhere()
		world.fakeServices.UserInputService.InputBegan:Fire({ UserInputType = roblox.Enum.UserInputType.MouseButton1 })
	end

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
		Keys = world:require("ReplicatedStorage.Config.Keys")
		Trove = world:require("ReplicatedStorage.Packages.Trove")
		Cinematic = world:require(`{controllerPath}.Cinematic`)
		Tiers = world:require(`{controllerPath}.Tiers`)
		playerGui = world:newInstance("Folder")
		isLow = false
		log = { Swell = 0, Reveal = 0, Duck = {} }
		controllers = {
			SoundController = {
				PlaySwell = function()
					log.Swell += 1
				end,
				PlayReveal = function()
					log.Reveal += 1
				end,
			},
			MusicController = {
				SetDucked = function(_self: any, isDucked: boolean)
					table.insert(log.Duck, isDucked)
				end,
			},
		}
		humanoid = { CameraOffset = roblox.Vector3.zero }
		local player = world:newPlayer({ Name = "You", DisplayName = "You" })
		player.Character = {
			FindFirstChildOfClass = function(_self: any, className: string)
				return if className == "Humanoid" then humanoid else nil
			end,
		}
		world.Players.LocalPlayer = player
	end)

	describe("threshold", function()
		it("plays exactly the ranks at or above each setting value", function()
			for _, setting in { 8, 6, 5, 4, 1 } do
				for rank = 1, 7 do
					local expected = setting <= 7 and rank >= setting
					expect(Tiers.ShouldPlay(rank, setting)):toBe(expected)
				end
			end
		end)

		it("maps the rarity order to the setting numbers", function()
			expect(Tiers.RankOf(Keys.RarityByName.Common)):toBe(1)
			expect(Tiers.RankOf(Keys.RarityByName.Legendary)):toBe(5)
			expect(Tiers.RankOf(Keys.RarityByName.Mythic)):toBe(6)
			expect(Tiers.RankOf(Keys.RarityByName.Secret)):toBe(7)
			expect(Tiers.OffRank):toBe(8)
		end)

		it("clamps odd setting values to a valid number", function()
			expect(Tiers.Clamp(nil)):toBe(5)
			expect(Tiers.Clamp(0)):toBe(1)
			expect(Tiers.Clamp(99)):toBe(8)
			expect(Tiers.Clamp(5.7)):toBe(5)
		end)

		it("picks a tier per rarity", function()
			expect(Tiers.For(1).Name):toBe("Mini")
			expect(Tiers.For(3).Name):toBe("Mini")
			expect(Tiers.For(4).Name):toBe("Epic")
			expect(Tiers.For(5).Name):toBe("Legendary")
			expect(Tiers.For(6).Name):toBe("Mythic")
			expect(Tiers.For(7).Name):toBe("Secret")
		end)
	end)

	describe("timing", function()
		it("runs each tier for its duration and then calls back once", function()
			local cases = {
				{ "Rare", 0.8 },
				{ "Epic", 1.2 },
				{ "Legendary", 2.2 },
				{ "Mythic", 3.2 },
				{ "Secret", 4 },
			}
			for _, case in cases do
				local cine = build()
				local done = 0
				expect(cine:Play(payload(case[1]), function()
					done += 1
				end)):toBe(true)
				expect(cine:IsPlaying()):toBe(true)
				run(cine, case[2] - 0.1)
				expect(done):toBe(0)
				run(cine, 0.3)
				expect(done):toBe(1)
				expect(cine:IsPlaying()):toBe(false)
				run(cine, 1)
				expect(done):toBe(1)
				trove:Destroy()
			end
		end)

		it("plays the build-up swell only for mythic and secret and the reveal once", function()
			local cine = build()
			cine:Play(payload("Legendary"))
			run(cine, 2.4)
			expect(log.Swell):toBe(0)
			expect(log.Reveal):toBe(1)
			cine:Play(payload("Mythic"))
			run(cine, 3.4)
			expect(log.Swell):toBe(1)
			expect(log.Reveal):toBe(2)
			cine:Play(payload("Secret"))
			run(cine, 4.2)
			expect(log.Swell):toBe(2)
			expect(log.Reveal):toBe(3)
		end)

		it("renders a chosen phase of each cinematic", function()
			local cine = build()
			cine:Play(payload("Mythic"))
			cine:Seek(2.2)
			expect(cine:Elapsed()):toBe(2.2)
			expect(cine:TierName()):toBe("Mythic")
			local gui = playerGui:FindFirstChild("RollCinematic")
			expect(gui.Enabled):toBe(true)
			expect(gui.IgnoreGuiInset):toBe(true)
			expect(gui:FindFirstChild("Title", true).Text):toBe("MYTHIC!!")
			expect(cine:VisibleParticles()):toBeGreaterThan(0)
		end)
	end)

	describe("skip", function()
		it("ignores taps in the first half second then jumps to the end", function()
			local cine = build()
			local done = 0
			cine:Play(payload("Legendary"), function()
				done += 1
			end)
			run(cine, 0.3)
			tapAnywhere()
			expect(cine:IsPlaying()):toBe(true)
			expect(done):toBe(0)
			run(cine, 0.3)
			tapAnywhere()
			expect(cine:IsPlaying()):toBe(false)
			expect(done):toBe(1)
			tapAnywhere()
			expect(done):toBe(1)
		end)
	end)

	describe("queueing under auto-roll", function()
		it("keeps one queued cinematic and refuses the rest", function()
			local cine = build()
			local order = {}
			expect(cine:CanAccept()):toBe(true)
			expect(cine:Play(payload("Legendary"), function()
				table.insert(order, "first")
			end)):toBe(true)
			expect(cine:Play(payload("Mythic"), function()
				table.insert(order, "second")
			end)):toBe(true)
			expect(cine:QueuedCount()):toBe(1)
			expect(cine:CanAccept()):toBe(false)
			expect(cine:Play(payload("Secret"), function()
				table.insert(order, "third")
			end)):toBe(false)
			run(cine, 2.4)
			expect(order):toEqual({ "first" })
			expect(cine:IsPlaying()):toBe(true)
			expect(cine:TierName()):toBe("Mythic")
			expect(cine:QueuedCount()):toBe(0)
			expect(cine:CanAccept()):toBe(true)
			run(cine, 3.4)
			expect(order):toEqual({ "first", "second" })
			expect(cine:IsPlaying()):toBe(false)
		end)

		it("starts the queued one when the first is skipped", function()
			local cine = build()
			cine:Play(payload("Legendary"))
			cine:Play(payload("Epic"))
			run(cine, 0.6)
			tapAnywhere()
			expect(cine:TierName()):toBe("Epic")
			expect(cine:Elapsed()):toBe(0)
			expect(cine:QueuedCount()):toBe(0)
		end)
	end)

	describe("low graphics", function()
		it("uses fewer particles and never shakes", function()
			local function peak(low: boolean): (number, any)
				isLow = low
				local cine = build()
				cine:Play(payload("Mythic"))
				local most = 0
				local shaken = false
				for _ = 1, 60 do
					cine:Step(0.05)
					most = math.max(most, cine:VisibleParticles())
					local world3 = playerGui:FindFirstChild("RollCinematic"):FindFirstChild("World")
					if world3 and (world3.Position.X.Offset ~= 0 or world3.Position.Y.Offset ~= 0) then
						shaken = true
					end
					if humanoid.CameraOffset ~= roblox.Vector3.zero then
						shaken = true
					end
				end
				trove:Destroy()
				return most, shaken
			end
			local normal, normalShake = peak(false)
			local low, lowShake = peak(true)
			expect(low):toBeLessThan(normal)
			expect(low):toBeGreaterThan(0)
			expect(normalShake):toBe(true)
			expect(lowShake):toBe(false)
		end)
	end)

	describe("cleanup", function()
		it("restores the camera offset and unducks music when finished", function()
			local cine = build()
			cine:Play(payload("Mythic"))
			cine:Seek(1.6)
			cine:Step(0.01)
			run(cine, 3.5)
			expect(humanoid.CameraOffset == roblox.Vector3.zero):toBe(true)
			expect(log.Duck):toEqual({ true, false })
		end)

		it("restores and unducks when destroyed mid-play", function()
			local cine = build()
			cine:Play(payload("Secret"))
			run(cine, 2.1)
			trove:Destroy()
			expect(humanoid.CameraOffset == roblox.Vector3.zero):toBe(true)
			expect(log.Duck):toEqual({ true, false })
			expect(playerGui:FindFirstChild("RollCinematic")):toBeNil()
			expect(cine:Play(payload("Legendary"))):toBe(false)
			cine:Step(0.1)
		end)

		it("survives a missing music controller", function()
			controllers.MusicController = nil
			local cine = build()
			cine:Play(payload("Legendary"))
			run(cine, 2.4)
			expect(cine:IsPlaying()):toBe(false)
		end)

		it("creates no new instances across 20 rapid rolls", function()
			local cine = build()
			local function count()
				local total = 0
				for _, item in playerGui:GetDescendants() do
					local ancestor = item.Parent
					local inside = false
					while ancestor and ancestor ~= playerGui do
						if ancestor.ClassName == "ViewportFrame" then
							inside = true
						end
						ancestor = ancestor.Parent
					end
					if not inside then
						total += 1
					end
				end
				return total
			end
			cine:Play(payload("Epic"))
			local baseline = count()
			local names = { "Legendary", "Mythic", "Secret", "Epic", "Rare" }
			for index = 1, 20 do
				cine:Play(payload(names[index % #names + 1]))
				run(cine, 0.2)
				tapAnywhere()
				run(cine, 0.4)
				tapAnywhere()
				expect(count()):toBe(baseline)
			end
			cine:Step(10)
			expect(count()):toBe(baseline)
			trove:Destroy()
			expect(#playerGui:GetDescendants()):toBe(0)
		end)
	end)
end)

describe("Settings reveal selector", function()
	local world, sent, screen, playerGui, data

	local function press(button: any)
		button.Activated:Fire({ UserInputType = roblox.Enum.UserInputType.MouseButton1 })
	end

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
		local Signal = world:require("ReplicatedStorage.Packages.Signal")
		local player = world:newPlayer({ Name = "You", DisplayName = "You" })
		player.GetAttributeChangedSignal = function()
			return Signal.new()
		end
		world.Players.LocalPlayer = player
		world.tree.ReplicatedStorage.GetAttributeChangedSignal = function()
			return Signal.new()
		end
		sent = {}
		world:packets().SetSetting.Fire = function(_packet: any, name: string, value: number)
			table.insert(sent, { name, value })
		end
		data = {
			Settings = {
				LowGraphics = false,
				AutoPlace = true,
				RollVolume = 1,
				BoardVolume = 1,
				OtherVolume = 1,
				MusicVolume = 0.5,
				EffectsMinRarity = 5,
			},
			Tutorial = 5,
		}
		local function lookup(path: { any }): any
			local node: any = data
			for _, part in path do
				if type(node) ~= "table" then
					return nil
				end
				node = node[part]
			end
			return node
		end
		playerGui = world:newInstance("Folder")
		local context = {
			Controllers = {
				DataController = {
					Get = function(_self: any, path: { any }?)
						return lookup(path or {})
					end,
					Observe = function(_self: any, path: { any }, callback: any)
						callback(lookup(path))
						return function() end
					end,
				},
			},
			PlayerGui = playerGui,
			Open = function() end,
			Close = function() end,
			IsOpen = function()
				return false
			end,
			Toast = function() end,
		}
		screen = world:require(`{screensPath}.Settings`).new(context)
	end)

	it("sends the matching number for each choice", function()
		local selector = playerGui:FindFirstChild("EffectsSelector", true)
		expect(selector ~= nil):toBe(true)
		local expected = { OFF = 8, ["MYTHIC+"] = 6, ["LEGENDARY+"] = 5, ["EPIC+"] = 4, ALL = 1 }
		local order = { { "8", "OFF" }, { "6", "MYTHIC+" }, { "5", "LEGENDARY+" }, { "4", "EPIC+" }, { "1", "ALL" } }
		for _, pair in order do
			press(selector:FindFirstChild(pair[1]))
			world:flush()
			local last = sent[#sent]
			expect(last[1]):toBe("EffectsMinRarity")
			expect(last[2]):toBe(expected[pair[2]])
		end
		expect(#sent):toBe(5)
	end)

	it("lists the five choices in order and a music slider", function()
		local selector = playerGui:FindFirstChild("EffectsSelector", true)
		local texts = {}
		for _, id in { "8", "6", "5", "4", "1" } do
			local button = selector:FindFirstChild(id)
			expect(button ~= nil):toBe(true)
			local found = ""
			for _, item in button:GetDescendants() do
				if item.ClassName == "TextLabel" and item.Text ~= "" then
					found = item.Text
					break
				end
			end
			table.insert(texts, found)
		end
		expect(texts):toEqual({ "OFF", "MYTHIC+", "LEGENDARY+", "EPIC+", "ALL" })
		expect(playerGui:FindFirstChild("MusicVolume", true) ~= nil):toBe(true)
		screen:Destroy()
	end)
end)
