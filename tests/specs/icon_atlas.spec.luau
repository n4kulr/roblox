local H = require("../harness/Harness")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

local atlasPath = "StarterPlayer.StarterPlayerScripts.Controllers.UIController.IconAtlas"
local atlasSize = 1024

local names = {
	"Keys", "Upgrades", "Index", "Rebirth", "Daily", "Gift", "Store", "Leaderboard", "Pass", "Shop",
	"Home", "Settings", "Roll", "Auto", "Golden", "Clicks", "Luck", "Speed", "Slots", "Income",
	"Walls", "LockTime", "Lock", "Unlock", "Trade", "Sound", "Music", "Graphics", "Code", "Crown",
	"Check", "Close", "Plus", "Minus", "Robux", "Clock", "Warning", "Thief", "Sparkle", "Potion",
	"Globe", "People", "Run", "Gem", "Season", "Arrow", "Info", "Fire", "Heart", "Bell",
	"Search", "Sell", "Equip", "Star", "Megaphone",
}

describe("IconAtlas", function()
	local world, atlas

	beforeEach(function()
		world = H.newWorld()
		atlas = world:require(atlasPath)
	end)

	it("has a rect for every icon name", function()
		for _, name in names do
			expect(atlas.Rects[name] ~= nil):toBe(true)
		end
	end)

	it("keeps rects inside the sheet and aligned to the cell grid", function()
		expect(atlas.CellSize):toBe(128)
		for _, rect in atlas.Rects do
			expect(rect.X >= 0 and rect.Y >= 0):toBe(true)
			expect(rect.X + atlas.CellSize <= atlasSize):toBe(true)
			expect(rect.Y + atlas.CellSize <= atlasSize):toBe(true)
			expect(rect.X % atlas.CellSize):toBe(0)
			expect(rect.Y % atlas.CellSize):toBe(0)
		end
	end)

	it("gives every icon its own cell", function()
		local seen = {}
		for _, rect in atlas.Rects do
			local key = `{rect.X},{rect.Y}`
			expect(seen[key]):toBe(nil)
			seen[key] = true
		end
	end)

	it("is frozen", function()
		expect(table.isfrozen(atlas)):toBe(true)
		expect(table.isfrozen(atlas.Rects)):toBe(true)
	end)

	it("does not apply while Image is empty", function()
		local label = world:newInstance("ImageLabel")
		label.Image = "untouched"
		if atlas.Image == "" then
			expect(atlas.Apply(label, "Luck")):toBe(false)
			expect(label.Image):toBe("untouched")
		end
		expect(atlas.Apply(label, "Nope")):toBe(false)
	end)

	it("applies the preview image from the attribute", function()
		if atlas.Image ~= "" then
			return
		end
		world.tree.ReplicatedStorage:SetAttribute("IconAtlasPreview", "rbxassetid://preview-atlas")
		local label = world:newInstance("ImageLabel")
		expect(atlas.Apply(label, "Luck")):toBe(true)
		expect(label.Image):toBe("rbxassetid://preview-atlas")
		expect(label.ImageRectOffset):toBe(atlas.Rects.Luck)
		expect(atlas.Apply(label, "Nope")):toBe(false)
	end)
end)
