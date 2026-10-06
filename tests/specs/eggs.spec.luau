local H = require("../harness/Harness")

local describe, it, expect, beforeEach, afterEach = H.describe, H.it, H.expect, H.beforeEach, H.afterEach

local startTime = 1700000250

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

	local function hatch(slot: any): any
		return world:invoke("HatchEgg", player, slot)
	end

	local function equip(id: any, on: any): any
		return world:invoke("EquipCharm", player, id, on)
	end

	local function place(slot: number, eggId: string, readyAt: number)
		data.Incubators[slot] = eggId
		data.IncubatorReadyAt[slot] = readyAt
	end

	describe("hatching", function()
		it("rejects a hatch before the egg is ready and changes nothing", function()
			place(1, "Linear", world.now + 60)
			expect(hatch(1)):toBe("")
			expect(data.Incubators[1]):toBe("Linear")
			expect(data.IncubatorReadyAt[1]):toBe(world.now + 60)
			expect(data.Charms):toEqual({})
			world:advance(59)
			expect(hatch(1)):toBe("")
		end)

		it("hatches at the ready time and grants a charm from the egg table", function()
			place(2, "Golden", world.now + 30)
			world:advance(30)
			local charmId = hatch(2)
			expect(charmId ~= ""):toBe(true)
			local allowed = false
			for _, drop in Rules.Drops("Golden") do
				if drop.CharmId == charmId then
					allowed = true
				end
			end
			expect(allowed):toBe(true)
			expect(data.Charms[charmId]):toBe(1)
			expect(data.Incubators[2]):toBe("")
			expect(data.IncubatorReadyAt[2]):toBe(0)
			expect((world.saves[player] or 0) > 0):toBe(true)
		end)

		it("stacks duplicate charms", function()
			local counts = 0
			for _ = 1, 40 do
				place(1, "Linear", 0)
				if hatch(1) ~= "" then
					counts += 1
				end
			end
			expect(counts):toBe(40)
			local total = 0
			for _, count in data.Charms do
				total += count
			end
			expect(total):toBe(40)
			expect(next(data.Charms) ~= nil):toBe(true)
		end)

		it("only ever grants charms from each egg drop table", function()
			for _, egg in Eggs.Catalog do
				local allowed: { [string]: boolean } = {}
				for _, drop in Rules.Drops(egg.Id) do
					allowed[drop.CharmId] = true
				end
				for _ = 1, 60 do
					place(3, egg.Id, 0)
					expect(allowed[hatch(3)]):toBe(true)
				end
			end
		end)

		it("rejects empty incubators and invalid slots", function()
			expect(hatch(1)):toBe("")
			for _, slot in { 0, 4, -1, 1.5, "1", true, 0 / 0, math.huge } do
				place(1, "Linear", 0)
				expect(hatch(slot)):toBe("")
			end
			expect(hatch(nil)):toBe("")
			expect(data.Incubators[1]):toBe("Linear")
			expect(data.Charms):toEqual({})
		end)

		it("rejects unknown egg ids in an incubator", function()
			place(1, "Mystery", 0)
			expect(hatch(1)):toBe("")
			expect(data.Incubators[1]):toBe("Mystery")
		end)

		it("fails for players without data", function()
			local stranger = world:newPlayer()
			expect(world:invoke("HatchEgg", stranger, 1)):toBe("")
		end)

		it("hatches each incubator independently", function()
			place(1, "Linear", 0)
			place(3, "Tactile", world.now + 500)
			expect(hatch(1) ~= ""):toBe(true)
			expect(hatch(3)):toBe("")
			expect(data.Incubators):toEqual({ "", "", "Tactile" })
		end)
	end)

	describe("placing eggs", function()
		it("reports room and fills the first empty incubator", function()
			local service = world.registry.EggService
			expect(service:HasRoom(player)):toBe(true)
			expect(service:PlaceEgg(player, "Rainbow")):toBe(1)
			expect(data.IncubatorReadyAt[1]):toBe(world.now + Eggs.ById.Rainbow.HatchSeconds)
			expect(service:PlaceEgg(player, "Linear")):toBe(2)
			expect(service:PlaceEgg(player, "Linear")):toBe(3)
			expect(service:HasRoom(player)):toBe(false)
			expect(service:PlaceEgg(player, "Linear")):toBe(0)
			expect(service:PlaceEgg(player, "Nope")):toBe(0)
		end)
	end)

	describe("equipping", function()
		beforeEach(function()
			data.Charms = { ThockPad = 2, LuckyCable = 1, GoldSpacebar = 1, KeycapPin = 1 }
		end)

		it("equips owned charms and publishes them", function()
			expect(equip("ThockPad", true)):toBe(true)
			expect(data.EquippedCharms):toEqual({ "ThockPad" })
			expect(player:GetAttribute("EquippedCharms")):toBe("ThockPad")
			expect(equip("LuckyCable", true)):toBe(true)
			expect(player:GetAttribute("EquippedCharms")):toBe("ThockPad,LuckyCable")
		end)

		it("rejects unowned and unknown charms", function()
			expect(equip("DiamondSpacebar", true)):toBe(false)
			expect(equip("Nope", true)):toBe(false)
			expect(equip(5, true)):toBe(false)
			expect(equip("ThockPad", "yes")):toBe(false)
			expect(data.EquippedCharms):toEqual({})
		end)

		it("allows duplicates only up to the owned count", function()
			expect(equip("ThockPad", true)):toBe(true)
			expect(equip("ThockPad", true)):toBe(true)
			expect(equip("ThockPad", true)):toBe(false)
			expect(data.EquippedCharms):toEqual({ "ThockPad", "ThockPad" })
		end)

		it("stops at three equipped charms", function()
			expect(equip("ThockPad", true)):toBe(true)
			expect(equip("LuckyCable", true)):toBe(true)
			expect(equip("GoldSpacebar", true)):toBe(true)
			expect(equip("KeycapPin", true)):toBe(false)
			expect(#data.EquippedCharms):toBe(Charms.EquipLimit)
		end)

		it("unequips one copy at a time and rejects charms that are not equipped", function()
			expect(equip("ThockPad", false)):toBe(false)
			equip("ThockPad", true)
			equip("ThockPad", true)
			expect(equip("ThockPad", false)):toBe(true)
			expect(data.EquippedCharms):toEqual({ "ThockPad" })
			expect(equip("ThockPad", false)):toBe(true)
			expect(equip("ThockPad", false)):toBe(false)
			expect(player:GetAttribute("EquippedCharms")):toBe("")
		end)

		it("fails for players without data", function()
			local stranger = world:newPlayer()
			expect(world:invoke("EquipCharm", stranger, "ThockPad", true)):toBe(false)
		end)

		it("trims invalid equipped charms when data loads", function()
			local other, otherData = world:join(
				nil,
				{ Charms = { ThockPad = 1 }, EquippedCharms = { "ThockPad", "ThockPad", "Nope", "GoldSpacebar" } },
				true
			)
			expect(otherData.EquippedCharms):toEqual({ "ThockPad" })
			expect(other:GetAttribute("EquippedCharms")):toBe("ThockPad")
		end)
	end)

	describe("integration", function()
		it("raises settled income with an equipped income charm", function()
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
			expect(equip("ThockPad", true)):toBe(true)
			data.Cash = 0
			data.IncomeAt = world.now - 100
			world.registry.KeyboardService:Settle(player)
			expect(data.Cash):toBe(plain * 2)
		end)

		it("keeps persistence fields valid", function()
			local PlayerData = world:require("ServerScriptService.Data.PlayerData")
			data.Charms = { ThockPad = 1 }
			equip("ThockPad", true)
			place(1, "Linear", world.now + 10)
			expect(PlayerData.Validate(data)):toBe(true)
			expect(PlayerData.Validate(PlayerData.Template)):toBe(true)
			expect(#PlayerData.Template.Incubators):toBe(Eggs.Slots)
			expect(#PlayerData.Template.IncubatorReadyAt):toBe(Eggs.Slots)
		end)

		it("clears its packet handlers on Destroy", function()
			local hatchPacket, equipPacket = world:packets().HatchEgg, world:packets().EquipCharm
			expect(hatchPacket.OnServerInvoke ~= nil):toBe(true)
			expect(equipPacket.OnServerInvoke ~= nil):toBe(true)
			world:destroy()
			expect(hatchPacket.OnServerInvoke):toBeNil()
			expect(equipPacket.OnServerInvoke):toBeNil()
		end)
	end)
end)

describe("Base incubators", function()
	local world, plots, Eggs

	beforeEach(function()
		world = H.newWorld({ Time = startTime })
		Eggs = world:require("ReplicatedStorage.Config.Eggs")
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

	it("builds three incubators with domes and countdown labels on every plot", function()
		for _, plot in plots:GetChildren() do
			local folder = plot:FindFirstChild("Incubators")
			expect(folder ~= nil):toBe(true)
			for index = 1, Eggs.Slots do
				local model = folder:FindFirstChild(`Incubator{index}`)
				expect(model ~= nil):toBe(true)
				expect(model:FindFirstChild("Pedestal") ~= nil):toBe(true)
				expect(model:FindFirstChild("Dome") ~= nil):toBe(true)
				expect(model:FindFirstChild("EggBody") ~= nil):toBe(true)
				expect(model:FindFirstChild("Countdown", true).Enabled):toBe(false)
			end
		end
	end)

	it("places the incubators behind the board edge, off the key grid", function()
		local plot = plots:GetChildren()[1]
		local base = plot.Base
		local half = base.Size.Z / 2
		for index = 1, Eggs.Slots do
			local pedestal = plot.Incubators:FindFirstChild(`Incubator{index}`).Pedestal
			local local_ = base.CFrame:PointToObjectSpace(pedestal.CFrame.Position)
			expect(math.abs(local_.Z) > half):toBe(true)
			expect(math.abs(local_.X) < base.Size.X / 2):toBe(true)
			expect(pedestal.Anchored):toBe(true)
		end
	end)

	it("shows an owner's egg with a countdown and READY when it hatches", function()
		local player, data = world:join({ Name = "Owner" }, nil, true)
		local plot = ownedPlot(player)
		data.Incubators[2] = "Rainbow"
		data.IncubatorReadyAt[2] = world.now + 252
		world.registry.EggService:PlaceEgg(player, "Linear")
		local model = plot.Incubators.Incubator2
		expect(model:GetAttribute("EggId")):toBe("Rainbow")
		local first = plot.Incubators.Incubator1
		expect(first:GetAttribute("EggId")):toBe("Linear")
		expect(first:FindFirstChild("Countdown", true).Enabled):toBe(true)
		expect(first:FindFirstChild("Text", true).Text):toBe("Linear Egg\n2:00")
		expect(first.EggBody.Color):toBe(Eggs.ById.Linear.Color)
		expect(first.EggBody.Transparency):toBe(0)
		world:advance(120)
		expect(first:FindFirstChild("Text", true).Text):toBe("READY! Hold E")
		expect(plot.Incubators.Incubator3.EggBody.Transparency):toBe(1)
	end)

	it("clears the visuals when the owner leaves", function()
		local player = world:join({ Name = "Owner" }, nil, true)
		local plot = ownedPlot(player)
		world.registry.EggService:PlaceEgg(player, "Tactile")
		expect(plot.Incubators.Incubator1:GetAttribute("EggId")):toBe("Tactile")
		world:removePlayer(player)
		expect(plot.Incubators.Incubator1:GetAttribute("EggId")):toBe("")
		expect(plot.Incubators.Incubator1.EggBody.Transparency):toBe(1)
	end)

	it("keeps one owner's eggs off other bases", function()
		local a = world:join({ Name = "A" }, nil, true)
		local b = world:join({ Name = "B" }, nil, true)
		world.registry.EggService:PlaceEgg(a, "Clicky")
		expect(ownedPlot(a).Incubators.Incubator1:GetAttribute("EggId")):toBe("Clicky")
		expect(ownedPlot(b).Incubators.Incubator1:GetAttribute("EggId")):toBe("")
	end)
end)
