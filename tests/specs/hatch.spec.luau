local H = require("../harness/Harness")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

local screens = "StarterPlayer.StarterPlayerScripts.Controllers.UIController"

describe("Hatch sequence", function()
	local world, HatchPlan, playerGui, context, settings, calls, closed, toasts, screen

	local function boot()
		screen = world:require(`{screens}.Screens.Hatch`).new(context)
		return screen
	end

	local function find(name: string): any
		return playerGui:FindFirstChild(name, true)
	end

	local function count(kind: string): number
		local total = 0
		for _, call in calls do
			if call.Kind == kind then
				total += 1
			end
		end
		return total
	end

	local function advance(seconds: number)
		local steps = math.ceil(seconds / 0.05)
		for _ = 1, steps do
			screen:Step(0.05)
		end
	end

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
		HatchPlan = world:require(`{screens}.HatchPlan`)
		playerGui = world:newInstance("Folder")
		settings = { LowGraphics = false, EffectsMinRarity = 5 }
		calls = {}
		closed = 0
		toasts = 0
		context = {
			Controllers = {
				DataController = {
					Get = function(_self: any, path: { any })
						if path[1] == "Settings" then
							return settings[path[2]]
						end
						return nil
					end,
				},
				SoundController = {
					PlayUi = function(_self: any, name: string)
						table.insert(calls, { Kind = "Ui", Name = name })
					end,
					PlaySwitch = function(_self: any, id: string, kind: string, pitch: number)
						table.insert(calls, { Kind = kind, Id = id, Pitch = pitch })
					end,
					PlayReveal = function(_self: any, rarity: any)
						table.insert(calls, { Kind = "Reveal", Name = rarity.Name })
					end,
					PlaySwell = function(_self: any, rarity: any)
						table.insert(calls, { Kind = "Swell", Name = rarity.Name })
					end,
				},
			},
			PlayerGui = playerGui,
			Open = function() end,
			Close = function(name: string)
				if name == "Hatch" then
					closed += 1
				end
			end,
			IsOpen = function()
				return false
			end,
			Toast = function()
				toasts += 1
			end,
		}
	end)

	describe("tier selection", function()
		it("picks the tier by pet rarity and the effects setting", function()
			expect(HatchPlan.TierName("Common", 5)):toBe("Basic")
			expect(HatchPlan.TierName("Uncommon", 5)):toBe("Basic")
			expect(HatchPlan.TierName("Rare", 5)):toBe("Big")
			expect(HatchPlan.TierName("Epic", 5)):toBe("Big")
			expect(HatchPlan.TierName("Legendary", 5)):toBe("Hype")
			expect(HatchPlan.TierName("Mythic", 5)):toBe("Hype")
			expect(HatchPlan.TierName("Legendary", 6)):toBe("Big")
			expect(HatchPlan.TierName("Mythic", 6)):toBe("Hype")
			expect(HatchPlan.TierName("Mythic", 99)):toBe("Basic")
			expect(HatchPlan.TierName("Legendary", 1)):toBe("Hype")
		end)

		it("strips shake, confetti and spin on low graphics", function()
			local plan = HatchPlan.For("Mythic", 5, true)
			expect(plan.Name):toBe("Hype")
			expect(plan.Confetti):toBe(0)
			expect(plan.Stars):toBe(0)
			expect(plan.Shake):toBe(0)
			expect(plan.Spin):toBe(0)
			local full = HatchPlan.For("Mythic", 5, false)
			expect(full.Confetti > 0 and full.Shake > 0 and full.Spin > 0):toBe(true)
		end)

		it("makes the bigger tiers longer", function()
			local basic = HatchPlan.For("Common", 5, false)
			local big = HatchPlan.For("Rare", 5, false)
			local hype = HatchPlan.For("Mythic", 5, false)
			expect(basic.BurstAt < big.BurstAt and big.BurstAt < hype.BurstAt):toBe(true)
			expect(#basic.Beats):toBe(3)
			expect(#hype.Beats):toBe(3)
			expect(basic.SwellAt):toBeNil()
			expect(hype.SwellAt ~= nil):toBe(true)
		end)

		it("uses the selected tier on screen", function()
			boot()
			screen:Play("Linear", "KeycapPin")
			expect(screen:TierName()):toBe("Basic")
			screen:Close()
			settings.EffectsMinRarity = 8
			screen:Play("Rainbow", "DiamondSpacebar")
			expect(screen:TierName()):toBe("Basic")
			screen:Close()
			settings.EffectsMinRarity = 5
			screen:Play("Rainbow", "DiamondSpacebar")
			expect(screen:TierName()):toBe("Hype")
		end)
	end)

	describe("phases and timing", function()
		it("walks drop, shake, reveal, ready and closes by itself", function()
			boot()
			screen:Play("Linear", "KeycapPin")
			local plan = HatchPlan.For("Common", 5, false)
			expect(screen:Phase()):toBe("Drop")
			advance(plan.Beats[1].Start + 0.2)
			expect(screen:Phase()):toBe("Shake")
			advance(plan.BurstAt - screen:Elapsed() + 0.1)
			expect(screen:Phase()):toBe("Reveal")
			expect(find("PetStage").Visible):toBe(true)
			advance(plan.ReadyAt - screen:Elapsed() + 0.05)
			expect(screen:Phase()):toBe("Ready")
			expect(find("Hint").Visible):toBe(true)
			expect(closed):toBe(0)
			advance(HatchPlan.AutoSeconds + 0.2)
			expect(closed):toBe(1)
			expect(screen:IsPlaying()):toBe(false)
		end)

		it("shows more crack lines on every shake beat", function()
			boot()
			screen:Play("Linear", "KeycapPin")
			local plan = HatchPlan.For("Common", 5, false)
			local function visibleCracks()
				local total = 0
				for index = 1, HatchPlan.CrackLines do
					if find(`Crack{index}`).Visible then
						total += 1
					end
				end
				return total
			end
			expect(visibleCracks()):toBe(0)
			local seen = {}
			for _, beat in plan.Beats do
				screen:Seek(beat.Start + 0.2)
				table.insert(seen, visibleCracks())
			end
			expect(seen[1] > 0 and seen[2] > seen[1] and seen[3] > seen[2]):toBe(true)
		end)

		it("skips to the reveal on the first tap, to ready on the second, and closes on the third", function()
			boot()
			screen:Play("Linear", "KeycapPin")
			advance(0.3)
			screen:Tap()
			expect(screen:Phase()):toBe("Reveal")
			screen:Tap()
			expect(screen:Phase()):toBe("Ready")
			expect(closed):toBe(0)
			screen:Tap()
			expect(closed):toBe(1)
		end)

		it("closes when the full-screen tap button is pressed", function()
			boot()
			screen:Play("Linear", "KeycapPin")
			advance(0.3)
			local button = find("Tap")
			button.Activated:Fire({})
			button.Activated:Fire({})
			button.Activated:Fire({})
			expect(closed):toBe(1)
		end)

		it("ignores a tap in the first instant", function()
			boot()
			screen:Play("Linear", "KeycapPin")
			screen:Tap()
			expect(screen:Phase()):toBe("Drop")
		end)

		it("queues a second hatch and plays it after the first", function()
			boot()
			screen:Play("Linear", "KeycapPin")
			screen:Play("Tactile", "ThockPad")
			expect(screen:QueuedCount()):toBe(1)
			advance(0.3)
			screen:Tap()
			screen:Tap()
			screen:Tap()
			expect(closed):toBe(0)
			expect(screen:IsPlaying()):toBe(true)
			expect(screen:TierName()):toBe("Big")
			expect(screen:QueuedCount()):toBe(0)
		end)
	end)

	describe("sounds", function()
		it("clicks a press and release for each crack, then pops and chimes", function()
			boot()
			screen:Play("Linear", "KeycapPin")
			local plan = HatchPlan.For("Common", 5, false)
			advance(plan.Land + 0.05)
			expect(count("Press")):toBe(1)
			advance(plan.Beats[1].Start - screen:Elapsed() + 0.3)
			expect(count("Press")):toBe(2)
			expect(count("Release")):toBe(1)
			advance(plan.BurstAt - screen:Elapsed() - 0.01)
			expect(count("Press")):toBe(4)
			expect(count("Release")):toBe(3)
			expect(count("Ui")):toBe(0)
			local pitches = {}
			for _, call in calls do
				if call.Kind == "Press" and call.Id == "MxBlue" then
					table.insert(pitches, call.Pitch)
				end
			end
			expect(pitches[1] < pitches[2] and pitches[2] < pitches[3]):toBe(true)
			advance(0.1)
			expect(count("Release")):toBe(4)
			expect(count("Ui")):toBe(1)
			expect(toasts):toBe(1)
		end)

		it("plays a rising swell and the reveal layers only on the hype tier", function()
			boot()
			screen:Play("Rainbow", "DiamondSpacebar")
			local plan = HatchPlan.For("Mythic", 5, false)
			advance(plan.SwellAt + 0.05)
			expect(count("Swell")):toBe(1)
			advance(plan.BurstAt - screen:Elapsed() + 0.1)
			expect(count("Reveal")):toBe(1)
			expect(count("Swell")):toBe(1)
			screen:Close()
			calls = {}
			screen:Play("Linear", "KeycapPin")
			advance(HatchPlan.For("Common", 5, false).BurstAt + 0.1)
			expect(count("Swell")):toBe(0)
			expect(count("Reveal")):toBe(0)
		end)

		it("plays the reveal chime for rare pets", function()
			boot()
			screen:Play("Clicky", "ThockPad")
			advance(HatchPlan.For("Rare", 5, false).BurstAt + 0.1)
			expect(count("Reveal")):toBe(1)
			expect(count("Swell")):toBe(0)
		end)
	end)

	describe("models", function()
		local function frames(): { any }
			local found = {}
			for _, item in playerGui:GetDescendants() do
				if item.ClassName == "ViewportFrame" then
					table.insert(found, item)
				end
			end
			return found
		end

		it("shows the egg and the pet models in viewports", function()
			boot()
			screen:Play("Golden", "GoldSpacebar")
			local egg = find("EggModel")
			local pet = find("PetModel")
			expect(egg.ClassName):toBe("ViewportFrame")
			expect(egg:FindFirstChild("Egg_Golden") ~= nil):toBe(true)
			expect(pet:FindFirstChild("Pet_GoldSpacebar") ~= nil):toBe(true)
			expect(egg.CurrentCamera ~= nil):toBe(true)
			expect(find("Rays") ~= nil):toBe(true)
		end)

		it("empties the viewports on close and never grows over 20 hatches", function()
			boot()
			local baseline = nil
			local ids = { "KeycapPin", "ThockPad", "GoldSpacebar", "DiamondSpacebar" }
			for index = 1, 20 do
				screen:Play("Linear", ids[index % #ids + 1])
				screen:Seek(HatchPlan.For("Common", 5, false).BurstAt + 0.2)
				local total = 0
				for _, frame in frames() do
					expect(#frame:GetChildren() <= 2):toBe(true)
					total += 1
				end
				baseline = baseline or total
				expect(total):toBe(baseline)
				screen:Close()
				expect(find("EggModel"):FindFirstChildOfClass("Model")):toBeNil()
				expect(find("PetModel"):FindFirstChildOfClass("Model")):toBeNil()
			end
			screen:Destroy()
			expect(#playerGui:GetDescendants()):toBe(0)
		end)

		it("keeps the effects off on low graphics", function()
			settings.LowGraphics = true
			boot()
			screen:Play("Linear", "KeycapPin")
			screen:Seek(3.5)
			expect(find("Confetti1").Visible):toBe(false)
			expect(find("Star1").Visible):toBe(false)
		end)

		it("fires confetti and stars on hype", function()
			boot()
			screen:Play("Rainbow", "DiamondSpacebar")
			screen:Seek(HatchPlan.For("Mythic", 5, false).BurstAt + 0.5)
			expect(find("Confetti1").Visible):toBe(true)
			expect(find("Star1").Visible):toBe(true)
			expect(find("Shard1").Visible):toBe(true)
		end)
	end)
end)
