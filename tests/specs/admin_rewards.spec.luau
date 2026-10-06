local H = require("../harness/Harness")

local describe, it, expect, beforeEach = H.describe, H.it, H.expect, H.beforeEach

local rollPath = "StarterPlayer.StarterPlayerScripts.Controllers.RollController"
local hatchPath = "StarterPlayer.StarterPlayerScripts.Controllers.UIController.Screens.Hatch"

describe("AdminReward client dispatch", function()
	local world, AdminRewards, Eggs, Keys, keysShown, toasts, pops, handlers

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
		AdminRewards = world:require(`{rollPath}.AdminRewards`)
		Eggs = world:require("ReplicatedStorage.Config.Eggs")
		Keys = world:require("ReplicatedStorage.Config.Keys")
		keysShown, toasts, pops = {}, {}, 0
		handlers = {
			Key = function(keyId: string, order: number)
				table.insert(keysShown, { keyId, order })
			end,
			Toast = function(text: string, kind: string)
				table.insert(toasts, { text, kind })
			end,
			Pop = function()
				pops += 1
			end,
		}
	end)

	it("reveals one key per listed id in order", function()
		local ids = `{Keys.Catalog[1].Id},{Keys.Catalog[2].Id}`
		expect(AdminRewards.Dispatch(handlers, "Key", ids, 2)):toBe(true)
		expect(keysShown):toEqual({ { Keys.Catalog[1].Id, 1 }, { Keys.Catalog[2].Id, 2 } })
		expect(#toasts):toBe(0)
	end)

	it("caps visible key reveals at three and toasts the rest", function()
		local id = Keys.Catalog[1].Id
		AdminRewards.Dispatch(handlers, "Key", `{id},{id},{id}`, 10)
		expect(#keysShown):toBe(3)
		expect(toasts):toEqual({ { "+7 more", "Info" } })
	end)

	it("never reveals more than three even if more ids arrive", function()
		local id = Keys.Catalog[1].Id
		AdminRewards.Dispatch(handlers, "Key", `{id},{id},{id},{id},{id}`, 5)
		expect(#keysShown):toBe(3)
		expect(toasts):toEqual({ { "+2 more", "Info" } })
	end)

	it("toasts and pops for eggs", function()
		local egg = Eggs.ById.Golden
		expect(AdminRewards.Dispatch(handlers, "Egg", "Golden", 2)):toBe(true)
		expect(toasts):toEqual({ { `+2 {egg.Name} added to your backpack!`, "Good" } })
		expect(pops):toBe(1)
		expect(#keysShown):toBe(0)
	end)

	it("toasts and pops a compact amount for cash", function()
		expect(AdminRewards.Dispatch(handlers, "Cash", "1500000", 1)):toBe(true)
		expect(toasts):toEqual({ { "+1.5M Clicks", "Good" } })
		expect(pops):toBe(1)
	end)

	it("ignores bad payloads and leaves pets to the hatch screen", function()
		expect(AdminRewards.Dispatch(handlers, "Egg", "Nope", 1)):toBe(false)
		expect(AdminRewards.Dispatch(handlers, "Cash", "abc", 1)):toBe(false)
		expect(AdminRewards.Dispatch(handlers, "Pet", "KeycapPin", 1)):toBe(false)
		expect(AdminRewards.Dispatch(handlers, "Mystery", "x", 1)):toBe(false)
		expect(#keysShown + #toasts + pops):toBe(0)
	end)
end)

describe("Hatch screen admin reveal", function()
	local world, playerGui, context, opened, Charms

	local function build()
		return world:require(hatchPath).new(context)
	end

	beforeEach(function()
		world = H.newWorld({ PrintErrors = false })
		Charms = world:require("ReplicatedStorage.Config.Charms")
		playerGui = world:newInstance("Folder")
		opened = {}
		context = {
			Controllers = {
				DataController = {
					Get = function()
						return {}
					end,
				},
			},
			PlayerGui = playerGui,
			Open = function(name: string)
				table.insert(opened, name)
			end,
			Close = function() end,
			IsOpen = function()
				return false
			end,
			Toast = function() end,
		}
	end)

	it("plays the hatch reveal for a pet reward packet", function()
		build()
		local pet = Charms.Catalog[1]
		world:packets().AdminReward.OnClientEvent:Fire("Pet", pet.Id, 1)
		world:flush()
		expect(opened):toEqual({ "Hatch" })
		local label = playerGui:FindFirstChild("PetName", true)
		expect(label ~= nil):toBe(true)
		expect(label.Text):toBe(pet.Name)
	end)

	it("ignores other reward kinds and unknown pets", function()
		local screen = build()
		world:packets().AdminReward.OnClientEvent:Fire("Key", "PlainClack", 1)
		world:packets().AdminReward.OnClientEvent:Fire("Pet", "Nope", 1)
		expect(opened):toEqual({})
		expect(screen:Reveal("Nope")):toBe(false)
	end)

	it("exposes Reveal for a pet id", function()
		local screen = build()
		expect(screen:Reveal(Charms.Catalog[2].Id)):toBe(true)
		expect(opened):toEqual({ "Hatch" })
	end)
end)
