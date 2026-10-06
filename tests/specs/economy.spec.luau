local H = require("../harness/Harness")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

describe("Economy pacing", function()
	local Keys, Upgrades, GameConfig, Rebirth

	beforeEach(function()
		local world = H.newWorld()
		Keys = world:require("ReplicatedStorage.Config.Keys")
		Upgrades = world:require("ReplicatedStorage.Config.Upgrades")
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		Rebirth = world:require("ReplicatedStorage.Rules.Rebirth")
	end)

	it("makes each rarity rarer and richer than the one below", function()
		for index = 2, #Keys.Rarities do
			expect(Keys.Rarities[index].Chance):toBeGreaterThan(Keys.Rarities[index - 1].Chance)
			expect(Keys.Rarities[index].Income):toBeGreaterThan(Keys.Rarities[index - 1].Income)
		end
	end)

	it("keeps every income step between 5 and 12 times", function()
		for index = 3, #Keys.Rarities do
			local ratio = Keys.Rarities[index].Income / Keys.Rarities[index - 1].Income
			expect(ratio):toBeGreaterThan(5)
			expect(ratio < 12):toBe(true)
		end
	end)

	it("lets a new player afford a first upgrade within seconds", function()
		local rare = Keys.RarityByName.Rare.Income
		local uncommon = Keys.RarityByName.Uncommon.Income
		local startRate = rare + (GameConfig.BaseSlots - 1) * uncommon
		local cheapest = math.huge
		for _, upgrade in Upgrades.List do
			cheapest = math.min(cheapest, upgrade.BaseCost)
		end
		expect(cheapest <= startRate * 8):toBe(true)
	end)

	it("guarantees a Rare in the first few rolls", function()
		expect(GameConfig.GuaranteedRareRoll <= 5):toBe(true)
	end)

	it("keeps the defense upgrades pricier than every key upgrade", function()
		local mostExpensiveStart = 0
		for _, upgrade in Upgrades.List do
			if upgrade.Category == "Keys" then
				mostExpensiveStart = math.max(mostExpensiveStart, upgrade.BaseCost)
			end
		end
		for _, upgrade in Upgrades.List do
			if upgrade.Category == "Defense" then
				expect(upgrade.BaseCost):toBeGreaterThan(mostExpensiveStart)
			end
		end
	end)

	it("lets the slot and speed upgrades reach exactly the board and roll caps", function()
		local slots = Upgrades.ById.Slots
		local speed = Upgrades.ById.Speed
		expect(GameConfig.BaseSlots + slots.MaxLevel * slots.PerLevel):toBe(GameConfig.BoardSlots)
		expect(GameConfig.RollsPerSecond + speed.MaxLevel * speed.PerLevel):toBeCloseTo(
			GameConfig.MaxRollsPerSecond,
			1e-9
		)
	end)

	it("makes the first rebirth a long goal on the starting keys", function()
		local legendary = Keys.RarityByName.Legendary.Income
		expect(Rebirth.Cost(0) / (GameConfig.BoardSlots * legendary)):toBeGreaterThan(60)
		expect(Rebirth.Cost(0)):toBeGreaterThan(Keys.RarityByName.Epic.Income * GameConfig.BoardSlots * 3600)
	end)
end)
