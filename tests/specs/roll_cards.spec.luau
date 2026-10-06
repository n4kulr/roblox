local H = require("../harness/Harness")
local roblox = require("@lune/roblox")
local Layout = require("../../tools/ui_preview/Layout")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

local controllerPath = "StarterPlayer.StarterPlayerScripts.Controllers.RollController"
local viewport = roblox.Vector2.new(1280, 720)

describe("Roll result cards", function()
	local world, Keys, Trove, ResultCards, ResultSlots, playerGui, trove, isLow

	local function build()
		trove = Trove.new()
		return ResultCards.new(playerGui, trove, function()
			return isLow
		end)
	end

	local function payload(rarityName: string, isGolden: boolean?, longest: boolean?): any
		local pick = Keys.ByRarity[rarityName][1]
		if longest then
			for _, key in Keys.ByRarity[rarityName] do
				if #key.Name > #pick.Name then
					pick = key
				end
			end
		end
		return { Key = pick, Rarity = Keys.GetRarity(pick), IsGolden = isGolden == true }
	end

	local function gui(): any
		return playerGui:FindFirstChild("RollCard")
	end

	local function countDescendants(root: any): number
		return #root:GetDescendants()
	end

	local function absolute(record: any, x: number, y: number, out: { any }, trail: { any })
		local ax, ay = x + record.x, y + record.y
		local here = { Record = record, X = ax, Y = ay, Trail = trail }
		table.insert(out, here)
		local nextTrail = table.clone(trail)
		table.insert(nextTrail, here)
		for _, child in record.children do
			absolute(child, ax, ay, out, nextTrail)
		end
	end

	local function measure(): { any }
		local laidOut = Layout.Gui(gui(), viewport)
		local flat: { any } = {}
		for _, child in laidOut.children do
			absolute(child, 0, 0, flat, {})
		end
		return flat
	end

	local function holdersOf(flat: { any }): { any }
		local holders = {}
		for _, item in flat do
			if string.match(item.Record.name, "^Result%d$") and item.Record.w > 0 then
				table.insert(holders, item)
			end
		end
		return holders
	end

	local function intersects(a: any, b: any): boolean
		return a.X < b.X + b.Record.w
			and b.X < a.X + a.Record.w
			and a.Y < b.Y + b.Record.h
			and b.Y < a.Y + a.Record.h
	end

	local function showPair(cards: any, leftRarity: string, rightRarity: string, golden: boolean?)
		cards:Show("Left", payload(leftRarity, golden, true), true)
		cards:Show("Right", payload(rightRarity, golden, true), false)
		for _ = 1, 8 do
			cards:Step(0.05)
		end
		world:flush()
	end

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
		Keys = world:require("ReplicatedStorage.Config.Keys")
		Trove = world:require("ReplicatedStorage.Packages.Trove")
		ResultCards = world:require(`{controllerPath}.ResultCards`)
		ResultSlots = world:require(`{controllerPath}.ResultSlots`)
		playerGui = world:newInstance("Folder")
		isLow = false
	end)

	describe("clipping regression", function()
		it("never puts a clipping frame or CanvasGroup between the cards and their text", function()
			local cards = build()
			showPair(cards, "Legendary", "Uncommon", false)
			local checked = 0
			for _, item in gui():GetDescendants() do
				if item.ClassName == "CanvasGroup" then
					error("CanvasGroup found in the result popup")
				end
				if item.ClassName == "TextLabel" and item.Text ~= "" then
					local ancestor = item.Parent
					while ancestor and ancestor ~= playerGui do
						expect(ancestor.ClassName == "CanvasGroup"):toBe(false)
						local ok, clips = pcall(function()
							return ancestor.ClipsDescendants
						end)
						expect(ok and clips == true):toBe(false)
						ancestor = ancestor.Parent
					end
					checked += 1
				end
			end
			expect(checked):toBeGreaterThan(4)
		end)

		it(
			"keeps every label inside its card with room for the stroke, for two simultaneous results",
			function()
				for _, pair in { { "Legendary", "Uncommon" }, { "Mythic", "Common" }, { "Secret", "Rare" } } do
					local cards = build()
					showPair(cards, pair[1], pair[2], false)
					local flat = measure()
					local holders = holdersOf(flat)
					expect(#holders):toBe(2)
					local seen = 0
					for _, item in flat do
						local record = item.Record
						if record.text and record.name ~= "Banner" then
							seen += 1
							expect(record.text.overflow):toBe(false)
							local owner
							for _, holder in holders do
								if table.find(item.Trail, holder) then
									owner = holder
								end
							end
							expect(owner ~= nil):toBe(true)
							expect(item.X >= owner.X - 0.5):toBe(true)
							expect(item.X + record.w <= owner.X + owner.Record.w + 0.5):toBe(true)
							expect(item.Y >= owner.Y - 0.5):toBe(true)
							expect(item.Y + record.h <= owner.Y + owner.Record.h + 0.5):toBe(true)
							local parent = item.Trail[#item.Trail]
							expect(item.X - parent.X >= 0):toBe(true)
							expect(item.X + record.w <= parent.X + parent.Record.w + 0.5):toBe(true)
						end
					end
					expect(seen):toBe(6)
					trove:Destroy()
				end
			end
		)

		it("keeps the two cards and banner from overlapping each other", function()
			local cards = build()
			showPair(cards, "Legendary", "Uncommon", true)
			local flat = measure()
			local holders = holdersOf(flat)
			expect(intersects(holders[1], holders[2])):toBe(false)
			local gap = math.abs(holders[1].X - holders[2].X) - holders[1].Record.w
			expect(math.abs(gap) > 0):toBe(true)
			for _, item in flat do
				if item.Record.name == "Banner" and item.Record.w > 0 then
					for _, holder in holders do
						if not table.find(item.Trail, holder) then
							expect(intersects(item, holder)):toBe(false)
						end
					end
					expect(item.X >= 0 and item.X + item.Record.w <= 1280):toBe(true)
				end
			end
		end)

		it("fits long names on a narrow screen", function()
			local narrow = H.newWorld({ PrintErrors = false, GuiSize = roblox.Vector2.new(640, 360) })
			local NarrowCards = narrow:require(`{controllerPath}.ResultCards`)
			local NarrowKeys = narrow:require("ReplicatedStorage.Config.Keys")
			local narrowGui = narrow:newInstance("Folder")
			local narrowTrove = narrow:require("ReplicatedStorage.Packages.Trove").new()
			local cards = NarrowCards.new(narrowGui, narrowTrove, function()
				return false
			end)
			local longest = NarrowKeys.ByRarity.Legendary[1]
			for _, key in NarrowKeys.ByRarity.Legendary do
				if #key.Name > #longest.Name then
					longest = key
				end
			end
			cards:Show(
				"Left",
				{ Key = longest, Rarity = NarrowKeys.GetRarity(longest), IsGolden = true },
				true
			)
			cards:Show(
				"Right",
				{ Key = longest, Rarity = NarrowKeys.GetRarity(longest), IsGolden = false },
				false
			)
			narrow:flush()
			local laidOut = Layout.Gui(narrowGui:FindFirstChild("RollCard"), roblox.Vector2.new(640, 360))
			local flat: { any } = {}
			for _, child in laidOut.children do
				absolute(child, 0, 0, flat, {})
			end
			local holders = holdersOf(flat)
			expect(#holders):toBe(2)
			expect(intersects(holders[1], holders[2])):toBe(false)
			for _, item in flat do
				if item.Record.text then
					expect(item.Record.text.overflow):toBe(false)
				end
			end
		end)
	end)

	describe("presentation", function()
		it("tints the card by rarity and shows the gold frame only for golden rolls", function()
			local cards = build()
			cards:Show("Center", payload("Rare", true), false)
			local frame = gui():FindFirstChild("GoldFrame", true)
			expect(frame.Visible):toBe(true)
			cards:Show("Center", payload("Rare", false), false)
			expect(frame.Visible):toBe(false)
		end)

		it("adds burst, shimmer, banner and confetti by rarity tier", function()
			local cards = build()
			cards:Show("Center", payload("Common"), false)
			local holder = gui():FindFirstChild("Result1", true)
			expect(holder:FindFirstChild("Burst").Visible):toBe(false)
			expect(holder:FindFirstChild("Banner").Visible):toBe(false)
			expect(cards:ActiveConfetti()):toBe(0)
			cards:Show("Center", payload("Rare"), false)
			expect(holder:FindFirstChild("Burst").Visible):toBe(true)
			expect(holder:FindFirstChild("Shimmer", true).Visible):toBe(false)
			cards:Show("Center", payload("Epic"), false)
			expect(holder:FindFirstChild("Shimmer", true).Visible):toBe(true)
			expect(holder:FindFirstChild("Banner").Visible):toBe(false)
			cards:Show("Center", payload("Legendary"), true)
			local banners = {}
			for _, item in gui():GetDescendants() do
				if item.Name == "Banner" and item.Visible then
					table.insert(banners, item.Text)
				end
			end
			expect(banners):toEqual({ "LEGENDARY!" })
			expect(cards:ActiveConfetti()):toBeGreaterThan(0)
			expect(cards:ActiveConfetti() <= 30):toBe(true)
		end)

		it("skips the motion effects on low graphics", function()
			isLow = true
			local cards = build()
			cards:Show("Center", payload("Legendary"), true)
			expect(cards:ActiveConfetti()):toBe(0)
			local holder = gui():FindFirstChild("Result1", true)
			expect(holder.Rotation):toBe(0)
			expect(holder:FindFirstChild("UIScale").Scale):toBe(1)
			cards:Step(0.1)
			expect(holder:FindFirstChild("Shimmer", true).Visible):toBe(false)
		end)

		it("fades a card out and hides it", function()
			local cards = build()
			cards:Show("Center", payload("Common"), false)
			expect(cards:VisibleCount()):toBe(1)
			cards:Fade(false, false)
			for _ = 1, 10 do
				cards:Step(0.05)
			end
			expect(cards:VisibleCount()):toBe(0)
		end)

		it("confetti pieces never exceed the cap and are all recycled", function()
			local cards = build()
			for _ = 1, 10 do
				cards:Show("Center", payload("Secret"), true)
				cards:Step(0.01)
				expect(cards:ActiveConfetti() <= 30):toBe(true)
			end
			for _ = 1, 60 do
				cards:Step(0.05)
			end
			expect(cards:ActiveConfetti()):toBe(0)
		end)
	end)

	describe("rapid rolls", function()
		it("keeps at most one card and a bounded instance count over 20 rolls in 2 seconds", function()
			local cards = build()
			local slots = ResultSlots.new()
			local rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Common", "Mythic" }
			local baseline = countDescendants(gui())
			local now = 100
			for roll = 1, 20 do
				local rarity = rarities[(roll - 1) % #rarities + 1]
				local isRare = rarity == "Legendary" or rarity == "Mythic"
				cards:Run(slots:Push(payload(rarity), if isRare then 5 else 0.7, now))
				now += 0.1
				cards:Run(slots:Tick(now))
				cards:Step(0.1)
				expect(cards:VisibleCount() <= 1):toBe(true)
				expect(cards:ActiveConfetti() <= 30):toBe(true)
				expect(countDescendants(gui())):toBe(baseline)
			end
			for _ = 1, 140 do
				now += 0.1
				cards:Run(slots:Tick(now))
				cards:Step(0.1)
			end
			expect(cards:VisibleCount()):toBe(0)
			expect(cards:ActiveConfetti()):toBe(0)
			expect(countDescendants(gui())):toBe(baseline)
		end)

		it("cleans everything up when the trove is destroyed", function()
			local cards = build()
			cards:Show("Left", payload("Legendary"), true)
			cards:Show("Right", payload("Common"), false)
			trove:Destroy()
			expect(playerGui:FindFirstChild("RollCard")):toBeNil()
			expect(playerGui:FindFirstChild("RollFlash")):toBeNil()
			cards:Show("Center", payload("Common"), false)
			cards:Step(0.1)
			expect(cards:VisibleCount()):toBe(0)
		end)
	end)
end)
