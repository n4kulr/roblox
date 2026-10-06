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
					PlaySwitch = function(_self: any, id: string, kind: string, pitch: number, volume: number)
						table.insert(calls, { Kind = kind, Id = id, Pitch = pitch, Volume = volume })
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
		end)

		it("strips shake, confetti and spin on low graphics", function()
			local plan = HatchPlan.For("Mythic", 5, true)
			expect(plan.Confetti):toBe(0)
			expect(plan.Stars):toBe(0)
			expect(plan.Shake):toBe(0)
			expect(plan.Spin):toBe(0)
			expect(plan.Sparks <= 4 and plan.Shards <= 6):toBe(true)
			local full = HatchPlan.For("Mythic", 5, false)
			expect(full.Confetti > 0 and full.Shake > 0 and full.Spin > 0):toBe(true)
		end)

		it("holds common pets briefly and legendary pets longer", function()
			local basic = HatchPlan.For("Common", 5, false)
			local big = HatchPlan.For("Rare", 5, false)
			local hype = HatchPlan.For("Mythic", 5, false)
			expect(basic.HoldSeconds):toBe(1.2)
			expect(basic.HoldSeconds < big.HoldSeconds and big.HoldSeconds < hype.HoldSeconds):toBe(true)
			expect(basic.Stars):toBe(0)
			expect(big.Stars > 0 and big.Confetti == 0):toBe(true)
			expect(hype.Confetti > 0 and hype.Rainbow):toBe(true)
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

	describe("timeline", function()
		it("pops the egg in over a quarter second with a 1.15 overshoot", function()
			expect(HatchPlan.PopScale(0)):toBe(0)
			expect(math.abs(HatchPlan.PopScale(0.15) - 1.15) < 1e-6):toBe(true)
			expect(HatchPlan.PopScale(0.25)):toBe(1)
			expect(HatchPlan.PopScale(0.1) > 0.8):toBe(true)
		end)

		it("shakes for 2.2 seconds with an accelerating rhythm and growing swing", function()
			local plan = HatchPlan.For("Common", 5, false)
			expect(plan.ShakeStart):toBe(0.25)
			expect(math.abs(plan.BurstAt - plan.ShakeStart - 2.2) < 1e-6):toBe(true)
			expect(math.abs(HatchPlan.Period(plan, plan.ShakeStart) - 0.35) < 1e-6):toBe(true)
			expect(math.abs(HatchPlan.Period(plan, plan.BurstAt) - 0.12) < 1e-6):toBe(true)
			expect(math.abs(HatchPlan.Amplitude(plan, plan.ShakeStart) - 12) < 1e-6):toBe(true)
			expect(math.abs(HatchPlan.Amplitude(plan, plan.BurstAt) - 25) < 1e-6):toBe(true)
			expect(math.abs(HatchPlan.Grow(plan, plan.BurstAt) - 1.12) < 1e-6):toBe(true)
			expect(HatchPlan.Grow(plan, plan.ShakeStart)):toBe(1)
			local gaps = {}
			for index = 2, #plan.Swings do
				table.insert(gaps, plan.Swings[index].At - plan.Swings[index - 1].At)
			end
			expect(#plan.Swings >= 12):toBe(true)
			expect(gaps[1] > gaps[#gaps]):toBe(true)
			for index = 2, #gaps do
				expect(gaps[index] <= gaps[index - 1] + 1e-9):toBe(true)
			end
			for index = 2, #plan.Swings do
				expect(plan.Swings[index].Pitch > plan.Swings[index - 1].Pitch):toBe(true)
				expect(plan.Swings[index].Side ~= plan.Swings[index - 1].Side):toBe(true)
			end
		end)

		it("stays within the tilt range and squashes on each tilt", function()
			local plan = HatchPlan.For("Common", 5, false)
			local peak = 0
			local minSquash = 1
			for step = 0, 220 do
				local time = plan.ShakeStart + step * 0.01
				peak = math.max(peak, math.abs(HatchPlan.Tilt(plan, time)))
				local _, squashY = HatchPlan.Squash(plan, time)
				minSquash = math.min(minSquash, squashY)
			end
			expect(peak > 12 and peak <= 25.0001):toBe(true)
			expect(minSquash < 0.97):toBe(true)
			expect(HatchPlan.Tilt(plan, plan.BurstAt + 0.1)):toBe(0)
		end)

		it("reveals cracks in three stages", function()
			local plan = HatchPlan.For("Common", 5, false)
			expect(#plan.Cracks):toBe(3)
			expect(HatchPlan.CracksShown(plan, 0.5)):toBe(0)
			local seen = {}
			for _, stage in plan.Cracks do
				table.insert(seen, HatchPlan.CracksShown(plan, stage.At + 0.01))
			end
			expect(seen[1] < seen[2] and seen[2] < seen[3]):toBe(true)
			expect(seen[3]):toBe(HatchPlan.CrackLines)
		end)

		it("flashes white for 0.08 seconds and fades over 0.25", function()
			local plan = HatchPlan.For("Common", 5, false)
			expect(HatchPlan.Flash(plan, plan.BurstAt - 0.01)):toBe(0)
			expect(HatchPlan.Flash(plan, plan.BurstAt + 0.05)):toBe(1)
			local mid = HatchPlan.Flash(plan, plan.BurstAt + 0.08 + 0.125)
			expect(mid > 0 and mid < 1):toBe(true)
			expect(HatchPlan.Flash(plan, plan.BurstAt + 0.34)):toBe(0)
		end)
	end)

	describe("phases", function()
		it("walks appear, shake, reveal, ready, exit and closes by itself", function()
			boot()
			screen:Play("Linear", "KeycapPin")
			local plan = HatchPlan.For("Common", 5, false)
			expect(screen:Phase()):toBe("Appear")
			advance(plan.ShakeStart + 0.2)
			expect(screen:Phase()):toBe("Shake")
			advance(plan.BurstAt - screen:Elapsed() + 0.1)
			expect(screen:Phase()):toBe("Reveal")
			expect(find("PetStage").Visible):toBe(true)
			expect(find("EggStage").Visible):toBe(false)
			advance(plan.ReadyAt - screen:Elapsed() + 0.05)
			expect(screen:Phase()):toBe("Ready")
			expect(find("Hint").Visible):toBe(true)
			expect(closed):toBe(0)
			advance(plan.AutoAt - screen:Elapsed() + 0.05)
			expect(screen:Phase()):toBe("Exit")
			expect(toasts):toBe(1)
			expect(closed):toBe(0)
			advance(HatchPlan.ExitSeconds + 0.1)
			expect(closed):toBe(1)
			expect(screen:IsPlaying()):toBe(false)
		end)

		it("shows more crack lines at every stage", function()
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
			for _, stage in plan.Cracks do
				screen:Seek(stage.At + 0.05)
				table.insert(seen, visibleCracks())
			end
			expect(seen[1] > 0 and seen[2] > seen[1] and seen[3] > seen[2]):toBe(true)
		end)

		it("shows the pet name, rarity and chance in a staggered order", function()
			boot()
			screen:Play("Linear", "KeycapPin")
			local plan = HatchPlan.For("Common", 5, false)
			screen:Seek(plan.BurstAt + 0.1)
			expect(find("PetName").Visible):toBe(false)
			screen:Seek(plan.NameAt + 0.01)
			expect(find("PetName").Visible and not find("RarityName").Visible):toBe(true)
			screen:Seek(plan.RarityAt + 0.01)
			expect(find("RarityName").Visible and not find("Chance").Visible):toBe(true)
			screen:Seek(plan.ChanceAt + 0.01)
			expect(find("Chance").Visible):toBe(true)
			expect(find("PetName").Text):toBe("Keycap Kitty")
			expect(find("RarityName").Text):toBe("Common")
			expect(string.sub(find("Chance").Text, 1, 5)):toBe("1 in ")
		end)

		it("skips to the reveal on the first tap and closes on the second", function()
			boot()
			screen:Play("Linear", "KeycapPin")
			advance(0.3)
			screen:Tap()
			expect(screen:Phase()):toBe("Reveal")
			screen:Tap()
			expect(screen:Phase()):toBe("Exit")
			screen:Tap()
			expect(closed):toBe(1)
			expect(toasts):toBe(1)
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
			expect(screen:Phase()):toBe("Appear")
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
			advance(0.3)
			screen:Tap()
			screen:Tap()
			screen:Tap()
			expect(closed):toBe(1)
		end)

		it("is driven by render stepped", function()
			boot()
			screen:Open()
			screen:Play("Linear", "KeycapPin")
			world.fakeServices.RunService.RenderStepped:Fire(0.05)
			expect(screen:Elapsed() > 0.04):toBe(true)
		end)
	end)

	describe("sounds", function()
		it("ticks on every swing with a rising pitch, then pops and chimes", function()
			boot()
			screen:Play("Linear", "KeycapPin")
			local plan = HatchPlan.For("Common", 5, false)
			advance(plan.BurstAt - 0.06)
			local pitches = {}
			for _, call in calls do
				if call.Kind == "Press" and call.Id == "MxBlue" then
					table.insert(pitches, call.Pitch)
				end
			end
			expect(#pitches):toBe(#plan.Swings)
			for index = 2, #pitches do
				expect(pitches[index] > pitches[index - 1]):toBe(true)
			end
			expect(count("Ui")):toBe(0)
			expect(toasts):toBe(0)
			advance(0.1)
			expect(count("Ui")):toBe(1)
			expect(count("Release") >= 4):toBe(true)
			expect(count("Reveal")):toBe(0)
		end)

		it("plays a rising swell and the reveal layers only on the hype tier", function()
			boot()
			screen:Play("Rainbow", "DiamondSpacebar")
			local plan = HatchPlan.For("Mythic", 5, false)
			advance(plan.ShakeStart + 0.05)
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

		it("uses authored Assets.Eggs and Assets.Pets models when present", function()
			local assets = world.tree.ReplicatedStorage:FindFirstChild("Assets")
			if not assets then
				assets = world:newInstance("Folder")
				assets.Name = "Assets"
				assets.Parent = world.tree.ReplicatedStorage
			end
			for category, id in { Eggs = "Golden", Pets = "GoldSpacebar" } do
				local folder = world:newInstance("Folder")
				folder.Name = category
				folder.Parent = assets
				local model = world:newInstance("Model")
				model.Name = id
				local part = world:newInstance("Part")
				part.Name = "Authored"
				part.Parent = model
				model.Parent = folder
			end
			boot()
			screen:Play("Golden", "GoldSpacebar")
			expect(find("EggModel"):FindFirstChild("Golden") ~= nil):toBe(true)
			expect(find("EggModel"):FindFirstChild("Egg_Golden")):toBeNil()
			expect(find("PetModel"):FindFirstChild("GoldSpacebar") ~= nil):toBe(true)
			expect(find("PetModel"):FindFirstChild("Pet_GoldSpacebar")):toBeNil()
			assets:Destroy()
		end)

		it("has no dark full-screen panel", function()
			boot()
			expect(find("Backdrop")):toBeNil()
			expect(find("VignetteTop") ~= nil):toBe(true)
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
			screen:Play("Rainbow", "DiamondSpacebar")
			screen:Seek(3.5)
			expect(find("Confetti1").Visible):toBe(false)
			expect(find("Star1").Visible):toBe(false)
			expect(find("Shaker").Position.X.Offset):toBe(0)
		end)

		it("fires confetti, stars and shards on hype", function()
			boot()
			screen:Play("Rainbow", "DiamondSpacebar")
			screen:Seek(HatchPlan.For("Mythic", 5, false).BurstAt + 0.3)
			expect(find("Confetti1").Visible):toBe(true)
			expect(find("Star1").Visible):toBe(true)
			expect(find("Shard1").Visible):toBe(true)
			expect(find("Spark1").Visible):toBe(true)
		end)
	end)
end)
