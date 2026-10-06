local roblox = require("@lune/roblox")
local H = require("../harness/Harness")

local Vector3, CFrame = roblox.Vector3, roblox.CFrame
local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

local startTime = 1700000250

local function toolsOf(player: any): { any }
	local list = {}
	for _, child in player:FindFirstChild("Backpack"):GetChildren() do
		if child.ClassName == "Tool" then
			table.insert(list, child)
		end
	end
	return list
end

local function toolNames(player: any): { string }
	local names = {}
	for _, tool in toolsOf(player) do
		table.insert(names, tool.Name)
	end
	table.sort(names)
	return names
end

describe("EggService", function()
	local world, Charms, Eggs, Rules, GameConfig, player, data

	beforeEach(function()
		world = H.newWorld({ Time = startTime })
		world:boot({ "KeyboardService", "EggService" })
		Charms = world:require("ReplicatedStorage.Config.Charms")
		Eggs = world:require("ReplicatedStorage.Config.Eggs")
		Rules = world:require("ReplicatedStorage.Rules.Charms")
		GameConfig = world:require("ReplicatedStorage.Config.GameConfig")
		player, data = world:join(nil, { Settings = { AutoPlace = false } }, true)
	end)

	afterEach(function()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	local function hatch(index: any): any
		return world:invoke("HatchEgg", player, index)
	end

	local function placeEgg(eggId: any, x: any, z: any): any
		return world:invoke("PlaceEgg", player, eggId, x, z)
	end

	local function give(eggId: string, count: number)
		data.EggInventory[eggId] = (data.EggInventory[eggId] or 0) + count
	end

	local function plant(eggId: string, readyAt: number, x: number?, z: number?)
		table.insert(data.PlacedEggs, { Id = eggId, ReadyAt = readyAt, X = x or (#data.PlacedEggs * 8), Z = z or 10 })
	end

	describe("egg bag", function()
		it("adds a bought egg to the inventory", function()
			local service = world.registry.EggService
			expect(service:AddEgg(player, "Golden")):toBe(true)
			expect(service:AddEgg(player, "Golden")):toBe(true)
			expect(service:AddEgg(player, "Linear")):toBe(true)
			expect(data.EggInventory):toEqual({ Golden = 2, Linear = 1 })
			expect(data.PlacedEggs):toEqual({})
		end)

		it("caps the bag at ten eggs in total", function()
			local service = world.registry.EggService
			expect(Eggs.BagCap):toBe(10)
			for _ = 1, 6 do
				expect(service:AddEgg(player, "Linear")):toBe(true)
			end
			for _ = 1, 4 do
				expect(service:AddEgg(player, "Rainbow")):toBe(true)
			end
			expect(service:HasRoom(player)):toBe(false)
			expect(service:AddEgg(player, "Linear")):toBe(false)
			expect(service:AddEgg(player, "Tactile")):toBe(false)
			expect(data.EggInventory):toEqual({ Linear = 6, Rainbow = 4 })
		end)

		it("makes room again after an egg is placed", function()
			local service = world.registry.EggService
			give("Linear", 10)
			expect(service:HasRoom(player)):toBe(false)
			expect(placeEgg("Linear", 5, 5)):toBe(true)
			expect(service:HasRoom(player)):toBe(true)
		end)

		it("rejects unknown eggs and players without data", function()
			local service = world.registry.EggService
			expect(service:AddEgg(player, "Mystery")):toBe(false)
			expect(data.EggInventory):toEqual({})
			local stranger = world:newPlayer()
			expect(service:AddEgg(stranger, "Linear")):toBe(false)
			expect(service:HasRoom(stranger)):toBe(false)
		end)

		it("drops invalid bag entries when data loads", function()
			local other, otherData = world:join(
				nil,
				{ EggInventory = { Linear = 2, Mystery = 3, Golden = -1, Tactile = 1.5 } },
				true
			)
			expect(otherData.EggInventory):toEqual({ Linear = 2 })
			expect(toolNames(other)):toEqual({ "Linear Egg x2" })
		end)
	end)

	describe("carrying tools", function()
		it("creates one tool per egg type with the count in its name", function()
			local service = world.registry.EggService
			service:AddEgg(player, "Golden")
			service:AddEgg(player, "Golden")
			service:AddEgg(player, "Linear")
			expect(toolNames(player)):toEqual({ "Golden Egg x2", "Linear Egg x1" })
			for _, tool in toolsOf(player) do
				expect(tool:FindFirstChild("Handle") ~= nil):toBe(true)
				expect(tool.CanBeDropped):toBe(false)
				expect(tool:FindFirstChild("EggSpot1") ~= nil):toBe(true)
			end
		end)

		it("tags each tool with its egg id and count", function()
			give("Tactile", 3)
			world.registry.EggService:Sync(player)
			local tool = toolsOf(player)[1]
			expect(tool:GetAttribute("EggId")):toBe("Tactile")
			expect(tool:GetAttribute("Count")):toBe(3)
			expect(tool.Handle.Color):toBe(Eggs.ById.Tactile.Color)
		end)

		it("updates the count and removes the tool when the last egg is placed", function()
			give("Linear", 2)
			world.registry.EggService:Sync(player)
			expect(toolNames(player)):toEqual({ "Linear Egg x2" })
			expect(placeEgg("Linear", 5, 5)):toBe(true)
			expect(toolNames(player)):toEqual({ "Linear Egg x1" })
			expect(placeEgg("Linear", 12, 5)):toBe(true)
			expect(toolNames(player)):toEqual({})
		end)

		it("updates a tool that is held in the character instead of duplicating it", function()
			local character = world:spawnCharacter(player, 0, 3, 0)
			world.registry.EggService:AddEgg(player, "Linear")
			local tool = toolsOf(player)[1]
			tool.Parent = character
			world.registry.EggService:AddEgg(player, "Linear")
			expect(toolNames(player)):toEqual({})
			expect(tool.Name):toBe("Linear Egg x2")
			expect(tool.Parent == character):toBe(true)
			expect(placeEgg("Linear", 5, 5)):toBe(true)
			expect(placeEgg("Linear", 12, 5)):toBe(true)
			expect(tool.Parent):toBeNil()
		end)

		it("gives tools back after the character respawns", function()
			give("Linear", 1)
			give("Rainbow", 1)
			world.registry.EggService:Sync(player)
			world:spawnCharacter(player, 0, 3, 0)
			for _, tool in toolsOf(player) do
				tool:Destroy()
			end
			expect(toolNames(player)):toEqual({})
			world:resetCharacter(player)
			world:spawnCharacter(player, 0, 3, 0)
			world:advance(0)
			expect(toolNames(player)):toEqual({ "Linear Egg x1", "Rainbow Egg x1" })
		end)

		it("builds tools for eggs already owned when data loads", function()
			local other = world:join(nil, { EggInventory = { Clicky = 2 } }, true)
			expect(toolNames(other)):toEqual({ "Clicky Egg x2" })
		end)

		it("keeps tools per player", function()
			local other = world:join(nil, nil, true)
			give("Linear", 1)
			world.registry.EggService:Sync(player)
			expect(toolNames(player)):toEqual({ "Linear Egg x1" })
			expect(toolNames(other)):toEqual({})
		end)
	end)

	describe("placing eggs", function()
		it("moves an owned egg from the bag onto the base with a hatch timer", function()
			give("Golden", 2)
			expect(placeEgg("Golden", 6, 12)):toBe(true)
			expect(data.EggInventory):toEqual({ Golden = 1 })
			expect(#data.PlacedEggs):toBe(1)
			expect(data.PlacedEggs[1]):toEqual({
				Id = "Golden",
				ReadyAt = world.now + Eggs.ById.Golden.HatchSeconds,
				X = 6,
				Z = 12,
			})
			expect((world.saves[player] or 0) > 0):toBe(true)
		end)

		it("rejects eggs the player does not own", function()
			expect(placeEgg("Linear", 5, 5)):toBe(false)
			give("Linear", 1)
			expect(placeEgg("Golden", 5, 5)):toBe(false)
			expect(placeEgg("Mystery", 5, 5)):toBe(false)
			expect(data.EggInventory):toEqual({ Linear = 1 })
			expect(data.PlacedEggs):toEqual({})
		end)

		it("rejects bad arguments", function()
			give("Linear", 3)
			for _, bad in { "5", true, 0 / 0, math.huge, -math.huge } do
				expect(placeEgg("Linear", bad, 5)):toBe(false)
				expect(placeEgg("Linear", 5, bad)):toBe(false)
			end
			expect(placeEgg(nil, 5, 5)):toBe(false)
			expect(placeEgg(5, 5, 5)):toBe(false)
			expect(placeEgg("Linear", nil, nil)):toBe(false)
			expect(data.EggInventory):toEqual({ Linear = 3 })
			expect(data.PlacedEggs):toEqual({})
		end)

		it("only accepts spots on the player's own base, inset from the edge", function()
			give("Linear", 8)
			expect(Eggs.PlaceInset):toBe(2)
			expect(placeEgg("Linear", 100, 0)):toBe(false)
			expect(placeEgg("Linear", 0, -100)):toBe(false)
			expect(placeEgg("Linear", 21, 10)):toBe(false)
			expect(placeEgg("Linear", 20.5, 10)):toBe(false)
			expect(placeEgg("Linear", -20.5, 10)):toBe(false)
			expect(placeEgg("Linear", 10, 20.5)):toBe(false)
			expect(placeEgg("Linear", 10, -20.5)):toBe(false)
			expect(#data.PlacedEggs):toBe(0)
			expect(placeEgg("Linear", 20, 20)):toBe(true)
			expect(placeEgg("Linear", -20, 20)):toBe(true)
		end)

		it("keeps eggs at least four studs apart", function()
			give("Linear", 4)
			expect(Eggs.PlaceSpacing):toBe(4)
			expect(placeEgg("Linear", 10, 10)):toBe(true)
			expect(placeEgg("Linear", 13.9, 10)):toBe(false)
			expect(placeEgg("Linear", 10, 6.5)):toBe(false)
			expect(placeEgg("Linear", 12, 12)):toBe(false)
			expect(placeEgg("Linear", 14, 10)):toBe(true)
			expect(#data.PlacedEggs):toBe(2)
		end)

		it("rejects spots on the roll key", function()
			give("Linear", 4)
			expect(placeEgg("Linear", 0, -10)):toBe(false)
			expect(placeEgg("Linear", 4, -10)):toBe(false)
			expect(placeEgg("Linear", 0, -15)):toBe(false)
			expect(placeEgg("Linear", 0, -16)):toBe(true)
			expect(placeEgg("Linear", 8, -10)):toBe(true)
		end)

		it("holds at most three placed eggs", function()
			give("Linear", 6)
			expect(Eggs.PlacedCap):toBe(3)
			expect(placeEgg("Linear", 0, 10)):toBe(true)
			expect(placeEgg("Linear", 8, 10)):toBe(true)
			expect(placeEgg("Linear", 16, 10)):toBe(true)
			expect(placeEgg("Linear", -8, 10)):toBe(false)
			expect(data.EggInventory):toEqual({ Linear = 3 })
			expect(#data.PlacedEggs):toBe(3)
			data.PlacedEggs[1].ReadyAt = 0
			expect(hatch(1) ~= ""):toBe(true)
			expect(placeEgg("Linear", -8, 10)):toBe(true)
		end)

		it("fails for players without data", function()
			local stranger = world:newPlayer()
			expect(world:invoke("PlaceEgg", stranger, "Linear", 5, 5)):toBe(false)
		end)

		it("fails when the player has no base", function()
			give("Linear", 1)
			world.registry.PlotService.GetBase = function()
				return nil
			end
			expect(placeEgg("Linear", 5, 5)):toBe(false)
			expect(data.EggInventory):toEqual({ Linear = 1 })
		end)
	end)

	describe("hatching", function()
		it("rejects a hatch before the egg is ready and changes nothing", function()
			plant("Linear", world.now + 60)
			expect(hatch(1)):toBe("")
			expect(#data.PlacedEggs):toBe(1)
			expect(data.PlacedEggs[1].ReadyAt):toBe(world.now + 60)
			expect(data.Charms):toEqual({})
			world:advance(59)
			expect(hatch(1)):toBe("")
		end)

		it("hatches at the ready time, grants a pet from the egg table and removes the egg", function()
			plant("Golden", world.now + 30)
			world:advance(30)
			local charmId = hatch(1)
			expect(charmId ~= ""):toBe(true)
			local allowed = false
			for _, drop in Rules.Drops("Golden") do
				if drop.CharmId == charmId then
					allowed = true
				end
			end
			expect(allowed):toBe(true)
			expect(data.Charms[charmId]):toBe(1)
			expect(data.PlacedEggs):toEqual({})
			expect((world.saves[player] or 0) > 0):toBe(true)
			expect(hatch(1)):toBe("")
		end)

		it("stacks duplicate pets", function()
			local count = 0
			for _ = 1, 40 do
				plant("Linear", 0)
				if hatch(1) ~= "" then
					count += 1
				end
			end
			expect(count):toBe(40)
			local total = 0
			for _, amount in data.Charms do
				total += amount
			end
			expect(total):toBe(40)
		end)

		it("only ever grants pets from each egg drop table", function()
			for _, egg in Eggs.Catalog do
				local allowed: { [string]: boolean } = {}
				for _, drop in Rules.Drops(egg.Id) do
					allowed[drop.CharmId] = true
				end
				for _ = 1, 60 do
					plant(egg.Id, 0)
					expect(allowed[hatch(#data.PlacedEggs)]):toBe(true)
				end
			end
		end)

		it("rejects invalid indexes", function()
			expect(hatch(1)):toBe("")
			plant("Linear", 0)
			for _, index in { 0, 2, -1, 1.5, "1", true, 0 / 0, math.huge } do
				expect(hatch(index)):toBe("")
			end
			expect(hatch(nil)):toBe("")
			expect(#data.PlacedEggs):toBe(1)
			expect(data.Charms):toEqual({})
		end)

		it("rejects unknown egg ids", function()
			table.insert(data.PlacedEggs, { Id = "Mystery", ReadyAt = 0, X = 5, Z = 5 })
			expect(hatch(1)):toBe("")
			expect(#data.PlacedEggs):toBe(1)
		end)

		it("fails for players without data", function()
			local stranger = world:newPlayer()
			expect(world:invoke("HatchEgg", stranger, 1)):toBe("")
		end)

		it("hatches each placed egg independently", function()
			plant("Linear", 0)
			plant("Golden", world.now + 500)
			plant("Tactile", 0)
			expect(hatch(2)):toBe("")
			expect(hatch(3) ~= ""):toBe(true)
			expect(#data.PlacedEggs):toBe(2)
			expect(data.PlacedEggs[1].Id):toBe("Linear")
			expect(data.PlacedEggs[2].Id):toBe("Golden")
			expect(hatch(1) ~= ""):toBe(true)
			expect(data.PlacedEggs[1].Id):toBe("Golden")
		end)

		it("ReadyEggs sets every unready egg to now", function()
			plant("Linear", world.now + 90)
			plant("Golden", world.now + 10)
			plant("Tactile", 0)
			local service = world.registry.EggService
			expect(service:ReadyEggs(player)):toBe(2)
			expect(data.PlacedEggs[1].ReadyAt):toBe(world.now)
			expect(data.PlacedEggs[2].ReadyAt):toBe(world.now)
			expect(data.PlacedEggs[3].ReadyAt):toBe(0)
			expect(service:ReadyEggs(player)):toBe(0)
		end)

		it("HatchAll readies and hatches every placed egg", function()
			plant("Linear", world.now + 40)
			plant("Golden", world.now + 80)
			local service = world.registry.EggService
			local charms = service:HatchAll(player)
			expect(#charms):toBe(2)
			expect(data.PlacedEggs):toEqual({})
			local total = 0
			for _, amount in data.Charms do
				total += amount
			end
			expect(total):toBe(2)
		end)
	end)

	describe("legacy incubators", function()
		it("moves eggs from the old incubators onto the base when data loads", function()
			local other, otherData = world:join(nil, {
				Incubators = { "Linear", "", "Golden" },
				IncubatorReadyAt = { world.now + 50, 0, world.now - 5 },
			}, true)
			expect(#otherData.PlacedEggs):toBe(2)
			expect(otherData.PlacedEggs[1].Id):toBe("Linear")
			expect(otherData.PlacedEggs[1].ReadyAt):toBe(world.now + 50)
			expect(otherData.PlacedEggs[2].Id):toBe("Golden")
			expect(otherData.PlacedEggs[2].ReadyAt):toBe(world.now - 5)
			expect(otherData.Incubators):toEqual({ "", "", "" })
			expect(otherData.IncubatorReadyAt):toEqual({ 0, 0, 0 })
			local EggPlacement = world:require("ReplicatedStorage.Utils.EggPlacement")
			local base = world.registry.PlotService:GetBase(other)
			local rect = EggPlacement.RectOf(base.CFrame, world.registry.PlotService:GetRollKey(other))
			local first = otherData.PlacedEggs[1]
			expect(EggPlacement.Check(base.Size, rect, {}, first.X, first.Z)):toBe("Ok")
			expect(
				EggPlacement.Check(base.Size, rect, { { X = first.X, Z = first.Z } }, otherData.PlacedEggs[2].X, otherData.PlacedEggs[2].Z)
			):toBe("Ok")
		end)

		it("keeps the hatch time of an egg that had none recorded", function()
			local _, otherData = world:join(nil, { Incubators = { "", "Tactile", "" } }, true)
			expect(otherData.PlacedEggs[1].ReadyAt):toBe(world.now + Eggs.ById.Tactile.HatchSeconds)
		end)

		it("does nothing when there are no legacy eggs", function()
			local _, otherData = world:join(nil, nil, true)
			expect(otherData.PlacedEggs):toEqual({})
		end)
	end)

	describe("pets", function()
		local plot

		local function activeAttribute(target: any): string
			return target:GetAttribute("EquippedCharms")
		end

		local function petModels(): { any }
			local folder = plot:FindFirstChild("Pets")
			return if folder then folder:GetChildren() else {}
		end

		local function petIds(): { string }
			local ids = {}
			for _, model in petModels() do
				table.insert(ids, model:GetAttribute("PetId"))
			end
			table.sort(ids)
			return ids
		end

		beforeEach(function()
			plot = world:newInstance("Model")
			world.registry.PlotService.GetPlot = function()
				return plot
			end
		end)

		it("names the pets after keyboard animals with the same rarities", function()
			expect(Charms.ById.KeycapPin.Name):toBe("Keycap Kitty")
			expect(Charms.ById.DiamondSpacebar.Name):toBe("Diamond Dragon")
			expect(Charms.ById.GoldSpacebar.Name):toBe("Spacebar Bunny")
			expect(Charms.ById.MidasKey.Name):toBe("Golden Goose")
			expect(Charms.ById.HyperSwitch.Name):toBe("Switch Fox")
			expect(Charms.ById.TinySwitch.Name):toBe("Thock Pup")
			expect(Charms.ById.CloverFob.Name):toBe("Clicky Chick")
			expect(Charms.ById.DiamondSpacebar.Rarity):toBe("Mythic")
			expect(Charms.ActiveLimit):toBe(6)
		end)

		it("grants a pet from a hatch and makes it active when there is room", function()
			plant("Linear", 0)
			local id = hatch(1)
			expect(Charms.ById[id] ~= nil):toBe(true)
			expect(data.Charms[id]):toBe(1)
			expect(data.EquippedCharms):toEqual({ id })
			expect(activeAttribute(player)):toBe(id)
			expect(#petModels()):toBe(1)
			expect(petModels()[1]:GetAttribute("PetId")):toBe(id)
		end)

		it("keeps only the best six pets active", function()
			data.Charms = {
				KeycapPin = 1,
				CloverFob = 1,
				TinySwitch = 1,
				BrassStab = 1,
				ThockPad = 1,
				GoldSpacebar = 1,
				DiamondSpacebar = 1,
				LuckyLube = 1,
			}
			world.registry.EggService:Sync(player)
			expect(data.EquippedCharms):toEqual({
				"DiamondSpacebar",
				"GoldSpacebar",
				"ThockPad",
				"BrassStab",
				"LuckyLube",
				"KeycapPin",
			})
			expect(#petModels()):toBe(6)
			expect(table.find(petIds(), "CloverFob")):toBeNil()
			expect(table.find(petIds(), "TinySwitch")):toBeNil()
			expect(data.Charms.TinySwitch):toBe(1)
		end)

		it("never activates more than six pets however many are owned", function()
			for _, charm in Charms.Catalog do
				data.Charms[charm.Id] = 3
			end
			world.registry.EggService:Sync(player)
			plant("Linear", 0)
			hatch(1)
			expect(#data.EquippedCharms):toBe(6)
			expect(#petModels()):toBe(6)
			local effects = Rules.Effects(data.EquippedCharms)
			expect(effects.Income >= 10):toBe(true)
		end)

		it("derives the active set when data loads and ignores stale equipped lists", function()
			local other, otherData = world:join(
				nil,
				{ Charms = { ThockPad = 1, DiamondSpacebar = 1 }, EquippedCharms = { "KeycapPin", "Nope" } },
				true
			)
			expect(otherData.EquippedCharms):toEqual({ "DiamondSpacebar", "ThockPad" })
			expect(activeAttribute(other)):toBe("DiamondSpacebar,ThockPad")
		end)

		it("spawns one pet model per active pet with owner, id and seed", function()
			data.Charms = { ThockPad = 2, GoldSpacebar = 1 }
			world.registry.EggService:Sync(player)
			expect(#petModels()):toBe(3)
			expect(petIds()):toEqual({ "GoldSpacebar", "ThockPad", "ThockPad" })
			local seeds = {}
			for _, model in petModels() do
				expect(model:GetAttribute("Owner")):toBe(player.UserId)
				expect(type(model:GetAttribute("Seed"))):toBe("number")
				seeds[model:GetAttribute("Seed")] = true
				expect(model.PrimaryPart ~= nil):toBe(true)
				local body = model:FindFirstChild("Body")
				expect(body.Anchored):toBe(true)
				expect(body.CanCollide):toBe(false)
				local gui = model:FindFirstChild("Name", true)
				expect(gui.MaxDistance):toBe(40)
				expect(model:FindFirstChild("Head") ~= nil):toBe(true)
				expect(model:FindFirstChild("LeftEar") ~= nil):toBe(true)
			end
			local count = 0
			for _ in seeds do
				count += 1
			end
			expect(count):toBe(3)
		end)

		it("sizes and tints pets by rarity", function()
			data.Charms = { KeycapPin = 1, DiamondSpacebar = 1 }
			world.registry.EggService:Sync(player)
			for _, model in petModels() do
				local charm = Charms.ById[model:GetAttribute("PetId")]
				expect(model.Body.Color == charm.Color):toBe(true)
				local length = model.Body.Size.Z
				expect(length > 1 and length < 3):toBe(true)
			end
		end)

		it("updates the models when a better pet is hatched and does not rebuild otherwise", function()
			data.Charms = { KeycapPin = 1 }
			world.registry.EggService:Sync(player)
			local first = petModels()[1]
			world.registry.EggService:Sync(player)
			expect(petModels()[1] == first):toBe(true)
			data.Charms.DiamondSpacebar = 1
			plant("Linear", 0)
			hatch(1)
			expect(#petModels() >= 2):toBe(true)
			expect(table.find(petIds(), "DiamondSpacebar") ~= nil):toBe(true)
		end)

		it("clears pet models when the plot is released and when the player leaves", function()
			data.Charms = { ThockPad = 1 }
			world.registry.EggService:Sync(player)
			expect(#petModels()):toBe(1)
			world.registry.PlotService.GetPlot = function()
				return nil
			end
			world.registry.EggService:Sync(player)
			expect(plot:FindFirstChild("Pets")):toBeNil()
			world.registry.PlotService.GetPlot = function()
				return plot
			end
			world.registry.EggService:Sync(player)
			expect(#petModels()):toBe(1)
			world:removePlayer(player)
			expect(plot:FindFirstChild("Pets")):toBeNil()
		end)

		it("has no equip packet handler any more", function()
			expect(world:packets().EquipCharm):toBeNil()
		end)
	end)

	describe("integration", function()
		it("raises settled income with an active income pet", function()
			data.Board = {}
			for index = 1, GameConfig.BaseSlots do
				data.Board[index] = "PlainClack"
			end
			data.Cash = 0
			data.IncomeAt = world.now - 100
			world.registry.KeyboardService:Settle(player)
			local plain = data.Cash
			expect(plain > 0):toBe(true)
			data.Charms = { ThockPad = 1 }
			world.registry.EggService:Sync(player)
			expect(data.EquippedCharms):toEqual({ "ThockPad" })
			data.Cash = 0
			data.IncomeAt = world.now - 100
			world.registry.KeyboardService:Settle(player)
			expect(data.Cash):toBe(plain * 2)
		end)

		it("keeps persistence fields valid", function()
			local PlayerData = world:require("ServerScriptService.Data.PlayerData")
			data.Charms = { ThockPad = 1 }
			give("Linear", 2)
			plant("Linear", world.now + 10)
			expect(PlayerData.Validate(data)):toBe(true)
			expect(PlayerData.Validate(PlayerData.Template)):toBe(true)
			expect(PlayerData.Template.EggInventory):toEqual({})
			expect(PlayerData.Template.PlacedEggs):toEqual({})
		end)

		it("clears its packet handlers on Destroy", function()
			local packets = world:packets()
			local hatchPacket, placePacket = packets.HatchEgg, packets.PlaceEgg
			expect(hatchPacket.OnServerInvoke ~= nil):toBe(true)
			expect(placePacket.OnServerInvoke ~= nil):toBe(true)
			world:destroy()
			expect(hatchPacket.OnServerInvoke):toBeNil()
			expect(placePacket.OnServerInvoke):toBeNil()
		end)

		it("stops reacting to a player who left", function()
			give("Linear", 1)
			world.registry.EggService:Sync(player)
			world:removePlayer(player)
			expect(world:invoke("PlaceEgg", player, "Linear", 5, 5)):toBe(false)
		end)
	end)
end)

describe("Eggs and rebirth", function()
	local world

	afterEach(function()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	it("keeps carried and placed eggs through a rebirth", function()
		world = H.newWorld({ Time = startTime })
		world:boot({ "KeyboardService", "PassService", "RebirthService", "EggService" })
		local Rebirth = world:require("ReplicatedStorage.Rules.Rebirth")
		local player, data = world:join(nil, {
			Cash = Rebirth.Cost(0),
			IncomeAt = world.now,
			EggInventory = { Linear = 2 },
			PlacedEggs = { { Id = "Golden", ReadyAt = world.now + 99, X = 5, Z = 5 } },
		}, true)
		expect(world:invoke("Rebirth", player)):toBe(true)
		expect(data.Rebirths):toBe(1)
		expect(data.EggInventory):toEqual({ Linear = 2 })
		expect(#data.PlacedEggs):toBe(1)
		expect(data.PlacedEggs[1].Id):toBe("Golden")
		expect(toolNames(player)):toEqual({ "Linear Egg x2" })
	end)
end)

describe("Placed eggs on bases", function()
	local world, plots, Eggs, FloorGrid

	beforeEach(function()
		world = H.newWorld({ Time = startTime })
		Eggs = world:require("ReplicatedStorage.Config.Eggs")
		FloorGrid = world:require("ReplicatedStorage.Rules.FloorGrid")
		world.workspace = world:newInstance("Folder")
		local plotService = world:require("ServerScriptService.Services.PlotService")
		world:boot({ "KeyboardService", "PlotService", "EggService" }, { PlotService = plotService })
		plots = world.workspace:FindFirstChild("Plots")
	end)

	afterEach(function()
		expect(world.errors):toEqual({})
		world:destroy()
	end)

	local function ownedPlot(player: any): any
		for _, plot in plots:GetChildren() do
			if plot:GetAttribute("Owner") == player.UserId then
				return plot
			end
		end
		return nil
	end

	local function eggsOf(plot: any): { any }
		local folder = plot:FindFirstChild("PlacedEggs")
		return if folder then folder:GetChildren() else {}
	end

	it("no longer builds incubators on any plot", function()
		for _, plot in plots:GetChildren() do
			expect(plot:FindFirstChild("Incubators")):toBeNil()
			expect(#eggsOf(plot)):toBe(0)
		end
	end)

	it("spawns the egg on the key floor where the player placed it, with a countdown", function()
		local player, data = world:join({ Name = "Owner" }, { EggInventory = { Linear = 1 } }, true)
		local plot = ownedPlot(player)
		expect(world:invoke("PlaceEgg", player, "Linear", 6, 10)):toBe(true)
		local list = eggsOf(plot)
		expect(#list):toBe(1)
		local model = list[1]
		expect(model:GetAttribute("EggId")):toBe("Linear")
		expect(model:GetAttribute("Index")):toBe(1)
		expect(model:GetAttribute("ReadyAt")):toBe(data.PlacedEggs[1].ReadyAt)
		local base = plot.Base
		local body = model.EggBody
		local localPosition = base.CFrame:PointToObjectSpace(body.CFrame.Position)
		expect(math.abs(localPosition.X - 6) < 1e-3):toBe(true)
		expect(math.abs(localPosition.Z - 10) < 1e-3):toBe(true)
		local floorTop = base.Size.Y / 2 + FloorGrid.CapHeight
		local bottom = math.huge
		for _, part in model:GetChildren() do
			if part.ClassName == "Part" and string.sub(part.Name, 1, 3) == "Egg" then
				local offset = base.CFrame:PointToObjectSpace(part.CFrame.Position).Y - part.Size.Y / 2
				bottom = math.min(bottom, offset)
				expect(part.Anchored):toBe(true)
			end
		end
		expect(math.abs(bottom - floorTop) < 0.3):toBe(true)
		expect(model:FindFirstChild("EggSpot1") ~= nil):toBe(true)
		expect(model:FindFirstChild("Text", true).Text):toBe("Linear Egg\n2:00")
		expect(body.Color):toBe(Eggs.ById.Linear.Color)
	end)

	it("counts down and shows READY! Hold E", function()
		local player = world:join({ Name = "Owner" }, { EggInventory = { Linear = 1 } }, true)
		local plot = ownedPlot(player)
		world:invoke("PlaceEgg", player, "Linear", 6, 10)
		world:advance(60)
		expect(eggsOf(plot)[1]:FindFirstChild("Text", true).Text):toBe("Linear Egg\n1:00")
		world:advance(60)
		expect(eggsOf(plot)[1]:FindFirstChild("Text", true).Text):toBe("READY! Hold E")
	end)

	it("rebuilds placed eggs on the owner's plot when they rejoin", function()
		local player, data = world:join({ Name = "Owner" }, {
			PlacedEggs = {
				{ Id = "Tactile", ReadyAt = world.now + 100, X = -8, Z = 12 },
				{ Id = "Golden", ReadyAt = world.now - 1, X = 8, Z = 12 },
			},
		}, true)
		local plot = ownedPlot(player)
		local list = eggsOf(plot)
		expect(#list):toBe(2)
		expect(plot.PlacedEggs.PlacedEgg1:GetAttribute("EggId")):toBe("Tactile")
		expect(plot.PlacedEggs.PlacedEgg2:GetAttribute("EggId")):toBe("Golden")
		expect(plot.PlacedEggs.PlacedEgg2:FindFirstChild("Text", true).Text):toBe("READY! Hold E")
		world:removePlayer(player)
		expect(#eggsOf(plot)):toBe(0)
		expect(#data.PlacedEggs):toBe(2)
		local again = world:join({ Name = "Owner" }, { PlacedEggs = data.PlacedEggs }, true)
		expect(#eggsOf(ownedPlot(again))):toBe(2)
	end)

	it("moves legacy incubator eggs onto the base and shows them", function()
		local player, data = world:join(
			{ Name = "Owner" },
			{ Incubators = { "Rainbow", "", "" }, IncubatorReadyAt = { world.now + 30, 0, 0 } },
			true
		)
		expect(#data.PlacedEggs):toBe(1)
		expect(#eggsOf(ownedPlot(player))):toBe(1)
		expect(data.Incubators):toEqual({ "", "", "" })
	end)

	it("removes the egg model when it hatches and renumbers the rest", function()
		local player, data = world:join({ Name = "Owner" }, {
			PlacedEggs = {
				{ Id = "Linear", ReadyAt = 0, X = -8, Z = 12 },
				{ Id = "Golden", ReadyAt = world.now + 500, X = 8, Z = 12 },
			},
		}, true)
		local plot = ownedPlot(player)
		expect(world:invoke("HatchEgg", player, 1) ~= ""):toBe(true)
		local list = eggsOf(plot)
		expect(#list):toBe(1)
		expect(list[1]:GetAttribute("EggId")):toBe("Golden")
		expect(list[1]:GetAttribute("Index")):toBe(1)
		expect(#data.PlacedEggs):toBe(1)
	end)

	it("clears the egg visuals when the owner leaves", function()
		local player = world:join({ Name = "Owner" }, { PlacedEggs = { { Id = "Linear", ReadyAt = 0, X = 8, Z = 12 } } }, true)
		local plot = ownedPlot(player)
		expect(#eggsOf(plot)):toBe(1)
		world:removePlayer(player)
		expect(#eggsOf(plot)):toBe(0)
	end)

	it("keeps one owner's eggs off other bases", function()
		local a = world:join({ Name = "A" }, { EggInventory = { Clicky = 1 } }, true)
		local b = world:join({ Name = "B" }, nil, true)
		expect(world:invoke("PlaceEgg", a, "Clicky", 5, 5)):toBe(true)
		expect(#eggsOf(ownedPlot(a))):toBe(1)
		expect(#eggsOf(ownedPlot(b))):toBe(0)
	end)

	it("validates spots in the player's own base space, never another base's", function()
		local a, aData = world:join({ Name = "A" }, { EggInventory = { Linear = 3 } }, true)
		local b = world:join({ Name = "B" }, nil, true)
		local otherBase = ownedPlot(b).Base
		local own = ownedPlot(a).Base
		local world_ = otherBase.CFrame.Position
		expect(world:invoke("PlaceEgg", a, "Linear", world_.X, world_.Z)):toBe(false)
		local away = own.CFrame:PointToObjectSpace(world_)
		expect(world:invoke("PlaceEgg", a, "Linear", away.X, away.Z)):toBe(false)
		expect(#aData.PlacedEggs):toBe(0)
		expect(world:invoke("PlaceEgg", a, "Linear", 0, 12)):toBe(true)
	end)

	it("refuses spots on the roll key of a real plot", function()
		local a, aData = world:join({ Name = "A" }, { EggInventory = { Linear = 3 } }, true)
		local plot = ownedPlot(a)
		local rollKey = plot.RollKey
		local spot = plot.Base.CFrame:PointToObjectSpace(rollKey.CFrame.Position)
		expect(world:invoke("PlaceEgg", a, "Linear", spot.X, spot.Z)):toBe(false)
		expect(#aData.PlacedEggs):toBe(0)
	end)

	it("removes every placed egg model on Destroy", function()
		local player = world:join({ Name = "Owner" }, { PlacedEggs = { { Id = "Linear", ReadyAt = 0, X = 8, Z = 12 } } }, true)
		local plot = ownedPlot(player)
		expect(#eggsOf(plot)):toBe(1)
		world:destroy()
		expect(#eggsOf(plot)):toBe(0)
	end)
end)

describe("Egg model and placement rules", function()
	local world, EggPlacement, EggModel, Eggs

	beforeEach(function()
		world = H.newWorld({ Time = startTime })
		EggPlacement = world:require("ReplicatedStorage.Utils.EggPlacement")
		EggModel = world:require("ReplicatedStorage.Utils.EggModel")
		Eggs = world:require("ReplicatedStorage.Config.Eggs")
	end)

	it("reports why a spot is refused", function()
		local size = Vector3.new(40, 1, 40)
		local rollKey = { X = 0, Z = -10, HalfX = 4, HalfZ = 4 }
		local placed = { { X = 10, Z = 10 } }
		expect(EggPlacement.Check(size, rollKey, placed, 0, 10)):toBe("Ok")
		expect(EggPlacement.Check(size, rollKey, placed, 18, 0)):toBe("Ok")
		expect(EggPlacement.Check(size, rollKey, placed, 18.5, 0)):toBe("Bounds")
		expect(EggPlacement.Check(size, rollKey, placed, 0, -9)):toBe("RollKey")
		expect(EggPlacement.Check(size, rollKey, placed, 11, 11)):toBe("Spacing")
		expect(EggPlacement.Check(size, rollKey, placed, 0 / 0, 0)):toBe("Invalid")
		expect(EggPlacement.Check(size, nil, {}, 0, -9)):toBe("Ok")
	end)

	it("finds free default spots away from the roll key and each other", function()
		local size = Vector3.new(44, 1, 44)
		local rollKey = { X = 0, Z = -10, HalfX = 4, HalfZ = 4 }
		local placed = {}
		for _ = 1, 3 do
			local spot = EggPlacement.FindSpot(size, rollKey, placed)
			expect(spot ~= nil):toBe(true)
			expect(EggPlacement.Check(size, rollKey, placed, spot.X, spot.Z)):toBe("Ok")
			table.insert(placed, spot)
		end
	end)

	it("builds a spotted egg in the tier color with a handle for tools", function()
		local parent = world:newInstance("Model")
		local egg = Eggs.ById.Rainbow
		local parts = EggModel.Build(parent, egg, { Scale = 1, BodyName = "Handle", Anchored = false })
		expect(#parts >= 8):toBe(true)
		expect(parts[1].Name):toBe("Handle")
		expect(parts[1].Color):toBe(egg.Color)
		expect(parent:FindFirstChild("EggSpot1").Color):toBe(egg.SpotColor)
		expect(parts[1].Anchored):toBe(false)
		expect(parent:FindFirstChild("EggWeld", true) ~= nil):toBe(true)
	end)

	it("tints a ghost egg translucent", function()
		local parent = world:newInstance("Model")
		local parts = EggModel.Build(parent, Eggs.ById.Linear, {
			Scale = 1,
			Anchored = true,
			Ghost = roblox.Color3.new(0, 1, 0),
		})
		for _, part in parts do
			expect(part.Transparency > 0.3):toBe(true)
			expect(part.CanCollide):toBe(false)
		end
		EggModel.Tint(parts, roblox.Color3.new(1, 0, 0))
		expect(parts[1].Color):toBe(roblox.Color3.new(1, 0, 0))
	end)
end)
